import 'dart:convert';
import 'package:http/http.dart' as http;

class OpenAIService {
  final String apiKey =
      "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";
  final String baseUrl = "https://api.openai.com/v1";

  // ---------------------------------------
  // 1) 여행 요약 생성 (안전 버전)
  // ---------------------------------------
  Future<String?> generateSummary(
    String city,
    String date,
    String content,
  ) async {
    final prompt =
        """
너는 여행 작가야.
다음 여행을 3~4문장으로 감성적으로 요약해줘.

도시: $city
날짜: $date
내용:
$content
""";

    final url = Uri.parse("$baseUrl/chat/completions");

    final res = await http.post(
      url,
      headers: {
        "Authorization": "Bearer $apiKey",
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "model": "gpt-4.1-mini",
        "messages": [
          {"role": "user", "content": prompt},
        ],
      }),
    );

    final json = jsonDecode(res.body);

    // ⛔ 에러 응답이면 텍스트로 반환
    if (json["error"] != null) {
      return "❌ OpenAI 오류: ${json["error"]["message"]}";
    }

    // ⛔ choices가 null이면 안전 처리
    final contentText = json["choices"]?[0]?["message"]?["content"]?.toString();

    if (contentText == null) {
      return "❌ 응답 형식 오류: 요약 내용을 찾을 수 없습니다.";
    }

    return contentText;
  }

  // ---------------------------------------
  // 2) 여행 이미지 생성 (안전 버전)
  // ---------------------------------------
  Future<String?> generateImage(String city, String content) async {
    final prompt =
        """
초등학생 그림일기 스타일로 여행을 그려줘.
크레용 느낌 / 단순한 색 / 귀엽고 직관적인 표현.
도시: $city
여행내용: $content
""";

    final url = Uri.parse("$baseUrl/images/generations");

    final res = await http.post(
      url,
      headers: {
        "Authorization": "Bearer $apiKey",
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "model": "gpt-image-1",
        "prompt": prompt,
        "size": "1024x1024",
      }),
    );

    final json = jsonDecode(res.body);

    // ⛔ 이미지 에러 처리
    if (json["error"] != null) {
      return "❌ 이미지 생성 오류: ${json["error"]["message"]}";
    }

    final urlResult = json["data"]?[0]?["url"];

    if (urlResult == null) {
      return "❌ 이미지 URL을 찾을 수 없습니다.";
    }

    return urlResult;
  }
}
