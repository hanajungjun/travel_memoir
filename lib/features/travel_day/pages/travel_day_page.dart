import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:travel_memoir/services/gemini_service.dart';
import 'package:travel_memoir/services/image_upload_service.dart';
import 'package:travel_memoir/services/travel_day_service.dart';
import 'package:travel_memoir/services/travel_complete_service.dart';
import 'package:travel_memoir/services/prompt_cache.dart';

import 'package:travel_memoir/models/image_style_model.dart';
import 'package:travel_memoir/core/widgets/image_style_picker.dart';

import 'package:travel_memoir/core/utils/date_utils.dart';
import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/shared/styles/text_styles.dart';

class TravelDayPage extends StatefulWidget {
  final String travelId;
  final String placeName;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime date;

  const TravelDayPage({
    super.key,
    required this.travelId,
    required this.placeName,
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
  final List<String> _photoUrls = [];

  Uint8List? _generatedImage;
  String? _imageUrl;
  String? _summaryText;

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

  // =====================================================
  // 🔄 기존 일기 + 사진 로드
  // =====================================================
  Future<void> _loadDiary() async {
    final diary = await TravelDayService.getDiaryByDate(
      travelId: widget.travelId,
      date: widget.date,
    );

    if (!mounted || diary == null) return;

    // 🔥 텍스트 보호 (입력 중이면 덮어쓰지 않음)
    if (_contentController.text.isEmpty) {
      _contentController.text = (diary['text'] ?? '').toString();
    }

    _summaryText = diary['ai_summary'];

    if (diary['ai_summary'] != null) {
      _imageUrl = TravelDayService.getAiImageUrl(
        travelId: widget.travelId,
        date: widget.date,
      );
    }

    if (diary['photo_urls'] != null) {
      _photoUrls
        ..clear()
        ..addAll(List<String>.from(diary['photo_urls']));
    }

    setState(() {});
  }

  // =====================================================
  // 📸 사진 선택
  // =====================================================
  Future<void> _pickPhoto() async {
    if (_photos.length + _photoUrls.length >= 3) return;

    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);

    if (file != null) {
      setState(() => _photos.add(File(file.path)));
    }
  }

  // =====================================================
  // 🗑 이미 저장된 사진 삭제
  // =====================================================
  Future<void> _deleteUploadedPhoto(String url) async {
    setState(() => _loading = true);

    try {
      await ImageUploadService.deleteUserImageByUrl(url);
      _photoUrls.remove(url);

      await TravelDayService.updateDiaryPhotos(
        travelId: widget.travelId,
        date: widget.date,
        photoUrls: _photoUrls,
      );

      setState(() {});
    } finally {
      setState(() => _loading = false);
    }
  }

  void _deleteLocalPhoto(File file) {
    setState(() {
      _photos.remove(file);
    });
  }

  // =====================================================
  // 🎨 AI 생성
  // =====================================================
  Future<void> _generateAI() async {
    FocusManager.instance.primaryFocus?.unfocus();

    final content = _contentController.text.trim();
    if (content.isEmpty || _selectedStyle == null) return;

    setState(() => _loading = true);

    try {
      final gemini = GeminiService();

      final summary = await gemini.generateSummary(
        finalPrompt:
            '''
${PromptCache.textPrompt.content}

장소: ${widget.placeName}
날짜: ${DateUtilsHelper.formatMonthDay(widget.date)}
내용: $content
''',
        photos: _photos,
      );

      final imageBytes = await gemini.generateImage(
        finalPrompt:
            '''
${PromptCache.imagePrompt.content}

Style:
${_selectedStyle!.prompt}

Summary:
$summary
''',
      );

      if (!mounted) return;

      setState(() {
        _summaryText = summary;
        _generatedImage = imageBytes;
        _imageUrl = null;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // =====================================================
  // 💾 저장
  // =====================================================
  Future<void> _saveDiary() async {
    FocusManager.instance.primaryFocus?.unfocus();

    final text = _contentController.text.trim();
    if (text.isEmpty) return;

    setState(() => _loading = true);

    try {
      final List<String> uploadedUrls = [];

      for (final file in _photos) {
        final url = await ImageUploadService.uploadUserImage(
          file: file,
          travelId: widget.travelId,
          dayId: DateUtilsHelper.formatYMD(widget.date),
        );
        uploadedUrls.add(url);
      }

      final finalPhotoUrls = [..._photoUrls, ...uploadedUrls];

      final dayNumber = DateUtilsHelper.calculateDayNumber(
        startDate: widget.startDate,
        currentDate: widget.date,
      );

      await TravelDayService.upsertDiary(
        travelId: widget.travelId,
        dayIndex: dayNumber,
        date: widget.date,
        text: text,
        aiSummary: _summaryText,
        aiStyle: _selectedStyle?.id,
      );

      await TravelDayService.updateDiaryPhotos(
        travelId: widget.travelId,
        date: widget.date,
        photoUrls: finalPhotoUrls,
      );

      if (_generatedImage != null) {
        await ImageUploadService.uploadDiaryImage(
          travelId: widget.travelId,
          date: widget.date,
          imageBytes: _generatedImage!,
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);

      TravelCompleteService.tryCompleteTravel(
        travelId: widget.travelId,
        startDate: widget.startDate,
        endDate: widget.endDate,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // =====================================================
  // 🧱 UI (원본 유지 + ❌만 추가)
  // =====================================================
  @override
  Widget build(BuildContext context) {
    final dayNumber = DateUtilsHelper.calculateDayNumber(
      startDate: widget.startDate,
      currentDate: widget.date,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 4),
            color: Colors.black.withOpacity(0.04),
            child: const Text(
              'PAGE: TravelDayPage',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'DAY ${dayNumber.toString().padLeft(2, '0')}',
                          style: AppTextStyles.sectionTitle,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${DateUtilsHelper.formatYMD(widget.date)} · ${widget.placeName}',
                          style: AppTextStyles.bodyMuted,
                        ),
                        const SizedBox(height: 24),

                        TextField(
                          controller: _contentController,
                          maxLines: 6,
                          style: AppTextStyles.body,
                          decoration: InputDecoration(
                            hintText: '오늘 하루는 어땠나요?',
                            hintStyle: AppTextStyles.bodyMuted,
                            filled: true,
                            fillColor: AppColors.surface,
                            border: const OutlineInputBorder(
                              borderRadius: BorderRadius.zero,
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        Row(
                          children: [
                            ..._photoUrls.map(
                              (url) => Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Stack(
                                  children: [
                                    Image.network(
                                      url,
                                      width: 72,
                                      height: 72,
                                      fit: BoxFit.cover,
                                    ),
                                    Positioned(
                                      top: 2,
                                      right: 2,
                                      child: GestureDetector(
                                        onTap: () => _deleteUploadedPhoto(url),
                                        child: Container(
                                          width: 18,
                                          height: 18,
                                          decoration: BoxDecoration(
                                            color: Colors.black.withOpacity(
                                              0.6,
                                            ),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.close,
                                            size: 12,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            ..._photos.map(
                              (file) => Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Stack(
                                  children: [
                                    Image.file(
                                      file,
                                      width: 72,
                                      height: 72,
                                      fit: BoxFit.cover,
                                    ),

                                    // ❌ 로컬 사진 삭제
                                    Positioned(
                                      top: 2,
                                      right: 2,
                                      child: GestureDetector(
                                        onTap: () => _deleteLocalPhoto(file),
                                        child: Container(
                                          width: 18,
                                          height: 18,
                                          decoration: BoxDecoration(
                                            color: Colors.black.withOpacity(
                                              0.6,
                                            ),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.close,
                                            size: 12,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            if (_photos.length + _photoUrls.length < 3)
                              GestureDetector(
                                onTap: _pickPhoto,
                                child: Container(
                                  width: 72,
                                  height: 72,
                                  color: AppColors.surface,
                                  child: const Icon(Icons.add),
                                ),
                              ),
                          ],
                        ),

                        const SizedBox(height: 32),

                        Text('그림일기 스타일', style: AppTextStyles.sectionTitle),
                        const SizedBox(height: 8),

                        ImageStylePicker(
                          onChanged: (style) =>
                              setState(() => _selectedStyle = style),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.zero,
                        ),
                      ),
                      onPressed: _loading ? null : _generateAI,
                      child: const Text(
                        '그림으로 남기기',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  if (_imageUrl != null)
                    Image.network(
                      _imageUrl!,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    )
                  else if (_generatedImage != null)
                    Image.memory(
                      _generatedImage!,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),

                  if (_generatedImage != null)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.zero,
                          ),
                        ),
                        onPressed: _loading ? null : _saveDiary,
                        child: const Text(
                          '일기 저장',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
