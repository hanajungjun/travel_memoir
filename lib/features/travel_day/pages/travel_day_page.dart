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
import 'package:travel_memoir/services/logger_service.dart';

import 'package:travel_memoir/services/gemini_service.dart';
import 'package:travel_memoir/services/image_upload_service.dart';
import 'package:travel_memoir/services/travel_day_service.dart';
import 'package:travel_memoir/services/prompt_cache.dart';
import 'package:travel_memoir/services/stamp_service.dart';

import 'package:travel_memoir/models/image_style_model.dart';
import 'package:travel_memoir/core/widgets/image_style_picker.dart';
import 'package:travel_memoir/core/widgets/coin_paywall_bottom_sheet.dart';
import 'package:travel_memoir/features/travel_day/pages/travel_completion_page.dart';
import 'package:travel_memoir/services/travel_complete_service.dart';

import 'package:travel_memoir/core/utils/date_utils.dart';
import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/core/widgets/popup/app_toast.dart';
import 'package:travel_memoir/core/widgets/popup/app_dialogs.dart';

/**
 * 📱 Screen ID : TRAVEL_DAY_PAGE
 * 📝 Name      : 여행 일기 작성 및 AI 생성 화면
 * 🛠 Feature   : 
 * - Gemini AI 기반 일기 요약 및 커스텀 이미지 생성
 * - 스탬프(Daily/VIP/Paid) 차감 및 광고(AdMob) 연동 로직
 * - 멀티 이미지 선택(ImagePicker) 및 스토리지 업로드/관리
 * - 일기 저장 시 여행 완료 여부 자동 체크 (TravelCompleteService)
 * * [ UI Structure ]
 * ----------------------------------------------------------
 * travel_day_page.dart (Scaffold)
 * ├── Stack (Main Body)
 * │    ├── Column (Content)
 * │    │    ├── _buildTopInputCard (입력 영역)
 * │    │    │    ├── TextField [일기 입력]
 * │    │    │    ├── _buildPhotoList [사진 첨부]
 * │    │    │    ├── ImageStylePicker [AI 스타일 선택]
 * │    │    │    └── _buildGenerateButton [AI 생성 버튼]
 * │    │    └── Expanded [AI 생성 이미지 결과 영역]
 * │    ├── _buildFixedBottomSaveBar [하단 저장 버튼 고정]
 * │    └── _buildLoadingOverlay [AI 생성 중 Lottie 애니메이션]
 * └── app_dialogs.dart (이미지 크게 보기 / 공유 팝업)
 * ----------------------------------------------------------
 */

class TravelDayPage extends StatefulWidget {
  final String travelId;
  final String placeName;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime date;
  final Map<String, dynamic>? initialDiary;
  final bool isReordering; // 🎯 1. 이거 추가

  const TravelDayPage({
    super.key,
    required this.travelId,
    required this.placeName,
    required this.startDate,
    required this.endDate,
    required this.date,
    this.initialDiary,
    this.isReordering = false, // 🎯 2. 이거 추가
  });

  @override
  State<TravelDayPage> createState() => _TravelDayPageState();
}

class _TravelDayPageState extends State<TravelDayPage>
    with SingleTickerProviderStateMixin {
  final StampService _stampService = StampService();
  final TextEditingController _contentController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final _logger = LoggerService(); // ✅ 로거 인스턴스

  // ✅ 모든 번역 문자열을 클래스 변수로 선언
  String _languageCode = 'en';
  String _todaysMomentsText = '';
  String _maxPhotosText = '';
  String _drawingStyleText = '';
  String _generateImageButtonText = '';
  String _saveDiaryButtonText = '';
  String _diaryHintText = '';
  String _freeStampText = '';
  String _paidStampText = '';

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
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ✅ 모든 번역 문자열을 여기서 초기화
    _languageCode = context.locale.languageCode;
    _todaysMomentsText = 'todays_moments'.tr();
    _maxPhotosText = 'max_3_photos'.tr();
    _drawingStyleText = 'drawing_style'.tr();
    _generateImageButtonText = 'generate_image_button'.tr();
    _saveDiaryButtonText = 'save_diary_button'.tr();
    _diaryHintText = 'diary_hint'.tr();
    _freeStampText = 'free_stamp'.tr();
    _paidStampText = 'paid_stamp'.tr();
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

  // _TravelDayPageState 클래스 상단 변수 선언부에 추가 (95번 줄 근처)
  String? _currentDiaryId;

  // _loadDiary 함수 내부 수정 (220번 줄 근처)
  Future<void> _loadDiary() async {
    final diary =
        widget.initialDiary ??
        await TravelDayService.getDiaryByDate(
          travelId: _cleanTravelId,
          date: widget.date,
        );
    if (!mounted || diary == null) return;

    final String diaryId = diary['id'].toString().replaceAll(
      RegExp(r'[\s\n\r\t]+'),
      '',
    );

    setState(() {
      _currentDiaryId = diaryId; // 🎯 [추가] 고유 ID를 변수에 저장!
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
          'users/$_userId/travels/$_cleanTravelId/diaries/$diaryId/ai_generated.jpg';
      final String rawUrl = Supabase.instance.client.storage
          .from('travel_images')
          .getPublicUrl(aiPath);
      setState(
        () => _imageUrl =
            "$rawUrl?v=${DateTime.now().millisecondsSinceEpoch}&width=800&quality=70",
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
    // 🎯 [추가] 갤러리 열기 전에 키보드부터 확실하게 닫기
    FocusScope.of(context).unfocus();
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
    // ✅ setState 밖에서 미리 추출
    final String enterDiaryMessage = 'please_enter_diary_text'.tr();
    final String selectStyleMessage = 'select_style_msg'.tr();

    if (_contentController.text.trim().isEmpty) {
      AppToast.show(context, enterDiaryMessage); // ✅ 미리 추출한 값 사용
      return;
    }
    if (_selectedStyle == null) {
      AppToast.show(context, selectStyleMessage); // ✅ 미리 추출한 값 사용
      return;
    }

    String stampType = "";

    // 🎯 [수정된 로직] 코인 소진 우선순위 결정
    if (_isVip && _vipStamps > 0) {
      // 1순위: VIP 스탬프 (VIP 유저인 경우)
      stampType = "vip";
    } else if (_usePaidStampMode && _paidStamps > 0) {
      // 2순위 (유료모드 선택 시): 유료 스탬프
      stampType = "paid";
    } else if (!_usePaidStampMode && _dailyStamps > 0) {
      // 2순위 (무료모드 선택 시): 무료 스탬프
      stampType = "daily";
    } else if (_paidStamps > 0) {
      // 3순위 (구원 로직): 선택한 모드엔 없지만 유료 스탬프가 남은 경우
      stampType = "paid";
      _logger.log("💡 선택 모드 코인 부족으로 유료 코인 자동 전환", tag: "STAMP_PROCESS");
    } else if (_dailyStamps > 0) {
      // 3순위 (구원 로직): 선택한 모드엔 없지만 무료 스탬프가 남은 경우
      stampType = "daily";
      _logger.log("💡 선택 모드 코인 부족으로 무료 코인 자동 전환", tag: "STAMP_PROCESS");
    } else {
      // 4순위: 진짜 코인이 하나도 없을 때만 결제창
      _showCoinEmptyDialog();
      return;
    }

    _isAiDone = false;
    _isAdDone = false;
    _logger.log("🚀 생성 시작: 타입=$stampType, VIP=$_isVip", tag: "TRAVEL_DAY_UI");
    debugPrint("🚀 생성 버튼 클릭: 타입=$stampType, VIP=$_isVip");

    // ✅ AI 생성 시작
    _startAiGeneration(stampType)
        .then((_) {
          if (!mounted) return; // ✅ 화면이 닫혔으면 중단
          _isAiDone = true;
          _checkSync();
        })
        .catchError((e) {
          if (mounted) setState(() => _loading = false);
        });

    // ✅ 광고 로직 처리
    if (stampType == "vip" || stampType == "paid") {
      _isAdDone = true;
      _checkSync();
    } else {
      if (_rewardedAd != null && _isAdLoaded) {
        _rewardedAd!.show(
          onUserEarnedReward: (_, reward) {
            _isAdDone = true;
            _checkSync();
          },
        );
      } else {
        _isAdDone = true;
        _checkSync();
      }
    }
  }

  void _checkSync() {
    // ✅ setState 밖에서 미리 추출
    final String finishingMessage = "ai_finishing_touches".tr();

    if (_isAiDone && _isAdDone) {
      if (mounted) {
        // ✅ 이미 체크 중이지만 확실히 유지
        setState(() => _loading = false);
        _cardController.forward();
      }
    } else if (_isAdDone && !_isAiDone) {
      if (mounted) {
        setState(() => _loadingMessage = finishingMessage);
      }
    }
  }

  Future<void> _startAiGeneration(String stampType) async {
    final String drawingMessage = "ai_drawing_memories".tr();
    final String generationFailedMessage = 'ai_generation_failed'.tr();

    if (mounted) {
      setState(() {
        _loading = true;
        _loadingMessage = drawingMessage;
        _imageUrl = null;
        _generatedImage = null;
        _summaryText = null;
      });
    }

    bool isStampDeducted = false;

    try {
      // 🎯 [강력 로그] 여기서부터 시작입니다!
      print('🚩 [START_PROCESS] AI 생성 로직 진입');

      List<Uint8List> allPhotoBytes = [];

      // 리스트 개수부터 확인
      print(
        '📊 [CHECK] 로컬 사진: ${_localPhotos.length}장 / 서버 사진: ${_remotePhotoUrls.length}장',
      );

      // 1. 로컬 사진 처리
      for (int i = 0; i < _localPhotos.length; i++) {
        final file = _localPhotos[i];
        print('📸 [LOCAL_LOAD] ($i) 파일 읽기 시도: ${file.path}');
        final bytes = await file.readAsBytes();
        allPhotoBytes.add(bytes);
        print('✅ [LOCAL_LOAD] ($i) 완료: ${bytes.length} bytes');
      }

      // 2. 서버 사진 다운로드 (이 부분이 안 찍힌다면 _remotePhotoUrls가 [] 인 것입니다)
      for (int i = 0; i < _remotePhotoUrls.length; i++) {
        final url = _remotePhotoUrls[i];
        print('🌐 [REMOTE_LOAD] ($i) 다운로드 시도: $url');
        try {
          final res = await http
              .get(Uri.parse(url))
              .timeout(const Duration(seconds: 15));
          if (res.statusCode == 200) {
            allPhotoBytes.add(res.bodyBytes);
            print('✅ [REMOTE_LOAD] ($i) 성공: ${res.bodyBytes.length} bytes');
          } else {
            print('❌ [REMOTE_LOAD] ($i) 실패: HTTP ${res.statusCode}');
          }
        } catch (e) {
          print('🔥 [REMOTE_LOAD] ($i) 에러: $e');
        }
      }

      print('🚀 [TOTAL_READY] 총 ${allPhotoBytes.length}장의 사진 데이터 준비 완료');

      // --- 스탬프 로직 ---
      isStampDeducted = await _stampService.useStamp(_userId, stampType);
      if (!isStampDeducted) {
        print('⚠️ [STAMP] 스탬프 부족');
        if (mounted) setState(() => _loading = false);
        _showCoinEmptyDialog();
        return;
      }
      await _refreshStampCounts();
      await _loadDailyUsage();

      final gemini = GeminiService();

      // 🤖 AI 작업 정의
      Future<void> runAiTask() async {
        print('🤖 [GEMINI] summary 요청 시작...');
        final summary = await gemini.generateSummary(
          diaryText: _contentController.text,
          location: widget.placeName,
          photoBytes: allPhotoBytes,
          languageCode: _languageCode,
        );
        _summaryText = summary;
        print('✅ [GEMINI] 요약 완료');

        print('🤖 [GEMINI] image 요청 시작...');
        final image = await gemini.generateImage(
          summary: summary,
          stylePrompt: _selectedStyle!.prompt,
          languageCode: _languageCode,
        );
        if (image == null) throw Exception("Image generation failed");
        _generatedImage = image;
        print('✅ [GEMINI] 이미지 생성 완료');
      }

      if (stampType == 'daily') {
        await Future.wait([_playAdParallel(), runAiTask()]);
      } else {
        await runAiTask();
      }

      if (mounted) setState(() => _loading = false);
    } catch (e) {
      print('🔥 [CRITICAL_ERROR] $e');

      // 1️⃣ 스탬프 복구 (기존 로직 유지)
      if (isStampDeducted) await _stampService.addFreeStamp(_userId, 1);

      if (mounted) {
        setState(() => _loading = false);

        // 2️⃣ 에러 메시지 가공
        // 'Exception: '이라는 지저분한 문구를 지우고 알맹이만 추출합니다.
        String errorMessage = e.toString().replaceAll('Exception: ', '');

        // 만약 메시지가 너무 길거나 비어있을 경우를 대비한 방어 로직
        if (errorMessage.isEmpty || errorMessage.contains('Instance of')) {
          errorMessage = generationFailedMessage;
        }

        // 3️⃣ 사용자에게 토스트로 노출
        // 이제 "The content or photos may be difficult..." 문구가 직접 뜹니다.
        AppToast.show(context, errorMessage);
      }
    }
  }

  // ✅ [수정] 광고가 죽어도 AI 생성은 계속되도록 타임아웃 추가
  Future<void> _playAdParallel() async {
    final completer = Completer<void>();

    // 광고가 응답이 없을 경우를 대비해 30초 후 강제 완료
    Timer(const Duration(seconds: 30), () {
      if (!completer.isCompleted) {
        _logger.warn("⏰ 광고 응답 타임아웃 - 프로세스 강제 진행", tag: "AD_PROCESS");
        completer.complete();
      }
    });

    if (_rewardedAd != null && _isAdLoaded) {
      _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _loadAds();
          if (!completer.isCompleted) completer.complete();
        },
        onAdFailedToShowFullScreenContent: (ad, err) {
          _logger.error("❌ 광고 표시 실패: $err", tag: "AD_PROCESS");
          ad.dispose();
          _loadAds();
          if (!completer.isCompleted) completer.complete();
        },
      );

      _rewardedAd!.show(
        onUserEarnedReward: (_, reward) {
          _logger.log("🎁 광고 보상 획득 완료", tag: "AD_PROCESS");
        },
      );
    } else {
      _logger.warn("⚠️ 광고 미로드 상태", tag: "AD_PROCESS");
      if (!completer.isCompleted) completer.complete();
    }

    return completer.future;
  }

  // ✅ [수정 완료] 기존 알럿 없이 바로 바텀 시트를 띄웁니다.
  void _showCoinEmptyDialog() async {
    // 1. 코인 상점 바텀시트 즉시 호출
    bool? purchased = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true, // 높이 조절(85%)을 위해 true 설정
      backgroundColor: Colors.transparent, // 배경 투명 처리
      builder: (context) => const CoinPaywallBottomSheet(),
    );

    // 2. 구매 성공 혹은 광고 보상 획득 시(true 반환) 개수 새로고침
    if (purchased == true) {
      await _refreshStampCounts();
      // (선택사항) 필요하다면 여기서 다시 생성 로직을 자동으로 호출할 수도 있습니다.
      // _handleGenerateWithStamp();
    }
  }

  Future<void> _saveDiary() async {
    if (_generatedImage == null &&
        _imageUrl == null &&
        _contentController.text.trim().isEmpty)
      return;

    // ✅ setState 밖에서 미리 추출
    final String savingMessage = "saving_diary".tr();
    final String saveFailedMessage = 'save_failed'.tr();

    setState(() {
      _loading = true;
      _loadingMessage = savingMessage; // ✅ 미리 추출한 값 사용
    });

    try {
      final int currentDayIndex = DateUtilsHelper.calculateDayNumber(
        startDate: widget.startDate,
        currentDate: widget.date,
      );

      // 🎯 [핵심] 아까 저장해둔 고유 ID를 upsertDiary에 전달!
      final diaryData = await TravelDayService.upsertDiary(
        travelId: _cleanTravelId,
        dayIndex: currentDayIndex,
        date: widget.date,
        text: _contentController.text.trim(),
        aiSummary: _summaryText ?? widget.initialDiary?['ai_summary'],
        aiStyle: _selectedStyle?.id ?? _existingAiStyleId ?? 'default',
        existingId: _currentDiaryId, // 👈 이거 없어서 에러 났던 거야 형!
        skipDateUpdate: widget.isReordering,
      );

      final String diaryId = diaryData['id'].toString().replaceAll(
        RegExp(r'[\s\n\r\t]+'),
        '',
      );

      // ✅ 물리적 파일 삭제 로직
      try {
        final oldData = await Supabase.instance.client
            .from('travel_days')
            .select('photo_urls')
            .eq('id', diaryId)
            .maybeSingle();

        if (oldData != null && oldData['photo_urls'] != null) {
          final List<String> oldUrls = List<String>.from(oldData['photo_urls']);
          final List<String> toDelete = oldUrls
              .where((url) => !_remotePhotoUrls.contains(url))
              .toList();

          if (toDelete.isNotEmpty) {
            final storage = Supabase.instance.client.storage.from(
              'travel_images',
            );

            final List<String> pathsToDelete = toDelete.map((url) {
              final uri = Uri.parse(url);
              final segments = uri.pathSegments;
              final int bucketIndex = segments.indexOf('travel_images');
              return segments.skip(bucketIndex + 1).join('/');
            }).toList();

            await storage.remove(pathsToDelete);
            _logger.log(
              "🗑️ 스토리지 물리 파일 삭제 완료: $pathsToDelete",
              tag: "STORAGE_CLEANUP",
            );
          }
        }
      } catch (e) {
        _logger.error(
          "⚠️ 스토리지 정리 중 오류 발생 (무시하고 저장 진행): $e",
          tag: "STORAGE_CLEANUP",
        );
      }

      List<String> newlyUploadedUrls = [];

      if (_localPhotos.isNotEmpty) {
        final storage = Supabase.instance.client.storage.from('travel_images');
        for (int i = 0; i < _localPhotos.length; i++) {
          final targetPath =
              '${(await getTemporaryDirectory()).path}/${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
          final result = await FlutterImageCompress.compressAndGetFile(
            _localPhotos[i].absolute.path,
            targetPath,
            quality: 80,
            minWidth: 800,
            minHeight: 800,
          );
          final String fullPath =
              'users/$_userId/travels/$_cleanTravelId/diaries/$diaryId/moments/moment_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
          await storage.upload(fullPath, File(result!.path));
          newlyUploadedUrls.add(storage.getPublicUrl(fullPath));
        }
      }

      await _updatePhotoUrls(diaryId, newlyUploadedUrls);

      if (_generatedImage != null) {
        final tempDir = await getTemporaryDirectory();
        final tempPath =
            '${tempDir.path}/temp_ai_${DateTime.now().millisecondsSinceEpoch}.png';

        final tempFile = File(tempPath);
        await tempFile.writeAsBytes(_generatedImage!);

        final compressedPath =
            '${tempDir.path}/compressed_ai_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final compressedFile = await FlutterImageCompress.compressAndGetFile(
          tempPath,
          compressedPath,
          quality: 70,
          minWidth: 1024,
          minHeight: 1024,
          format: CompressFormat.jpeg,
        );

        if (compressedFile != null) {
          final compressedBytes = await File(compressedFile.path).readAsBytes();
          await ImageUploadService.uploadAiImage(
            path:
                'users/$_userId/travels/$_cleanTravelId/diaries/$diaryId/ai_generated.jpg',
            imageBytes: compressedBytes,
          );

          await tempFile.delete();
          await File(compressedFile.path).delete();
        }
      }

      if (mounted) {
        setState(() => _loading = false);

        final writtenDays = await TravelDayService.getWrittenDayCount(
          travelId: _cleanTravelId,
        );

        if (!mounted) return;

        final totalDays =
            widget.endDate.difference(widget.startDate).inDays + 1;

        if (writtenDays >= totalDays) {
          // ✅ _languageCode 변수 사용
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
                  languageCode: _languageCode, // ✅ 클래스 변수 사용
                ),
              ),
            ),
          );
        } else {
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      _logger.error("🔥 저장 중 에러: $e", tag: "SAVE_PROCESS");
      if (mounted) {
        setState(() => _loading = false);
        AppToast.show(context, saveFailedMessage); // ✅ 미리 추출한 값 사용
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _updatePhotoUrls(String diaryId, List<String> newUrls) async {
    try {
      // 1. 화면에 남아있는 기존 사진(리모트) + 새로 업로드된 사진 합치기
      final List<String> finalUrls = [..._remotePhotoUrls, ...newUrls];

      _logger.log(
        "📸 사진 리스트 동기화 시도 (총 ${finalUrls.length}장)",
        tag: "SAVE_PROCESS",
      );

      // 2. travel_days 테이블의 photo_urls 컬럼을 통째로 업데이트 (덮어쓰기)
      await Supabase.instance.client
          .from('travel_days')
          .update({'photo_urls': finalUrls})
          .eq('id', diaryId);

      _logger.log("✅ 사진 리스트 DB 반영 완료", tag: "SAVE_PROCESS");
    } catch (e) {
      _logger.error("🔥 _updatePhotoUrls 에러: $e", tag: "SAVE_PROCESS");
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
                      margin: const EdgeInsets.only(top: 22),
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
                      child: Align(
                        alignment: const Alignment(0, 0.2), // ✅ 살짝 아래로
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.grey.withOpacity(0.25),
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

                  const SizedBox(height: 5),
                  _buildDiaryInput(),
                  const SizedBox(height: 17),
                  _buildSectionTitle(
                    'assets/icons/ico_camera.png',
                    _todaysMomentsText, // ✅ 변수 사용
                    _maxPhotosText, // ✅ 변수 사용
                  ),
                  const SizedBox(height: 7),
                  _buildPhotoList(),
                  const SizedBox(height: 18),
                  _buildSectionTitle(
                    'assets/icons/ico_palette.png',
                    _drawingStyleText, // ✅ 변수 사용
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
    AppDialogs.showImagePreview(
      context: context,
      imageUrl: _imageUrl,
      imageBytes: _generatedImage,
      isSharing: _isSharing,
      onShare: (setPopupState) async {
        // 🎯 다이얼로그 내부 로딩 UI 업데이트
        setPopupState(() {});

        // 실제 공유 로직 실행
        await _shareDiaryImage(context);

        // 완료 후 다시 UI 업데이트
        setPopupState(() {});
      },
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
              _freeStampText,
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
              _paidStampText,
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
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: textColor,
              height: 1.15,
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
        autofocus: false, // 🎯 [추가] 페이지 로드시 자동으로 키보드 뜨는 것 방지
        style: const TextStyle(
          fontSize: 13,
          height: 1.2,
          color: Color(0xFF2B2B2B),
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: _diaryHintText,
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
      onTap: _loading ? null : _handleGenerateWithStamp, // ✅ 로직 연결 완료
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
            _generateImageButtonText,
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
                    _saveDiaryButtonText,
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
              _loadingMessage,
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
