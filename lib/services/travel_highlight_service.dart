import 'dart:ui';
import 'package:travel_memoir/services/gemini_service.dart';
import 'package:travel_memoir/services/travel_day_service.dart';

class TravelHighlightService {
  static Future<String?> generateHighlight({
    required String travelId,
    required String placeName,
    required String languageCode, // 🎯 넘겨받은 언어 코드 ('ko', 'en' 등)
  }) async {
    // 1️⃣ 모든 일기 가져오기
    final days = await TravelDayService.getDiariesByTravel(travelId: travelId);

    final combinedContents = days
        .map((d) {
          final String aiSum = (d['ai_summary'] ?? '').toString().trim();
          final String rawText = (d['text'] ?? '').toString().trim();
          return aiSum.isNotEmpty ? aiSum : rawText;
        })
        .where((content) => content.isNotEmpty)
        .toList();

    if (combinedContents.isEmpty) return null;

    // 2️⃣ 언어별 프롬프트 구성 (switch 문 하나로 종결)
    String prompt = '';
    final String diaryList = combinedContents.map((c) => '- $c').join('\n');

    print("------------------------------");
    print("Final  languageCode: $languageCode");
    print("------------------------------");

    switch (languageCode) {
      case 'ko':
        prompt =
            '''
다음은 여행 동안 작성된 일기 내용입니다.
이 여행 전체를 대표하는 "감정 중심의 한 문장"으로 요약해주세요.

조건:
- 1문장으로 작성할 것
- 감정 위주로, 감성적인 문체 사용
- 제목처럼 간결하게
- 반드시 한국어로 답변하세요.
- **와 같은 마크다운 강조 기호를 절대 사용하지 마세요. (순수 텍스트만 출력)
여행지: $placeName
일기 내용:
$diaryList
''';
        break;

      case 'ja': // 나중에 추가될 일본어 대비
        prompt =
            '''
旅行の日記の内容です。
この旅行を代表하는「感情中心の一文」に要約してください。
- 必ず日本語で回答してください。
- 1文で作成すること。
- [厳格] ** や # などのマークダウン記号、および特殊文字は一切「使用しない」こと。(純粋なテキストのみを出力)
目的地: $placeName
日記の内容:
$diaryList 
''';
        break;

      case 'en':
      default: // 영어 및 기타 언어
        prompt =
            '''
The following are trip diary entries.
Please summarize this entire trip into a "single emotion-centered sentence".

Conditions:
- Write in exactly 1 sentence.
- Use a poetic or emotional tone.
- Concise, like a title.
- [IMPORTANT] Must respond in English.
- [STRICT] Do not use any markdown formatting or special characters (e.g., **, #, _, *).
Destination: $placeName
Diaries:
$diaryList
''';
        break;
    }

    print("---------- [GEMINI PROMPT SEND] ----------");
    print("Target Language: $languageCode");
    print("Prompt Preview: ${prompt.substring(0, 50)}...");

    // 4️⃣ Gemini 호출
    try {
      final gemini = GeminiService();
      final highlight = await gemini.generateSummary(
        finalPrompt: prompt,
        photoBytes: const [], // 👈 여기를 photoBytes로 수정!
        languageCode: languageCode,
      );

      return highlight.trim();
    } catch (e) {
      print('❌ [Highlight-Error] $e');
      return null;
    }
  }
}
