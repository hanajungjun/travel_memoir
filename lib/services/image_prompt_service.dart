import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/image_prompt_model.dart';

class ImagePromptService {
  static final _client = Supabase.instance.client;

  static Future<ImagePromptModel> fetchActiveImagePrompt() async {
    final res = await _client
        .from('ai_image_prompts')
        .select()
        .eq('is_active', true)
        .single();

    return ImagePromptModel.fromMap(res);
  }
}
