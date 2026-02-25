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

  // --------------------------------------------------------------------------
  // ✅ 공통 HTTP 재시도 헬퍼 (503, 429 에러 대응)
  // --------------------------------------------------------------------------
  Future<http.Response> _postWithRetry(
    Uri uri,
    Map<String, dynamic> body,
  ) async {
    int retryCount = 0;
    const int maxRetries = 3;

    while (true) {
      try {
        final response = await http
            .post(
              uri,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(body),
            )
            .timeout(const Duration(seconds: 40)); // 이미지 생성은 시간이 걸리므로 40초

        if ((response.statusCode == 503 || response.statusCode == 429) &&
            retryCount < maxRetries) {
          retryCount++;
          int waitSeconds = math.pow(2, retryCount - 1).toInt();
          debugPrint(
            '⚠️ [Gemini] 서버 과부하(${response.statusCode}) 감지. ${waitSeconds}초 후 재시도... ($retryCount/$maxRetries)',
          );
          await Future.delayed(Duration(seconds: waitSeconds));
          continue;
        }
        return response;
      } catch (e) {
        if (retryCount < maxRetries) {
          retryCount++;
          await Future.delayed(const Duration(seconds: 2));
          continue;
        }
        rethrow;
      }
    }
  }

  // ✍️ 텍스트 요약
  Future<String> generateSummary({
    String? finalPrompt,
    String? diaryText,
    String? location,
    required List<Uint8List> photoBytes,
    String languageCode = 'en',
  }) async {
    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent?key=$_apiKey',
    );

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

    final res = await _postWithRetry(uri, {
      'contents': [
        {'parts': parts},
      ],
    });

    if (res.statusCode != 200) {
      throw Exception(
        res.statusCode == 503
            ? 'server_busy_error'.tr()
            : '❌ HTTP ${res.statusCode}',
      );
    }

    final decoded = jsonDecode(res.body);
    final candidates = decoded['candidates'];
    if (candidates == null || candidates.isEmpty) {
      throw Exception('ai_error_guide'.tr());
    }

    return candidates[0]['content']['parts'][0]['text'].toString().trim();
  }

  // 🎨 이미지 생성
  Future<Uint8List> generateImage({
    String? finalPrompt,
    String? summary,
    String? stylePrompt,
    String languageCode = 'en',
  }) async {
    String imagePrompt = (finalPrompt != null && finalPrompt.isNotEmpty)
        ? finalPrompt
        : '${(languageCode == 'ko') ? PromptCache.imagePrompt.contentKo : PromptCache.imagePrompt.contentEn}\nStyle: $stylePrompt\n[Context]: $summary';

    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-image:generateContent?key=$_apiKey',
    );

    try {
      return await _executeImageRequest(uri, imagePrompt);
    } catch (e) {
      return await _executeImageRequest(
        uri,
        '$imagePrompt\n\nGenerate exactly ONE image. No text.',
      );
    }
  }

  Future<Uint8List> _executeImageRequest(Uri uri, String prompt) async {
    final body = {
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
    };

    final res = await _postWithRetry(uri, body);
    if (res.statusCode != 200)
      throw Exception(
        res.statusCode == 503
            ? 'server_busy_error'.tr()
            : '❌ Gemini Image Error',
      );

    final decoded = jsonDecode(res.body);
    final base64Str =
        decoded['candidates']?[0]['content']?['parts']?[0]?['inlineData']?['data'];
    if (base64Str == null) throw Exception('GEMINI_TEXT_ONLY_RESPONSE');
    return base64Decode(base64Str);
  }

  // 🗺️ 인포그래픽 생성 (풀버전 로직 유지)
  Future<Uint8List> generateFullTravelInfographic({
    required List<String> allDiaryTexts,
    required String getPlaceName,
    required String travelType,
    List<String>? photoUrls,
  }) async {
    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-image:generateContent?key=$_apiKey',
    );
    final premiumPrompt = await AiPremiumPromptService.fetchActive();
    if (premiumPrompt == null) throw Exception('❌ 활성 프리미엄 프롬프트 없음');

    String placeName = getPlaceName;
    if (travelType == 'usa') {
      placeName = "$getPlaceName, a state in the United States Of America";
    } else if (travelType == 'domestic') {
      placeName = "$getPlaceName, South Korea";
    }

    String basePrompt = premiumPrompt.prompt.replaceAll(
      'Infographic',
      'Seamless Cinematic Travel Mural Illustration',
    );

    String durationInstruction = "";
    String textStrictRule = "";
    int dayCount = allDiaryTexts.length;

    if (dayCount <= 1) {
      durationInstruction =
          """
\n[Style Focus: Single Landscape Masterpiece]
- This is a 1-day journey. [CRITICAL] ABSOLUTELY NO TEXT, NO NUMBERS, NO LABELS.
- Do not create any banner or title plate at the top.
- Focus 100% on a single, unified, atmospheric scenery of $placeName.
""";
      textStrictRule = "ZERO TEXT ALLOWED. No letters, no numbers, no words.";
    } else {
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

    String layoutAndTextInstruction =
        """
\n[STRICT LAYOUT OVERRIDE]
- NO HEADERS, NO BANNERS, NO TITLE PLATES, NO RECTANGULAR BOXES.
- The top of the image MUST be filled with the sky, clouds, or landscape scenery. 
- Ensure there is NO blank or solid-colored bar at the top or bottom.
- $textStrictRule
- Entire image must be edge-to-edge illustration with no borders.
""";

    String finalPrompt =
        basePrompt.replaceAll(
          '\${allDiaryTexts.join(\'\\n\')}',
          allDiaryTexts.join('\n'),
        ) +
        durationInstruction +
        layoutAndTextInstruction;

    final body = {
      'contents': [
        {
          'parts': [
            {'text': finalPrompt},
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
    };

    // ✅ 재시도 로직 적용
    final res = await _postWithRetry(uri, body);
    if (res.statusCode != 200)
      throw Exception('❌ 이미지 생성 실패 (${res.statusCode})');

    final data = jsonDecode(res.body);
    final imageBase64 =
        data['candidates'][0]['content']['parts'][0]['inlineData']['data'];
    return base64Decode(imageBase64);
  }
}
