import 'dart:io';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

class ImageUploadService {
  static final _supabase = Supabase.instance.client;

  // =====================================================
  // 🤖 AI 생성 이미지 업로드 (원본 메서드)
  // =====================================================
  static Future<String> uploadAiImage({
    required Uint8List imageBytes,
    required String travelId,
    required DateTime date,
  }) async {
    final fileName = '${date.toIso8601String().substring(0, 10)}.png';
    final path = 'ai/$travelId/$fileName';

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
  // ✍️ 일기 이미지 업로드 (AI 이미지 alias)
  // =====================================================
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
  // 📸 사용자가 직접 올린 사진 업로드
  // =====================================================
  static Future<String> uploadUserImage({
    required File file,
    required String travelId,
    required String dayId,
  }) async {
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    final path = 'user/$travelId/$dayId/$fileName';

    await _supabase.storage
        .from('travel_images')
        .upload(
          path,
          file,
          fileOptions: const FileOptions(contentType: 'image/jpeg'),
        );

    return _supabase.storage.from('travel_images').getPublicUrl(path);
  }

  // =====================================================
  // 🖼 여행 완료 후 AI 커버 이미지 업로드 (추가)
  // path: ai/{travelId}/cover.png
  // =====================================================
  static Future<String> uploadTravelCoverImage({
    required Uint8List imageBytes,
    required String travelId,
  }) async {
    final path = 'ai/$travelId/cover.png';

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
  // 🗺 여행 완료 후 AI 지도 이미지 업로드 (추가)
  // path: ai/{travelId}/map.png
  // =====================================================
  static Future<String> uploadTravelMapImage({
    required Uint8List imageBytes,
    required String travelId,
  }) async {
    final path = 'ai/$travelId/map.png';

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
}
