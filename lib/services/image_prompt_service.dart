import 'dart:ui' as ui; // 기기 언어 확인용
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/image_prompt_model.dart';

class ImagePromptService {
  static final _client = Supabase.instance.client;

  // 1. 활성화된 이미지 프롬프트 데이터 가져오기
  static Future<ImagePromptModel?> fetchActiveImagePrompt() async {
    // 🔥 single() 대신 maybeSingle()을 써서 데이터가 없을 때 터지는 것을 방지합니다.
    final res = await _client
        .from('ai_image_prompts')
        .select()
        .eq('is_active', true)
        .maybeSingle();

    if (res == null) return null;
    return ImagePromptModel.fromMap(res);
  }

  // 🔥 2. [사용자용] 현재 기기 언어에 맞는 설명(한글/영어) 반환
  static String getLocalizedDescription(ImagePromptModel prompt) {
    final String languageCode = ui.window.locale.languageCode;

    if (languageCode == 'ko') {
      return prompt.contentKo.isNotEmpty ? prompt.contentKo : prompt.contentEn;
    } else {
      return prompt.contentEn.isNotEmpty ? prompt.contentEn : prompt.contentKo;
    }
  }

  // 🔥 3. [AI 생성용] 실제 AI에게 던질 프롬프트 (영문 우선 전략)
  static String getEffectivePrompt(ImagePromptModel prompt) {
    // DALL-E/Gemini Imagen 등은 영문 프롬프트가 훨씬 정확합니다.
    // 영문 데이터가 있다면 영문을 우선적으로 반환합니다.
    if (prompt.contentEn.isNotEmpty) {
      return prompt.contentEn;
    }
    return prompt.contentKo;
  }
}
