import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:travel_memoir/services/gemini_service.dart';
import 'package:travel_memoir/services/image_upload_service.dart';
import 'package:travel_memoir/services/travel_day_service.dart';

import 'package:travel_memoir/services/prompt_cache.dart';

import 'package:travel_memoir/models/image_style_model.dart';
import 'package:travel_memoir/core/widgets/image_style_picker.dart';

import 'package:travel_memoir/core/utils/date_utils.dart';
import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/shared/styles/text_styles.dart';

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

  // ✅ DB 기반 스타일로 변경
  ImageStyleModel? _selectedStyle;

  // ✅ 사진은 요약에 넣을 거라서 필요함
  final List<File> _photos = [];

  Uint8List? _generatedImage;
  String? _imageUrl;
  String? _summaryText;

  bool _loading = false;
  bool _isNewDiary = true;

  @override
  void initState() {
    super.initState();
    _loadDiary();
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
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
    _isNewDiary = text.isEmpty;

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

    if (_selectedStyle == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('스타일을 먼저 선택해주세요')));
      return;
    }

    setState(() => _loading = true);

    try {
      final gemini = GeminiService();

      // ✅ 1) DB에서 가져온 "텍스트 요약 프롬프트" 사용 (하드코딩 ❌)
      final textBasePrompt = PromptCache.textPrompt.content;

      final summaryFinalPrompt =
          '''
$textBasePrompt

도시: ${widget.city}
날짜: ${DateUtilsHelper.formatMonthDay(widget.date)}
내용: $content
''';

      final summary = await gemini.generateSummary(
        finalPrompt: summaryFinalPrompt,
        photos: _photos,
      );

      // ✅ 2) DB에서 가져온 "이미지 프롬프트" + "선택된 스타일 prompt" 조합 (하드코딩 ❌)
      final imageBasePrompt = PromptCache.imagePrompt.content;

      final imageFinalPrompt =
          '''
$imageBasePrompt

Style:
${_selectedStyle!.prompt}

Summary:
$summary
''';

      final imageBytes = await gemini.generateImage(
        finalPrompt: imageFinalPrompt,
      );

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
        aiStyle: _selectedStyle!.id, // ✅ DB 스타일 id 저장
      );

      if (!mounted) return;

      setState(() {
        _summaryText = summary;
        _generatedImage = imageBytes;
        _imageUrl = null;
        _isNewDiary = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('AI 생성 실패: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // -----------------------------
  // 💾 AI 이미지 저장
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          '${widget.city} · ${dayNumber}일차',
          style: AppTextStyles.appBarTitle,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(DateUtilsHelper.todayText(), style: AppTextStyles.caption),
            const SizedBox(height: 16),

            Text('오늘의 여행기록', style: AppTextStyles.sectionTitle),
            const SizedBox(height: 12),

            TextField(
              controller: _contentController,
              maxLines: 6,
              style: AppTextStyles.body.copyWith(
                color: AppColors.textPrimary, // ✅ 글씨 안 보이던거 방지
              ),
              decoration: InputDecoration(
                hintText: '오늘 있었던 일을 적어보세요',
                hintStyle: AppTextStyles.bodyMuted,
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ✅ DB 기반 스타일 선택 위젯
            ImageStylePicker(
              onChanged: (style) {
                setState(() => _selectedStyle = style);
              },
            ),

            const SizedBox(height: 24),

            Text('사진 (최대 3장)', style: AppTextStyles.sectionTitle),
            const SizedBox(height: 8),

            Row(
              children: [
                ..._photos.map(
                  (file) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        file,
                        width: 70,
                        height: 70,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
                if (_photos.length < 3)
                  GestureDetector(
                    onTap: _pickPhoto,
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.textSecondary.withOpacity(0.3),
                        ),
                      ),
                      child: const Icon(Icons.add_a_photo),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _loading ? null : _generateAI,
                child: _loading
                    ? const CircularProgressIndicator()
                    : const Text('🎨 AI 그림일기 생성하기'),
              ),
            ),

            const SizedBox(height: 32),

            if (_imageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.network(_imageUrl!),
              )
            else if (_generatedImage != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.memory(_generatedImage!),
              ),

            if (_summaryText != null) ...[
              const SizedBox(height: 16),
              Text(_summaryText!, style: AppTextStyles.body),
            ],

            if (_generatedImage != null) ...[
              const SizedBox(height: 24),
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
