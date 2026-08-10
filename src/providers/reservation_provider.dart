import 'package:flutter/foundation.dart';

/// 예약 변동을 다른 화면에 알리는 신호.
///
/// 호스트가 캘린더 화면에서 예약을 수락해도, 이미 만들어져 있는 숙소 관리 화면은
/// 자기가 다시 빌드되기 전까지 예전 값을 그대로 들고 있었다.
/// 분명히 처리한 예약이 다른 화면에서는 계속 "대기 중"으로 보였다.
///
/// 여기서 필요한 건 데이터 자체가 아니라 "다시 불러와야 한다"는 사실이다.
/// 그래서 예약 목록을 통째로 공유하는 대신 플래그 하나만 공유한다.
/// 목록을 공유하면 두 화면이 서로 다른 필터·정렬·페이지를 쓰기 때문에 곧 어긋난다.
class ReservationProvider with ChangeNotifier {
  bool _should_refresh = false;
  int _refresh_count = 0;

  bool get should_refresh => _should_refresh;

  /// 화면이 이미 떠 있는 동안 변동이 두 번 이상 일어났는지 구분하는 데 쓴다.
  /// 플래그만으로는 "true에서 true로" 바뀐 경우를 알 수 없다.
  int get refresh_count => _refresh_count;

  /// 예약을 수락·취소한 쪽에서 호출한다.
  void refreshSchedules() {
    _should_refresh = true;
    _refresh_count++;
    notifyListeners();
  }

  /// 다시 불러오기를 마친 화면이 호출한다.
  ///
  /// 이 호출을 빠뜨리면 플래그가 계속 true로 남아 같은 요청이 반복된다.
  /// 플래그 방식에서 가장 흔하게 밟는 지점이다.
  void resetRefreshFlag() {
    _should_refresh = false;
    notifyListeners();
  }
}
