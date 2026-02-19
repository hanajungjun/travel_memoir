/// Supabase Storage PATH 전용
/// ❗️URL 생성 금지 (업로드 / DB 저장용)
class StoragePaths {
  StoragePaths._();

  // ===============================
  // 👤 User & Travels (travel_images)
  // ===============================

  static String userRoot(String userId) => 'users/$userId';

  static String profileRoot(String userId) => '${userRoot(userId)}/profile';

  // ✅ 아바타 경로 수정
  static String profileAvatarPath(String userId) {
    // return '${profileRoot(userId)}/avatar.png'; // [기존 PNG 경로]
    return '${profileRoot(userId)}/avatar.webp'; // [NAS/WebP 최적화 경로]
  }

  static String travelRoot(String userId, String travelId) =>
      '${userRoot(userId)}/travels/$travelId';

  // ✅ 커버 이미지 경로 수정
  static String travelCoverPath(String userId, String travelId) {
    // return '${travelRoot(userId, travelId)}/cover.png';
    return '${travelRoot(userId, travelId)}/cover.webp';
  }

  // ✅ 타임라인 이미지 경로 수정
  static String travelTimelinePath(String userId, String travelId) {
    // return '${travelRoot(userId, travelId)}/timeline.png';
    return '${travelRoot(userId, travelId)}/timeline.webp';
  }

  // ✅ 지도 이미지 경로 수정
  static String travelMapPath(String userId, String travelId) {
    // return '${travelRoot(userId, travelId)}/map.png';
    return '${travelRoot(userId, travelId)}/map.webp';
  }

  static String travelDaysRoot(String userId, String travelId) =>
      '${travelRoot(userId, travelId)}/days';

  // ✅ 다이어리 데이 이미지 경로 수정
  static String travelDayImagePath(
    String userId,
    String travelId,
    String diaryId,
  ) {
    // return '${travelDaysRoot(userId, travelId)}/$diaryId.png';
    return '${travelDaysRoot(userId, travelId)}/$diaryId.webp';
  }

  static String travelUserPhotoPath(
    String userId,
    String travelId,
    String fileName,
  ) {
    // 유저가 직접 올리는 사진은 원본 확장자를 유지하는 경우가 많으므로 그대로 둡니다.
    // 만약 이 사진들도 WebP로 일괄 변환하여 NAS에 올리셨다면 아래처럼 수정하세요.
    // final webpFileName = fileName.replaceAll('.png', '.webp').replaceAll('.jpg', '.webp');
    // return '${travelDaysRoot(userId, travelId)}/photos/$webpFileName';

    return '${travelDaysRoot(userId, travelId)}/photos/$fileName';
  }
}
