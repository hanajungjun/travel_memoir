import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ImageUploadService {
  static final _supabase = Supabase.instance.client;

  static const _bucketName = 'travel_images';

  // =====================================================
  // 🤖 AI 생성 이미지 업로드
  // =====================================================
  static Future<String> uploadAiImage({
    required Uint8List imageBytes,
    required String travelId,
    required DateTime date,
  }) async {
    final fileName = '${date.toIso8601String().substring(0, 10)}.png';
    final path = 'ai/$travelId/$fileName';

    await _supabase.storage
        .from(_bucketName)
        .uploadBinary(
          path,
          imageBytes,
          fileOptions: const FileOptions(
            contentType: 'image/png',
            upsert: true,
          ),
        );

    return _supabase.storage.from(_bucketName).getPublicUrl(path);
  }

  static Future<String> uploadDiaryImage({
    required Uint8List imageBytes,
    required String travelId,
    required DateTime date,
  }) {
    return uploadAiImage(
      imageBytes: imageBytes,
      travelId: travelId,
      date: date,
    );
  }

  // =====================================================
  // 📸 유저 업로드 이미지
  // =====================================================
  static Future<String> uploadUserImage({
    required File file,
    required String travelId,
    required String dayId,
  }) async {
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    final path = 'user/$travelId/$dayId/$fileName';

    await _supabase.storage
        .from(_bucketName)
        .upload(
          path,
          file,
          fileOptions: const FileOptions(contentType: 'image/jpeg'),
        );

    return _supabase.storage.from(_bucketName).getPublicUrl(path);
  }

  // =====================================================
  // 🖼 여행 커버 이미지
  // =====================================================
  static Future<String> uploadTravelCoverImage({
    required Uint8List imageBytes,
    required String travelId,
  }) async {
    final path = 'ai/$travelId/cover.png';

    await _supabase.storage
        .from(_bucketName)
        .uploadBinary(
          path,
          imageBytes,
          fileOptions: const FileOptions(
            contentType: 'image/png',
            upsert: true,
          ),
        );

    return _supabase.storage.from(_bucketName).getPublicUrl(path);
  }

  // =====================================================
  // 🗺 여행 지도 이미지
  // =====================================================
  static Future<String> uploadTravelMapImage({
    required Uint8List imageBytes,
    required String travelId,
  }) async {
    final path = 'ai/$travelId/map.png';

    await _supabase.storage
        .from(_bucketName)
        .uploadBinary(
          path,
          imageBytes,
          fileOptions: const FileOptions(
            contentType: 'image/png',
            upsert: true,
          ),
        );

    return _supabase.storage.from(_bucketName).getPublicUrl(path);
  }

  // =====================================================
  // ❌ 여행 이미지 전체 삭제 (로그/에러 노출 버전)
  // ai/{travelId}/*
  // user/{travelId}/{dayId}/*
  // =====================================================
  static Future<void> deleteTravelImages(String travelId) async {
    final bucket = _supabase.storage.from(_bucketName);

    debugPrint('🗑️ [STORAGE] deleteTravelImages START travelId=$travelId');

    try {
      // ---------- AI ----------
      final aiList = await bucket.list(path: 'ai/$travelId');
      debugPrint('🗑️ [STORAGE] aiList count=${aiList.length}');

      if (aiList.isNotEmpty) {
        final aiPaths = aiList.map((f) => 'ai/$travelId/${f.name}').toList();
        debugPrint('🗑️ [STORAGE] remove aiPaths=$aiPaths');
        await bucket.remove(aiPaths);
        debugPrint('✅ [STORAGE] ai removed');
      }

      // ---------- USER (dayId 폴더) ----------
      final dayFolders = await bucket.list(path: 'user/$travelId');
      debugPrint('🗑️ [STORAGE] dayFolders count=${dayFolders.length}');

      for (final folder in dayFolders) {
        final folderPath = 'user/$travelId/${folder.name}';
        final files = await bucket.list(path: folderPath);
        debugPrint('🗑️ [STORAGE] $folderPath files=${files.length}');

        if (files.isNotEmpty) {
          final userPaths = files.map((f) => '$folderPath/${f.name}').toList();
          debugPrint('🗑️ [STORAGE] remove userPaths=$userPaths');
          await bucket.remove(userPaths);
          debugPrint('✅ [STORAGE] removed $folderPath');
        }
      }

      debugPrint('✅ [STORAGE] deleteTravelImages END travelId=$travelId');
    } catch (e, s) {
      // 🔥 여기서 403/Unauthorized가 거의 나옴
      debugPrint('❌ [STORAGE] deleteTravelImages FAILED: $e');
      debugPrint('$s');
      rethrow; // 실패 숨기지 말고 위로 올려서 원인 바로 보자
    }
  }
}
