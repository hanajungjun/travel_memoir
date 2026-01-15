/// 대한민국 지역 타입
/// - city   : 시
/// - county : 군 (여행지로 취급, UI에는 구분 안 함)
enum KoreaRegionType { city, county }

/// 지도 표시용 지역 타입
/// - metro   : 특별시 / 광역시 / 세종
/// - city    : 도 소속 시/군 (구리, 일산 등)
/// - special : 울릉도, 독도
enum MapRegionType { metro, city, special }

/// 대한민국 지역 모델
/// 내부적으로는 행정구역을 구분하지만
/// UI에서는 name만 사용한다.
class KoreaRegion {
  /// 고유 ID (절대 변경 금지)
  /// 예: KR_GB_YEONGYANG
  final String id;

  /// 사용자에게 보여줄 이름
  /// 예: 영양, 청도, 울릉도
  final String name;

  final String nameEn;

  /// 광역단위
  /// 예: 경상북도
  final String province;

  /// 행정 타입 (내부 로직용)
  final KoreaRegionType type;

  /// 대표 위도 (행정 중심)
  final double lat;

  /// 대표 경도 (행정 중심)
  final double lng;

  // =========================
  // 🔥 추가된 필드 (지도용)
  // =========================

  /// 지도 색칠·집계 기준 ID
  /// 예:
  /// - 대구 중구   → KR_DAEGU
  /// - 인천 연수구 → KR_INCHEON
  /// - 구리        → KR_GG_GURI
  /// - 울릉도      → KR_SPECIAL_ULLEUNG
  final String mapRegionId;

  /// 지도 표시 단위
  /// metro / city / special
  final MapRegionType mapRegionType;

  const KoreaRegion({
    required this.id,
    required this.name,
    required this.nameEn,
    required this.province,
    required this.type,
    required this.lat,
    required this.lng,
    required this.mapRegionId,
    required this.mapRegionType,
  });
}
