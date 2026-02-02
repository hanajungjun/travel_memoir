/// ****************************************************************************
/// 🚩 MASTER RULES FOR THIS PAGE:
/// 1. PARALLEL PROCESSING: Background AI tasks and foreground Ads must run
///    concurrently. Never 'await' AI generation before showing Ads.
/// 2. BALANCED (60/40): AI summary must give EQUAL importance to visual
///    analysis of photos and narrative details of the text diary.
/// 3. NO OMISSION: All logic blocks, including UI, Services, and State
///    management, must be fully preserved during updates.
/// ****************************************************************************

import 'dart:io';
import 'dart:typed_data';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:lottie/lottie.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

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
  String? _existingAiStyleId;
  final List<File> _localPhotos = [];
  List<String> _remotePhotoUrls = [];
  Uint8List? _generatedImage;
  String? _imageUrl;
  String? _summaryText;

  bool _loading = false;
  bool _isSharing = false;
  String _loadingMessage = "";

  int _dailyStamps = 0;
  int _vipStamps = 0;
  int _paidStamps = 0;
  bool _isVip = false;
  bool _usePaidStampMode = false;
  bool _isPremiumUser = false;
  int _usageCountToday = 0;

  bool _isTripTypeLoaded = false;
  String? _travelType;

  RewardedAd? _rewardedAd;
  bool _isAdLoaded = false;

  late AnimationController _cardController;
  bool _isAiDone = false;
  bool _isAdDone = false;

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
  }

  @override
  void dispose() {
    _contentController.dispose();
    _rewardedAd?.dispose();
    _cardController.dispose();
    super.dispose();
  }

  Future<void> _initData() async {
    await _loadDefaultCoinSetting();
    await _loadDiary();
    await _refreshStampCounts();
    _loadAds();
    _checkTripType();
    _checkVipStatus();
    _loadDailyUsage();
  }

  Future<void> _loadDailyUsage() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;
      final data = await Supabase.instance.client
          .from('users')
          .select('daily_usage_count, last_generated_at')
          .eq('auth_uid', userId)
          .maybeSingle();
      if (mounted && data != null) {
        final lastDate = DateTime.parse(data['last_generated_at']).toLocal();
        final now = DateTime.now();
        if (lastDate.year != now.year ||
            lastDate.month != now.month ||
            lastDate.day != now.day) {
          setState(() => _usageCountToday = 0);
        } else {
          setState(() => _usageCountToday = data['daily_usage_count'] ?? 0);
        }
      }
    } catch (e) {
      debugPrint('사용량 로드 실패: $e');
    }
  }

  Future<void> _checkVipStatus() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    final data = await Supabase.instance.client
        .from('users')
        .select('is_vip, is_premium')
        .eq('auth_uid', userId)
        .maybeSingle();
    if (mounted && data != null) {
      setState(() {
        _isVip = data['is_vip'] ?? false;
        _isPremiumUser = data['is_premium'] ?? false;
      });
    }
  }

  Future<void> _loadDefaultCoinSetting() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted)
      setState(
        () => _usePaidStampMode =
            prefs.getBool('use_credit_mode_default') ?? false,
      );
  }

  Future<void> _saveDefaultCoinSetting(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('use_credit_mode_default', value);
  }

  Future<void> _refreshStampCounts() async {
    final stamps = await _stampService.getStampData(_userId);
    if (!mounted || stamps == null) return;
    setState(() {
      _dailyStamps = (stamps['daily_stamps'] ?? 0).toInt();
      _vipStamps = (stamps['vip_stamps'] ?? 0).toInt();
      _paidStamps = (stamps['paid_stamps'] ?? 0).toInt();
      _isVip = stamps['is_vip'] ?? false;
    });
  }

  Future<void> _checkTripType() async {
    final tripData = await Supabase.instance.client
        .from('travels')
        .select('travel_type')
        .eq('id', _cleanTravelId)
        .maybeSingle();
    if (!mounted) return;
    setState(() {
      if (tripData != null) _travelType = tripData['travel_type'] ?? 'domestic';
      _isTripTypeLoaded = true;
    });
  }

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
      _summaryText = diary['ai_summary'];
      _existingAiStyleId = diary['ai_style'];
    });
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
        setState(() => _remotePhotoUrls = urls);
      }
    } catch (e) {
      debugPrint('📸 사진 로드 실패: $e');
    }
    if ((diary['ai_summary'] ?? '').toString().trim().isNotEmpty) {
      final String aiPath =
          'users/$_userId/travels/$_cleanTravelId/diaries/$diaryId/ai_generated.png';
      final String rawUrl = Supabase.instance.client.storage
          .from('travel_images')
          .getPublicUrl(aiPath);
      setState(
        () => _imageUrl =
            "$rawUrl?v=${DateTime.now().millisecondsSinceEpoch}&width=800&quality=80",
      );
      if (_imageUrl != null) _cardController.forward();
    }
  }

  Future<void> _shareDiaryImage(BuildContext ctx) async {
    if (_imageUrl == null && _generatedImage == null) return;
    setState(() => _isSharing = true);
    try {
      Uint8List imageBytes;
      if (_generatedImage != null) {
        imageBytes = _generatedImage!;
      } else {
        final res = await http.get(Uri.parse(_imageUrl!));
        imageBytes = res.bodyBytes;
      }

      if (!_isVip && !_isPremiumUser) {
        final ByteData watermarkData = await rootBundle.load(
          'assets/images/watermark.png',
        );
        final Uint8List watermarkBytes = watermarkData.buffer.asUint8List();
        img.Image? originalImg = img.decodeImage(imageBytes);
        img.Image? watermarkImg = img.decodeImage(watermarkBytes);
        if (originalImg != null && watermarkImg != null) {
          int targetWidth = (originalImg.width * 0.15).toInt();
          img.Image resizedWatermark = img.copyResize(
            watermarkImg,
            width: targetWidth,
          );
          for (var pixel in resizedWatermark) {
            pixel.a = (pixel.a * 0.5).toInt();
          }
          int x = originalImg.width - resizedWatermark.width - 20;
          int y = originalImg.height - resizedWatermark.height - 20;
          img.compositeImage(originalImg, resizedWatermark, dstX: x, dstY: y);
          imageBytes = Uint8List.fromList(img.encodePng(originalImg));
        }
      }
      final temp = await getTemporaryDirectory();
      final file = await File('${temp.path}/share_diary.png').create();
      await file.writeAsBytes(imageBytes);
      final box = ctx.findRenderObject() as RenderBox?;
      await Share.shareXFiles(
        [XFile(file.path)],
        sharePositionOrigin: box != null
            ? box.localToGlobal(Offset.zero) & box.size
            : null,
      );
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  Future<void> _pickImages() async {
    final int currentTotal = _localPhotos.length + _remotePhotoUrls.length;
    if (currentTotal >= 3) return;
    final List<XFile> pickedFiles = await _picker.pickMultiImage();
    if (pickedFiles.isNotEmpty) {
      setState(
        () => _localPhotos.addAll(
          pickedFiles.take(3 - currentTotal).map((file) => File(file.path)),
        ),
      );
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

  Future<void> _handleGenerateWithStamp() async {
    FocusScope.of(context).unfocus();
    if (_selectedStyle == null || _contentController.text.trim().isEmpty)
      return;
    setState(() => _loading = true);
    try {
      final response = await Supabase.instance.client.rpc(
        'check_ai_generation_limit',
        params: {'target_user_id': _userId},
      );
      if (!(response['can_generate'] ?? false)) {
        setState(() => _loading = false);
        _showLimitDialog(response['reason'], response['remaining_min'] ?? 0);
        return;
      }
    } catch (e) {
      debugPrint('수문장 실패: $e');
    }

    String stampToUse = 'daily_stamps';
    bool skipAd = false;
    if (_isVip && _vipStamps > 0) {
      stampToUse = 'vip_stamps';
      skipAd = true;
    } else if (_usePaidStampMode && _paidStamps > 0) {
      stampToUse = 'paid_stamps';
      skipAd = true;
    } else if (_dailyStamps > 0) {
      stampToUse = 'daily_stamps';
      skipAd = false;
    } else {
      setState(() => _loading = false);
      _showCoinEmptyDialog();
      return;
    }

    _isAiDone = false;
    _isAdDone = false;
    _startAiGeneration(stampToUse)
        .then((_) {
          _isAiDone = true;
          _checkSync();
        })
        .catchError((e) {
          if (mounted) setState(() => _loading = false);
        });

    if (!skipAd && _isAdLoaded && _rewardedAd != null) {
      _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _loadAds();
          _isAdDone = true;
          _checkSync();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
          _isAdDone = true;
          _checkSync();
        },
      );
      _rewardedAd!.show(onUserEarnedReward: (ad, reward) {});
    } else {
      _isAdDone = true;
      _checkSync();
    }
  }

  void _showLimitDialog(String reason, int minutes) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(reason == 'cooling_down' ? '🎨 화가가 쉬는 중' : '예술혼 완전 연소!'),
        content: Text(
          reason == 'cooling_down'
              ? '너무 열심히 그렸나 봐요! $minutes분 후에 다시 그려드릴게요.'
              : '오늘 준비된 기회를 모두 사용하셨습니다. 내일 다시 만나요!',
        ),
        actions: [
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                '확인',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _checkSync() {
    if (_isAiDone && _isAdDone) {
      if (mounted) {
        setState(() => _loading = false);
        _cardController.forward();
      }
    } else if (_isAdDone && !_isAiDone) {
      if (mounted)
        setState(() => _loadingMessage = "ai_finishing_touches".tr());
    }
  }

  Future<void> _startAiGeneration(String stampType) async {
    if (mounted)
      setState(() {
        _loading = true;
        _loadingMessage = "ai_drawing_memories".tr();
        _imageUrl = null;
        _generatedImage = null;
        _summaryText = null;
      });
    try {
      final gemini = GeminiService();
      final summary = await gemini.generateSummary(
        finalPrompt:
            '${PromptCache.textPrompt.contentKo}\n[Information]\nLocation: ${widget.placeName}\nDiary Content: ${_contentController.text}',
        photos: _localPhotos,
      );
      _summaryText = summary;
      final image = await gemini.generateImage(
        finalPrompt:
            '${PromptCache.imagePrompt.contentKo}\nStyle: ${_selectedStyle!.prompt}\n[Context from Diary Summary]: $summary\n',
      );
      if (image == null) throw Exception("Image generation failed");
      await _stampService.useStamp(_userId, stampType);
      await _refreshStampCounts();
      await _loadDailyUsage();
      setState(() => _generatedImage = image);
    } catch (e) {
      rethrow;
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
      final diaryData = await TravelDayService.upsertDiary(
        travelId: _cleanTravelId,
        dayIndex: currentDayIndex,
        date: widget.date,
        text: _contentController.text.trim(),
        aiSummary: _summaryText,
        aiStyle: _selectedStyle?.id ?? _existingAiStyleId ?? 'default',
      );
      final String diaryId = diaryData['id'].toString().replaceAll(
        RegExp(r'[\s\n\r\t]+'),
        '',
      );
      if (_localPhotos.isNotEmpty) {
        final storage = Supabase.instance.client.storage.from('travel_images');
        for (int i = 0; i < _localPhotos.length; i++) {
          final targetPath =
              '${(await getTemporaryDirectory()).path}/${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
          final result = await FlutterImageCompress.compressAndGetFile(
            _localPhotos[i].absolute.path,
            targetPath,
            quality: 70,
            minWidth: 1024,
            minHeight: 1024,
          );
          final String fullPath =
              'users/$_userId/travels/$_cleanTravelId/diaries/$diaryId/moments/moment_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
          await storage.upload(fullPath, File(result!.path));
          await _appendPhotoUrl(diaryId, storage.getPublicUrl(fullPath));
        }
      }
      if (_generatedImage != null)
        await ImageUploadService.uploadAiImage(
          path:
              'users/$_userId/travels/$_cleanTravelId/diaries/$diaryId/ai_generated.png',
          imageBytes: _generatedImage!,
        );
      if (mounted) {
        setState(() => _loading = false);
        final writtenDays = await TravelDayService.getWrittenDayCount(
          travelId: _cleanTravelId,
        );
        final totalDays =
            widget.endDate.difference(widget.startDate).inDays + 1;
        if (writtenDays >= totalDays) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TravelCompletionPage(
                rewardedAd: _rewardedAd,
                usedPaidStamp: _usePaidStampMode,
                isVip: _isVip,
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
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _appendPhotoUrl(String travelDayId, String imageUrl) async {
    final client = Supabase.instance.client;
    final data = await client
        .from('travel_days')
        .select('photo_urls')
        .eq('id', travelDayId)
        .single();
    final List<String> urls = List<String>.from(data['photo_urls'] ?? []);
    if (!urls.contains(imageUrl)) {
      urls.add(imageUrl);
      await client
          .from('travel_days')
          .update({'photo_urls': urls})
          .eq('id', travelDayId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool hasAiImage = _imageUrl != null || _generatedImage != null;
    final Color generateButtonColor = !_isTripTypeLoaded
        ? const Color(0xFFC2C2C2)
        : _travelType == 'domestic'
        ? AppColors.travelingBlue
        : _travelType == 'usa'
        ? AppColors.travelingRed
        : AppColors.travelingPurple;

    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F6F6),
        resizeToAvoidBottomInset: false, // ✅ 하단 버튼 철벽 고정
        body: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              Column(
                children: [
                  // ✅ [필살기] 상단 카드만 스크롤 가능하게 분리하여 이미지 제스처 방해 금지
                  SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: _buildTopInputCard(generateButtonColor),
                  ),

                  // ✅ [해결] 이미지 영역을 Expanded로 잡아 남은 화면을 꽉 채웁니다.
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(top: 10),
                      color: hasAiImage
                          ? Colors.transparent
                          : const Color(0xFFE6E6E6),
                      child: hasAiImage
                          ? _buildAiImageContent()
                          : _buildEmptyImageContent(),
                    ),
                  ),

                  // ✅ [해결] 저장 버튼에 가려지는 영역만큼 물리적 여백 추가
                  const SizedBox(height: 58),
                ],
              ),

              // 저장 버튼을 Stack의 맨 바닥에 고정
              _buildFixedBottomSaveBar(),

              if (_loading) _buildLoadingOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAiImageContent() {
    return ClipRect(
      child: InteractiveViewer(
        panEnabled: true,
        scaleEnabled: true,
        minScale: 1.0,
        maxScale: 5.0,
        boundaryMargin: EdgeInsets.zero,
        constrained: false,
        child: GestureDetector(
          onTap: _showImagePopup,
          child: SizedBox(
            width: MediaQuery.of(context).size.width,
            child: _imageUrl != null
                ? CachedNetworkImage(
                    imageUrl: _imageUrl!,
                    fit: BoxFit.cover,
                    memCacheWidth: 800,
                    placeholder: (_, __) => Container(
                      color: Colors.white.withOpacity(0), // 은은하게
                      child: Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.grey.withOpacity(0.25), // 은은하게
                          ),
                        ),
                      ),
                    ),
                    errorWidget: (_, __, ___) => const Icon(Icons.broken_image),
                  )
                : Image.memory(_generatedImage!, fit: BoxFit.cover),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyImageContent() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/icons/ico_attached2.png',
            width: 110,
            height: 101,
          ),
          const SizedBox(height: 5),
          Text(
            '오늘의 하루를\n그림으로 남겨보세요',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: const Color(0xFFB3B3B3),
              fontSize: 15,
              height: 1.2,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopInputCard(Color btnColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 27, vertical: 5),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(17, 15, 17, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 5),
                        child: Text(
                          'DAY ${DateUtilsHelper.calculateDayNumber(startDate: widget.startDate, currentDate: widget.date).toString().padLeft(2, '0')}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textColor01,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${DateFormat('yyyy.MM.dd').format(widget.date)} · ${widget.placeName}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textColor04,
                          ),
                        ),
                      ),
                      _buildAppBarCoinToggle(),
                    ],
                  ),
                  if (_isPremiumUser)
                    Padding(
                      padding: const EdgeInsets.only(left: 5, top: 4),
                      child: Text(
                        '오늘 남은 생성 횟수: ${100 - _usageCountToday}/100',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.amber[800],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  const SizedBox(height: 5),
                  _buildDiaryInput(),
                  const SizedBox(height: 17),
                  _buildSectionTitle(
                    'assets/icons/ico_camera.png',
                    'todays_moments'.tr(),
                    'max_3_photos'.tr(),
                  ),
                  const SizedBox(height: 7),
                  _buildPhotoList(),
                  const SizedBox(height: 18),
                  _buildSectionTitle(
                    'assets/icons/ico_palette.png',
                    'drawing_style'.tr(),
                    '',
                  ),
                  const SizedBox(height: 3),
                  ImageStylePicker(
                    onChanged: (style) {
                      FocusManager.instance.primaryFocus?.unfocus();
                      setState(() => _selectedStyle = style);
                    },
                  ),
                  const SizedBox(height: 11),
                ],
              ),
            ),
            _buildGenerateButton(btnColor),
          ],
        ),
      ),
    );
  }

  void _showImagePopup() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.9),
      builder: (_) => StatefulBuilder(
        builder: (context, setPopupState) => Stack(
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Dialog(
                insetPadding: EdgeInsets.zero,
                backgroundColor: Colors.transparent,
                child: SizedBox(
                  width: double.infinity,
                  height: double.infinity,
                  child: InteractiveViewer(
                    minScale: 1.0,
                    maxScale: 4.0,
                    child: _imageUrl != null
                        ? Image.network(_imageUrl!, fit: BoxFit.contain)
                        : (_generatedImage != null
                              ? Image.memory(
                                  _generatedImage!,
                                  fit: BoxFit.contain,
                                )
                              : const SizedBox()),
                  ),
                ),
              ),
            ),
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              right: 20,
              child: Material(
                color: Colors.transparent,
                child: GestureDetector(
                  onTap: _isSharing
                      ? null
                      : () async {
                          setPopupState(() {});
                          await _shareDiaryImage(context);
                          setPopupState(() {});
                        },
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: _isSharing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(
                              Icons.ios_share,
                              color: Colors.white,
                              size: 24,
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBarCoinToggle() {
    if (_isVip && _vipStamps > 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFFFD700).withOpacity(0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFFFD700), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.stars, size: 14, color: Color(0xFFFFD700)),
            const SizedBox(width: 5),
            const Text(
              'VIP',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Color(0xFFFFD700),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              _vipStamps.toString(),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Color(0xFFFFD700),
              ),
            ),
          ],
        ),
      );
    }
    return GestureDetector(
      onTap: () {
        bool newValue = !_usePaidStampMode;
        setState(() => _usePaidStampMode = newValue);
        _saveDefaultCoinSetting(newValue);
      },
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: const Color(0xFF454B54),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            _coinUnit(
              'free_stamp'.tr(),
              _dailyStamps,
              const Color.fromARGB(255, 77, 181, 255),
              !_usePaidStampMode,
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 1,
              height: 5,
              color: Colors.white.withOpacity(0.2),
            ),
            _coinUnit(
              'paid_stamp'.tr(),
              _paidStamps,
              const Color.fromARGB(226, 255, 183, 68),
              _usePaidStampMode,
            ),
          ],
        ),
      ),
    );
  }

  Widget _coinUnit(String label, int count, Color activeBg, bool isActive) {
    final Color textColor = isActive ? Colors.white : activeBg;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isActive ? activeBg : Colors.transparent,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: textColor,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(width: 3),
          Text(
            count.toString(),
            style: TextStyle(
              color: textColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              height: 1.45,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiaryInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE7E7E7)),
      ),
      child: TextField(
        controller: _contentController,
        maxLines: 5,
        style: const TextStyle(
          fontSize: 13,
          height: 1.2,
          color: Color(0xFF2B2B2B),
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: 'diary_hint'.tr(),
          hintStyle: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 13),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String icon, String title, String sub) {
    return Row(
      children: [
        Image.asset(icon, width: 14, height: 14),
        const SizedBox(width: 5),
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textColor01,
          ),
        ),
        const SizedBox(width: 3),
        Text(
          sub,
          style: const TextStyle(fontSize: 13, color: AppColors.textColor06),
        ),
      ],
    );
  }

  Widget _buildPhotoList() {
    return SizedBox(
      height: 42,
      child: LayoutBuilder(
        builder: (ctx, box) {
          final w = (box.maxWidth - 42 - 18) / 3;
          return Row(
            children: [
              _buildPhotoSlot(0, w),
              const SizedBox(width: 6),
              _buildPhotoSlot(1, w),
              const SizedBox(width: 6),
              _buildPhotoSlot(2, w),
              const SizedBox(width: 6),
              _buildAddPhotoButton(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPhotoSlot(int i, double w) {
    final rc = _remotePhotoUrls.length;
    final lc = _localPhotos.length;
    Widget? img;
    bool del = false;
    VoidCallback? onDel;
    if (i < rc) {
      img = Image.network(_remotePhotoUrls[i], fit: BoxFit.cover);
      del = true;
      onDel = () => setState(() => _remotePhotoUrls.removeAt(i));
    } else if (i < rc + lc) {
      final li = i - rc;
      img = Image.file(_localPhotos[li], fit: BoxFit.cover);
      del = true;
      onDel = () => setState(() => _localPhotos.removeAt(li));
    }
    return _buildFixedPhotoBox(
      width: w,
      child: img,
      showRemove: del,
      onRemove: onDel,
    );
  }

  Widget _buildAddPhotoButton() {
    return GestureDetector(
      onTap: _pickImages,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: const Color(0xFFDBDBDB),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Center(
          child: Image.asset(
            'assets/icons/ico_add_photo.png',
            width: 18,
            height: 18,
          ),
        ),
      ),
    );
  }

  Widget _buildGenerateButton(Color c) {
    return GestureDetector(
      onTap: _loading ? null : _handleGenerateWithStamp,
      child: Container(
        width: double.infinity,
        height: 47,
        decoration: BoxDecoration(
          color: c,
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(12),
            bottomRight: Radius.circular(12),
          ),
        ),
        child: Center(
          child: Text(
            'generate_image_button'.tr(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
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
          height: 58,
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
                    'save_diary_button'.tr(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
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

  Widget _buildFixedPhotoBox({
    required double width,
    required Widget? child,
    required bool showRemove,
    VoidCallback? onRemove,
  }) {
    final hasImg = child != null;
    return Container(
      width: width,
      height: 42,
      decoration: BoxDecoration(
        color: const Color(0xFFEDEDED),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: SizedBox(
              width: width,
              height: 42,
              child: hasImg ? child : const SizedBox(),
            ),
          ),
          if (!hasImg)
            Center(
              child: Image.asset(
                'assets/icons/ico_attached.png',
                width: 26,
                height: 19,
              ),
            ),
          if (hasImg && showRemove && onRemove != null)
            Positioned(
              top: 2,
              right: 2,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.55),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, size: 10, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
