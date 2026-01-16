import 'dart:io';
import 'dart:typed_data';
import 'dart:async';

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
  // 🤖 AI 생성 이미지 업로드 (TravelDayPage에서 호출하는 이름)
  // ✅ [추가 및 수정] 이 메서드가 없어서 에러가 났던 것입니다.
  // =====================================================
  static Future<String> uploadAiImage({
    required String path,
    required Uint8List imageBytes,
  }) async {
    try {
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

      // 업로드 후 DB에 저장할 수 있도록 publicUrl을 반환해야 합니다.
      return _supabase.storage.from('travel_images').getPublicUrl(path);
    } catch (e) {
      print('❌ [AI IMAGE UPLOAD] 실패: $e');
      rethrow;
    }
  }

  // =====================================================
  // 🤖 일기 이미지 업로드 (기존 로직 유지)
  // =====================================================
  static Future<void> uploadDiaryImage({
    required String userId,
    required String travelId,
    required String diaryId,
    required Uint8List imageBytes,
  }) async {
    final path = StoragePaths.travelDayImage(userId, travelId, diaryId);

    print('-----------------------------------------');
    print('📤 [STORAGE UPLOAD] 시작');
    try {
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
      print('✅ [STORAGE UPLOAD] 성공!');
    } catch (e) {
      print('❌ [STORAGE UPLOAD] 실패: $e');
    }
    print('-----------------------------------------');
  }

  // =====================================================
  // 🖼 여행 커버 업로드
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
