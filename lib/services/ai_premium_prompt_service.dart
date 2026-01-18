import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/ai_premium_prompt_model.dart';

class AiPremiumPromptService {
  static final _supabase = Supabase.instance.client;
  static const _table = 'ai_premium_prompt';

  /// ✅ 활성화된 프리미엄 프롬프트 1개 가져오기
  static Future<AiPremiumPromptModel?> fetchActive() async {
    final row = await _supabase
        .from(_table)
        .select()
        .eq('is_active', true)
        .order('updated_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (row == null) return null;
    return AiPremiumPromptModel.fromMap(row);
  }
}
