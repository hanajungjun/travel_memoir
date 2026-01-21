/// Supabase Storage 경로 및 URL 규칙 통합 관리 클래스
class StoragePaths {
  StoragePaths._();

  static const String _projectId = 'tpgfnqbtioxmvartxjii';
  static const String _basePublicUrl =
      'https://$_projectId.supabase.co/storage/v1/object/public';

  // 모든 URL 생성 시 인코딩 및 기본 주소 결합
  static String _toFullUrl(String path) {
    final String url = '$_basePublicUrl/$path';
    return Uri.encodeFull(url);
  }

  // =====================================================
  // 🎨 System (공용 지도 리소스 - 각자 버킷이 다름)
  // =====================================================
  static String domesticMap(String regionKey) =>
      _toFullUrl('map_images/$regionKey.png');

  static String globalMap(String countryCode) =>
      _toFullUrl('global_map_image/$countryCode.png');

  static String usaMap(String regionKey) =>
      _toFullUrl('usa_map_image/$regionKey.png');

  static String styleThumbnail(String styleId) =>
      _toFullUrl('system/style_thumbnails/$styleId.png');

  // =====================================================
  // 👤 User & Travels (사용자 개별 데이터 - 모두 'travel_images' 버킷 사용)
  // =====================================================

  // 🎯 모든 사용자 경로 앞에 'travel_images/'를 명시적으로 추가했습니다.
  static String userRoot(String userId) => 'travel_images/users/$userId';

  static String profileRoot(String userId) => '${userRoot(userId)}/profile';

  static String profileAvatar(String userId) =>
      _toFullUrl('${profileRoot(userId)}/avatar.png');

  static String travelRoot(String userId, String travelId) =>
      '${userRoot(userId)}/travels/$travelId';

  static String travelCover(String userId, String travelId) =>
      _toFullUrl('${travelRoot(userId, travelId)}/cover.png');

  static String travelTimeline(String userId, String travelId) =>
      _toFullUrl('${travelRoot(userId, travelId)}/timeline.png');

  static String travelDaysRoot(String userId, String travelId) =>
      '${travelRoot(userId, travelId)}/days';

  static String travelDayImage(
    String userId,
    String travelId,
    String diaryId,
  ) => _toFullUrl('${travelDaysRoot(userId, travelId)}/$diaryId.png');

  static String travelUserPhoto(
    String userId,
    String travelId,
    String fileName,
  ) => _toFullUrl('${travelDaysRoot(userId, travelId)}/photos/$fileName');

  static String travelMap(String userId, String travelId) =>
      _toFullUrl('${travelRoot(userId, travelId)}/map.png');
}
