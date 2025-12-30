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

  Future<void> _loadDiary() async {
    final diary = await TravelDayService.getDiaryByDate(
      travelId: widget.travelId,
      date: widget.date,
    );

    if (!mounted) return;

    if (diary != null) {
      _contentController.text = (diary['text'] ?? '').toString();
      _summaryText = diary['ai_summary'];

      if (diary['ai_summary'] != null) {
        _imageUrl = TravelDayService.getAiImageUrl(
          travelId: widget.travelId,
          date: widget.date,
        );
      }
    }

    setState(() {});
  }

  Future<void> _pickPhoto() async {
    if (_photos.length >= 3) return;

    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);

    if (file != null) {
      setState(() => _photos.add(File(file.path)));
    }
  }

  Future<void> _generateAI() async {
    FocusManager.instance.primaryFocus?.unfocus();

    final content = _contentController.text.trim();
    if (content.isEmpty || _selectedStyle == null) return;

    setState(() => _loading = true);

    try {
      final gemini = GeminiService();

      final summaryPrompt =
          '''
${PromptCache.textPrompt.content}

장소: ${widget.placeName}
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
        _imageUrl = null;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveDiary() async {
    FocusManager.instance.primaryFocus?.unfocus();

    final text = _contentController.text.trim();
    if (text.isEmpty) return;

    setState(() => _loading = true);

    try {
      if (_generatedImage != null) {
        await ImageUploadService.uploadDiaryImage(
          travelId: widget.travelId,
          date: widget.date,
          imageBytes: _generatedImage!,
        );
      }

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

      debugPrint('✅ diary upsert done -> pop(true)');

      if (!mounted) return;
      Navigator.of(context).pop(true);

      debugPrint('🟢 [DAY] tryCompleteTravel CALL');
      debugPrint('🟢 [DAY] travelId=${widget.travelId}');
      debugPrint('🟢 [DAY] start=${widget.startDate} end=${widget.endDate}');

      TravelCompleteService.tryCompleteTravel(
        travelId: widget.travelId,
        startDate: widget.startDate,
        endDate: widget.endDate,
      );

      debugPrint('🔥 tryCompleteTravel fired in background');
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
      resizeToAvoidBottomInset: true,
      backgroundColor: AppColors.background,
      appBar: AppBar(
        elevation: 0,
        title: Text(
          '${widget.placeName} · ${dayNumber}일차',
          style: AppTextStyles.appBarTitle,
        ),
      ),
      body: Column(
        children: [
          // ===== 🔍 페이지 이름 라벨 =====
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

          // ===== 기존 내용 =====
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => FocusScope.of(context).unfocus(),
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
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
                      style: AppTextStyles.body,
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
                      onChanged: (style) =>
                          setState(() => _selectedStyle = style),
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
                        child: const Text('🎨 AI 그림일기 생성하기'),
                      ),
                    ),
                    const SizedBox(height: 20),
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
                    if (_generatedImage != null) ...[
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _saveDiary,
                          child: const Text('💾 일기 저장'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
