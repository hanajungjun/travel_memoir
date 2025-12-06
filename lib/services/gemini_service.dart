import 'dart:convert';
import 'dart:typed_data';
import '../env.dart';
import 'package:http/http.dart' as http;

class GeminiService {
  final String apiKey = "AIzaSyBgRHDXyL8YA797h5o-PYZUtety1UAdU10";

  // --------------------------
  // 🟩 텍스트 요약 (정상 작동)
  // --------------------------
  Future<String> generateSummary(
    String city,
    String date,
    String content,
  ) async {
    final url =
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$apiKey";

    final prompt =
        """
당신은 여행 일기를 요약하는 작가입니다.
도시: $city
날짜: $date
내용: $content

이 여행을 3~4문장으로 감성적으로 요약해줘.
""";

    final res = await http.post(
      Uri.parse(url),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "contents": [
          {
            "parts": [
              {"text": prompt},
            ],
          },
        ],
      }),
    );

    print("🟩 Summary Response:");
    print(res.body);

    final data = jsonDecode(res.body);

    return data["candidates"][0]["content"]["parts"][0]["text"];
  }

  // --------------------------
  // 🟦 Imagen 4 이미지 생성 (정답)
  // --------------------------
  Future<Uint8List> generateImage(String prompt) async {
    final url =
        "https://generativelanguage.googleapis.com/v1beta/models/imagen-4.0-generate-001:predict?key=$apiKey";

    final res = await http.post(
      Uri.parse(url),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "instances": [
          {"prompt": prompt},
        ],
      }),
    );

    print("🟦 Image API Response:");
    print(res.body);

    if (res.body.isEmpty) throw Exception("❌ 응답이 비었음");

    final data = jsonDecode(res.body);

    try {
      final base64Img = data["predictions"][0]["bytesBase64Encoded"];

      return base64Decode(base64Img);
    } catch (e) {
      throw Exception("❌ 이미지 생성 오류: $e\n원본: $data");
    }
  }
}
