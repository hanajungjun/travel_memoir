import 'dart:io';
import 'dart:typed_data';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:lottie/lottie.dart';

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
import 'package:travel_memoir/features/travel_day/pages/travel_completion_page.dart';

class TravelDayPage extends StatefulWidget {
  final String travelId;
  final String placeName;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime date;
  // ✨ [추가] 목록에서 넘겨주는 초기 데이터
  final Map<String, dynamic>? initialDiary;

  const TravelDayPage({
    super.key,
    required this.travelId,
    required this.placeName,
    required this.startDate,
    required this.endDate,
    required this.date,
    this.initialDiary, // 파라미터 추가
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
  String? _diaryId;

  bool _loading = false;
  String _loadingMessage = "";

  RewardedAd? _rewardedAd;
  bool _isAdLoaded = false;

  String get _userId => Supabase.instance.client.auth.currentUser!.id;

  @override
  void initState() {
    super.initState();
    _loadDiary();
    _loadAds();
  }

  @override
  void dispose() {
    _contentController.dispose();
    _rewardedAd?.dispose();
    super.dispose();
  }

  void _loadAds() {
    final String adId = Platform.isAndroid
        ? 'ca-app-pub-3890698783881393/3553280276'
        : 'ca-app-pub-3890698783881393/4814391052';

    RewardedAd.load(
      adUnitId: adId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          setState(() {
            _rewardedAd = ad;
            _isAdLoaded = true;
          });
        },
        onAdFailedToLoad: (error) => setState(() => _isAdLoaded = false),
      ),
    );
  }

  // ✅ [핵심 수정] 기존 데이터 로드 로직 변경
  Future<void> _loadDiary() async {
    // 1. 목록에서 넘겨받은 데이터가 있다면 먼저 사용 (데이터 꼬임 방지)
    if (widget.initialDiary != null) {
      _applyDiaryData(widget.initialDiary!);
      return;
    }

    // 2. 넘겨받은 데이터가 없을 때만 DB에서 직접 가져오기
    final diary = await TravelDayService.getDiaryByDate(
      travelId: widget.travelId,
      date: widget.date,
    );
    if (!mounted || diary == null) return;
    _applyDiaryData(diary);
  }

  // ✅ 데이터를 화면 변수들에 적용하는 공통 함수
  void _applyDiaryData(Map<String, dynamic> diary) {
    setState(() {
      _diaryId = diary['id']?.toString();
      _contentController.text = diary['text'] ?? diary['content'] ?? '';

      if (diary['photo_urls'] != null) {
        _uploadedPhotoUrls.clear();
        _uploadedPhotoUrls.addAll(List<String>.from(diary['photo_urls']));
      }

      // AI 요약이 있고 diaryId가 있는 경우 이미지 URL 생성
      if (_diaryId != null &&
          (diary['ai_summary'] != null &&
              diary['ai_summary'].toString().isNotEmpty)) {
        _imageUrl = TravelDayService.getAiImageUrl(
          travelId: widget.travelId,
          diaryId: _diaryId!,
        );
      }
    });
  }

  Future<void> _deleteUploadedPhoto(String url) async {
    setState(() {
      _loading = true;
      _loadingMessage = "deleting_photo".tr();
    });
    try {
      await ImageUploadService.deleteUserImageByUrl(url);
      setState(() => _uploadedPhotoUrls.remove(url));
      await TravelDayService.updateDiaryPhotos(
        travelId: widget.travelId,
        date: widget.date,
        photoUrls: _uploadedPhotoUrls,
      );
    } catch (e) {
      debugPrint("❌ 사진 삭제 실패: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickPhoto() async {
    if (_localPhotos.length + _uploadedPhotoUrls.length >= 3) return;
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) setState(() => _localPhotos.add(File(picked.path)));
  }

  Future<void> _handleGenerateWithAd() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final content = _contentController.text.trim();
    if (content.isEmpty || _selectedStyle == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('select_diary_style_error'.tr())));
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AdRequestDialog(
        onAccept: () async {
          setState(() {
            _loading = true;
            _loadingMessage = "ad_loading_message".tr();
          });

          try {
            final Future<Map<String, dynamic>> aiTask = Future(
              () => _runAiGeneration(),
            );

            await Future.delayed(const Duration(milliseconds: 100));

            if (_isAdLoaded && _rewardedAd != null) {
              final adCompleter = Completer<void>();
              _rewardedAd!.fullScreenContentCallback =
                  FullScreenContentCallback(
                    onAdDismissedFullScreenContent: (ad) {
                      ad.dispose();
                      adCompleter.complete();
                      _loadAds();
                    },
                    onAdFailedToShowFullScreenContent: (ad, error) {
                      ad.dispose();
                      adCompleter.complete();
                      _loadAds();
                    },
                  );

              await _rewardedAd!.show(onUserEarnedReward: (ad, reward) {});
              await adCompleter.future;
            }

            final aiData = await aiTask;
            _updateAiResult(aiData);
          } catch (e) {
            debugPrint("❌ AI 생성 중 에러: $e");
          } finally {
            if (mounted) setState(() => _loading = false);
          }
        },
      ),
    );
  }

  void _updateAiResult(Map<String, dynamic> aiData) {
    if (!mounted) return;
    setState(() {
      _summaryText = aiData['summary'];
      _generatedImage = aiData['image'];
      _imageUrl = null;
    });
  }

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

    final int totalDays =
        widget.endDate.difference(widget.startDate).inDays + 1;
    final int currentDayNumber = DateUtilsHelper.calculateDayNumber(
      startDate: widget.startDate,
      currentDate: widget.date,
    );

    final bool isLastDay = currentDayNumber >= totalDays;
    _executeSave(isLastDay);
  }

  Future<void> _executeSave(bool isCompleting) async {
    if (!mounted) return;

    if (isCompleting) {
      final Future<void> saveTask = Future(() => _performActualSaveLogic());

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TravelCompletionPage(
            processingTask: saveTask,
            rewardedAd: _rewardedAd,
          ),
        ),
      );
    } else {
      setState(() {
        _loading = true;
        _loadingMessage = "saving_memory_loading".tr();
      });
      try {
        await _performActualSaveLogic();
        if (mounted) Navigator.pop(context, true);
      } catch (e) {
        debugPrint("❌ 저장 중 에러: $e");
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    }
  }

  Future<void> _performActualSaveLogic() async {
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

    final savedDiary = await TravelDayService.upsertDiary(
      travelId: widget.travelId,
      dayIndex: dayIndex,
      date: widget.date,
      text: _contentController.text.trim(),
      aiSummary: _summaryText,
      aiStyle: _selectedStyle?.id,
    );

    await TravelDayService.updateDiaryPhotos(
      travelId: widget.travelId,
      date: widget.date,
      photoUrls: allPhotoUrls,
    );

    if (_generatedImage != null) {
      await ImageUploadService.uploadDiaryImage(
        userId: _userId,
        travelId: widget.travelId,
        diaryId: savedDiary['id'],
        imageBytes: _generatedImage!,
      );
    }

    await TravelCompleteService.tryCompleteTravel(
      travelId: widget.travelId,
      startDate: widget.startDate,
      endDate: widget.endDate,
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = AppColors.travelingBlue;

    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      behavior: HitTestBehavior.translucent,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          backgroundColor: themeColor,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'travel_day_title'.tr(
              args: [
                DateUtilsHelper.calculateDayNumber(
                  startDate: widget.startDate,
                  currentDate: widget.date,
                ).toString().padLeft(2, '0'),
              ],
            ),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
        ),
        body: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(height: 40, color: themeColor),
            ),
            SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                    child: Column(
                      children: [
                        _buildDiaryCard(),
                        const SizedBox(height: 20),
                        _buildAiResultCard(),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _buildBottomSaveButton(),
            if (_loading) _buildLoadingOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.8),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Lottie.asset(
              'assets/lottie/ai_magic_wand.json',
              width: 200,
              height: 200,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 20),
            Text(
              _loadingMessage,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "please_wait".tr(),
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiaryCard() {
    final dayNum = DateUtilsHelper.calculateDayNumber(
      startDate: widget.startDate,
      currentDate: widget.date,
    );
    return Container(
      decoration: _cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'travel_day_title'.tr(
                    args: [dayNum.toString().padLeft(2, '0')],
                  ),
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _contentController,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: 'diary_hint'.tr(),
                filled: true,
                fillColor: const Color(0xFFF8F9FA),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: const BorderSide(color: Color(0xFFEEEEEE)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _buildSectionTitle(
            Icons.camera_alt,
            'todays_moments'.tr(),
            subtitle: 'max_3_photos'.tr(),
          ),
          _buildPhotoRow(),
          const SizedBox(height: 10),
          _buildSectionTitle(Icons.palette, 'drawing_style'.tr()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ImageStylePicker(
              onChanged: (style) => setState(() => _selectedStyle = style),
            ),
          ),
          const SizedBox(height: 10),
          _buildGenerateButton(),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(IconData icon, String title, {String? subtitle}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          if (subtitle != null) ...[
            const SizedBox(width: 4),
            Text(
              subtitle,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGenerateButton() {
    return GestureDetector(
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
        child: Center(
          child: Text(
            'generate_image_button'.tr(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
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
      margin: const EdgeInsets.only(top: 10),
      decoration: _cardDeco(),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: Column(
          children: [
            if (_imageUrl != null)
              Image.network(
                '$_imageUrl?v=${DateTime.now().millisecondsSinceEpoch}',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(Icons.error),
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
          child: Text(
            'save_as_memory'.tr(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
      ),
    );
  }

  BoxDecoration _cardDeco() => BoxDecoration(
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
