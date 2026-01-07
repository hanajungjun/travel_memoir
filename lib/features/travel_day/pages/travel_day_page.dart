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
import 'package:travel_memoir/core/widgets/ad_request_dialog.dart';

import 'package:travel_memoir/core/utils/date_utils.dart';
import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/shared/styles/text_styles.dart';

// TODO: [설명] 일기 작성
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
  String? _diaryId; // 🔥 일기의 고유 ID를 저장할 변수 추가
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

  Future<void> _loadDiary() async {
    final diary = await TravelDayService.getDiaryByDate(
      travelId: widget.travelId,
      date: widget.date,
    );

    if (!mounted || diary == null) {
      print('⚠️ [LOAD DIARY] 해당 날짜에 일기 데이터가 없습니다.');
      return;
    }

    setState(() {
      _diaryId = diary['id'];

      // 🔥 불러오기 로그 추가
      print('-----------------------------------------');
      print('📥 [LOAD DIARY] 데이터 가져옴');
      print('🆔 가져온 일기 ID: $_diaryId');

      _imageUrl = TravelDayService.getAiImageUrl(
        travelId: widget.travelId,
        diaryId: _diaryId!,
      );
      // 🔥 [핵심 수정]
      // 앱이 "이건 처음 보는 주소네?"라고 생각하게 뒤에 랜덤한 숫자를 붙입니다.
      if (_imageUrl != null) {
        _imageUrl = '$_imageUrl?t=${DateTime.now().millisecondsSinceEpoch}';
      }
      print('🔗 생성된 이미지 URL: $_imageUrl');
      print('-----------------------------------------');

      // ... 기존 로직 ...
    });
  }

  Future<void> _pickPhoto() async {
    if (_localPhotos.length + _uploadedPhotoUrls.length >= 3) return;
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) setState(() => _localPhotos.add(File(picked.path)));
  }

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

  Future<void> _generateAI() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final content = _contentController.text.trim();
    if (content.isEmpty || _selectedStyle == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('일기와 스타일을 선택해주세요!')));
      return;
    }
    setState(() => _loading = true);
    try {
      final gemini = GeminiService();
      final summary = await gemini.generateSummary(
        finalPrompt:
            '${PromptCache.textPrompt.content}\n장소: ${widget.placeName}\n내용: $content',
        photos: _localPhotos,
      );
      final imageBytes = await gemini.generateImage(
        finalPrompt:
            '${PromptCache.imagePrompt.content}\nStyle:\n${_selectedStyle!.prompt}\nSummary:\n$summary',
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

  // 1. [추가] 광고 팝업을 띄우고 생성을 시작하는 메인 함수
  Future<void> _handleGenerateWithAd() async {
    FocusManager.instance.primaryFocus?.unfocus();

    final content = _contentController.text.trim();
    if (content.isEmpty || _selectedStyle == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('일기와 스타일을 선택해주세요!')));
      return;
    }

    // 광고 확인 팝업 (우리가 만든 위젯) 호출
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AdRequestDialog(
        onAccept: () async {
          setState(() => _loading = true); // 로딩 시작

          try {
            // [핵심] 광고 대기(15초)와 AI 호출을 동시에 시작!
            final results = await Future.wait([
              Future.delayed(const Duration(seconds: 15)), // 15초 광고 시간 벌기
              _runAiGeneration(), // 백그라운드에서 AI 실행
            ]);

            if (!mounted) return;

            // 결과 반영 (results[1]에 AI가 만든 데이터가 들어있음)
            final aiData = results[1] as Map<String, dynamic>;
            setState(() {
              _summaryText = aiData['summary'];
              _generatedImage = aiData['image'];
              _imageUrl = null;
            });
          } catch (e) {
            print("에러 발생: $e");
          } finally {
            if (mounted) setState(() => _loading = false); // 로딩 끝
          }
        },
      ),
    );
  }

  // 2. [추가] 실제 AI API 호출만 담당 (백그라운드용)
  Future<Map<String, dynamic>> _runAiGeneration() async {
    final gemini = GeminiService();
    final content = _contentController.text.trim();

    final summary = await gemini.generateSummary(
      finalPrompt:
          '${PromptCache.textPrompt.content}\n장소: ${widget.placeName}\n내용: $content',
      photos: _localPhotos,
    );

    final imageBytes = await gemini.generateImage(
      finalPrompt:
          '${PromptCache.imagePrompt.content}\nStyle:\n${_selectedStyle!.prompt}\nSummary:\n$summary',
    );

    return {'summary': summary, 'image': imageBytes};
  }

  Future<void> _saveDiary() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final text = _contentController.text.trim();
    if (text.isEmpty) return;
    setState(() => _loading = true);
    try {
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

      // 1. 일기 데이터 저장 (upsert)
      final savedDiary = await TravelDayService.upsertDiary(
        travelId: widget.travelId,
        dayIndex: dayIndex,
        date: widget.date,
        text: text,
        aiSummary: _summaryText,
        aiStyle: _selectedStyle?.id,
      );

      final currentDiaryId = savedDiary['id']; // 저장된/기존의 UUID

      // 2. 사진 리스트 업데이트
      await TravelDayService.updateDiaryPhotos(
        travelId: widget.travelId,
        date: widget.date,
        photoUrls: allPhotoUrls,
      );

      // 3. 🔥 AI 이미지 저장 (날짜 대신 currentDiaryId 사용!)
      if (_generatedImage != null) {
        await ImageUploadService.uploadDiaryImage(
          userId: _userId,
          travelId: widget.travelId,
          diaryId: currentDiaryId, // 날짜 대신 ID를 파일명으로!
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

  // ... (이하 빌드 함수 및 UI 위젯 로직은 사장님 코드와 동일하며,
  // _imageUrl 렌더링 시 타임스탬프를 추가하여 캐시를 방지하는 부분만 살짝 보강했습니다)

  @override
  Widget build(BuildContext context) {
    final dayNumber = DateUtilsHelper.calculateDayNumber(
      startDate: widget.startDate,
      currentDate: widget.date,
    );
    const themeColor = AppColors.travelingBlue;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: themeColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'DAY ${dayNumber.toString().padLeft(2, '0')}',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              children: [
                Container(height: 30, color: themeColor),
                Transform.translate(
                  offset: const Offset(0, -10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        _buildFigmaContentCard(),
                        const SizedBox(height: 20),
                        _buildAiResultCard(),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          _buildBottomSaveButton(),
          if (_loading)
            Container(
              color: Colors.black.withOpacity(
                0.7,
              ), // 배경을 조금 더 어둡게 해서 글자가 잘 보이게 함
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      "광고 시청 후 일기가 자동 생성됩니다",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "잠시만 기다려 주세요...",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 14,
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

  BoxDecoration _cardDeco() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(25),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 15,
          offset: const Offset(0, 5),
        ),
      ],
    );
  }

  Widget _buildFigmaContentCard() {
    return Container(
      decoration: _cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'DAY ${DateUtilsHelper.calculateDayNumber(startDate: widget.startDate, currentDate: widget.date).toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${DateUtilsHelper.formatYMD(widget.date)} · ${widget.placeName}',
                  style: AppTextStyles.bodyMuted,
                ),
              ],
            ),
          ),
          const SizedBox(height: 15),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _contentController,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: '나중에 다시 읽었을 때 그때의 기분이 생각나도록 적어주세요.',
                filled: true,
                fillColor: const Color(0xFFF8F9FA),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: const BorderSide(color: Color(0xFFEEEEEE)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: const BorderSide(color: Color(0xFFEEEEEE)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Icon(Icons.camera_alt, size: 18),
                SizedBox(width: 8),
                Text('오늘의 순간들', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _buildPhotoRow(),
          const SizedBox(height: 20),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Icon(Icons.palette, size: 18),
                SizedBox(width: 8),
                Text(
                  '오늘을 그리는 방식',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ImageStylePicker(
              onChanged: (style) => setState(() => _selectedStyle = style),
            ),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: _loading ? null : _handleGenerateWithAd,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: const BoxDecoration(
                color: Color(0xFF3498DB),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(25),
                  bottomRight: Radius.circular(25),
                ),
              ),
              child: const Center(
                child: Text(
                  '↓ 이 하루를 그림으로..',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
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
              onDelete: () => setState(() => _localPhotos.remove(file)),
            ),
          ),
          if (_uploadedPhotoUrls.length + _localPhotos.length < 3)
            GestureDetector(
              onTap: _pickPhoto,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F3F5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.add, color: Colors.grey),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAiResultCard() {
    if (_imageUrl == null && _generatedImage == null)
      return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      decoration: _cardDeco(),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: Column(
          children: [
            if (_imageUrl != null)
              Image.network(
                // 🔥 캐시 방지를 위해 타임스탬프 추가
                '$_imageUrl&t=${DateTime.now().millisecondsSinceEpoch}',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 200,
                    width: double.infinity,
                    color: const Color(0xFFF1F3F5),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.image_not_supported_outlined,
                          color: Colors.grey,
                          size: 40,
                        ),
                        SizedBox(height: 10),
                        Text(
                          '아직 생성된 그림이 없어요!',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                },
              )
            else if (_generatedImage != null)
              Image.memory(_generatedImage!, fit: BoxFit.cover),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomSaveButton() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
        decoration: BoxDecoration(
          color: const Color(0xFF454B54),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10),
          ],
        ),
        child: GestureDetector(
          onTap: _loading ? null : _saveDiary,
          child: const Text(
            '기억으로 남기기',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
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
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(width: 60, height: 60, child: image),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: GestureDetector(
              onTap: onDelete,
              child: const CircleAvatar(
                radius: 10,
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
