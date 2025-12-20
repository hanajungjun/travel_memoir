import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:travel_memoir/services/gemini_service.dart';
import 'package:travel_memoir/services/image_upload_service.dart';
import 'package:travel_memoir/services/travel_day_service.dart';
import 'package:travel_memoir/services/prompt_cache.dart';
import 'package:travel_memoir/services/travel_complete_service.dart';

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

  ImageStyleModel? _selectedStyle;
  final List<File> _photos = [];

  Uint8List? _generatedImage; // 미리보기
  String? _imageUrl; // 저장된 이미지 URL
  String? _summaryText; // 요약

  bool _loading = false;

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
  // 기존 일기 로드
  // -----------------------------
  Future<void> _loadDiary() async {
    final diary = await TravelDayService.getDiaryByDate(
      travelId: widget.travelId,
      date: widget.date,
    );

    if (!mounted) return;

    if (diary != null) {
      _contentController.text = (diary['text'] ?? '').toString();
    }

    final imageUrl = TravelDayService.getAiImageUrl(
      travelId: widget.travelId,
      date: widget.date,
    );

    setState(() {
      _imageUrl = imageUrl;
    });
  }

  // -----------------------------
  // 사진 선택
  // -----------------------------
  Future<void> _pickPhoto() async {
    if (_photos.length >= 3) return;

    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);

    if (file != null) {
      setState(() => _photos.add(File(file.path)));
    }
  }

  // -----------------------------
  // AI 생성 (미리보기만)
  // -----------------------------
  Future<void> _generateAI() async {
    final content = _contentController.text.trim();
    if (content.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('내용을 먼저 작성해주세요')));
      return;
    }

    if (_selectedStyle == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('스타일을 먼저 선택해주세요')));
      return;
    }

    setState(() => _loading = true);

    try {
      final gemini = GeminiService();

      final summaryPrompt =
          '''
${PromptCache.textPrompt.content}

도시: ${widget.city}
날짜: ${DateUtilsHelper.formatMonthDay(widget.date)}
내용: $content
''';

      final summary = await gemini.generateSummary(
        finalPrompt: summaryPrompt,
        photos: _photos,
      );

      final imagePrompt =
          '''
${PromptCache.imagePrompt.content}

Style:
${_selectedStyle!.prompt}

Summary:
$summary
''';

      final imageBytes = await gemini.generateImage(finalPrompt: imagePrompt);

      if (!mounted) return;

      setState(() {
        _summaryText = summary;
        _generatedImage = imageBytes;
        _imageUrl = null; // 미리보기 우선
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
  // 저장 (🔥 수정된 부분)
  // -----------------------------
  Future<void> _saveDiary() async {
    final text = _contentController.text.trim();
    final hasNewAi = _generatedImage != null;

    if (text.isEmpty) return;

    setState(() => _loading = true);

    try {
      String? imageUrl;

      // ✅ 새 AI 생성했을 때만 이미지 업로드
      if (hasNewAi) {
        imageUrl = await ImageUploadService.uploadDiaryImage(
          travelId: widget.travelId,
          date: widget.date,
          imageBytes: _generatedImage!,
        );
      }

      final dayNumber = DateUtilsHelper.calculateDayNumber(
        startDate: widget.startDate,
        currentDate: widget.date,
      );

      // ✅ 텍스트는 항상 저장
      await TravelDayService.upsertDiary(
        travelId: widget.travelId,
        dayIndex: dayNumber,
        date: widget.date,
        text: text,
        aiSummary: _summaryText,
        aiStyle: _selectedStyle?.id,
      );

      if (!mounted) return;

      if (imageUrl != null) {
        setState(() {
          _imageUrl = imageUrl;
          _generatedImage = null;
        });
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('일기 저장 완료 🎉')));

      // 🔥 목록 새로고침 신호
      Navigator.of(context).pop(true);

      // 🔁 여행 완료 여부 체크 (백그라운드)
      TravelCompleteService.tryCompleteTravel(
        travelId: widget.travelId,
        city: widget.city,
        startDate: widget.startDate,
        endDate: widget.endDate,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('저장 실패: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
        elevation: 0,
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
            Text(
              DateUtilsHelper.formatYMD(widget.date),
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: 16),

            Text('오늘의 여행기록', style: AppTextStyles.sectionTitle),
            const SizedBox(height: 12),

            TextField(
              controller: _contentController,
              maxLines: 6,
              style: AppTextStyles.body.copyWith(color: AppColors.textPrimary),
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

            ImageStylePicker(
              onChanged: (style) => setState(() => _selectedStyle = style),
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
                    onTap: _loading ? null : _pickPhoto,
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

            const SizedBox(height: 28),

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

            const SizedBox(height: 20),

            if (_imageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.network(
                  '$_imageUrl?ts=${DateTime.now().millisecondsSinceEpoch}',
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
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

            if (_generatedImage != null ||
                _contentController.text.isNotEmpty) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _loading ? null : _saveDiary,
                  child: _loading
                      ? const CircularProgressIndicator()
                      : const Text('💾 일기 저장'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
