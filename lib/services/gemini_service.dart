import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import '../env.dart';

class GeminiService {
  final String _apiKey = AppEnv.geminiApiKey;

  /// ✍️ 텍스트 요약 (프롬프트는 외부에서 완성된 문자열로 전달)
  Future<String> generateSummary({
    required String finalPrompt,
    required List<File> photos,
  }) async {
    final url =
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$_apiKey';

    final parts = <Map<String, dynamic>>[];

    parts.add({'text': finalPrompt});

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
      throw Exception('Gemini summary failed: ${res.body}');
    }

    final data = jsonDecode(res.body);
    return data['candidates'][0]['content']['parts'][0]['text'];
  }

  /// 🎨 이미지 생성 (프롬프트는 무조건 외부에서 완성)
  Future<Uint8List> generateImage({required String finalPrompt}) async {
    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-image:generateContent?key=$_apiKey',
    );

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'role': 'user',
            'parts': [
              {'text': finalPrompt},
            ],
          },
        ],
        'generationConfig': {
          'responseModalities': ['IMAGE'],
        },
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Gemini image failed: ${response.body}');
    }

    final decoded = jsonDecode(response.body);

    // ✅ 안전 파싱 (여기 중요)
    final candidates = decoded['candidates'];
    if (candidates == null || candidates.isEmpty) {
      throw Exception('Gemini image response has no candidates');
    }

    final parts = candidates[0]['content']?['parts'];
    if (parts == null || parts.isEmpty) {
      throw Exception('Gemini image response has no parts');
    }

    final inlineData = parts[0]['inlineData'];
    if (inlineData == null || inlineData['data'] == null) {
      throw Exception('Gemini image response has no inlineData');
    }

    final base64Str = inlineData['data'];
    return base64Decode(base64Str);
  }
}
