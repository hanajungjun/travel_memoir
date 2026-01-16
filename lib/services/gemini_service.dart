import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../env.dart';

class GeminiService {
  final String _apiKey = AppEnv.geminiApiKey;

  // ============================
  // ✍️ 텍스트 요약 (무조건 String 반환)
  // ============================
  Future<String> generateSummary({
    required String finalPrompt, // <-- 수정됨: 올바른 required 사용
    required List<File> photos, // <-- 수정됨: 올바른 required 사용
  }) async {
    // final url =
    //     'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$_apiKey';
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
    if (text.isEmpty) {
      throw Exception('❌ Gemini summary: text is empty');
    }

    debugPrint('✅ [GEMINI] summary success');
    return text;
  }

  // ============================
  // 🎨 이미지 생성 (🔥 반드시 IMAGE 반환)
  // ============================
  Future<Uint8List> generateImage({required String finalPrompt}) async {
    debugPrint('🤖 [GEMINI] image request');

    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-image:generateContent?key=$_apiKey',
    );

    // 1차 시도
    try {
      return await _requestImage(uri, finalPrompt);
    } catch (e) {
      debugPrint('⚠️ [GEMINI] image retry once');
    }

    // 🔁 2차 시도 (프롬프트 보강)
    return await _requestImage(uri, '''
$finalPrompt

반드시 하나의 이미지로 결과를 생성하세요.
텍스트 설명 없이 이미지만 반환하세요.
''');
  }

  // ============================
  // 내부 이미지 요청 (공통)
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
      throw Exception(
        '❌ Gemini image HTTP ${response.statusCode}: ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);

    final candidates = decoded['candidates'];
    if (candidates == null || candidates.isEmpty) {
      throw Exception('❌ Gemini image: no candidates');
    }

    final parts = candidates[0]['content']?['parts'];
    if (parts == null || parts.isEmpty) {
      throw Exception('❌ Gemini image: no parts');
    }

    final inlineData = parts[0]['inlineData'];
    if (inlineData == null || inlineData['data'] == null) {
      debugPrint('🚫 [GEMINI] text-only response → no retry');
      throw Exception('GEMINI_TEXT_ONLY_RESPONSE');
    }

    final base64Str = inlineData['data'];
    final bytes = base64Decode(base64Str);

    if (bytes.isEmpty) {
      throw Exception('❌ Gemini image: decoded bytes empty');
    }

    debugPrint('✅ [GEMINI] image success');
    return bytes;
  }
}
