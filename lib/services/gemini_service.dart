import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../env.dart';

import 'package:travel_memoir/models/ai_premium_prompt_model.dart';
import 'package:travel_memoir/services/ai_premium_prompt_service.dart';

class GeminiService {
  final String _apiKey = AppEnv.geminiApiKey;

  // ============================
  // ✍️ 텍스트 요약 (개별 일차용)
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
  // 🎨 이미지 생성 (반드시 IMAGE 반환)
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
  // ✅ 프리미엄 전용: 여행 전체 통합 인포그래픽 이미지 생성
  //  - 하루 여행 / 여러 날 여행 자동 분기
  // ============================
  Future<Uint8List> generateFullTravelInfographic({
    required String travelTitle,
    required List<String> allDiaryTexts,
    List<File>? allPhotos,
  }) async {
    final url =
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-image:generateContent?key=$_apiKey';

    final premiumPrompt = await AiPremiumPromptService.fetchActive();

    if (premiumPrompt == null) {
      throw Exception('❌ 활성 프리미엄 프롬프트 없음');
    }

    String finalPrompt = premiumPrompt.prompt
        .replaceAll('\${travelTitle}', travelTitle)
        .replaceAll(
          '\${allDiaryTexts.join(\'\\n\')}',
          allDiaryTexts.join('\n'),
        );

    // debugPrint('🤖 [GEMINI PREMIUM PROMPT]');
    // debugPrint(finalPrompt);

    final parts = <Map<String, dynamic>>[
      {'text': finalPrompt},
    ];

    // --------------------------------------------------
    // 3️⃣ 사진 참고 데이터 (최대 5장)
    // --------------------------------------------------
    if (allPhotos != null && allPhotos.isNotEmpty) {
      for (final file in allPhotos.take(5)) {
        final bytes = await file.readAsBytes();
        parts.add({
          'inlineData': {'mimeType': 'image/jpeg', 'data': base64Encode(bytes)},
        });
      }
    }

    // --------------------------------------------------
    // 4️⃣ Gemini 이미지 생성 요청
    // --------------------------------------------------
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

    // ✅ [형님 요청 로그] 이미지 성공 시점 확인 (데이터 크기 추가)
    debugPrint('🤖 [GEMINI] image success (Size: ${imageBase64.length} bytes)');

    return base64Decode(imageBase64);
  }

  // ============================
  // 내부 이미지 요청 (공통 헬퍼)
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
