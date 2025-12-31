import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ImageUploadService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  // =====================================================
  // 📸 유저 사진 업로드
  // =====================================================
  static Future<String> uploadUserImage({
    required File file,
    required String travelId,
    required String dayId, // 예: 2025.12.10
  }) async {
    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';

    final String path = 'user/$travelId/$dayId/$fileName';

    debugPrint('==============================');
    debugPrint('☁️ [USER IMAGE UPLOAD] START');
    debugPrint('☁️ bucket = travel_images');
    debugPrint('☁️ path   = $path');
    debugPrint('==============================');

    try {
      final Uint8List bytes = await file.readAsBytes();

      final res = await _supabase.storage
          .from('travel_images')
          .uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: false,
            ),
          );

      debugPrint('☁️ [USER IMAGE UPLOAD] DONE');
    } catch (e, s) {
      debugPrint('❌ [USER IMAGE UPLOAD] FAILED');
      debugPrint(e.toString());
      debugPrint(s.toString());
      rethrow;
    }

    final String publicUrl = _supabase.storage
        .from('travel_images')
        .getPublicUrl(path);

    debugPrint('☁️ [USER IMAGE UPLOAD] publicUrl');
    debugPrint(publicUrl);

    return publicUrl;
  }

  // =====================================================
  // 🎨 AI 그림일기 이미지 업로드
  // =====================================================
  static Future<String> uploadDiaryImage({
    required String travelId,
    required DateTime date,
    required Uint8List imageBytes,
  }) async {
    final String dayId =
        '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';

    final String fileName = 'ai_${DateTime.now().millisecondsSinceEpoch}.jpg';

    final String path = 'diary/$travelId/$dayId/$fileName';

    debugPrint('==============================');
    debugPrint('🎨 [DIARY IMAGE UPLOAD] START');
    debugPrint('🎨 bucket = travel_images');
    debugPrint('🎨 path   = $path');
    debugPrint('==============================');

    try {
      final res = await _supabase.storage
          .from('travel_images')
          .uploadBinary(
            path,
            imageBytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: false,
            ),
          );

      debugPrint('🎨 [DIARY IMAGE UPLOAD] DONE');
    } catch (e, s) {
      debugPrint('❌ [DIARY IMAGE UPLOAD] FAILED');
      debugPrint(e.toString());
      debugPrint(s.toString());
      rethrow;
    }

    final String publicUrl = _supabase.storage
        .from('travel_images')
        .getPublicUrl(path);

    debugPrint('🎨 [DIARY IMAGE UPLOAD] publicUrl');
    debugPrint(publicUrl);

    return publicUrl;
  }

  // =====================================================
  // 🗑 publicUrl → storage path 변환
  // =====================================================
  static String getPathFromPublicUrl(String publicUrl) {
    final uri = Uri.parse(publicUrl);
    final segments = uri.pathSegments;

    final bucketIndex = segments.indexOf('travel_images');
    if (bucketIndex == -1) {
      throw Exception('Invalid storage url');
    }

    return segments.sublist(bucketIndex + 1).join('/');
  }

  // =====================================================
  // 🗑 사진 삭제 (URL 기준)
  // =====================================================
  static Future<void> deleteUserImageByUrl(String publicUrl) async {
    final path = getPathFromPublicUrl(publicUrl);

    debugPrint('🗑 [STORAGE DELETE] path = $path');

    try {
      await _supabase.storage.from('travel_images').remove([path]);
      debugPrint('🗑 [STORAGE DELETE] DONE');
    } catch (e, s) {
      debugPrint('❌ [STORAGE DELETE] FAILED');
      debugPrint(e.toString());
      debugPrint(s.toString());
      rethrow;
    }
  }

  // =====================================================
  // 🖼 여행 커버 이미지 업로드 (TravelCompleteService용)
  // =====================================================
  static Future<String> uploadTravelCoverImage({
    required String travelId,
    required Uint8List imageBytes,
  }) async {
    final fileName = 'cover_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final path = 'travel/$travelId/cover/$fileName';

    debugPrint('🖼 [COVER IMAGE UPLOAD] START');
    debugPrint('🖼 path = $path');

    try {
      final res = await _supabase.storage
          .from('travel_images')
          .uploadBinary(
            path,
            imageBytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: false,
            ),
          );
    } catch (e, s) {
      debugPrint('❌ [COVER IMAGE UPLOAD] FAILED');
      debugPrint(e.toString());
      debugPrint(s.toString());
      rethrow;
    }

    final url = _supabase.storage.from('travel_images').getPublicUrl(path);

    debugPrint('🖼 [COVER IMAGE UPLOAD] publicUrl=$url');
    return url;
  }

  // =====================================================
  // 🗺 여행 지도 이미지 업로드 (TravelCompleteService용)
  // =====================================================
  static Future<String> uploadTravelMapImage({
    required String travelId,
    required Uint8List imageBytes,
  }) async {
    final fileName = 'map_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final path = 'travel/$travelId/map/$fileName';

    debugPrint('🗺 [MAP IMAGE UPLOAD] START');
    debugPrint('🗺 path = $path');

    try {
      final res = await _supabase.storage
          .from('travel_images')
          .uploadBinary(
            path,
            imageBytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: false,
            ),
          );
    } catch (e, s) {
      debugPrint('❌ [MAP IMAGE UPLOAD] FAILED');
      debugPrint(e.toString());
      debugPrint(s.toString());
      rethrow;
    }

    final url = _supabase.storage.from('travel_images').getPublicUrl(path);

    debugPrint('🗺 [MAP IMAGE UPLOAD] publicUrl=$url');
    return url;
  }
}
