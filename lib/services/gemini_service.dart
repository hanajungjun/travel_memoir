import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:travel_memoir/env.dart';

import 'package:travel_memoir/models/ai_premium_prompt_model.dart';
import 'package:travel_memoir/services/ai_premium_prompt_service.dart';

class GeminiService {
  final String _apiKey = AppEnv.geminiApiKey;

  // ============================
  // ✍️ 텍스트 요약 (개별 일차용) - 기존 동일
  // ============================
  Future<String> generateSummary({
    required String finalPrompt,
    required List<File> photos,
  }) async {
    final url =
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent?key=$_apiKey';

    debugPrint('🤖 [GEMINI] summary request');

    final parts = <Map<String, dynamic>>[
      {'text': finalPrompt},
    ];

    for (final file in photos) {
      final bytes = await file.readAsBytes();
      parts.add({
        'inlineData': {'mimeType': 'image/jpeg', 'data': base64Encode(bytes)},
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

    if (res.statusCode != 200) {
      throw Exception('❌ Gemini summary HTTP ${res.statusCode}: ${res.body}');
    }

    final decoded = jsonDecode(res.body);
    final candidates = decoded['candidates'];
    if (candidates == null || candidates.isEmpty) {
      throw Exception('❌ Gemini summary: no candidates');
    }

    final content = candidates[0]['content'];
    final partsRes = content?['parts'];
    if (partsRes == null || partsRes.isEmpty || partsRes[0]['text'] == null) {
      throw Exception('❌ Gemini summary: empty text response');
    }

    final text = partsRes[0]['text'].toString().trim();
    debugPrint('✅ [GEMINI] summary success');
    return text;
  }

  // ============================
  // 🎨 이미지 생성 (반드시 IMAGE 반환) - 기존 동일
  // ============================
  Future<Uint8List> generateImage({required String finalPrompt}) async {
    debugPrint('🤖 [GEMINI] image request');

    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-image:generateContent?key=$_apiKey',
    );

    try {
      return await _requestImage(uri, finalPrompt);
    } catch (e) {
      debugPrint('⚠️ [GEMINI] image retry once');
    }

    return await _requestImage(uri, '''
$finalPrompt

  Generate exactly ONE image as the final result.
  Return IMAGE ONLY with no text explanation.
  ''');
  }

  // ============================
  // 내부 이미지 요청 (공통 헬퍼) - 기존 동일
  // ============================
  Future<Uint8List> _requestImage(Uri uri, String prompt) async {
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
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('❌ Gemini image HTTP ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    final base64Str =
        decoded['candidates'][0]['content']?['parts'][0]['inlineData']?['data'];

    if (base64Str == null) {
      throw Exception('GEMINI_TEXT_ONLY_RESPONSE');
    }

    return base64Decode(base64Str);
  }

  Future<Uint8List> generateFullTravelInfographic({
    required List<String> allDiaryTexts,
    required String placeName, // 👈 widget.placeName 대신 파라미터로 받음
    List<String>? photoUrls,
  }) async {
    final url =
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-image:generateContent?key=$_apiKey';

    final premiumPrompt = await AiPremiumPromptService.fetchActive();

    if (premiumPrompt == null) {
      throw Exception('❌ 활성 프리미엄 프롬프트 없음');
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
