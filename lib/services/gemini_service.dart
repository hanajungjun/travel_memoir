import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';

import 'package:http/http.dart' as http;
import '../env.dart';

class GeminiService {
  final String apiKey = AppEnv.geminiApiKey;

  // ---------------------------------------------------------
  // 🟩 요약 생성 (텍스트 + 사진 포함)
  // ---------------------------------------------------------
  Future<String> generateSummary({
    required String city,
    required String date,
    required String content,
    required List<File> photos,
  }) async {
    final url =
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$apiKey";

    final parts = <Map<String, dynamic>>[];

    // 텍스트
    parts.add({
      "text":
          """
당신은 여행 작가입니다.
다음 정보를 감성적으로 3~6문장으로 요약하세요.

도시: $city
날짜: $date
내용: $content
""",
    });

    // 사진 포함 (0~3장)
    for (final file in photos) {
      final bytes = await file.readAsBytes();
      parts.add({
        "inlineData": {"mimeType": "image/jpeg", "data": base64Encode(bytes)},
      });
    }

    final body = {
      "contents": [
        {"parts": parts},
      ],
    };

    final res = await http.post(
      Uri.parse(url),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(body),
    );

    final data = jsonDecode(res.body);

    if (data["candidates"] == null) {
      return "요약 생성 오류: $data";
    }

    return data["candidates"][0]["content"]["parts"][0]["text"];
  }

  // ---------------------------------------------------------
  // 🎨 이미지 생성 (base64 → Uint8List)
  // ---------------------------------------------------------
  Future<Uint8List> generateImage(String prompt) async {
    final url =
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-image:generateContent?key=$apiKey";

    final strongPrompt =
        """
$prompt

Rules:
- MUST return image.
- MUST include inlineData.
- NO text, NO captions, NO letters.
""";

    final body = {
      "contents": [
        {
          "parts": [
            {"text": strongPrompt},
          ],
        },
      ],
    };

    final res = await http.post(
      Uri.parse(url),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(body),
    );

    if (res.body.isEmpty) {
      throw Exception("❌ 빈 응답");
    }

    final data = jsonDecode(res.body);

    if (data["candidates"] == null) {
      throw Exception("❌ 이미지 생성 오류: $data");
    }

    final parts = data["candidates"][0]["content"]["parts"] as List<dynamic>?;

    if (parts == null) {
      throw Exception("❌ parts 없음: $data");
    }

    final inlinePart = parts.firstWhere(
      (p) => p["inlineData"] != null,
      orElse: () => null,
    );

    if (inlinePart == null) {
      throw Exception("❌ inlineData 없음 → 이미지가 아닌 텍스트만 반환됨.\n원본: $data");
    }

    final base64img = inlinePart["inlineData"]["data"];
    return base64Decode(base64img);
  }
}
