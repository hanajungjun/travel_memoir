import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';

import '../../services/gemini_service.dart';
import 'widgets/ai_image_with_text.dart';

class AiTestPage extends StatefulWidget {
  const AiTestPage({super.key});

  @override
  State<AiTestPage> createState() => _AiTestPageState();
}

class _AiTestPageState extends State<AiTestPage> {
  final _cityController = TextEditingController();
  final _dateController = TextEditingController();
  final _contentController = TextEditingController();

  String? _summaryText;
  Uint8List? _generatedImage;

  bool _loading = false;

  Future<void> _generateAI() async {
    final city = _cityController.text.trim();
    final date = _dateController.text.trim();
    final content = _contentController.text.trim();

    if (city.isEmpty || date.isEmpty || content.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("모든 항목을 입력해주세요.")));
      return;
    }

    setState(() => _loading = true);

    final gemini = GeminiService();

    // 1) 요약 생성
    final summary = await gemini.generateSummary(city, date, content);

    // 2) 이미지 생성
    final imageBytes = await gemini.generateImage(
      "korean crayon style kids travel diary illustration, city: $city, date: $date, content: $content",
    );

    setState(() {
      _summaryText = summary;
      _generatedImage = imageBytes;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("AI 여행 그림일기 테스트")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("여행 도시"),
            TextField(controller: _cityController),

            const SizedBox(height: 20),

            const Text("여행 날짜"),
            TextField(controller: _dateController),

            const SizedBox(height: 20),

            const Text("여행 내용"),
            TextField(
              controller: _contentController,
              maxLines: 5,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),

            const SizedBox(height: 25),

            ElevatedButton(
              onPressed: _loading ? null : _generateAI,
              child: _loading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("AI 그림일기 생성하기"),
            ),

            const SizedBox(height: 30),

            if (_generatedImage != null && _summaryText != null)
              AiImageWithText(
                imageBytes: _generatedImage!,
                title: _summaryText!,
              ),
          ],
        ),
      ),
    );
  }
}
