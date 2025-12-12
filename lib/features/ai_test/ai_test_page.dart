import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

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

  Uint8List? _generatedImage;
  String? _summaryText;

  bool _loading = false;

  // 사진 최대 3장
  final List<File> _selectedPhotos = [];

  // 스타일 선택
  String _selectedStyle = "A: Korean Crayon Kids Style";

  final Map<String, String> _stylePrompts = {
    "A: Korean Crayon Kids Style":
        "korean crayon style, child-like hand drawing, soft pastel colors, NO TEXT, NO LETTERS",

    "B: Simpsons Style":
        "simpsons cartoon style illustration, thick outline, bright flat colors, NO TEXT",

    "C: Joseon Dynasty Painting":
        "traditional korean joseon minhwa painting style, soft brush strokes, historical atmosphere, NO TEXT",
  };

  // ---------------------------------------------------------
  // 🔵 사진 선택 (최대 3장)
  // ---------------------------------------------------------
  Future<void> _pickPhotos() async {
    if (_selectedPhotos.length >= 3) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("사진은 최대 3장까지 가능합니다.")));
      return;
    }

    final picker = ImagePicker();
    final XFile? file = await picker.pickImage(source: ImageSource.gallery);

    if (file != null) {
      setState(() => _selectedPhotos.add(File(file.path)));
    }
  }

  // ---------------------------------------------------------
  // 🔥 AI 생성
  // ---------------------------------------------------------
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
    final summary = await gemini.generateSummary(
      city: city,
      date: date,
      content: content,
      photos: _selectedPhotos,
    );

    // 2) 이미지 프롬프트 구성
    final stylePrompt = _stylePrompts[_selectedStyle] ?? "";
    final prompt =
        "$stylePrompt, travel diary illustration about $city, content: $content";

    // 3) 이미지 생성
    final imageBytes = await gemini.generateImage(prompt);

    setState(() {
      _summaryText = summary;
      _generatedImage = imageBytes;
      _loading = false;
    });
  }

  // ---------------------------------------------------------
  // 🔽 UI
  // ---------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("AI 여행 그림일기 테스트")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 여행 도시
            const Text("여행 도시"),
            TextField(controller: _cityController),

            const SizedBox(height: 20),

            // 여행 날짜
            const Text("여행 날짜"),
            TextField(controller: _dateController),

            const SizedBox(height: 20),

            // 여행 내용
            const Text("여행 내용"),
            TextField(
              controller: _contentController,
              maxLines: 4,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),

            const SizedBox(height: 25),

            // 스타일 선택
            const Text("그림 스타일 선택"),
            const SizedBox(height: 5),
            DropdownButton<String>(
              value: _selectedStyle,
              isExpanded: true,
              items: _stylePrompts.keys
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (v) {
                setState(() => _selectedStyle = v!);
              },
            ),

            const SizedBox(height: 20),

            // 사진 선택
            const Text("사진 선택 (최대 3장)"),
            const SizedBox(height: 5),

            Row(
              children: [
                ..._selectedPhotos.map(
                  (file) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Image.file(
                      file,
                      width: 70,
                      height: 70,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                if (_selectedPhotos.length < 3)
                  GestureDetector(
                    onTap: _pickPhotos,
                    child: Container(
                      width: 70,
                      height: 70,
                      color: Colors.grey.shade300,
                      child: const Icon(Icons.add),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 30),

            // 버튼
            ElevatedButton(
              onPressed: _loading ? null : _generateAI,
              child: _loading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("AI 그림일기 생성하기"),
            ),

            const SizedBox(height: 30),

            // 결과 표시
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
