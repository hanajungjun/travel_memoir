import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../env.dart';

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

    final bool isSingleDay = allDiaryTexts.length <= 1;

    debugPrint('🤖 [GEMINI] premium infographic image request start');
    debugPrint('📊 [INFOGRAPHIC] title=$travelTitle');
    debugPrint('📊 [INFOGRAPHIC] diaryCount=${allDiaryTexts.length}');
    debugPrint('📊 [INFOGRAPHIC] isSingleDay=$isSingleDay');

    // --------------------------------------------------
    // 1️⃣ 프롬프트 구성 (하루 여행 / 여러 날 여행 분기)
    // --------------------------------------------------
    final String combinedText = isSingleDay
        ? """
너는 프리미엄 여행 리포트를 제작하는 비주얼 디자이너이자 일러스트레이터야.
아래 여행 정보를 바탕으로, 하루 여행을 한 장의 인포그래픽 이미지로 표현해줘.

⚠️ 규칙 (매우 중요):
- DAY 2, DAY 3 같은 여러 날짜를 절대 표현하지 마
- 타임라인, 일차 개념을 사용하지 마
- 오직 하루의 분위기와 기억만 시각적으로 표현해
- 설명문이나 텍스트 결과를 출력하지 말고, 이미지만 생성해

🎨 이미지 스타일:
- 인스타그램 여행 광고 느낌
- 따뜻하고 감성적인 톤
- 종이 다이어리 / 스크랩북 / 여행 노트 스타일
- 스티커, 테이프, 손글씨 느낌 요소
- 고급스럽고 프리미엄 감성

🧭 이미지 구성:
- 상단 제목: "${travelTitle}"
- 중앙: 하루 동안의 주요 순간들을 콜라주 형태로 배치
- 하단: "One perfect day" 같은 단일 하루 감성 문구

📷 참고 기록:
${allDiaryTexts.join('\n')}
"""
        : """
너는 프리미엄 여행 리포트를 제작하는 비주얼 디자이너이자 일러스트레이터야.
아래 여행 정보를 바탕으로, 여러 날에 걸친 여행을 한 장의 인포그래픽 이미지로 표현해줘.

⚠️ 규칙:
- 설명문이나 텍스트 결과를 출력하지 말고, 이미지만 생성해

🎨 이미지 스타일:
- 인스타그램 여행 광고 느낌
- 따뜻하고 감성적인 톤
- 종이 다이어리 / 스크랩북 / 여행 노트 스타일
- 스티커, 테이프, 손글씨 느낌 요소
- 고급스럽고 프리미엄 감성

🧭 이미지 구성:
- 상단 제목: "${travelTitle}"
- 중앙: DAY 1 ~ DAY ${allDiaryTexts.length} 타임라인과 여행 경로 아이콘
- 하단: "A journey to remember" 감성 문구

📷 참고 기록:
${allDiaryTexts.join('\n')}
""";

    final parts = <Map<String, dynamic>>[
      {'text': combinedText},
    ];

    // --------------------------------------------------
    // 2️⃣ 사진 참고 데이터 (최대 5장)
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
    // 3️⃣ Gemini 이미지 생성 요청
    // --------------------------------------------------
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
      debugPrint('❌ [GEMINI] error body: ${res.body}');
      throw Exception('❌ 이미지 생성 실패 (${res.statusCode})');
    }

    // --------------------------------------------------
    // 4️⃣ 이미지 결과 파싱
    // --------------------------------------------------
    try {
      final decoded = jsonDecode(res.body);
      final String base64Str =
          decoded['candidates'][0]['content']['parts'][0]['inlineData']['data'];

      debugPrint('✅ [GEMINI] premium infographic image success');
      return base64Decode(base64Str);
    } catch (e) {
      debugPrint('❌ [GEMINI] parsing error: $e');
      throw Exception('❌ 이미지 데이터 파싱 실패');
    }
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
