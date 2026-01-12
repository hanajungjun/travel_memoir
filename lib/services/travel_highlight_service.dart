import 'package:intl/intl.dart'; // 👈 현재 로케일 확인을 위해 필요
import 'package:travel_memoir/services/gemini_service.dart';
import 'package:travel_memoir/services/travel_day_service.dart';

class TravelHighlightService {
  static Future<String?> generateHighlight({
    required String travelId,
    required String placeName,
  }) async {
    // 1️⃣ 모든 일기 가져오기
    final days = await TravelDayService.getDiariesByTravel(travelId: travelId);

    final summaries = days
        .map((d) => (d['ai_summary'] ?? '').toString().trim())
        .where((s) => s.isNotEmpty)
        .toList();

    if (summaries.isEmpty) return null;

    // 2️⃣ 현재 언어 확인 (ko 또는 en 등)
    final String currentLocale = Intl.getCurrentLocale();
    final bool isKorean = currentLocale.contains('ko');

    // 3️⃣ 다국어 프롬프트 구성
    final prompt = isKorean
        ? '''
다음은 하나의 여행 동안 작성된 일기 요약들입니다.
이 여행 전체를 대표하는 "감정 중심의 한 문장"으로 요약해주세요.

조건:
- 1문장으로 작성
- 감정 위주로 표현
- 설명하는 투가 아닌 감성적인 문체
- 제목처럼 간결하게
- 반드시 한국어로 답변하세요.

여행지: $placeName
일기 요약들:
${summaries.map((s) => '- $s').join('\n')}
'''
        : '''
The following are summaries written during a trip.
Please summarize this entire trip into a "single emotion-centered sentence" that represents the whole journey.

Conditions:
- Write in exactly 1 sentence.
- Focus on emotions and feelings.
- Use a poetic or emotional tone, not an explanatory one.
- Concise, like a title.
- Must respond in English.

Destination: $placeName
Diaries:
${summaries.map((s) => '- $s').join('\n')}
''';

    // 4️⃣ Gemini 호출
    final gemini = GeminiService();
    final highlight = await gemini.generateSummary(
      finalPrompt: prompt,
      photos: const [],
    );

    return highlight.trim();
  }
}
