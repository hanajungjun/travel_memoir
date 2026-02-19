import 'package:supabase_flutter/supabase_flutter.dart';
import 'storage_paths.dart';

/// NAS 이미지 서버 및 Supabase Storage Public URL 생성 전용
class StorageUrls {
  StorageUrls._();

  // ✅ 이번에 새로 추가된 시놀로지 NAS 기본 주소
  static const String _nasBaseUrl =
      "http://hajungtech.synology.me/travel_assets";

  // =====================================================
  // ✅ 공용: travel_images 버킷 (유저 생성 이미지)
  // =====================================================
  static String travelImage(String path) {
    return Supabase.instance.client.storage
        .from('travel_images')
        .getPublicUrl(path);
  }

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
  // ✅ 시스템 지도 (NAS 주소로 변경 완료)
  // =====================================================

  /// 확장자를 .webp로 강제 변환해주는 헬퍼 함수
  static String _toWebp(String path) {
    return path.replaceAll('.png', '.webp').replaceAll('.jpg', '.webp');
  }

  /// domestic_map_image (기존 map_images 버킷)
  static String domesticMapFromPath(String path) {
    final fileName = path.startsWith('map_images/')
        ? path.replaceFirst('map_images/', '')
        : path;

    /* [기존 Supabase 로직 주석처리]
    return Supabase.instance.client.storage
        .from('map_images')
        .getPublicUrl(fileName);
    */

    // ✅ NAS 로직 적용
    return "$_nasBaseUrl/map_images/${_toWebp(fileName)}";
  }

  /// global_map_image 버킷
  static String globalMapFromPath(String path) {
    final fileName = path.startsWith('global_map_image/')
        ? path.replaceFirst('global_map_image/', '')
        : path;

    /* [기존 Supabase 로직 주석처리]
    return Supabase.instance.client.storage
        .from('global_map_image')
        .getPublicUrl(fileName);
    */

    // ✅ NAS 로직 적용
    return "$_nasBaseUrl/global_map_image/${_toWebp(fileName)}";
  }

  /// usa_map_image 버킷
  static String usaMapFromPath(String path) {
    final fileName = path.startsWith('usa_map_image/')
        ? path.replaceFirst('usa_map_image/', '')
        : path;

    /* [기존 Supabase 로직 주석처리]
    return Supabase.instance.client.storage
        .from('usa_map_image')
        .getPublicUrl(fileName);
    */

    // ✅ NAS 로직 적용
    return "$_nasBaseUrl/usa_map_image/${_toWebp(fileName)}";
  }
}
