import 'package:flutter/foundation.dart';

/// 숙소 찜(하트) 상태.
///
/// 같은 숙소가 최소 세 화면에 동시에 떠 있을 수 있다.
/// 숙소 목록, 숙소 상세, 마이페이지 즐겨찾기 탭.
/// 목록에서 하트를 눌렀는데 상세로 들어가니 안 눌려 있으면 사용자는 저장이 안 됐다고 생각한다.
///
/// 그래서 찜 상태를 화면이 아니라 여기에 둔다.
/// 화면들은 이 값을 구독만 하고, 어느 화면에서 바꾸든 모두가 같은 값을 본다.
class HouseWishProvider with ChangeNotifier {
  /// house_id -> 찜 여부(0 또는 1).
  ///
  /// 서버가 0/1 정수로 내려주기 때문에 bool로 바꾸지 않고 그대로 받는다.
  final Map<int, int> house_wish_status = {};

  int getWishStatus(int house_id) => house_wish_status[house_id] ?? 0;

  void setWishStatus(int house_id, int status) {
    house_wish_status[house_id] = status;
    notifyListeners();
  }

  void toggleWishStatus(int house_id) {
    setWishStatus(house_id, getWishStatus(house_id) == 1 ? 0 : 1);
  }

  /// 목록 응답이 오면 여러 숙소의 상태를 한 번에 채운다.
  ///
  /// 숙소마다 setWishStatus를 부르면 20번 호출에 리빌드가 20번 일어난다.
  /// 한 번에 넣고 알림도 한 번만 보낸다.
  void setMultipleWishStatus(Map<int, int> status_map) {
    house_wish_status.addAll(status_map);
    notifyListeners();
  }

  /// 로그아웃 시 호출. 다음 사용자에게 이전 계정의 찜이 남아 보이면 안 된다.
  void clear() {
    house_wish_status.clear();
    notifyListeners();
  }
}
