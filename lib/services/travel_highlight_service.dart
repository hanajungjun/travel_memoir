import 'package:intl/intl.dart';
import 'package:travel_memoir/services/gemini_service.dart';
import 'package:travel_memoir/services/travel_day_service.dart';

class TravelHighlightService {
  static Future<String?> generateHighlight({
    required String travelId,
    required String placeName,
  }) async {
    // 1️⃣ 모든 일기 가져오기
    final days = await TravelDayService.getDiariesByTravel(travelId: travelId);

    // ✅ [핵심 로직] AI 요약이 있으면 1순위, 없으면 원본 글을 2순위로 가져오기
    final combinedContents = days
        .map((d) {
          final String aiSum = (d['ai_summary'] ?? '').toString().trim();
          final String rawText = (d['text'] ?? '').toString().trim();

          // AI 요약이 비어있지 않으면 그걸 쓰고, 비어있으면 원본 글을 씁니다.
          return aiSum.isNotEmpty ? aiSum : rawText;
        })
        .where((content) => content.isNotEmpty)
        .toList();

    // 재료가 아예 없으면 포기
    if (combinedContents.isEmpty) return null;

    // 2️⃣ 현재 언어 확인
    final String currentLocale = Intl.getCurrentLocale();
    final bool isKorean = currentLocale.contains('ko');

    // 3️⃣ 다국어 프롬프트 구성 (summaries 대신 combinedContents 사용)
    final prompt = isKorean
        ? '''
다음은 하나의 여행 동안 작성된 일기 내용들입니다. (AI 요약 혹은 원본 글)
이 여행 전체를 대표하는 "감정 중심의 한 문장"으로 요약해주세요.

조건:
- 1문장으로 작성
- 감정 위주로 표현
- 설명하는 투가 아닌 감성적인 문체
- 제목처럼 간결하게
- 반드시 한국어로 답변하세요.

여행지: $placeName
일기 내용들:
${combinedContents.map((c) => '- $c').join('\n')}
'''
        : '''
The following are trip diary entries (AI summaries or raw text).
Please summarize this entire trip into a "single emotion-centered sentence" that represents the whole journey.

Conditions:
- Write in exactly 1 sentence.
- Focus on emotions and feelings.
- Use a poetic or emotional tone, not an explanatory one.
- Concise, like a title.
- Must respond in English.

Destination: $placeName
Diaries:
${combinedContents.map((c) => '- $c').join('\n')}
''';

    // 4️⃣ Gemini 호출
    try {
      final gemini = GeminiService();
      final highlight = await gemini.generateSummary(
        finalPrompt: prompt,
        photos: const [],
      );

      return highlight.trim();
    } catch (e) {
      print('❌ [Highlight-Error] $e');
      return null;
    }
  }
}
