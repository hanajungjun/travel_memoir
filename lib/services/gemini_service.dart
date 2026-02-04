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

  Future<Uint8List> generateFullTravelInfographic({
    required List<String> allDiaryTexts,
    List<String>? photoUrls,
  }) async {
    final url =
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-image:generateContent?key=$_apiKey';

    final premiumPrompt = await AiPremiumPromptService.fetchActive();

    if (premiumPrompt == null) {
      throw Exception('❌ 활성 프리미엄 프롬프트 없음');
    }

    // 1️⃣ 여행 기간에 따른 컨셉 지시문 (기존 로직 유지)
    String durationInstruction = "";
    int dayCount = allDiaryTexts.length;

    if (dayCount <= 1) {
      durationInstruction = """
\n[Style Focus: Day Trip Snapshot]
- This is a single-day trip. Focus on capturing the intense mood and atmosphere of this one day.
- Highlight the core events of the day in a centralized, large-scale infographic design.
- Don't split the page; use a unified, high-impact layout that emphasizes the key emotion.
""";
    } else {
      durationInstruction =
          """
\n[Style Focus: Multi-day Journey Timeline]
- This is a journey of $dayCount days. Focus on the chronological flow (Day 1, Day 2, etc.).
- Use a timeline or road-map style layout to distinguish between different days.
- Ensure each day's highlights are summarized and visually partitioned within the graphic.
""";

      // 각 날짜별 하이라이트 추가
      List<String> dayInstructions = [];
      for (int i = 0; i < dayCount; i++) {
        dayInstructions.add("""
      [Day ${i + 1} Highlights]:
      - ${allDiaryTexts[i]}
      """);
      }

      // "DAY ~" 대신 구체적인 날짜 추가
      durationInstruction += dayInstructions.join("\n");
    }

    // 2️⃣ 사진 배치 지시문 (기존 로직 유지)
    String photoInstruction = "";
    if (photoUrls != null && photoUrls.isNotEmpty) {
      photoInstruction =
          "\n[Photo Overlay Note]: Real photos will be placed inside the top-left and bottom-right corners as stickers. Keep these areas simple to let the photos stand out.";
    }

    // 3️⃣ [중요] 텍스트 생성 금지 지시 (제목을 지우기 위함)
    String noTextInstruction =
        "\n[STRICT REQUIREMENT: NO TEXT] Do not include any text or letters in the image.";

    // 4️⃣ 최종 프롬프트 조립
    String finalPrompt =
        premiumPrompt.prompt.replaceAll(
          '\${allDiaryTexts.join(\'\\n\')}',
          allDiaryTexts.join('\n'),
        ) +
        durationInstruction +
        photoInstruction +
        noTextInstruction;

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
}
