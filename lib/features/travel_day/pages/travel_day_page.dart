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
import 'package:travel_memoir/services/prompt_cache.dart';
import 'package:travel_memoir/services/stamp_service.dart';
import 'package:travel_memoir/services/payment_service.dart';

import 'package:travel_memoir/models/image_style_model.dart';
import 'package:travel_memoir/core/widgets/image_style_picker.dart';
import 'package:travel_memoir/core/widgets/coin_paywall_bottom_sheet.dart';
import 'package:travel_memoir/features/mission/pages/ad_mission_page.dart';
import 'package:travel_memoir/features/travel_day/pages/travel_completion_page.dart';
import 'package:travel_memoir/services/travel_complete_service.dart';

import 'package:travel_memoir/core/utils/date_utils.dart';
import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/storage_paths.dart';

class TravelDayPage extends StatefulWidget {
  final String travelId;
  final String placeName;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime date;
  final Map<String, dynamic>? initialDiary;

  const TravelDayPage({
    super.key,
    required this.travelId,
    required this.placeName,
    required this.startDate,
    required this.endDate,
    required this.date,
    this.initialDiary,
  });

  @override
  State<TravelDayPage> createState() => _TravelDayPageState();
}

class _TravelDayPageState extends State<TravelDayPage>
    with SingleTickerProviderStateMixin {
  final StampService _stampService = StampService();
  final TextEditingController _contentController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  ImageStyleModel? _selectedStyle;
  final List<File> _localPhotos = [];
  List<String> _remotePhotoUrls = [];
  Uint8List? _generatedImage;
  String? _imageUrl;
  String? _summaryText;

  bool _loading = false;
  String _loadingMessage = "";

  int _dailyStamps = 0;
  int _paidStamps = 0;
  bool _usePaidStampMode = false;
  String _travelType = 'domestic';

  RewardedAd? _rewardedAd;
  bool _isAdLoaded = false;

  late AnimationController _cardController;
  late Animation<Offset> _cardOffset;

  String get _userId => Supabase.instance.client.auth.currentUser!.id
      .replaceAll(RegExp(r'[\s\n\r\t]+'), '');
  String get _cleanTravelId =>
      widget.travelId.replaceAll(RegExp(r'[\s\n\r\t]+'), '');

  @override
  void initState() {
    super.initState();
    _initData();
    _cardController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _cardOffset = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _cardController, curve: Curves.easeOutBack),
        );
  }

  @override
  void dispose() {
    _contentController.dispose();
    _rewardedAd?.dispose();
    _cardController.dispose();
    super.dispose();
  }

  Future<void> _initData() async {
    await _loadDiary();
    await _refreshStampCounts();
    _loadAds();
    _checkTripType();
  }

  Future<void> _refreshStampCounts() async {
    final stamps = await _stampService.getStampData(_userId);
    if (!mounted || stamps == null) return;
    setState(() {
      _dailyStamps = (stamps['daily_stamps'] ?? 0).toInt();
      _paidStamps = (stamps['paid_stamps'] ?? 0).toInt();
    });
  }

  Future<void> _checkTripType() async {
    final tripData = await Supabase.instance.client
        .from('travels')
        .select('travel_type')
        .eq('id', _cleanTravelId)
        .maybeSingle();
    if (!mounted || tripData == null) return;
    setState(() => _travelType = tripData['travel_type'] ?? 'domestic');
  }

  // ✅ [수정] diaryId 기반으로 사진을 불러오도록 로직 변경
  Future<void> _loadDiary() async {
    final diary = await TravelDayService.getDiaryByDate(
      travelId: _cleanTravelId,
      date: widget.date,
    );

    if (!mounted || diary == null) return;

    final String diaryId = diary['id'].toString().replaceAll(
      RegExp(r'[\s\n\r\t]+'),
      '',
    );

    setState(() {
      _contentController.text = diary['text'] ?? '';
    });

    // 📸 diaryId 폴더 내의 moments 사진들 불러오기
    try {
      final String momentsPath =
          'users/$_userId/travels/$_cleanTravelId/diaries/$diaryId/moments';
      final List<FileObject> files = await Supabase.instance.client.storage
          .from('travel_images')
          .list(path: momentsPath);

      if (files.isNotEmpty) {
        final List<String> urls = files
            .where((f) => !f.name.startsWith('.'))
            .map(
              (f) => Supabase.instance.client.storage
                  .from('travel_images')
                  .getPublicUrl('$momentsPath/${f.name}'),
            )
            .toList();

        setState(() {
          _remotePhotoUrls = urls;
        });
      }
    } catch (e) {
      debugPrint('📸 사진 불러오기 실패: $e');
    }

    final bool hasAiSummary = (diary['ai_summary'] ?? '')
        .toString()
        .trim()
        .isNotEmpty;

    if (hasAiSummary) {
      // AI 이미지 경로도 diaryId 기반으로 생성
      final String aiPath =
          'users/$_userId/travels/$_cleanTravelId/diaries/$diaryId/ai_generated.png';
      final String aiUrl = Supabase.instance.client.storage
          .from('travel_images')
          .getPublicUrl(aiPath);

      setState(() {
        _imageUrl = aiUrl;
      });
      if (_imageUrl != null) _cardController.forward();
    }
  }

  Future<void> _pickImages() async {
    final int currentTotal = _localPhotos.length + _remotePhotoUrls.length;
    if (currentTotal >= 3) return;

    final List<XFile> pickedFiles = await _picker.pickMultiImage();
    if (pickedFiles.isNotEmpty) {
      setState(() {
        _localPhotos.addAll(
          pickedFiles.take(3 - currentTotal).map((file) => File(file.path)),
        );
      });
    }
  }

  void _loadAds() {
    final adId = Platform.isAndroid
        ? 'ca-app-pub-3890698783881393/3553280276'
        : 'ca-app-pub-3890698783881393/4814391052';
    RewardedAd.load(
      adUnitId: adId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) => setState(() {
          _rewardedAd = ad;
          _isAdLoaded = true;
        }),
        onAdFailedToLoad: (_) => setState(() => _isAdLoaded = false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = _travelType == 'domestic'
        ? AppColors.travelingBlue
        : const Color(0xFF9B59B6);

    return Scaffold(
      backgroundColor: Colors.white,
      body: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        behavior: HitTestBehavior.opaque,
        child: Stack(
          children: [
            CustomScrollView(
              slivers: [
                SliverAppBar(
                  pinned: true,
                  backgroundColor: themeColor,
                  elevation: 0,
                  leading: IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new,
                      color: Colors.white,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  actions: [_buildAppBarStampToggle()],
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 20,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDayHeader(),
                        const SizedBox(height: 15),
                        _buildDiaryInput(),
                        const SizedBox(height: 30),
                        _buildSectionTitle(
                          Icons.camera_alt,
                          '오늘의 순간들',
                          '(최대 3장)',
                        ),
                        const SizedBox(height: 12),
                        _buildPhotoList(),
                        const SizedBox(height: 30),
                        _buildSectionTitle(Icons.palette, '오늘을 그리는 방식', ''),
                        const SizedBox(height: 12),
                        ImageStylePicker(
                          onChanged: (style) =>
                              setState(() => _selectedStyle = style),
                        ),
                        const SizedBox(height: 35),
                        if (_imageUrl == null && _generatedImage == null)
                          _buildGenerateButton(),
                        const SizedBox(height: 20),
                        SlideTransition(
                          position: _cardOffset,
                          child: _buildAiResultCard(),
                        ),
                        const SizedBox(height: 120),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            _buildFixedBottomSaveBar(),
            if (_loading) _buildLoadingOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBarStampToggle() {
    return GestureDetector(
      onTap: () => setState(() => _usePaidStampMode = !_usePaidStampMode),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _usePaidStampMode ? Colors.orange : Colors.blue,
            width: 2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _stampUnit("무료", _dailyStamps, Colors.blue, !_usePaidStampMode),
            const VerticalDivider(
              width: 15,
              thickness: 1,
              indent: 8,
              endIndent: 8,
            ),
            _stampUnit("보관", _paidStamps, Colors.orange, _usePaidStampMode),
          ],
        ),
      ),
    );
  }

  Widget _stampUnit(String label, int count, Color color, bool isActive) {
    return Opacity(
      opacity: isActive ? 1.0 : 0.3,
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: Colors.black54),
          ),
          const SizedBox(width: 4),
          Text(
            count.toString(),
            style: TextStyle(
              color: color,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'DAY ${DateUtilsHelper.calculateDayNumber(startDate: widget.startDate, currentDate: widget.date).toString().padLeft(2, '0')}',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: Color(0xFF444444),
          ),
        ),
        Text(
          '${DateFormat('yyyy.MM.dd').format(widget.date)} · ${widget.placeName}',
          style: const TextStyle(fontSize: 14, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildDiaryInput() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: TextField(
        controller: _contentController,
        maxLines: 6,
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: 'diary_hint'.tr(),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(IconData icon, String title, String subTitle) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF444444)),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF444444),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          subTitle,
          style: const TextStyle(fontSize: 14, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildPhotoList() {
    final int totalCount = _remotePhotoUrls.length + _localPhotos.length;
    return SizedBox(
      height: 85,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: totalCount + 1,
        itemBuilder: (context, index) {
          if (index == totalCount) {
            return totalCount < 3
                ? _buildAddPhotoButton()
                : const SizedBox.shrink();
          }
          if (index < _remotePhotoUrls.length) {
            return _buildRemotePhotoItem(index);
          }
          return _buildPhotoItem(index - _remotePhotoUrls.length);
        },
      ),
    );
  }

  Widget _buildRemotePhotoItem(int index) {
    return Container(
      width: 85,
      height: 85,
      margin: const EdgeInsets.only(right: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        image: DecorationImage(
          image: NetworkImage(_remotePhotoUrls[index]),
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _buildPhotoItem(int index) {
    return Stack(
      children: [
        Container(
          width: 85,
          height: 85,
          margin: const EdgeInsets.only(right: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            image: DecorationImage(
              image: FileImage(_localPhotos[index]),
              fit: BoxFit.cover,
            ),
          ),
        ),
        Positioned(
          top: 5,
          right: 15,
          child: GestureDetector(
            onTap: () => setState(() => _localPhotos.removeAt(index)),
            child: const CircleAvatar(
              radius: 10,
              backgroundColor: Colors.black54,
              child: Icon(Icons.close, size: 12, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAddPhotoButton() {
    return GestureDetector(
      onTap: _pickImages,
      child: Container(
        width: 85,
        height: 85,
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.add, color: Colors.grey, size: 30),
      ),
    );
  }

  Widget _buildGenerateButton() {
    return GestureDetector(
      onTap: _loading ? null : _handleGenerateWithStamp,
      child: Container(
        width: double.infinity,
        height: 60,
        decoration: BoxDecoration(
          color: const Color(0xFF3498DB),
          borderRadius: BorderRadius.circular(15),
        ),
        child: const Center(
          child: Text(
            '↓ 이 하루를 그림으로..',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAiResultCard() {
    if (_imageUrl == null && _generatedImage == null)
      return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 15),
        ],
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(25),
            child: _imageUrl != null
                ? Image.network(_imageUrl!, fit: BoxFit.cover)
                : Image.memory(_generatedImage!, fit: BoxFit.cover),
          ),
          Positioned(
            top: 15,
            right: 15,
            child: IconButton(
              icon: const CircleAvatar(
                backgroundColor: Colors.black54,
                child: Icon(Icons.close, color: Colors.white),
              ),
              onPressed: () => _cardController.reverse().then(
                (_) => setState(() {
                  _generatedImage = null;
                  _imageUrl = null;
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFixedBottomSaveBar() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: GestureDetector(
        onTap: () {
          if (!_loading) _saveDiary();
        },
        child: Container(
          width: double.infinity,
          height: 70,
          color: _loading ? Colors.grey : const Color(0xFF454B54),
          child: Center(
            child: _loading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    '기록 저장하기'.tr(),
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                  ),
          ),
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
            Lottie.asset('assets/lottie/ai_magic_wand.json', width: 200),
            const SizedBox(height: 20),
            Text(
              _loadingMessage.tr(),
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleGenerateWithStamp() async {
    FocusScope.of(context).unfocus();

    // 스타일 선택 안 했거나 내용 없으면 리턴
    if (_selectedStyle == null || _contentController.text.trim().isEmpty)
      return;

    // 1️⃣ [수정 로직] 무료 모드인데 무료 코인이 없고 보관 코인이 있는 경우
    if (!_usePaidStampMode && _dailyStamps <= 0 && _paidStamps > 0) {
      setState(() => _usePaidStampMode = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('무료 코인이 모두 소진되어 보관 중인 코인을 사용합니다.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
    // 2️⃣ 반대의 경우 (보관 모드인데 보관 코인 없고 무료 코인 있을 때)
    else if (_usePaidStampMode && _paidStamps <= 0 && _dailyStamps > 0) {
      setState(() => _usePaidStampMode = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('보관 코인이 없어 무료 코인을 사용합니다.'),
          duration: Duration(seconds: 2),
        ),
      );
    }

    // 3️⃣ 최종적으로 현재 선택된 모드의 코인 개수 확인
    int currentCoins = _usePaidStampMode ? _paidStamps : _dailyStamps;

    // 진짜 둘 다 없으면 그제서야 충전 팝업!
    if (currentCoins <= 0) {
      _showCoinEmptyDialog();
      return;
    }

    // 광고가 필요한 무료 모드라면 광고 송출 후 생성 시작
    if (!_usePaidStampMode && _isAdLoaded && _rewardedAd != null) {
      _rewardedAd!.show(
        onUserEarnedReward: (ad, reward) {
          // 보상 획득 시 생성 시작 (기존 로직 유지)
          _startAiGeneration();
        },
      );
    } else {
      // 보관 코인 사용 시에는 바로 생성 시작
      _startAiGeneration();
    }
  }

  Future<void> _startAiGeneration() async {
    setState(() {
      _loading = true;
      _loadingMessage = _usePaidStampMode
          ? "ai_drawing_memories".tr()
          : "ai_drawing_after_ad".tr();
    });
    try {
      final gemini = GeminiService();
      final summary = await gemini.generateSummary(
        finalPrompt:
            '${PromptCache.textPrompt.content}\n장소:${widget.placeName}\n내용:${_contentController.text}',
        photos: _localPhotos,
      );
      final image = await gemini.generateImage(
        finalPrompt:
            '${PromptCache.imagePrompt.content}\nStyle:\n${_selectedStyle!.prompt}\nSummary:\n$summary',
      );

      await _stampService.useStamp(_userId, _usePaidStampMode);
      await _refreshStampCounts();
      setState(() {
        _summaryText = summary;
        _generatedImage = image;
        _imageUrl = null;
        _loading = false;
      });
      _cardController.forward();
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  void _showCoinEmptyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('coin_empty_title'.tr()),
        content: Text('coin_empty_desc'.tr()),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AdMissionPage()),
              );
            },
            child: Text(
              'free_charging_station'.tr(),
              style: const TextStyle(
                color: Colors.blue,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              bool? purchased = await showModalBottomSheet<bool>(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => const CoinPaywallBottomSheet(),
              );
              if (purchased == true) await _refreshStampCounts();
            },
            child: Text('go_to_shop_btn'.tr()),
          ),
        ],
      ),
    );
  }

  // ✅ [수정] diaryId 기반 저장 로직
  Future<void> _saveDiary() async {
    if (_generatedImage == null &&
        _imageUrl == null &&
        _contentController.text.trim().isEmpty)
      return;
    setState(() {
      _loading = true;
      _loadingMessage = "saving_diary".tr();
    });

    try {
      final int currentDayIndex = DateUtilsHelper.calculateDayNumber(
        startDate: widget.startDate,
        currentDate: widget.date,
      );

      // 1. DB에 일기를 먼저 저장해서 diaryId를 가져옵니다.
      final diaryData = await TravelDayService.upsertDiary(
        travelId: _cleanTravelId,
        dayIndex: currentDayIndex,
        date: widget.date,
        text: _contentController.text.trim(),
        aiSummary: _summaryText,
        aiStyle: _selectedStyle?.id ?? 'default',
      );
      final String diaryId = diaryData['id'].toString().replaceAll(
        RegExp(r'[\s\n\r\t]+'),
        '',
      );

      // 2. [변경] 고유한 diaryId 폴더 안에 사진 업로드
      if (_localPhotos.isNotEmpty) {
        for (int i = 0; i < _localPhotos.length; i++) {
          final String fileName =
              'moment_${DateTime.now().millisecondsSinceEpoch}_$i.png';
          final String fullPath =
              'users/$_userId/travels/$_cleanTravelId/diaries/$diaryId/moments/$fileName';
          await Supabase.instance.client.storage
              .from('travel_images')
              .upload(fullPath, _localPhotos[i]);
        }
      }

      // 3. [변경] 고유한 diaryId 폴더 안에 AI 이미지 업로드
      if (_generatedImage != null) {
        final String aiPath =
            'users/$_userId/travels/$_cleanTravelId/diaries/$diaryId/ai_generated.png';
        await ImageUploadService.uploadAiImage(
          path: aiPath,
          imageBytes: _generatedImage!,
        );
      }

      final writtenDays = await TravelDayService.getWrittenDayCount(
        travelId: _cleanTravelId,
      );
      final totalDays = widget.endDate.difference(widget.startDate).inDays + 1;

      if (mounted) {
        setState(() => _loading = false);
        if (writtenDays >= totalDays) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TravelCompletionPage(
                rewardedAd: _rewardedAd,
                processingTask: TravelCompleteService.tryCompleteTravel(
                  travelId: _cleanTravelId,
                  startDate: widget.startDate,
                  endDate: widget.endDate,
                ),
              ),
            ),
          );
        } else {
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      debugPrint('❌ 저장 실패: $e');
      setState(() => _loading = false);
    }
  }
}
