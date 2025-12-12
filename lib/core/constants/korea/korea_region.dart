/// 대한민국 지역 타입
/// - city   : 시
/// - county : 군 (여행지로 취급, UI에는 구분 안 함)
enum KoreaRegionType { city, county }

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

  /// 광역단위
  /// 예: 경상북도
  final String province;

  /// 행정 타입 (내부 로직용)
  final KoreaRegionType type;

  const KoreaRegion({
    required this.id,
    required this.name,
    required this.province,
    required this.type,
  });
}
