# 상태 관리

> 전역 변수가 못 하는 한 가지 · 리빌드 범위를 좁히는 법

[← 목록으로](../README.md#문서)

---

## 문제

호스트가 예약 캘린더에서 예약을 수락합니다. 그리고 뒤로 나와 숙소 관리 화면을 봅니다. 거기에는 방금 수락한 예약이 여전히 "**대기 중**"으로 떠 있습니다.

새로고침을 하면 정상으로 보입니다. 앱을 껐다 켜도 정상입니다. 하지만 사용자 입장에서는 "**내가 누른 게 안 먹혔나?**"입니다. 그래서 한 번 더 누릅니다.

이건 데이터가 틀린 문제가 아닙니다. **화면이 자기가 들고 있는 값이 낡았다는 사실을 모르는** 문제입니다.

---

## 01 · 왜 전역 변수로는 안 되나

초기에는 전역 변수와 싱글톤에 값을 담았습니다. 저장은 잘 됐습니다. 문제는 그다음이었습니다.

> **Flutter 위젯은 `setState()`가 호출된 위젯 트리 내부에서만 다시 그려집니다.**

전역 변수의 값이 바뀌는 것 자체는 아무 일도 일으키지 않습니다. 캘린더 화면에서 값을 바꿔도, 이미 만들어져 있는 숙소 관리 화면은 자기가 다시 빌드될 이유가 없으므로 예전 값을 그대로 들고 있습니다.

| 방식 | 데이터 저장 | 변경 감지 | 다른 화면 반영 |
|---|---|---|---|
| 전역 변수 · 싱글톤 | 가능 | **없음** | 화면을 다시 들어가야 반영 |
| Provider (ChangeNotifier) | 가능 | `notifyListeners()` | 구독 중인 화면이 즉시 리빌드 |

정리하면 이렇습니다.

> 변수 방식은 **"저장"까지만** 해결했을 뿐, "**구독 → 알림 → 리빌드**" 라는 연결고리가 통째로 빠져 있었습니다.

Provider가 해결한 문제는 "**데이터가 바뀌었다는 사실을 누구에게 언제 알릴 것인가**"입니다. 데이터를 어디에 둘 것인가는 전역 변수로도 됐습니다.

---

## 02 · 무엇을 공유할지 고르기

여기서 갈림길이 있었습니다. **예약 목록 자체를 공유할 것인가, 아니면 "바뀌었다"는 사실만 공유할 것인가.**

목록을 통째로 공유하는 쪽이 처음엔 깔끔해 보였습니다. 그런데 실제로는 화면마다 보는 게 다릅니다.

- 캘린더 화면 — 날짜별로 묶인 예약
- 숙소 관리 화면 — 상태별로 필터링된 예약, 페이지네이션 적용
- 정산 화면 — 기간별로 합산된 금액

같은 "예약"이지만 필터도, 정렬도, 페이지도 다릅니다. 하나의 목록을 공유하면 어느 화면 기준으로 정렬할지부터 싸우게 되고, 결국 각 화면이 다시 가공하게 됩니다.

그래서 **필요한 만큼만 공유하는** 두 가지 형태로 나눴습니다.

### 형태 ①: 값을 공유한다 — 찜 상태

같은 값이 여러 화면에 동시에 떠 있고, 화면마다 가공할 필요가 없는 경우입니다.

```dart
class HouseWishProvider with ChangeNotifier {
  final Map<int, int> house_wish_status = {};   // house_id -> 0 또는 1

  int getWishStatus(int house_id) => house_wish_status[house_id] ?? 0;

  void setWishStatus(int house_id, int status) {
    house_wish_status[house_id] = status;
    notifyListeners();
  }

  /// 목록 응답이 오면 한 번에 채운다.
  /// 숙소마다 setWishStatus를 부르면 20번 호출에 리빌드가 20번 일어난다.
  void setMultipleWishStatus(Map<int, int> status_map) {
    house_wish_status.addAll(status_map);
    notifyListeners();
  }
}
```

하트 상태는 숙소 목록 · 숙소 상세 · 마이페이지 즐겨찾기 탭에 동시에 나타납니다. 목록에서 눌렀는데 상세에 반영이 안 되면 저장이 안 된 것처럼 보입니다. 값 자체를 한 곳에 두는 게 맞습니다.

### 형태 ②: 신호만 공유한다 — 예약 변동

```dart
class ReservationProvider with ChangeNotifier {
  bool _should_refresh = false;
  int _refresh_count = 0;

  bool get should_refresh => _should_refresh;
  int get refresh_count => _refresh_count;

  void refreshSchedules() {          // 예약을 수락·취소한 쪽이 호출
    _should_refresh = true;
    _refresh_count++;
    notifyListeners();
  }

  void resetRefreshFlag() {          // 다시 불러오기를 마친 화면이 호출
    _should_refresh = false;
    notifyListeners();
  }
}
```

여기서 필요한 건 데이터가 아니라 **"다시 불러와야 한다"는 사실**뿐입니다. 각 화면은 신호를 받고 자기 방식대로 다시 조회합니다.

> [!NOTE]
> `_refresh_count`가 왜 필요한가: 플래그만 있으면 "**true에서 다시 true로**" 바뀐 경우를 구분할 수 없습니다. 화면이 떠 있는 동안 예약이 두 번 바뀌면 두 번째 변동을 놓칩니다. 카운터는 그 경우를 잡아줍니다.

---

## 03 · 플래그를 종류별로 쪼개기

<div align="center">
<img src="../assets/demos/host_revenue.gif" width="260" /><br>
<sub>호스트 정산 화면 · 예약이 바뀔 때마다 수익 · 달력 · 숙소 관리가 함께 갱신되어야 합니다</sub>
</div>

<br>

호스트 콘솔에서는 플래그를 하나만 두면 문제가 생깁니다. 방 이름 하나를 고쳤는데 이벤트 목록과 예약 현황까지 전부 다시 불러옵니다. 호스트 쪽 응답은 무거운 편이라 이 낭비가 눈에 띄었습니다.

그래서 **무엇이 바뀌었는지를 종류별로** 들고 있습니다.

```dart
bool _should_refresh_rooms = false;
bool _should_refresh_events = false;
bool _should_refresh_reservations = false;
```

방 관리 화면은 방 플래그만, 이벤트 관리 화면은 이벤트 플래그만 봅니다. 서로의 데이터를 건드리지 않습니다.

숙소를 전환할 때는 반대로 **전부 비우고 전부 세웁니다.**

```dart
void switchHouse(int house_id) {
  _current_house_id = house_id;
  _room_list.clear();
  _event_list.clear();
  // ...
  _should_refresh_rooms = true;
  _should_refresh_events = true;
  _should_refresh_reservations = true;
  notifyListeners();
}
```

비우지 않으면 이전 숙소의 방 목록이 새 숙소 화면에 잠깐 스쳐 보입니다. 데이터가 곧 교체되더라도 그 찰나가 사용자에게는 버그로 보입니다.

---

## 04 · 리빌드 범위가 성능을 가른다

Provider를 붙이는 것보다 **어떻게 구독하느냐**가 실제 성능을 갈랐습니다.

| 방법 | 리빌드 범위 |
|---|---|
| `context.watch<T>()` · `Provider.of<T>(context)` | **위젯 전체** |
| `Consumer<T>` | **감싼 영역만** |
| `Provider.of<T>(context, listen: false)` | 리빌드 없음 (값 변경 전용) |

무한 스크롤되는 숙소 목록에서 이 차이가 극명했습니다.

```dart
// 목록 전체를 watch로 구독하면
// 하트 하나를 눌렀을 때 화면의 모든 카드가 다시 그려진다
final wish = context.watch<HouseWishProvider>();

// Consumer로 하트 아이콘만 감싸면
// 그 아이콘 하나만 다시 그려진다
Consumer<HouseWishProvider>(
  builder: (context, wish, _) => Icon(
    wish.getWishStatus(house.id) == 1 ? Icons.favorite : Icons.favorite_border,
  ),
)
```

카드에는 이미지 · 텍스트 · 별점 · 태그가 들어 있습니다. 하트 색 하나 바꾸자고 이걸 전부 다시 그리면 스크롤이 눈에 띄게 걸립니다.

> [!IMPORTANT]
> 반대 방향으로도 틀릴 수 있습니다. `listen: false`만 쓰면 값은 바뀌는데 화면에 아무 반응이 없습니다. "**바꾸기만 할 때는 `listen: false`, 보여줄 때는 `Consumer`**" 로 정리하면 대부분 맞습니다.

---

## 트레이드오프

| 주의할 점 | 증상 |
|---|---|
| 구독 범위를 넓게 잡음 | 관계없는 위젯까지 리빌드 · 스크롤이 걸림 |
| `listen: false` 남용 | 값은 바뀌는데 화면이 그대로 |
| 플래그를 리셋하지 않음 | 같은 요청이 무한 반복 |
| Provider 개수가 늘어남 | 어떤 화면이 무엇을 구독하는지 추적이 어려워짐 |

마지막 항목이 실제로 부담이 됐습니다. **최종적으로 ChangeNotifier가 32개**까지 늘었고, 그중 31개가 한 파일에 모여 있습니다. 새로 합류한 사람이 "이 값은 어디서 바뀌나"를 찾으려면 파일 전체를 읽어야 합니다.

지금 다시 만든다면 도메인별로 파일을 나누고, 화면 간 공유가 정말 필요한 것과 화면 안에서 끝나는 것을 더 엄격하게 구분할 것 같습니다. 스크롤 위치 보존 같은 건 굳이 전역에 있을 이유가 없었습니다.

Provider 자체는 후회 없는 선택이었습니다. `InheritedWidget` 위에 얇게 얹힌 구조라 새로 배울 것이 적었고, 팀에서 상태 관리 라이브러리 학습에 시간을 쓸 여유가 없었기 때문입니다.

---

## 마치며

이 작업에서 배운 건 **공유의 단위를 정하는 감각**이었습니다. 라이브러리 사용법을 익히는 일과는 다른 문제였습니다.

값을 공유할지, 신호만 공유할지. 이 갈림길이 먼저였습니다. 플래그는 하나로 묶지 않고 종류별로 쪼갰고, 구독 범위는 하트 아이콘 하나까지 좁혔습니다. 이 세 가지 판단이 성능과 유지보수를 결정했고, 라이브러리는 그 판단을 실행하는 도구였을 뿐입니다.

---

**관련 코드** → [`src/providers/`](../src/providers)
**관련 글** → [상태 관리가 필요했던 순간: 변수에서 Provider로](https://yeohaenghage.kr/frontend/flutter_provider)
**다음 문서** → [API 클라이언트](04-api-client.md)
