import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  final List<File> _localPhotos = [];
  final List<String> _uploadedPhotoUrls = [];

  Uint8List? _generatedImage;
  String? _imageUrl;
  String? _summaryText;

  bool _loading = false;

  String get _userId => Supabase.instance.client.auth.currentUser!.id;

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
  // 🔄 기존 일기 로드
  // =====================================================
  Future<void> _loadDiary() async {
    final diary = await TravelDayService.getDiaryByDate(
      travelId: widget.travelId,
      date: widget.date,
    );

    if (!mounted || diary == null) return;

    if (_contentController.text.isEmpty) {
      _contentController.text = diary['text'] ?? '';
    }

    _summaryText = diary['ai_summary'];

    _imageUrl = TravelDayService.getAiImageUrl(
      travelId: widget.travelId,
      date: widget.date,
    );

    final urls = diary['photo_urls'];
    if (urls is List) {
      _uploadedPhotoUrls
        ..clear()
        ..addAll(urls.cast<String>());
    }

    setState(() {});
  }

  // =====================================================
  // 📸 사진 선택
  // =====================================================
  Future<void> _pickPhoto() async {
    if (_localPhotos.length + _uploadedPhotoUrls.length >= 3) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);

    if (picked != null) {
      setState(() => _localPhotos.add(File(picked.path)));
    }
  }

  // =====================================================
  // 🗑 업로드된 사진 삭제
  // =====================================================
  Future<void> _deleteUploadedPhoto(String url) async {
    setState(() => _loading = true);

    try {
      await ImageUploadService.deleteUserImageByUrl(url);
      _uploadedPhotoUrls.remove(url);

      await TravelDayService.updateDiaryPhotos(
        travelId: widget.travelId,
        date: widget.date,
        photoUrls: _uploadedPhotoUrls,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _deleteLocalPhoto(File file) {
    setState(() => _localPhotos.remove(file));
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
        photos: _localPhotos,
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
      // 📸 사용자 사진 업로드
      final List<String> newUrls = [];

      for (final file in _localPhotos) {
        final url = await ImageUploadService.uploadUserImage(
          file: file,
          userId: _userId,
          travelId: widget.travelId,
          date: widget.date,
        );
        newUrls.add(url);
      }

      final allPhotoUrls = [..._uploadedPhotoUrls, ...newUrls];

      final dayIndex = DateUtilsHelper.calculateDayNumber(
        startDate: widget.startDate,
        currentDate: widget.date,
      );

      await TravelDayService.upsertDiary(
        travelId: widget.travelId,
        dayIndex: dayIndex,
        date: widget.date,
        text: text,
        aiSummary: _summaryText,
        aiStyle: _selectedStyle?.id,
      );

      await TravelDayService.updateDiaryPhotos(
        travelId: widget.travelId,
        date: widget.date,
        photoUrls: allPhotoUrls,
      );

      // 🎨 AI 이미지 저장
      if (_generatedImage != null) {
        await ImageUploadService.uploadDiaryImage(
          userId: _userId,
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
  // 🧱 UI
  // =====================================================
  @override
  Widget build(BuildContext context) {
    final dayNumber = DateUtilsHelper.calculateDayNumber(
      startDate: widget.startDate,
      currentDate: widget.date,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
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
                      filled: true,
                      fillColor: AppColors.surface,
                      border: InputBorder.none,
                    ),
                  ),

                  const SizedBox(height: 24),

                  Row(
                    children: [
                      ..._uploadedPhotoUrls.map(
                        (url) => _PhotoThumb(
                          image: Image.network(url, fit: BoxFit.cover),
                          onDelete: () => _deleteUploadedPhoto(url),
                        ),
                      ),
                      ..._localPhotos.map(
                        (file) => _PhotoThumb(
                          image: Image.file(file, fit: BoxFit.cover),
                          onDelete: () => _deleteLocalPhoto(file),
                        ),
                      ),
                      if (_uploadedPhotoUrls.length + _localPhotos.length < 3)
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

            ElevatedButton(
              onPressed: _loading ? null : _generateAI,
              child: const Text('그림으로 남기기'),
            ),

            if (_imageUrl != null)
              Image.network(_imageUrl!)
            else if (_generatedImage != null)
              Image.memory(_generatedImage!),

            if (_generatedImage != null)
              ElevatedButton(
                onPressed: _loading ? null : _saveDiary,
                child: const Text('일기 저장'),
              ),
          ],
        ),
      ),
    );
  }
}

class _PhotoThumb extends StatelessWidget {
  final Widget image;
  final VoidCallback onDelete;

  const _PhotoThumb({required this.image, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Stack(
        children: [
          SizedBox(width: 72, height: 72, child: image),
          Positioned(
            top: 2,
            right: 2,
            child: GestureDetector(
              onTap: onDelete,
              child: const CircleAvatar(
                radius: 9,
                backgroundColor: Colors.black54,
                child: Icon(Icons.close, size: 12, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
