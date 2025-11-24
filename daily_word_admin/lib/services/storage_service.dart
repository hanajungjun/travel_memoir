import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

class StorageService {
  final storage = Supabase.instance.client.storage;

  Future<String> uploadImage({
    required String dateKey,
    required Uint8List bytes,
  }) async {
    // 🔥 고유 파일명 생성 (날짜 + timestamp 조합)
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = "${dateKey}_$timestamp.png";

    await storage
        .from('daily_images')
        .uploadBinary(
          fileName,
          bytes,
          fileOptions: const FileOptions(
            upsert: false, // 🔥 절대 덮어쓰기 안함
            contentType: 'image/png',
          ),
        );

    return storage.from('daily_images').getPublicUrl(fileName);
  }
}
