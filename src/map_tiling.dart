import 'dart:async';

/// 지도 화면의 숙소 데이터 로딩을 담당하는 부분.
///
/// 핵심 아이디어: 지도의 "연속적인 위경도 범위" 문제를 "정수 타일 ID 집합" 문제로 바꾼다.
/// 그러면 이미 받아온 영역인지 아닌지를 Set 연산 한 번으로 판단할 수 있고,
/// 캐시 키가 안정적이라 같은 지역은 줌을 바꿔도 항상 같은 ID에 귀속된다.
///
/// 자세한 배경은 docs/02-map-tiling.md 참고.
class MapService {
  // ───────────────────────────────────────────────────────────
  // 그리드 정의
  //
  // 격자의 좌상단 기준점과 한 칸의 크기. 서버와 클라이언트가 이 값을 공유하기 때문에
  // 양쪽이 같은 좌표에서 같은 타일 ID를 계산한다. 즉 좌표를 맞춰보는 과정이 필요 없다.
  //
  // 값이 10km 같은 딱 떨어지는 단위가 아닌 이유:
  // 위경도를 거리 축으로 환산해 쓰면 위도에 따라 실제 거리가 달라지고 실수 연산 오차가 쌓인다.
  // 그래서 거리를 기준으로 잡는 대신, 서비스 범위를 약 2천 개 칸으로 나눈다는 목표를 먼저 두고
  // 거기서 한 칸의 위경도 폭을 역산했다. 최종적으로 본토 2,021개 + 제주 45개, 합쳐서 2,066개다.
  // 제주는 본토와 지리적으로 떨어져 있어 격자를 따로 뒀다.
  // 본토 격자를 남쪽으로 늘리면 그 사이 바다까지 전부 칸으로 잡히기 때문이다.
  //
  // 줌에 따라 칸 크기를 바꾸는 적응형 격자를 쓰지 않은 것도 같은 이유다.
  // 같은 지역이 줌마다 다른 ID를 가지면 캐시가 거의 재사용되지 않는다.
  // ───────────────────────────────────────────────────────────

  static const double origin_north_lat = 38.6600;
  static const double origin_west_lng = 125.5677;
  static const double lat_step = 0.09938;
  static const double lng_step = 0.09886;

  /// 한 행에 들어가는 열 개수. 타일 ID를 1차원으로 펴는 데 쓰인다.
  static const int columns_per_row = 43;

  /// 타일 캐시 유효 시간.
  /// 숙소 목록은 분 단위로 바뀌지 않지만, 앱을 오래 켜 둔 채 돌아다니는 사용자가 있어
  /// 무한정 들고 있지는 않는다.
  static const Duration cache_expiration = Duration(minutes: 30);

  // ───────────────────────────────────────────────────────────
  // 캐시
  //
  // 세 자료구조가 각각 다른 일을 한다.
  //   - 데이터 저장         : tile_accommodation_cache
  //   - 신선도 판정         : tile_cache_timestamps
  //   - 적재 여부 빠른 조회  : loaded_tiles
  // ───────────────────────────────────────────────────────────

  final Map<int, List<Accommodation>> tile_accommodation_cache = {};
  final Map<int, DateTime> tile_cache_timestamps = {};
  final Set<int> loaded_tiles = <int>{};

  /// 위경도 한 점이 속한 타일 ID.
  ///
  /// 행·열 인덱스를 구한 뒤 행 우선으로 1차원에 편다. +1은 번호를 1부터 시작시키기 위한 것.
  int tileIdOf(double lat, double lng) {
    final int row = ((origin_north_lat - lat) / lat_step).toInt();
    final int col = ((lng - origin_west_lng) / lng_step).toInt();
    return row * columns_per_row + col + 1;
  }

  /// 화면 경계가 덮는 모든 타일 ID.
  ///
  /// 경계에 걸친 타일은 넉넉하게 포함시킨다.
  /// 몇 개를 더 가져오는 비용은 캐시와 후처리로 흡수되지만,
  /// 하나를 놓치면 그 자리에 숙소가 아예 안 뜨는 빈 구멍이 생기기 때문이다.
  List<int> tilesInBounds({
    required double north_lat,
    required double south_lat,
    required double east_lng,
    required double west_lng,
  }) {
    final int top = ((origin_north_lat - north_lat) / lat_step).toInt();
    final int bottom = ((origin_north_lat - south_lat) / lat_step).toInt();
    final int left = ((west_lng - origin_west_lng) / lng_step).toInt();
    final int right = ((east_lng - origin_west_lng) / lng_step).toInt();

    final List<int> tiles = [];
    for (int row = top; row <= bottom; row++) {
      for (int col = left; col <= right; col++) {
        tiles.add(row * columns_per_row + col + 1);
      }
    }
    return tiles;
  }

  /// 타일이 아직 쓸 수 있는 캐시를 갖고 있는지.
  ///
  /// 키 존재 여부만 보지 않고 유효기간까지 함께 판정한다.
  /// 만료된 것을 발견하면 그 자리에서 세 자료구조에서 모두 지운다.
  /// 유효성 검사와 청소를 한 흐름에 묶어 두면 별도의 청소 주기를 돌릴 필요가 없다.
  bool isTileCached(int tile_id) {
    if (!tile_accommodation_cache.containsKey(tile_id)) return false;

    final timestamp = tile_cache_timestamps[tile_id];
    if (timestamp != null && DateTime.now().difference(timestamp) < cache_expiration) {
      return true;
    }

    tile_accommodation_cache.remove(tile_id);
    tile_cache_timestamps.remove(tile_id);
    loaded_tiles.remove(tile_id);
    return false;
  }

  void cacheTileData(int tile_id, List<Accommodation> accommodations) {
    tile_accommodation_cache[tile_id] = accommodations;
    tile_cache_timestamps[tile_id] = DateTime.now();
    loaded_tiles.add(tile_id);
  }

  /// 캐시된 타일들에서 숙소를 모은다.
  /// 하나의 숙소가 여러 타일에 중복 등장할 수 있어 house_id로 걸러낸다.
  List<Accommodation> getAccommodationsFromCachedTiles(List<int> tile_ids) {
    final Set<int> seen = {};
    final List<Accommodation> result = [];

    for (final tile_id in tile_ids) {
      if (!isTileCached(tile_id)) continue;

      for (final accommodation in tile_accommodation_cache[tile_id]!) {
        if (seen.add(accommodation.house_id)) {
          result.add(accommodation);
        }
      }
    }
    return result;
  }

  List<Accommodation> getAllCachedAccommodations() =>
      getAccommodationsFromCachedTiles(loaded_tiles.toList());

  /// 화면에 필요한 숙소를 확보한다.
  ///
  /// 서버에는 아직 캐시가 없는 타일만 물어본다.
  /// 전부 캐시에 있으면 네트워크를 아예 타지 않는다.
  Future<List<Accommodation>> getAccommodationsInBounds({
    required double north_lat,
    required double south_lat,
    required double east_lng,
    required double west_lng,
  }) async {
    final current_tiles = tilesInBounds(
      north_lat: north_lat,
      south_lat: south_lat,
      east_lng: east_lng,
      west_lng: west_lng,
    );

    final uncached_tiles = current_tiles.where((id) => !isTileCached(id)).toList();

    if (uncached_tiles.isEmpty) {
      return getAccommodationsFromCachedTiles(current_tiles);
    }

    try {
      final response = await getHouseByTiles(uncached_tiles);

      if (response == null || response['houses'] == null) {
        // 응답이 비었어도 빈 리스트로 캐시해 둔다.
        // 그러지 않으면 숙소가 없는 지역을 지날 때마다 같은 요청을 반복하게 된다.
        for (final tile_id in uncached_tiles) {
          cacheTileData(tile_id, []);
        }
        return getAccommodationsFromCachedTiles(current_tiles);
      }

      // 서버는 숙소 목록을 평평하게 내려준다.
      // 클라이언트가 각 숙소의 좌표로 타일 ID를 다시 계산해 타일별로 흩어 담는다.
      // 양쪽이 같은 격자 정의를 쓰기 때문에 이 재계산 결과는 서버의 분류와 일치한다.
      final Map<int, List<Accommodation>> by_tile = {};

      for (final house_data in response['houses'] as List) {
        final accommodation = Accommodation.fromJson(house_data);
        by_tile
            .putIfAbsent(tileIdOf(accommodation.latitude, accommodation.longitude), () => [])
            .add(accommodation);
      }

      // 요청했던 타일은 결과가 비었더라도 전부 캐시에 기록한다.
      for (final tile_id in uncached_tiles) {
        cacheTileData(tile_id, by_tile[tile_id] ?? []);
      }

      return getAccommodationsFromCachedTiles(current_tiles);
    } catch (_) {
      // 네트워크가 끊겨도 이미 받아 둔 지역은 계속 보여준다.
      return getAccommodationsFromCachedTiles(current_tiles);
    }
  }

  void clearCache() {
    tile_accommodation_cache.clear();
    tile_cache_timestamps.clear();
    loaded_tiles.clear();
  }
}

// ─────────────────────────────────────────────────────────────
// 화면 쪽: 요청이 쏟아지는 것을 막는 세 겹의 방어선
// ─────────────────────────────────────────────────────────────

mixin MapViewportLoader {
  Timer? debounce_timer;
  SimpleLatLngBounds? last_bounds;

  /// 첫 번째 방어선 — 디바운스.
  ///
  /// 카메라 이동 콜백은 손가락이 움직이는 내내 불린다.
  /// 300ms는 "손을 뗐다"고 볼 수 있으면서 사용자가 기다린다고 느끼지 않는 지점이었다.
  void onCameraMoveEnd() {
    debounce_timer?.cancel();
    debounce_timer = Timer(const Duration(milliseconds: 300), loadAccommodationsInBounds);

    // 마커 개수 표시는 네트워크와 무관하므로 즉시 갱신한다.
    updateVisibleCount();
  }

  Future<void> loadAccommodationsInBounds();

  Future<void> updateVisibleCount();

  /// 두 번째 방어선 — 사실상 같은 영역이면 요청하지 않는다.
  ///
  /// 지도를 살짝 건드려 경계가 미세하게 흔들리는 경우가 잦다.
  /// 이 정도 이동으로는 타일 집합이 바뀌지 않으므로 계산 자체를 건너뛴다.
  bool isSimilarBounds(SimpleLatLngBounds a, SimpleLatLngBounds b) {
    const double threshold = 0.0005;
    return (a.northeast.latitude - b.northeast.latitude).abs() < threshold &&
        (a.southwest.latitude - b.southwest.latitude).abs() < threshold &&
        (a.northeast.longitude - b.northeast.longitude).abs() < threshold &&
        (a.southwest.longitude - b.southwest.longitude).abs() < threshold;
  }

  /// 화면에 실제로 보이는 점만 남긴다.
  ///
  /// 타일은 화면보다 넓게 가져오므로, 그대로 그리면 화면 밖 숙소까지 마커가 생긴다.
  /// 요청은 타일 단위로 넓게, 렌더링은 다각형 단위로 좁게 한다.
  ///
  /// 다각형은 화면 네 귀퉁이라 항상 4개다.
  /// 경계 상자로 먼저 걸러낸 뒤 통과한 점에만 Ray-Casting을 적용한다.
  bool isPointInPolygon(double lat, double lng, List<LatLng> polygon) {
    double min_lat = polygon[0].latitude, max_lat = polygon[0].latitude;
    double min_lng = polygon[0].longitude, max_lng = polygon[0].longitude;

    for (int i = 1; i < 4; i++) {
      final p_lat = polygon[i].latitude;
      final p_lng = polygon[i].longitude;
      if (p_lat < min_lat) min_lat = p_lat;
      if (p_lat > max_lat) max_lat = p_lat;
      if (p_lng < min_lng) min_lng = p_lng;
      if (p_lng > max_lng) max_lng = p_lng;
    }

    if (lat < min_lat || lat > max_lat || lng < min_lng || lng > max_lng) {
      return false;
    }

    bool is_inside = false;
    for (int i = 0, j = 3; i < 4; j = i++) {
      final yi = polygon[i].latitude;
      final yj = polygon[j].latitude;

      // 위도 구간에 걸치는 변만 검사한다. 나눗셈은 이 조건을 통과한 뒤에 한다.
      if ((yi > lat) != (yj > lat)) {
        if (yi == yj) continue;

        final xi = polygon[i].longitude;
        final xj = polygon[j].longitude;

        if (lng < (xj - xi) * (lat - yi) / (yj - yi) + xi) {
          is_inside = !is_inside;
        }
      }
    }
    return is_inside;
  }
}
