import 'dart:io';
import 'dart:typed_data';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

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
  String? _diaryId;

  bool _loading = false;
  String _loadingMessage = "";

  // 📢 광고 관련 변수
  RewardedAd? _rewardedAd;
  InterstitialAd? _interstitialAd;
  bool _isAdLoaded = false;
  bool _isInterstitialLoaded = false;

  String get _userId => Supabase.instance.client.auth.currentUser!.id;

  @override
  void initState() {
    super.initState();
    _loadDiary();
    _loadRewardedAd();
    _loadInterstitialAd();
  }

  @override
  void dispose() {
    _contentController.dispose();
    _rewardedAd?.dispose();
    _interstitialAd?.dispose();
    super.dispose();
  }

  // 📺 광고 로드 로직 (기존 유지)
  void _loadRewardedAd() {
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

  void _loadInterstitialAd() {
    final String adId = Platform.isAndroid
        ? 'ca-app-pub-3890698783881393/1136502741'
        : 'ca-app-pub-3890698783881393/9417088998';
    InterstitialAd.load(
      adUnitId: adId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint("✅ 전면 광고 로드 성공");
          setState(() {
            _interstitialAd = ad;
            _isInterstitialLoaded = true;
          });
        },
        onAdFailedToLoad: (error) {
          debugPrint("❌ 전면 광고 로드 실패: ${error.message}");
          setState(() => _isInterstitialLoaded = false);
        },
      ),
    );
  }

  // ---------------------------------------------------------
  // 📝 데이터 로드 및 삭제 로직 (기존 유지)
  // ---------------------------------------------------------
  Future<void> _loadDiary() async {
    final diary = await TravelDayService.getDiaryByDate(
      travelId: widget.travelId,
      date: widget.date,
    );
    if (!mounted || diary == null) return;
    setState(() {
      _diaryId = diary['id'];
      _contentController.text = diary['content'] ?? '';
      if (diary['ai_summary'] != null &&
          diary['ai_summary'].toString().isNotEmpty) {
        _imageUrl = TravelDayService.getAiImageUrl(
          travelId: widget.travelId,
          diaryId: _diaryId!,
        );
      }
    });
  }

  Future<void> _pickPhoto() async {
    if (_localPhotos.length + _uploadedPhotoUrls.length >= 3) return;
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) setState(() => _localPhotos.add(File(picked.path)));
  }

  Future<void> _deleteUploadedPhoto(String url) async {
    setState(() {
      _loading = true;
      _loadingMessage = "사진 삭제 중...";
    });
    try {
      await ImageUploadService.deleteUserImageByUrl(url);
      setState(() => _uploadedPhotoUrls.remove(url));
      await TravelDayService.updateDiaryPhotos(
        travelId: widget.travelId,
        date: widget.date,
        photoUrls: _uploadedPhotoUrls,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleGenerateWithAd() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final content = _contentController.text.trim();
    if (content.isEmpty || _selectedStyle == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('일기와 스타일을 선택해주세요!')));
      return;
    }
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AdRequestDialog(
        onAccept: () async {
          setState(() {
            _loading = true;
            _loadingMessage = "광고 시청 후 일기가 자동 생성됩니다";
          });
          try {
            if (_isAdLoaded && _rewardedAd != null) {
              final Completer<void> adCompleter = Completer<void>();
              _rewardedAd!.fullScreenContentCallback =
                  FullScreenContentCallback(
                    onAdDismissedFullScreenContent: (ad) {
                      ad.dispose();
                      adCompleter.complete();
                      _loadRewardedAd();
                    },
                    onAdFailedToShowFullScreenContent: (ad, error) {
                      ad.dispose();
                      adCompleter.complete();
                      _loadRewardedAd();
                    },
                  );
              _rewardedAd!.show(onUserEarnedReward: (ad, reward) {});
              await adCompleter.future;
            }
            final aiData = await _runAiGeneration();
            _updateAiResult(aiData);
          } catch (e) {
            debugPrint("에러 발생: $e");
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

  // ---------------------------------------------------------
  // 🔥 [핵심] 투트랙 저장 로직 (Parallel Processing)
  // ---------------------------------------------------------
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

    // 마지막 날 일기인지 여부
    final bool isLastDay = currentDayNumber >= totalDays;

    _executeSave(isLastDay);
  }

  Future<void> _executeSave(bool isCompleting) async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _loadingMessage = isCompleting
          ? "AI가 여행 전체를 정산 중입니다..."
          : "추억을 저장하고 있습니다...";
    });

    try {
      // 🎯 투트랙(병렬) 처리를 위한 리스트
      final List<Future> tasks = [];
      Completer<void>? adCompleter;

      // 1️⃣ 광고 시청 태스크 (전면 광고가 로드되어 있고 완료 시점인 경우)
      if (isCompleting && _isInterstitialLoaded && _interstitialAd != null) {
        adCompleter = Completer<void>();
        _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
          onAdDismissedFullScreenContent: (ad) {
            ad.dispose();
            _loadInterstitialAd(); // 미리 다음 광고 로드
            if (!adCompleter!.isCompleted) adCompleter.complete();
          },
          onAdFailedToShowFullScreenContent: (ad, error) {
            ad.dispose();
            _loadInterstitialAd();
            if (!adCompleter!.isCompleted) adCompleter.complete();
          },
        );

        // 광고 실행 (비동기로 실행됨)
        _interstitialAd!.show();
        tasks.add(adCompleter.future);
      }

      // 2️⃣ AI 및 DB 저장 태스크 (광고가 나오는 동안 뒤에서 열일함)
      final saveTask = Future(() async {
        // 사진 업로드
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

        // DB Upsert
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

        // 여행 완료 정산 (이미지 생성 등)
        await TravelCompleteService.tryCompleteTravel(
          travelId: widget.travelId,
          startDate: widget.startDate,
          endDate: widget.endDate,
        );
        debugPrint("✅ 백그라운드 AI 작업 완료");
      });

      tasks.add(saveTask);

      // 🏁 광고 끝날 때까지 & AI 작업 끝날 때까지 대기
      await Future.wait(tasks);

      if (!mounted) return;
      Navigator.of(context).pop(true); // 광고 닫자마자 바로 홈으로!
    } catch (e) {
      debugPrint("❌ 저장 중 에러: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ---------------------------------------------------------
  // 🎨 UI 빌더 (기존 유지)
  // ---------------------------------------------------------
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
              color: Colors.black.withOpacity(0.7),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _loadingMessage,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "잠시만 기다려 주세요...",
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
        ],
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
      margin: const EdgeInsets.only(top: 10),
      decoration: _cardDeco(),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: Column(
          children: [
            if (_imageUrl != null)
              Image.network(
                _imageUrl!.contains('?')
                    ? '$_imageUrl&v=${DateTime.now().millisecondsSinceEpoch}'
                    : '$_imageUrl?v=${DateTime.now().millisecondsSinceEpoch}',
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    height: 200,
                    width: double.infinity,
                    color: const Color(0xFFF1F3F5),
                    child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 200,
                  width: double.infinity,
                  color: const Color(0xFFF1F3F5),
                  child: const Center(child: Text('이미지를 불러오는 중입니다...')),
                ),
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
