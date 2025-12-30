import 'package:travel_memoir/services/gemini_service.dart';
import 'package:travel_memoir/services/travel_day_service.dart';

class TravelHighlightService {
  static Future<String?> generateHighlight({
    required String travelId,
    required String placeName,
  }) async {
    // 1️⃣ 모든 일기 가져오기
    final days = await TravelDayService.getDiariesByTravel(travelId: travelId);

    // ai_summary 있는 것만
    final summaries = days
        .map((d) => (d['ai_summary'] ?? '').toString().trim())
        .where((s) => s.isNotEmpty)
        .toList();

    if (summaries.isEmpty) return null;

    // 2️⃣ 프롬프트
    final prompt =
        '''
다음은 하나의 여행 동안 작성된 일기 요약들입니다.

이 여행 전체를 대표하는
"감정 중심의 한 문장"으로 요약해주세요.

조건:
- 1문장
- 감정 위주
- 설명체 ❌
- 제목처럼 간결하게

여행지: $placeName

일기 요약들:
${summaries.map((s) => '- $s').join('\n')}
''';

    // 3️⃣ Gemini 호출
    final gemini = GeminiService();
    final highlight = await gemini.generateSummary(
      finalPrompt: prompt,
      photos: const [],
    );

    return highlight.trim();
  }
}
