import 'dart:io';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:travel_memoir/storage_paths.dart';

class ImageUploadService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  // =====================================================
  // 📸 사용자 사진 업로드 (travel_days/photos/)
  // =====================================================
  static Future<String> uploadUserImage({
    required File file,
    required String userId,
    required String travelId,
    required DateTime date,
  }) async {
    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';

    final path = StoragePaths.travelUserPhoto(userId, travelId, fileName);

    final bytes = await file.readAsBytes();

    await _supabase.storage
        .from('travel_images')
        .uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: false,
          ),
        );

    return _supabase.storage.from('travel_images').getPublicUrl(path);
  }

  // =====================================================
  // 🎨 AI 그림일기 업로드 (travels/{id}/days/yyyy-MM-dd.png)
  // =====================================================
  static Future<String> uploadDiaryImage({
    required String userId,
    required String travelId,
    required DateTime date,
    required Uint8List imageBytes,
  }) async {
    final path = StoragePaths.travelDayImage(
      userId,
      travelId,
      date.toIso8601String().substring(0, 10), // yyyy-MM-dd
    );

    await _supabase.storage
        .from('travel_images')
        .uploadBinary(
          path,
          imageBytes,
          fileOptions: const FileOptions(
            contentType: 'image/png',
            upsert: true, // 🔥 같은 날짜면 덮어쓰기 (정답)
          ),
        );

    return _supabase.storage.from('travel_images').getPublicUrl(path);
  }

  // =====================================================
  // 🖼 여행 커버 업로드 (travels/{id}/cover.png)
  // ✅ TravelCompleteService에서 쓰는 이름
  // =====================================================
  static Future<String> uploadTravelCover({
    required String userId,
    required String travelId,
    required Uint8List imageBytes,
  }) async {
    final path = StoragePaths.travelCover(userId, travelId);

    await _supabase.storage
        .from('travel_images')
        .uploadBinary(
          path,
          imageBytes,
          fileOptions: const FileOptions(
            contentType: 'image/png',
            upsert: true,
          ),
        );

    return _supabase.storage.from('travel_images').getPublicUrl(path);
  }

  // =====================================================
  // 🗺 여행 지도 업로드 (travels/{id}/map.png)
  // ✅ TravelCompleteService에서 쓰는 이름
  // =====================================================
  static Future<String> uploadTravelMap({
    required String userId,
    required String travelId,
    required Uint8List imageBytes,
  }) async {
    final path = '${StoragePaths.travelRoot(userId, travelId)}/map.png';

    await _supabase.storage
        .from('travel_images')
        .uploadBinary(
          path,
          imageBytes,
          fileOptions: const FileOptions(
            contentType: 'image/png',
            upsert: true,
          ),
        );

    return _supabase.storage.from('travel_images').getPublicUrl(path);
  }

  // =====================================================
  // 🗑 publicUrl → storage path 변환
  // =====================================================
  static String getPathFromPublicUrl(String publicUrl) {
    final uri = Uri.parse(publicUrl);
    final segments = uri.pathSegments;
    final bucketIndex = segments.indexOf('travel_images');
    return segments.sublist(bucketIndex + 1).join('/');
  }

  // =====================================================
  // 🗑 사진 삭제 (URL 기준)
  // =====================================================
  static Future<void> deleteUserImageByUrl(String publicUrl) async {
    final path = getPathFromPublicUrl(publicUrl);
    await _supabase.storage.from('travel_images').remove([path]);
  }
}
