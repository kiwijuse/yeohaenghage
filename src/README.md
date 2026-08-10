# src — 코드 발췌

> [!IMPORTANT]
> 여기 있는 파일은 **발췌본이며 단독으로 빌드되지 않습니다.**
> 실제 앱은 231개 Dart 파일로 이루어져 있고, 그중 설계 의도가 잘 드러나는 네 덩어리만 골라
> 시크릿·사내 도메인·디버그 로그를 제거하고 옮겨 두었습니다.

## 무엇을 골랐나

| 파일 | 다루는 문제 | 관련 문서 |
|---|---|---|
| [`api_client.dart`](./api_client.dart) | 토큰 만료가 동시에 터질 때 리프레시 요청이 N번 나가는 문제 | [04-api-client](../docs/04-api-client.md) |
| [`map_tiling.dart`](./map_tiling.dart) | 지도를 드래그할 때마다 서버를 때리는 문제 | [02-map-tiling](../docs/02-map-tiling.md) |
| [`design_function.dart`](./design_function.dart) | 디자인 시안 크기를 실제 기기 화면에 맞추는 문제 | [07-design-system](../docs/07-design-system.md) |
| [`providers/`](./providers) | 화면 A에서 바꾼 값이 화면 B에 반영되지 않는 문제 | [03-state-management](../docs/03-state-management.md) |

## 원본과 달라진 점

옮기면서 아래를 정리했습니다. 로직은 그대로입니다.

- **API 키·시크릿 전면 제거.** 값이 필요한 자리는 `String.fromEnvironment(...)` 플레이스홀더로 바꿨습니다.
- **디버그 `print()` 제거.** 원본에는 릴리스 빌드에까지 847개가 남아 있었습니다. 이건 실제 문제였고 [아쉬운 점](../README.md#아쉬운-점)에 적어 두었습니다.
- **변경 이력을 설명하던 주석을 코드를 설명하는 주석으로 다시 썼습니다.** `// 수정됨: ~` 같은 주석은 diff를 읽는 사람에게만 의미가 있지, 코드를 처음 보는 사람에게는 아무것도 알려주지 않습니다.
- **죽은 코드·테스트 스캐폴딩 제거.** 도달 불가능한 `return`, 플레이스홀더 이미지 URL, 목 데이터 생성기 등.

변수명은 원본의 `snake_case`를 그대로 두었습니다. Dart 권장 스타일(`lowerCamelCase`)과는 다르지만, 실제 코드베이스가 그렇게 되어 있고 여기서만 예쁘게 고치면 발췌본으로서 정직하지 않기 때문입니다. 이 선택 자체도 [아쉬운 점](../README.md#아쉬운-점)에 적었습니다.
