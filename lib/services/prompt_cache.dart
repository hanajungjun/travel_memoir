import 'package:flutter/foundation.dart';
import '../models/prompt_model.dart';
import '../models/image_prompt_model.dart';
import 'prompt_service.dart';
import 'image_prompt_service.dart';

class PromptCache {
  static PromptModel? _textPrompt;
  static ImagePromptModel? _imagePrompt;

  static PromptModel get textPrompt {
    if (_textPrompt == null) {
      throw Exception('❌ need text prompt');
    }
    return _textPrompt!;
  }

  static ImagePromptModel get imagePrompt {
    if (_imagePrompt == null) {
      throw Exception('❌ need image prompt');
    }
    return _imagePrompt!;
  }

  static Future<void> refresh() async {
    _textPrompt = await PromptService.fetchActivePrompt();
    _imagePrompt = await ImagePromptService.fetchActiveImagePrompt();

    //  debugPrint('✅ [PromptCache] 프롬프트 로드 완료');
    //  debugPrint('📝 TEXT (${_textPrompt!.title})');
    //  debugPrint(_textPrompt!.content);
    //  debugPrint('🎨 IMAGE (${_imagePrompt!.title})');
    //  debugPrint(_imagePrompt!.content);
  }
}
