/// Supabase Storage 경로 규칙 모음
/// ⚠️ 이 파일은 절대 임의로 수정하지 말 것
/// (계정 삭제 / 이미지 재생성 / 유료 기능 전부 이 규칙에 의존)

class StoragePaths {
  StoragePaths._(); // static only

  // =====================================================
  // 🔹 User Root
  // =====================================================
  static String userRoot(String userId) => 'users/$userId';

  // =====================================================
  // 👤 Profile
  // =====================================================
  static String profileRoot(String userId) => '${userRoot(userId)}/profile';

  static String profileAvatar(String userId) =>
      '${profileRoot(userId)}/avatar.png';

  // =====================================================
  // ✈️ Travels
  // =====================================================
  static String travelRoot(String userId, String travelId) =>
      '${userRoot(userId)}/travels/$travelId';

  /// 여행 대표 이미지
  static String travelCover(String userId, String travelId) =>
      '${travelRoot(userId, travelId)}/cover.png';

  /// 🔥 유료 기능: 타임라인 이미지
  static String travelTimeline(String userId, String travelId) =>
      '${travelRoot(userId, travelId)}/timeline.png';

  // =====================================================
  // 📅 Day Images
  // =====================================================
  static String travelDaysRoot(String userId, String travelId) =>
      '${travelRoot(userId, travelId)}/days';

  /// AI 생성 일자 이미지 (예: 2025-01-01.png)
  static String travelDayImage(
    String userId,
    String travelId,
    String date, // yyyy-MM-dd
  ) => '${travelDaysRoot(userId, travelId)}/$date.png';

  /// 사용자가 직접 업로드한 사진
  static String travelUserPhoto(
    String userId,
    String travelId,
    String fileName,
  ) => '${travelDaysRoot(userId, travelId)}/photos/$fileName';

  // =====================================================
  // 🧪 Temporary (AI 미리보기 등)
  // =====================================================
  static String tempRoot(String userId) => '${userRoot(userId)}/temp';

  static String tempAiPreview(String userId) =>
      '${tempRoot(userId)}/ai_preview.png';

  // =====================================================
  // 🎨 System (공용 리소스)
  // =====================================================
  static const String systemRoot = 'system';

  static String styleThumbnail(String styleId) =>
      '$systemRoot/style_thumbnails/$styleId.png';
}
