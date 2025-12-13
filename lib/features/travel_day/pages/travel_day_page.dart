import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:travel_memoir/models/diary_style.dart';
import 'package:travel_memoir/core/widgets/diary_style_picker.dart';
import 'package:travel_memoir/core/utils/date_utils.dart';
import 'package:travel_memoir/services/gemini_service.dart';
import 'package:travel_memoir/services/image_upload_service.dart';
import 'package:travel_memoir/services/travel_day_service.dart';

class TravelDayPage extends StatefulWidget {
  final String travelId;
  final String city;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime date;

  const TravelDayPage({
    super.key,
    required this.travelId,
    required this.city,
    required this.startDate,
    required this.endDate,
    required this.date,
  });

  @override
  State<TravelDayPage> createState() => _TravelDayPageState();
}

class _TravelDayPageState extends State<TravelDayPage> {
  final TextEditingController _contentController = TextEditingController();

  DiaryStyle _selectedStyle = diaryStyles.first;
  final List<File> _photos = [];

  Uint8List? _generatedImage; // 새로 생성된 AI 이미지
  String? _imageUrl; // 서버에 저장된 AI 이미지 URL
  String? _summaryText;

  bool _loading = false;
  bool _isNewDiary = true; // 🔥 핵심: 새 작성 여부

  @override
  void initState() {
    super.initState();
    _loadDiary();
  }

  // -----------------------------
  // 📖 기존 일기 로드
  // -----------------------------
  Future<void> _loadDiary() async {
    final diary = await TravelDayService.getDiaryByDate(
      travelId: widget.travelId,
      date: widget.date,
    );

    if (!mounted) return;

    if (diary == null) {
      _isNewDiary = true;
      return;
    }

    final text = (diary['text'] ?? '').toString();
    _contentController.text = text;

    // 🔥 텍스트가 비어 있으면 "새 작성"
    _isNewDiary = text.isEmpty;

    // 기존 AI 이미지 URL 계산
    final imageUrl = TravelDayService.getAiImageUrl(
      travelId: widget.travelId,
      date: widget.date,
    );

    setState(() {
      _imageUrl = imageUrl;
    });
  }

  // -----------------------------
  // 📸 사진 선택
  // -----------------------------
  Future<void> _pickPhoto() async {
    if (_photos.length >= 3) return;

    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);

    if (file != null) {
      setState(() {
        _photos.add(File(file.path));
      });
    }
  }

  // -----------------------------
  // 🤖 AI 생성
  // -----------------------------
  Future<void> _generateAI() async {
    final content = _contentController.text.trim();
    if (content.isEmpty) return;

    setState(() => _loading = true);

    try {
      final gemini = GeminiService();

      final summary = await gemini.generateSummary(
        city: widget.city,
        date: DateUtilsHelper.formatMonthDay(widget.date),
        content: content,
        photos: _photos,
      );

      final imageBytes = await gemini.generateImage('''
${_selectedStyle.prompt}
Travel diary illustration.
City: ${widget.city}
Content: $content
NO TEXT, NO LETTERS
''');

      // 🔥 AI 생성 직후: 일기 텍스트 + 요약 먼저 저장
      final dayNumber = DateUtilsHelper.calculateDayNumber(
        startDate: widget.startDate,
        currentDate: widget.date,
      );

      await TravelDayService.upsertDiary(
        travelId: widget.travelId,
        dayIndex: dayNumber,
        date: widget.date,
        text: content,
        aiSummary: summary,
        aiStyle: _selectedStyle.id,
      );

      if (!mounted) return;

      setState(() {
        _summaryText = summary;
        _generatedImage = imageBytes;
        _imageUrl = null; // 새 이미지 생성 시 기존 URL 무효
        _isNewDiary = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('AI 생성 실패: $e')));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  // -----------------------------
  // 💾 AI 이미지 저장 (Storage)
  // -----------------------------
  Future<void> _saveImage() async {
    if (_generatedImage == null) return;

    final url = await ImageUploadService.uploadDiaryImage(
      travelId: widget.travelId,
      date: widget.date,
      imageBytes: _generatedImage!,
    );

    if (!mounted) return;

    setState(() {
      _imageUrl = url;
      _generatedImage = null;
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('일기 저장 완료 🎉')));
  }

  @override
  Widget build(BuildContext context) {
    final dayNumber = DateUtilsHelper.calculateDayNumber(
      startDate: widget.startDate,
      currentDate: widget.date,
    );

    return Scaffold(
      appBar: AppBar(title: Text('${widget.city} · ${dayNumber}일차')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateUtilsHelper.todayText(),
              style: const TextStyle(color: Colors.grey),
            ),

            const SizedBox(height: 16),

            const Text(
              '오늘의 여행기록을 작성하세요 ✍️',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: _contentController,
              maxLines: 6,
              decoration: const InputDecoration(
                hintText: '오늘 있었던 일을 적어보세요',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 20),

            DiaryStylePicker(
              onChanged: (style) {
                setState(() => _selectedStyle = style);
              },
            ),

            const SizedBox(height: 20),

            const Text('사진 (최대 3장)'),
            const SizedBox(height: 8),

            Row(
              children: [
                ..._photos.map(
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
                if (_photos.length < 3)
                  GestureDetector(
                    onTap: _pickPhoto,
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

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _loading ? null : _generateAI,
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('🎨 AI 그림일기 생성하기'),
              ),
            ),

            const SizedBox(height: 30),

            // 🖼️ AI 이미지 표시
            if (_imageUrl != null)
              Image.network(_imageUrl!)
            else if (_generatedImage != null)
              Image.memory(_generatedImage!),

            if (_summaryText != null) ...[
              const SizedBox(height: 12),
              Text(_summaryText!),
            ],

            // 🔥 새로 생성한 경우에만 저장 버튼 노출
            if (_generatedImage != null) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _saveImage,
                  child: const Text('💾 일기 저장'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
