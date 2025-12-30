import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/prompt_model.dart';

class PromptService {
  static final _client = Supabase.instance.client;

  static Future<PromptModel?> fetchActivePrompt() async {
    final res = await _client
        .from('ai_prompts')
        .select()
        .eq('is_active', true)
        .limit(1)
        .maybeSingle();

    if (res == null) {
      // print('❌ [PromptService] 활성 프롬프트 없음');
      return null;
    }

    final prompt = PromptModel.fromMap(res);

    // 🔥 로그 핵심
    //print('✅ [PromptService] 활성 프롬프트 로드됨');
    //print('🆔 id: ${prompt.id}');
    //print('📌 title: ${prompt.title}');
    //print('📝 content:\n${prompt.content}');

    return prompt;
  }
}
