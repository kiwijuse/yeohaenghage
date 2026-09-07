# 라이브러리를 포크한 이야기

> 없는 기능을 만들어 넣고, 손가락 떨림 때문에 죽던 제스처를 되살린 이야기

[← 목록으로](../README.md#깊이-들어간-이야기)

---

## 문제

커뮤니티에 올라온 사진을 눌러 크게 봅니다. 여기서 나가려면 왼쪽 위 X를 눌러야 합니다.

인스타그램이나 카카오톡에서는 그렇게 하지 않습니다. **사진을 아래로 쓱 내리면 닫힙니다.** 손가락이 이미 사진 위에 있으니 구석의 작은 X까지 갈 이유가 없습니다.

우리도 그렇게 만들고 싶었습니다. 쓰던 라이브러리는 `photo_view` 0.15.0이었고, 문서를 뒤졌지만 그런 옵션이 없었습니다. 소스를 열어 봤습니다.

<div align="center">
<img src="../assets/demos/photo_drag.gif" width="260" /><br>
<sub>만들고 싶었던 동작 · 손가락을 내린 만큼 사진이 따라 내려가고, 충분히 내리면 닫힙니다</sub>
</div>

<br>

---

## 01 · 원본에 없던 것

`photo_view`는 두 겹입니다. 사진 한 장을 확대·이동시키는 `PhotoView`가 있고, 그것들을 좌우로 넘기게 묶은 `PhotoViewGallery`가 있습니다. 우리가 쓰는 건 갤러리 쪽입니다.

갤러리 소스를 열어 보니 세로 방향 제스처를 받는 코드가 한 줄도 없었습니다. `GestureDetector` 자체가 없고, `PageView.builder`가 좌우 넘김만 처리합니다. 옵션을 못 찾은 게 아니라 기능이 없었습니다.

> [!NOTE]
> 이 저장소의 예전 판에는 "원본에 확대가 끝나는 시점을 알려주는 콜백이 없었다"고 적혀 있었습니다. **사실이 아니라서 고쳤습니다.** `onScaleEnd`는 원본에 이미 있었고, 최소한 0.12.0(2021년)부터 있었습니다. 없던 것은 콜백이 아니라 세로 드래그 처리 전체였습니다.

없으면 만들어야 합니다. 그런데 만들려고 보니 진짜 문제는 다른 데 있었습니다.

---

## 02 · 갤러리는 자기가 확대 중인지 모른다

세로로 내리면 닫는다고 정하자 바로 부딪히는 상황이 나왔습니다.

사진을 두 배로 확대해 놓고 아래쪽을 보려고 손가락을 내리면 어떻게 될까요. 사용자 의도는 "확대한 사진을 위로 밀어 아래를 보는 것"인데, 화면은 "아래로 내렸으니 닫자"로 알아듣습니다. 사진을 들여다보려 할 때마다 뷰어가 닫힙니다.

그러니까 갤러리가 **지금 이 사진이 확대돼 있는지**를 알아야 합니다. 확대돼 있으면 세로 드래그는 사진 이동이고, 원래 크기면 닫기 동작입니다.

문제는 그 정보가 갤러리에 없다는 것입니다. 확대 배율은 사진 한 장을 그리는 안쪽 `PhotoView`가 들고 있습니다. 갤러리는 그것들을 페이지로 늘어놓기만 할 뿐, 각 장이 지금 얼마나 확대돼 있는지 모릅니다.

---

## 03 · 이미 있던 신호를 가로채기

새 콜백을 만들어 안쪽부터 바깥까지 배선을 새로 깔 수도 있었습니다. 그렇게 하지 않았습니다.

`PhotoView`에는 `scaleStateChangedCallback`이라는 게 원래 있습니다. 확대 상태가 바뀔 때마다 불리고, 갤러리는 이 값을 그냥 사용자에게 전달만 하고 있었습니다. 갤러리가 지나가는 길목에 서 있으면서 내용물을 안 보고 있었던 셈입니다.

그래서 **갤러리가 자기 함수를 대신 끼워 넣고, 값을 읽은 다음 원래 받을 사람에게 넘기도록** 바꿨습니다.

```dart
void scaleStateChangedCallback(PhotoViewScaleState scaleState) {
  setState(() {
    _isScaled = scaleState != PhotoViewScaleState.initial;
  });

  if (widget.scaleStateChangedCallback != null) {
    widget.scaleStateChangedCallback!(scaleState);
  }
}
```

각 페이지를 만들 때 사용자가 넘긴 콜백 대신 이 함수를 꽂아 줍니다. 사용자 쪽에서 보면 달라진 게 없습니다. 자기가 등록한 콜백은 그대로 불립니다. 다만 그전에 갤러리가 한 번 들여다봅니다.

이 방식의 좋은 점은 **앱 코드를 한 줄도 고치지 않아도 된다**는 것입니다. 우리 사진 뷰어는 `scaleStateChangedCallback`을 아예 넘기지 않는데도 쓸어내려 닫기가 동작합니다.

---

## 04 · 값 하나가 세 곳을 가른다

`_isScaled`가 생기고 나니 갈라야 할 곳이 셋이었습니다.

**세로 드래그를 받을지 말지.** 확대 중이면 드래그 처리를 통째로 건너뜁니다.

**좌우 넘김을 허용할지 말지.** 확대한 상태에서 옆으로 밀면 다음 사진으로 넘어가 버립니다. 확대 중에는 페이지 스크롤을 막습니다.

```dart
ScrollPhysics _getScrollPhysics() {
  if (_isScaled) {
    return const NeverScrollableScrollPhysics();
  }
  return widget.scrollPhysics ?? const PageScrollPhysics();
}
```

마지막은 위젯 트리를 어떻게 그리느냐입니다. 확대 중이면 드래그를 받는 `GestureDetector`로 감싸지 않습니다. 감싸 두고 안에서 무시하는 방법도 있지만, 제스처 인식기는 존재하는 것만으로 다른 제스처와 경합합니다. 아예 트리에서 빼는 쪽이 확실했습니다.

---

## 05 · 내리는 동안과 놓은 다음

드래그 자체는 단순합니다. 내린 거리만큼 사진을 아래로 옮기고, 손을 뗐을 때 얼마나 내렸는지로 판단합니다.

```dart
onVerticalDragEnd: (details) {
  if (!_isScaled && _isVerticalDrag) {
    if (_dragDistance.abs() > _dragThreshold) {
      Navigator.of(context).pop();
    } else {
      // 임계값에 못 미치면 제자리로 되돌린다
      _offsetTween = Tween(begin: _offset, end: Offset.zero);
      _offsetAnimation = _offsetTween.animate(
        CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
      );
      _animationController
        ..value = 0.0
        ..forward();
    }
  }
}
```

임계값은 100입니다. 이 값이 작으면 사진을 살짝 건드렸을 뿐인데 닫히고, 크면 한참 내려도 안 닫혀서 답답합니다. 손으로 여러 번 만져 보고 정했습니다.

되돌아갈 때 `Curves.easeOut`을 쓴 건 [UX 문서](08-ux-details.md#04--애니메이션에는-적정-구간이-있다)에 적은 이유와 같습니다. 현실의 물건은 등속으로 멈추지 않습니다.

신경 쓴 곳은 되돌아가는 애니메이션이 **아직 도는 중에 사용자가 다시 잡는 경우**입니다.

```dart
onVerticalDragStart: (details) {
  if (!_isScaled) {
    _isVerticalDrag = true;
    _dragDistance = 0.0;

    if (_animationController.isAnimating) {
      _animationController.stop();
      _offset = _offsetAnimation.value;   // 지금 있는 자리에서 이어받는다
    }
  }
}
```

이걸 빼먹으면 사진이 올라가던 도중에 손을 대는 순간 원래 자리로 순간이동합니다. 애니메이션을 멈추고 **그 시점의 위치를 새 출발점으로 삼아야** 손가락에 붙어 있는 느낌이 납니다.

---

## 06 · 정확히 같은 자리를 눌러야 먹히던 더블탭

사진을 두 번 두드리면 확대되는 동작이 있습니다. 그런데 잘 안 됐습니다.

되긴 되는데 **손가락을 아주 가만히 두고 정확히 같은 자리를 눌러야** 했습니다. 조금이라도 흔들리면 아무 일도 일어나지 않습니다. 될 때도 있고 안 될 때도 있으니 버그로 잡기도 애매했습니다.

<div align="center">
<img src="../assets/demos/photo_doubletap.gif" width="260" /><br>
<sub>고친 뒤 · 손가락이 살짝 흔들리는 탭으로 찍었습니다</sub>
</div>

<br>

### 왜 그랬나

화면 하나에 제스처 인식기가 여럿 붙어 있습니다. 두 번 두드리기를 보는 쪽과, 손가락을 벌려 확대하는 쪽이 같은 터치를 동시에 지켜봅니다. 둘 중 하나가 "이건 내 제스처다"라고 선언하면 나머지는 물러납니다.

확대 인식기가 너무 일찍 손을 드는 게 문제였습니다. 원본 코드는 이랬습니다.

```dart
void _decideIfWeAcceptEvent(PointerEvent event) {
  if (!(event is PointerMoveEvent)) {
    return;
  }
  final move = _initialFocalPoint! - _currentFocalPoint!;
  final bool shouldMove = hitDetector!.shouldMove(move, validateAxis!);
  if (shouldMove || _pointerLocations.keys.length > 1) {
    acceptGesture(event.pointer);   // 여기서 제스처를 가져간다
  }
}
```

손가락이 움직였다는 신호가 오면 곧바로 확대 제스처로 확정합니다. 그런데 사람의 손가락은 화면에 닿는 순간에도 가만히 있지 않습니다. 누르고 떼는 사이에 몇 픽셀씩 미세하게 흔들립니다. 그 흔들림이 "움직였다"로 잡히면서 확대 인식기가 제스처를 가져가 버리고, 두 번째 탭은 두드리기 인식기에 도달하지 못합니다.

그래서 미동 없이 누른 사람에게만 더블탭이 먹혔던 겁니다.

### 무엇을 고쳤나

누른 자리를 기억해 두고, **거기서 얼마 안 움직였으면 움직이지 않은 것으로 친다**는 규칙을 넣었습니다.

```dart
if (event is PointerDownEvent) {
  _tabDown = event.position;      // 누른 자리를 기억한다
  return;
}

if (event is PointerMoveEvent) {
  final double distance = (_tabDown! - event.position).distance;

  const double doubleTapThreshold = 10.0;
  if (distance <= doubleTapThreshold) {
    return;                       // 이 정도는 흔들린 것이지 움직인 게 아니다
  }

  final move = _initialFocalPoint! - _currentFocalPoint!;
  final bool shouldMove = hitDetector?.shouldMove(move, validateAxis!) ?? false;
  if (shouldMove || _pointerLocations.keys.length > 1) {
    acceptGesture(event.pointer);
  }
}
```

10픽셀 안쪽의 움직임은 무시합니다. 확대 인식기가 그만큼 늦게 손을 들게 되니, 그 사이에 두 번째 탭이 도착해 더블탭이 성립합니다.

> [!NOTE]
> 이런 여유값은 Flutter가 이미 쓰고 있습니다. 스크롤을 시작할지 판단하는 기준값 `kTouchSlop`이 18입니다. 그 값을 몰라서 10을 손으로 정했는데, 결과적으로 같은 종류의 판단이었습니다.

---

## 07 · 검은 화면에 흰 내비게이션 바

포크 저장소에 "갤러리 버그 수정"이라고만 적어 둔 것이 둘 있는데, 하나는 [앞에서 다룬 확대 중 페이지 넘김](#04--값-하나가-세-곳을-가른다)이고 나머지가 이것입니다.

사진 뷰어는 배경이 검습니다. 그런데 화면 아래 시스템 내비게이션 바는 흰색 그대로였습니다. 사진을 보는 내내 아래쪽에 흰 띠가 남아 있는 셈입니다.

갤러리가 뜰 때 시스템 바를 검게 맞추고, 나갈 때 원래대로 되돌리도록 했습니다.

```dart
static Future<void> setPhotoViewMode() async {
  await SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.manual,
    overlays: [SystemUiOverlay.bottom],
  );
  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle.light.copyWith(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.black,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
}
```

첫 프레임이 그려진 뒤에 부릅니다. `initState`에서 바로 부르면 아직 화면이 붙기 전이라 적용이 밀립니다.

라이브러리가 앱의 시스템 바 색을 건드리는 건 원래 넘지 말아야 할 선입니다. 뷰어를 닫을 때 반드시 원래대로 돌려놓는다는 조건에서만 허용되는 일인데, 그 되돌리는 부분이 실제로는 동작하지 않습니다.

```dart
@override
void dispose() {
  _animationController.dispose();
  FirstsetMode;        // 괄호가 없다 — 함수를 가리키기만 하고 부르지는 않는다
  super.dispose();
}
```

Dart에서 함수 이름만 적으면 그 함수를 가리키는 값이 될 뿐 호출되지 않습니다. 경고도 안 뜹니다. 증상이 없었던 건 앱이 사진 뷰어 화면에서 같은 일을 따로 해 주고 있었기 때문입니다. 앱이 대신 막아 주고 있어서 몇 달 동안 아무도 몰랐습니다.

포크한 코드는 아무도 리뷰하지 않는다는 걸 여기서 봤습니다.

---

## 08 · 두 번째 포크 — Dart에서 사라진 손잡이

프로필 사진을 등록할 때 `image_cropper`로 정사각형을 잘라 냅니다. 안드로이드에서는 이 플러그인이 uCrop이라는 네이티브 화면을 띄웁니다.

크롭 화면 배경은 검은색으로 맞춰 뒀는데, 상단 시계와 배터리가 안 보였습니다.

원인을 따라가 보니 이렇습니다. 9.0.0에서 이 플러그인은 화면 가장자리 처리 방식을 바꾸면서 관련 코드를 플러그인 밖으로 내보냈습니다. 그 과정에서 Dart 쪽 설정 클래스(`AndroidUiSettings`)에 상태바 색을 넘기는 항목이 사라졌습니다. 그런데 네이티브 코드는 여전히 그 값을 읽고 있습니다. 안 넘어오면 투명으로 칠하고, 안드로이드 12 이상에서는 상태바 글자를 어두운 색으로 바꿉니다.

검은 배경 + 투명 상태바 + 어두운 글자. 시계가 안 보이는 게 당연했습니다.

Dart에서 넘길 방법이 없으니 네이티브에서 기본값을 박았습니다. 세 줄입니다.

```java
UCrop.Options options = new UCrop.Options();
options.setStatusBarColor(Color.BLACK);
options.setToolbarColor(Color.BLACK);
options.setToolbarWidgetColor(Color.WHITE);
```

Dart에서 넘어온 설정을 적용하기 **전에** 두었습니다. 나중에 앱이 다른 색을 넘기면 그쪽이 이깁니다. 기본값만 바꾸고 길은 막지 않았습니다.

---

## 트레이드오프

포크는 공짜가 아닙니다.

`pubspec.yaml`에서 이 두 패키지는 버전이 아니라 깃 주소를 가리킵니다. 그 순간 업스트림 업데이트가 자동으로 오지 않습니다. 원본에 버그가 고쳐지거나 새 Flutter 버전 대응이 들어와도 우리 쪽에는 안 옵니다. 가져오려면 우리가 고친 부분과 손으로 합쳐야 합니다.

`photo_view` 쪽은 그럴 만했습니다. 기능 자체가 없었고, 앱에서 매일 쓰는 동작이었습니다.

`image_cropper` 쪽은 지금 다시 보면 아깝습니다. 프로필 화면 세 개에서만 쓰는 기능인데 패키지 하나를 통째로 떠안았습니다. 크롭 화면을 직접 만들거나, 상태바 색을 앱 쪽 테마에서 손보는 길이 있었는지 더 봤어야 했습니다. 세 줄을 고치려고 치른 값으로는 비쌉니다.

---

## 마치며

포크하기 전에는 라이브러리가 완제품처럼 보였습니다. 안 되는 게 있으면 그건 내가 못 찾은 옵션이라고 생각했습니다.

열어 보니 그냥 남이 쓴 코드였습니다. 이 갤러리를 만든 사람은 좌우로 넘기는 것까지 만들었고, 세로로 내려 닫는 건 필요하지 않았을 뿐입니다. 잘못 만든 코드가 아니었습니다. 거기까지였던 겁니다.

그리고 고칠 곳을 찾는 데 걸린 시간이 실제로 고치는 시간보다 훨씬 길었습니다. 최종 수정은 파일 두 개에 들어갔지만, 거기가 고칠 자리라는 걸 알기까지 확대 배율이 어디서 어디로 흐르는지, 제스처를 누가 먼저 가져가는지를 먼저 읽어야 했습니다. 읽는 게 일이고 쓰는 건 그다음이었습니다.

---

**관련 코드** → [`kiwijuse/Flutter_Photoview_Custom`](https://github.com/kiwijuse/Flutter_Photoview_Custom) · [`kiwijuse/flutter_image_cropper_custom`](https://github.com/kiwijuse/flutter_image_cropper_custom)
**처음으로** → [문서 목록](../README.md#깊이-들어간-이야기)
