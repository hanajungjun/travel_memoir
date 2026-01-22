import 'package:supabase_flutter/supabase_flutter.dart';
import 'storage_paths.dart';

/// Supabase Storage Public URL 생성 전용
/// ❗️업로드(쓰기)에는 절대 사용 금지
class StorageUrls {
  StorageUrls._();

  // =====================================================
  // ✅ 공용: travel_images 버킷의 path → public url
  // =====================================================
  static String travelImage(String path) {
    return Supabase.instance.client.storage
        .from('travel_images')
        .getPublicUrl(path);
  }

  // =====================================================
  // ✅ travel_images 버킷 (유저 생성 이미지)
  // =====================================================
  static String travelCover(String userId, String travelId) =>
      travelImage(StoragePaths.travelCoverPath(userId, travelId));

  static String travelTimeline(String userId, String travelId) =>
      travelImage(StoragePaths.travelTimelinePath(userId, travelId));

  static String travelMap(String userId, String travelId) =>
      travelImage(StoragePaths.travelMapPath(userId, travelId));

  static String travelDayImage(
    String userId,
    String travelId,
    String diaryId,
  ) => travelImage(StoragePaths.travelDayImagePath(userId, travelId, diaryId));

  // =====================================================
  // ✅ 시스템 지도 버킷들: "path"로만 받을 때 쓰는 변환기
  // (DB에 map_image_url로 저장된 값이 여기로 들어온다고 가정)
  // =====================================================

  /// map_images 버킷: path 예) "map_images/41.png" 또는 "41.png"
  static String domesticMapFromPath(String path) {
    final safe = path.startsWith('map_images/') ? path : 'map_images/$path';
    return Supabase.instance.client.storage
        .from('map_images')
        .getPublicUrl(safe);
  }

  /// global_map_image 버킷: path 예) "global_map_image/US.png" 또는 "US.png"
  static String globalMapFromPath(String path) {
    final safe = path.startsWith('global_map_image/')
        ? path
        : 'global_map_image/$path';
    return Supabase.instance.client.storage
        .from('global_map_image')
        .getPublicUrl(safe);
  }

  /// usa_map_image 버킷: path 예) "usa_map_image/ARIZONA.png" 또는 "ARIZONA.png"
  static String usaMapFromPath(String path) {
    final safe = path.startsWith('usa_map_image/')
        ? path
        : 'usa_map_image/$path';
    return Supabase.instance.client.storage
        .from('usa_map_image')
        .getPublicUrl(safe);
  }
}
