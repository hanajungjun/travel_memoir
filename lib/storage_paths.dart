/// Supabase Storage PATH 전용
/// ❗️URL 생성 금지 (업로드 / DB 저장용)
class StoragePaths {
  StoragePaths._();

  // ===============================
  // 👤 User & Travels (travel_images)
  // ===============================

  static String userRoot(String userId) => 'users/$userId';

  static String profileRoot(String userId) => '${userRoot(userId)}/profile';

  static String profileAvatarPath(String userId) =>
      '${profileRoot(userId)}/avatar.png';

  static String travelRoot(String userId, String travelId) =>
      '${userRoot(userId)}/travels/$travelId';

  static String travelCoverPath(String userId, String travelId) =>
      '${travelRoot(userId, travelId)}/cover.png';

  static String travelTimelinePath(String userId, String travelId) =>
      '${travelRoot(userId, travelId)}/timeline.png';

  static String travelMapPath(String userId, String travelId) =>
      '${travelRoot(userId, travelId)}/map.png';

  static String travelDaysRoot(String userId, String travelId) =>
      '${travelRoot(userId, travelId)}/days';

  static String travelDayImagePath(
    String userId,
    String travelId,
    String diaryId,
  ) => '${travelDaysRoot(userId, travelId)}/$diaryId.png';

  static String travelUserPhotoPath(
    String userId,
    String travelId,
    String fileName,
  ) => '${travelDaysRoot(userId, travelId)}/photos/$fileName';
}
