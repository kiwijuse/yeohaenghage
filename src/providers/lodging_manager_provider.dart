import 'package:flutter/foundation.dart';

/// 호스트 콘솔이 공유하는 숙소 상태.
///
/// 호스트 쪽은 화면이 40개가 넘고, 대부분이 "목록 → 항목 선택 → 항목 수정" 형태로 깊게 들어간다.
/// 수정 화면에서 방 이름을 바꾸고 뒤로 나오면, 세 단계 위의 목록 화면도 함께 바뀌어 있어야 한다.
///
/// 그래서 방·이벤트·예약 현황을 이 한 곳에 모아 두고 화면들은 구독만 한다.
class LodgingManagerProvider with ChangeNotifier {
  int _current_house_id = 0;
  bool _is_loading = false;

  final Map<int, RoomInfo> _room_list = {};
  final List<Event> _event_list = [];

  Map<DateTime, ReservationCount> _lodging_reservation = {};
  Map<DateTime, ReservationCount> _event_reservation = {};

  // 바깥에서는 읽기만 가능하게 열어 둔다.
  // 리스트를 직접 수정하면 notifyListeners가 불리지 않아 화면이 조용히 어긋난다.
  int get current_house_id => _current_house_id;
  bool get is_loading => _is_loading;
  Map<int, RoomInfo> get room_list => _room_list;
  List<Event> get event_list => _event_list;
  Map<DateTime, ReservationCount> get lodging_reservation => _lodging_reservation;
  Map<DateTime, ReservationCount> get event_reservation => _event_reservation;

  // ───────────────────────────────────────────────────────────
  // 새로고침 플래그
  //
  // 플래그를 하나로 두면 방을 하나 고쳤을 때 이벤트 목록과 예약 현황까지 전부 다시 불러온다.
  // 호스트 화면은 응답이 무거운 편이라 그 낭비가 눈에 띄었다.
  //
  // 그래서 "무엇이 바뀌었는지"를 종류별로 나눠 들고 있는다.
  // 방 관리 화면은 방 플래그만, 이벤트 관리 화면은 이벤트 플래그만 본다.
  // ───────────────────────────────────────────────────────────

  bool _should_refresh_rooms = false;
  bool _should_refresh_events = false;
  bool _should_refresh_reservations = false;

  bool get should_refresh_rooms => _should_refresh_rooms;
  bool get should_refresh_events => _should_refresh_events;
  bool get should_refresh_reservations => _should_refresh_reservations;

  void markRoomsChanged() {
    _should_refresh_rooms = true;
    notifyListeners();
  }

  void markEventsChanged() {
    _should_refresh_events = true;
    notifyListeners();
  }

  void markReservationsChanged() {
    _should_refresh_reservations = true;
    notifyListeners();
  }

  void clearRoomsFlag() {
    _should_refresh_rooms = false;
  }

  void clearEventsFlag() {
    _should_refresh_events = false;
  }

  void clearReservationsFlag() {
    _should_refresh_reservations = false;
  }

  /// 호스트가 운영하는 숙소를 전환할 때 호출한다.
  ///
  /// 숙소가 바뀌면 들고 있던 방·이벤트·예약은 전부 다른 숙소의 것이 된다.
  /// 비우지 않으면 이전 숙소의 방 목록이 잠깐 스쳐 보인다.
  void switchHouse(int house_id) {
    _current_house_id = house_id;
    _room_list.clear();
    _event_list.clear();
    _lodging_reservation = {};
    _event_reservation = {};
    _should_refresh_rooms = true;
    _should_refresh_events = true;
    _should_refresh_reservations = true;
    notifyListeners();
  }
}
