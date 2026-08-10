import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// 앱의 모든 REST 요청이 지나가는 단일 통로.
///
/// 두 가지 일을 한다.
///  1. 401 응답을 만나면 토큰을 갱신하고 원래 요청을 한 번 재시도한다.
///     이때 갱신 요청이 중복으로 나가지 않도록 락을 건다.
///  2. 서버에서 내려온 문자열을 화면에 그리기 전에 한 번 걸러낸다.
class ApiClient {
  static final ApiClient _instance = ApiClient._internal();

  factory ApiClient() => _instance;

  ApiClient._internal();

  /// 현재 갱신이 진행 중인지.
  bool _is_refreshing = false;

  /// 진행 중인 갱신 작업 그 자체.
  /// 뒤늦게 401을 만난 요청들은 새 갱신을 시작하지 않고 이 Future를 함께 기다린다.
  Future<bool>? _refresh_token_future;

  Future<Map<String, String>> _getHeaders(Map<String, String>? customHeaders) async {
    final prefs = await SharedPreferences.getInstance();
    final String? access_token = prefs.getString('access_token');

    final Map<String, String> headers = {
      'Content-Type': 'application/x-www-form-urlencoded',
      if (customHeaders != null) ...customHeaders,
    };

    if (access_token != null && access_token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $access_token';
    }
    return headers;
  }

  /// 토큰 갱신의 유일한 진입점.
  ///
  /// 앱을 켜면 홈 탭 하나가 5~6개의 요청을 동시에 던진다.
  /// 토큰이 만료된 상태라면 그 요청들이 전부 401을 받고 동시에 갱신을 시도하는데,
  /// 서버가 리프레시 토큰을 1회용으로 회전시키기 때문에 먼저 도착한 하나만 성공하고
  /// 나머지는 이미 폐기된 토큰으로 요청하다 로그아웃까지 갔다.
  ///
  /// 그래서 갱신을 "함수 호출"이 아니라 "공유되는 Future"로 다룬다.
  /// 먼저 온 쪽이 락을 잡고 작업을 시작하고, 나머지는 같은 Future를 await 한다.
  /// 서버로 나가는 리프레시 요청은 항상 정확히 한 번이다.
  Future<bool> handleTokenRefresh() async {
    if (_is_refreshing && _refresh_token_future != null) {
      return await _refresh_token_future!;
    }

    _is_refreshing = true;
    _refresh_token_future = refreshAccessToken().then((is_success) {
      _is_refreshing = false;
      _refresh_token_future = null;
      return is_success;
    });

    return await _refresh_token_future!;
  }

  Future<http.Response> get(Uri url, {Map<String, String>? headers}) async {
    var response = await http.get(url, headers: await _getHeaders(headers));

    // 갱신에 성공하면 새 토큰으로 한 번만 재시도한다.
    // 갱신마저 실패한 경우의 세션 정리는 구현되지 않은 채로 남았다. (README 아쉬운 점 참고)
    if (response.statusCode == 401 && await handleTokenRefresh()) {
      response = await http.get(url, headers: await _getHeaders(headers));
    }

    return _sanitizeHttpResponse(response);
  }

  Future<http.Response> post(Uri url, {Map<String, String>? headers, Object? body}) async {
    var response = await http.post(url, headers: await _getHeaders(headers), body: body);

    if (response.statusCode == 401 && await handleTokenRefresh()) {
      response = await http.post(url, headers: await _getHeaders(headers), body: body);
    }

    return _sanitizeHttpResponse(response);
  }

  /// 응답 본문을 파싱해 문자열을 정제한 뒤 새 Response로 다시 포장한다.
  ///
  /// 커뮤니티 글·닉네임·채팅은 전부 사용자가 쓴 값이라, 결합 문자를 잔뜩 쌓아
  /// 글자를 위아래로 흘러넘치게 만드는 입력(이른바 Zalgo 텍스트)이 들어오면
  /// 리스트 한 줄이 다른 게시글 영역까지 침범해 화면이 깨졌다.
  ///
  /// 서버에서도 막지만, 이미 저장된 데이터와 다른 경로로 들어오는 값이 있어
  /// 그리기 직전인 클라이언트에도 같은 방어선을 하나 더 뒀다.
  http.Response _sanitizeHttpResponse(http.Response response) {
    try {
      if (response.body.isEmpty) return response;

      final sanitized = sanitizeResponseData(json.decode(response.body));

      // 글자를 잘라내면 본문 길이가 달라진다.
      // content-length를 그대로 두면 실제 바이트 수와 어긋나므로 제거한다.
      final new_headers = Map<String, String>.from(response.headers)..remove('content-length');

      return http.Response(
        json.encode(sanitized),
        response.statusCode,
        headers: new_headers,
        isRedirect: response.isRedirect,
        persistentConnection: response.persistentConnection,
        reasonPhrase: response.reasonPhrase,
        request: response.request,
      );
    } catch (_) {
      // JSON이 아닌 응답(HTML 에러 페이지, 평문 등)은 건드리지 않고 그대로 넘긴다.
      return response;
    }
  }

  /// 응답이 어떤 모양이든 문자열 리프까지 내려가 정제한다.
  /// 서버 응답 스키마가 도메인마다 달라서, 특정 필드를 지정하는 대신 전체를 훑는다.
  dynamic sanitizeResponseData(dynamic data) {
    if (data is String) {
      // 결합 문자(Unicode Mark)가 3개 이상 연달아 붙은 구간을 제거한다.
      // 한글 자모나 일반적인 발음 구별 기호는 이 길이를 넘지 않는다.
      return data.replaceAll(RegExp(r'\p{M}{3,}', unicode: true), '');
    }
    if (data is List) {
      return data.map(sanitizeResponseData).toList();
    }
    if (data is Map<String, dynamic>) {
      return data.map((key, value) => MapEntry(key, sanitizeResponseData(value)));
    }
    return data;
  }
}

final apiClient = ApiClient();
