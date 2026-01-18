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

반드시 하나의 이미지로 결과를 생성하세요.
텍스트 설명 없이 이미지만 반환하세요.
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

    return base64Decode(imageBase64);
  }

  // ============================
  // ✅ [신규/수정] 프리미엄 전용: 여행 전체 통합 인포그래픽 이미지 생성
  // ============================
  Future<Uint8List> generateFullTravelInfographicOld({
    required String travelTitle,
    required List<String> allDiaryTexts,
    List<File>? allPhotos,
  }) async {
    // 이미지 생성을 위해 전용 모델 엔드포인트 사용
    final url =
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-image:generateContent?key=$_apiKey';

    debugPrint('🤖 [GEMINI] premium infographic image request');

    // 1. 모든 일기 내용을 하나의 맥락으로 합침
    String combinedContext = "여행 제목: $travelTitle\n\n[일자별 기록]\n";
    for (int i = 0; i < allDiaryTexts.length; i++) {
      if (allDiaryTexts[i].trim().isNotEmpty) {
        combinedContext += "${i + 1}일차: ${allDiaryTexts[i]}\n";
      }
    }

    // 2. 인포그래픽 생성을 위한 빡센 프롬프트 구성
    final prompt =
        '''
    $combinedContext

    위 내용을 바탕으로 이번 여행을 총망라하는 '여행 일기 이미지'를 딱 한 장만 생성해줘.
    디자인 가이드:
    1. 폴라로이드 사진, 손글씨 메모, 귀여운 스티커가 붙어있는 '다이어리 꾸미기(Scrapbook)' 스타일.
    2. 이미지 상단에는 "$travelTitle" 제목이 예쁘게 들어가야 함.
    3. 각 일차별 핵심 키워드가 말풍선이나 포스트잇 형태로 포함될 것.
    4. 전체적인 분위기는 화사하고 감성적인 여행 매거진 느낌.
    5. 텍스트 설명은 배제하고 오직 이미지만 반환할 것.
    ''';

    final parts = <Map<String, dynamic>>[
      {'text': prompt},
    ];

    // 사진이 있다면 참조용으로 추가 (최대 5장까지만 권장)
    if (allPhotos != null && allPhotos.isNotEmpty) {
      for (final file in allPhotos.take(5)) {
        final bytes = await file.readAsBytes();
        parts.add({
          'inlineData': {'mimeType': 'image/jpeg', 'data': base64Encode(bytes)},
        });
      }
    }

    final res = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {'parts': parts},
        ],
        'generationConfig': {
          'responseModalities': ['IMAGE'], // 🔥 반드시 이미지를 반환하도록 설정
        },
      }),
    );

    if (res.statusCode != 200) {
      throw Exception('❌ Gemini Infographic Error: ${res.body}');
    }

    final decoded = jsonDecode(res.body);
    final candidates = decoded['candidates'];
    if (candidates == null || candidates.isEmpty)
      throw Exception('No candidates');

    final base64Str =
        candidates[0]['content']?['parts'][0]['inlineData']?['data'];
    if (base64Str == null) throw Exception('Image data not found');

    debugPrint('✅ [GEMINI] premium infographic image success');
    return base64Decode(base64Str);
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
