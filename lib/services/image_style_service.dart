import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:travel_memoir/models/image_style_model.dart';

class ImageStyleService {
  static final _client = Supabase.instance.client;

  /// 앱용: 사용 중 스타일만
  static Future<List<ImageStyleModel>> fetchEnabled() async {
    final res = await _client
        .from('ai_image_styles')
        .select()
        .eq('is_enabled', true)
        .order('created_at', ascending: false);

    return (res as List).map((e) => ImageStyleModel.fromMap(e)).toList();
  }
}
