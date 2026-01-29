import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../models/image_style_model.dart';

class ImageStyleService {
  static final _client = Supabase.instance.client;

  /// ✅ 앱용: 활성화된 스타일만 정렬 순서대로 가져오기
  static Future<List<ImageStyleModel>> fetchEnabled() async {
    final res = await _client
        .from('ai_image_styles')
        .select()
        .eq('is_enabled', true)
        .order('sort_order', ascending: true); // 🔥 정렬 순서 반영

    return (res as List).map((e) => ImageStyleModel.fromMap(e)).toList();
  }

  /// 🔥 언어별 제목 반환 (위젯에서 직접 로직 짜지 않게 헬퍼로 분리)
  static String getLocalizedTitle(ImageStyleModel style, BuildContext context) {
    final String currentLang = context.locale.languageCode;
    if (currentLang == 'en' && style.titleEn.isNotEmpty) {
      return style.titleEn;
    }
    return style.title;
  }
}
