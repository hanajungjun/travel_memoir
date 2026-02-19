import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:travel_memoir/env.dart';
import 'package:travel_memoir/services/prompt_cache.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:travel_memoir/models/ai_premium_prompt_model.dart';
import 'package:travel_memoir/services/ai_premium_prompt_service.dart';

class GeminiService {
  final String _apiKey = AppEnv.geminiApiKey;

  // ============================
  // ✍️ 텍스트 요약 (generateSummary)
  // ============================
  Future<String> generateSummary({
    String? finalPrompt,
    String? diaryText,
    String? location,
    required List<Uint8List> photoBytes,
    String languageCode = 'en',
  }) async {
    final url =
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent?key=$_apiKey';

    // 변수명 충돌 방지를 위해 targetPrompt 사용
    String targetPrompt = (finalPrompt != null && finalPrompt.isNotEmpty)
        ? finalPrompt
        : '${(languageCode == 'ko') ? PromptCache.textPrompt.contentKo : PromptCache.textPrompt.contentEn}\n[Info] Location: $location\nDiary: $diaryText';

    final parts = <Map<String, dynamic>>[
      {'text': targetPrompt},
    ];

    for (final bytes in photoBytes) {
      parts.add({
        'inlineData': {'mimeType': 'image/webp', 'data': base64Encode(bytes)},
      });
    }

    final res = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {'parts': parts},
        ],
      }),
    );

    final decoded = jsonDecode(res.body);

    // 에러 발생 시 상세 로그 출력 (디버깅용)
    if (res.statusCode != 200) {
      debugPrint('❌ [Gemini Error Body]: ${res.body}');
      throw Exception('❌ HTTP ${res.statusCode}');
    }

    final candidates = decoded['candidates'];
    if (candidates == null || candidates.isEmpty) {
      // 🎯 Safety Filter에 걸렸을 가능성이 높음
      debugPrint('⚠️ [Safety Blocked]: ${decoded['promptFeedback']}');
      throw Exception('ai_error_guide'.tr());
    }

    return candidates[0]['content']['parts'][0]['text'].toString().trim();
  }

  // ============================
  // 🎨 이미지 생성 (generateImage)
  // ============================
  Future<Uint8List> generateImage({
    String? finalPrompt, // 👈 파라미터명 유지
    String? summary,
    String? stylePrompt,
    String languageCode = 'en',
  }) async {
    // 내부 변수명을 imagePrompt로 변경하여 파라미터와 충돌 방지
    String imagePrompt = "";

    if (finalPrompt != null && finalPrompt.isNotEmpty) {
      imagePrompt = finalPrompt;
    } else {
      final basePrompt = (languageCode == 'ko')
          ? PromptCache.imagePrompt.contentKo
          : PromptCache.imagePrompt.contentEn;
      imagePrompt = '$basePrompt\nStyle: $stylePrompt\n[Context]: $summary';
    }

    debugPrint('🤖 [GEMINI] image request (Lang: $languageCode)');
    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-image:generateContent?key=$_apiKey',
    );

    try {
      return await _requestImage(uri, imagePrompt);
    } catch (e) {
      debugPrint('⚠️ [GEMINI] image retry once');
      return await _requestImage(
        uri,
        '$imagePrompt\n\nGenerate exactly ONE image. No text.',
      );
    }
  }

  // 내부 이미지 요청 헬퍼
  Future<Uint8List> _requestImage(Uri uri, String prompt) async {
    debugPrint('🚀 [GEMINI_FINAL_PROMPT] >>>\n$prompt\n<<<');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'role': 'user',
            'parts': [
              {'text': prompt},
            ],
          },
        ],
        'generationConfig': {
          'responseModalities': ['IMAGE'],
        },
        'safetySettings': [
          {'category': 'HARM_CATEGORY_HARASSMENT', 'threshold': 'BLOCK_NONE'},
          {'category': 'HARM_CATEGORY_HATE_SPEECH', 'threshold': 'BLOCK_NONE'},
          {
            'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT',
            'threshold': 'BLOCK_NONE',
          },
          {
            'category': 'HARM_CATEGORY_DANGEROUS_CONTENT',
            'threshold': 'BLOCK_NONE',
          },
        ],
      }),
    );

    if (response.statusCode != 200) throw Exception('❌ Gemini Image Error');
    final decoded = jsonDecode(response.body);
    final base64Str =
        decoded['candidates'][0]['content']?['parts'][0]['inlineData']?['data'];
    if (base64Str == null) throw Exception('GEMINI_TEXT_ONLY_RESPONSE');
    return base64Decode(base64Str);
  }

  Future<Uint8List> generateFullTravelInfographic({
    required List<String> allDiaryTexts,
    required String getPlaceName, // 👈 widget.placeName 대신 파라미터로 받음
    required String travelType, // 👈 travel_type을 파라미터로 추가로 받으세요!
    List<String>? photoUrls,
  }) async {
    final url =
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-image:generateContent?key=$_apiKey';

    //어드민페이지 프리미엄프롬프트
    final premiumPrompt = await AiPremiumPromptService.fetchActive();

    if (premiumPrompt == null) {
      throw Exception('❌ 활성 프리미엄 프롬프트 없음');
    }

    String placeName = getPlaceName;
    if (travelType == 'usa') {
      placeName = "$getPlaceName, a state in the United States Of America";
    } else if (travelType == 'domestic') {
      placeName = "$getPlaceName, South Korea";
    }

    // 1️⃣ 'Infographic' 단어 제거 -> 'Mural Illustration'으로 교체 (배너 방지)
    String basePrompt = premiumPrompt.prompt.replaceAll(
      'Infographic',
      'Seamless Cinematic Travel Mural Illustration',
    );

    String durationInstruction = "";
    String textStrictRule = "";
    int dayCount = allDiaryTexts.length;

    // 2️⃣ 여행 기간별 텍스트 및 로직 처리
    if (dayCount <= 1) {
      // 당일치기: 텍스트/숫자/배너 완전 금지
      durationInstruction =
          """
\n[Style Focus: Single Landscape Masterpiece]
- This is a 1-day journey. [CRITICAL] ABSOLUTELY NO TEXT, NO NUMBERS, NO LABELS.
- Do not create any banner or title plate at the top.
- Focus 100% on a single, unified, atmospheric scenery of $placeName.
""";
      textStrictRule = "ZERO TEXT ALLOWED. No letters, no numbers, no words.";
    } else {
      // 다일 여행: 'Day X' 라벨만 허용 (박스/동그라미 숫자 금지)
      durationInstruction =
          """
\n[Style Focus: Artistic Journey Path of $dayCount Days]
- Visualize the sequence as a natural flow (e.g., a winding path through $placeName).
- Label each zone with VERY SMALL, simple English text: 'Day 1', 'Day 2' ... 'Day $dayCount'.
- [CRITICAL] Do not create any additional circles, icons, or buttons containing other numbers.
- Each 'Day X' label should be placed simply in the corner of its respective area.
""";
      textStrictRule =
          "The ONLY allowed text is 'Day 1', 'Day 2', etc. No other numbers or words.";

      for (int i = 0; i < dayCount; i++) {
        durationInstruction += "\n[Day ${i + 1} Scene]: ${allDiaryTexts[i]}";
      }
    }

    // 3️⃣ 레이아웃 파괴 명령 (상단 배너 및 네모칸 제거)
    String layoutAndTextInstruction =
        """
\n[STRICT LAYOUT OVERRIDE]
- NO HEADERS, NO BANNERS, NO TITLE PLATES, NO RECTANGULAR BOXES.
- The top of the image MUST be filled with the sky, clouds, or landscape scenery. 
- Ensure there is NO blank or solid-colored bar at the top or bottom.
- $textStrictRule
- Entire image must be edge-to-edge illustration with no borders.
""";

    // 4️⃣ 최종 프롬프트 조립
    String finalPrompt =
        basePrompt.replaceAll(
          '\${allDiaryTexts.join(\'\\n\')}',
          allDiaryTexts.join('\n'),
        ) +
        durationInstruction +
        layoutAndTextInstruction;

    print(' [finalPrompt] $finalPrompt');

    final parts = <Map<String, dynamic>>[
      {'text': finalPrompt},
    ];

    final res = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {'parts': parts},
        ],
        'generationConfig': {
          'responseModalities': ['IMAGE'],
        },
        'safetySettings': [
          {'category': 'HARM_CATEGORY_HARASSMENT', 'threshold': 'BLOCK_NONE'},
          {'category': 'HARM_CATEGORY_HATE_SPEECH', 'threshold': 'BLOCK_NONE'},
          {
            'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT',
            'threshold': 'BLOCK_NONE',
          },
          {
            'category': 'HARM_CATEGORY_DANGEROUS_CONTENT',
            'threshold': 'BLOCK_NONE',
          },
        ],
      }),
    );

    if (res.statusCode != 200) {
      debugPrint('❌ [GEMINI] error body: ${res.body}');
      throw Exception('❌ 이미지 생성 실패 (${res.statusCode})');
    }

    final data = jsonDecode(res.body);
    final imageBase64 =
        data['candidates'][0]['content']['parts'][0]['inlineData']['data'];

    return base64Decode(imageBase64);
  }
}
