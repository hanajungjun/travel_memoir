import 'dart:io';
import 'dart:async';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:travel_memoir/services/gemini_service.dart';
import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/shared/styles/text_styles.dart';
import 'package:travel_memoir/features/shop/page/shop_page.dart';
import 'package:travel_memoir/core/widgets/popup/app_toast.dart';
import 'package:travel_memoir/core/widgets/popup/app_dialogs.dart';

// ✅ 스티커 위치 정보 모델
class StickerPlacement {
  final String url;
  final double? top, bottom, left, right;
  final double angle;
  StickerPlacement({
    required this.url,
    this.top,
    this.bottom,
    this.left,
    this.right,
    required this.angle,
  });
}

// ✅ 앨범 아이템 모델
class _AlbumItem {
  final DateTime date;
  final String imageUrl;
  final bool isAi;
  final String? diaryText;
  _AlbumItem({
    required this.date,
    required this.imageUrl,
    this.isAi = false,
    this.diaryText,
  });
}

class TravelAlbumPage extends StatefulWidget {
  final Map<String, dynamic> travel;
  const TravelAlbumPage({super.key, required this.travel});

  @override
  State<TravelAlbumPage> createState() => _TravelAlbumPageState();
}

class _TravelAlbumPageState extends State<TravelAlbumPage> with RouteAware {
  late Future<Map<int, List<_AlbumItem>>> _groupedFuture;
  Uint8List? _premiumInfographic;
  String? _premiumImageUrl;
  bool _isPremiumLoading = false;
  bool _isPremiumUser = false;
  bool _isVipUser = false;
  bool _showStickers = false;
  bool _includePhotos = true;
  int _remainingCount = 0;

  List<StickerPlacement> _stickerPlacements = [];
  late SharedPreferences _prefs;

  @override
  void initState() {
    super.initState();
    _groupedFuture = _loadGroupedAlbum();
    _initSettings();
  }

  Future<void> _initSettings() async {
    _prefs = await SharedPreferences.getInstance();
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;

    final userRes = await client
        .from('users')
        .select('is_premium, is_vip')
        .eq('auth_uid', userId)
        .maybeSingle();
    if (mounted) {
      setState(() {
        _isPremiumUser = userRes?['is_premium'] ?? false;
        _isVipUser = userRes?['is_vip'] ?? false;
      });
    }

    final travelId = widget.travel['id']?.toString() ?? '';
    int maxLimit = _isVipUser ? 5 : 3;
    int usedCount = _prefs.getInt('infographic_count_$travelId') ?? 0;

    setState(() {
      _remainingCount = math.max(0, maxLimit - usedCount);
      _includePhotos = _prefs.getBool('include_photos_option') ?? true;
      _showStickers = _includePhotos;
    });

    final groupedData = await _groupedFuture;
    //_extractAndShuffleStickers(groupedData);

    final res = await client
        .from('travels')
        .select('premium_report_url')
        .eq('id', travelId)
        .maybeSingle();

    if (res != null &&
        res['premium_report_url'] != null &&
        res['premium_report_url'].toString().isNotEmpty) {
      setState(() {
        String url = res['premium_report_url'];
        _premiumImageUrl = '$url?t=${DateTime.now().millisecondsSinceEpoch}';
        if (_includePhotos) {
          Future.delayed(const Duration(milliseconds: 800), () {
            if (mounted) setState(() => _showStickers = true);
          });
        }
      });
    }
  }

  void _extractAndShuffleStickers(Map<int, List<_AlbumItem>> data) {
    List<String> allPhotoUrls = [];
    data.forEach((day, items) {
      for (var item in items) {
        if (!item.isAi && item.imageUrl.isNotEmpty)
          allPhotoUrls.add(item.imageUrl);
      }
    });

    if (allPhotoUrls.isEmpty) return;

    List<Map<String, double>> positions = [
      {'top': 20, 'left': 10, 'angle': -0.15},
      {'top': 30, 'right': 10, 'angle': 0.18},
      {'bottom': 15, 'left': 12, 'angle': -0.1},
      {'bottom': 25, 'right': 12, 'angle': 0.14},
    ];
    positions.shuffle();

    List<StickerPlacement> tempPlacements = [];
    int takeCount = math.min(allPhotoUrls.length, math.Random().nextInt(4) + 1);
    allPhotoUrls.shuffle();

    for (int i = 0; i < takeCount; i++) {
      final pos = positions[i];
      tempPlacements.add(
        StickerPlacement(
          url: allPhotoUrls[i],
          top: pos['top'],
          bottom: pos['bottom'],
          left: pos['left'],
          right: pos['right'],
          angle: pos['angle']!,
        ),
      );
    }
    setState(() => _stickerPlacements = tempPlacements);
  }

  Future<void> _generateAndSavePremiumInfographic(
    Map<int, List<_AlbumItem>> data,
  ) async {
    if (!_isPremiumUser && !_isVipUser) {
      _showPremiumRequiredDialog();
      return;
    }

    if (_remainingCount <= 0) {
      AppToast.error(context, 'infographic_limit_reached'.tr());
      return;
    }

    if (_isPremiumLoading) return;
    setState(() {
      _isPremiumLoading = true;
      _showStickers = false;
    });

    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();

    final client = Supabase.instance.client;
    final userId = client.auth.currentUser!.id;
    final travelId = widget.travel['id']?.toString() ?? '';

    try {
      final List<String> allTexts = [];
      data.forEach((day, items) {
        if (items.isNotEmpty && items.first.diaryText != null) {
          if (!allTexts.contains(items.first.diaryText))
            allTexts.add(items.first.diaryText!);
        }
      });

      // 🎯 인포그래픽 전용: "Trip to"가 빠진 순수 장소명 로직
      final bool isKo = context.locale.languageCode == 'ko';
      final String type = widget.travel['travel_type'] ?? 'domestic';
      String purePlace = "";

      if (type == 'usa') {
        // 🇺🇸 USA: region_name(예: New York) 우선
        purePlace = widget.travel['region_name'] ?? "USA";
      } else if (type == 'overseas') {
        // 🌏 해외: region_name 우선, 없으면 국가명
        purePlace =
            widget.travel['region_name'] ??
            (isKo
                ? widget.travel['country_name_ko']
                : widget.travel['country_name_en']) ??
            widget.travel['display_country_name'] ??
            "TRAVEL";
      } else {
        // 🏠 국내: 제주, 서울 등 지역명 우선
        purePlace =
            widget.travel['region_name'] ?? widget.travel['city'] ?? "KOREA";
      }

      // 중복 호출 방지를 위해 스티커 추출은 여기서 한 번만
      _extractAndShuffleStickers(data);

      final imageBytes = await GeminiService().generateFullTravelInfographic(
        allDiaryTexts: allTexts,
        getPlaceName: purePlace.toUpperCase(),
        travelType: widget.travel['travel_type'] ?? 'domestic',
        photoUrls: _includePhotos
            ? _stickerPlacements.map((e) => e.url).toList()
            : null,
      );

      final String storagePath =
          'users/$userId/travels/$travelId/premium_report.png';
      await client.storage
          .from('travel_images')
          .uploadBinary(
            storagePath,
            imageBytes,
            fileOptions: const FileOptions(upsert: true),
          );
      final String baseUrl = client.storage
          .from('travel_images')
          .getPublicUrl(storagePath);
      await client
          .from('travels')
          .update({'premium_report_url': baseUrl})
          .eq('id', travelId);

      int maxLimit = _isVipUser ? 5 : 3;
      setState(() {
        _remainingCount--;
      });
      await _prefs.setInt(
        'infographic_count_$travelId',
        maxLimit - _remainingCount,
      );

      if (mounted) {
        setState(() {
          _premiumInfographic = imageBytes;
          _premiumImageUrl =
              '$baseUrl?t=${DateTime.now().millisecondsSinceEpoch}';
          _isPremiumLoading = false;
          _showStickers = _includePhotos;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isPremiumLoading = false);
        AppToast.error(context, 'generating_infographic_failed'.tr());
      }
    }
  }

  void _showPremiumRequiredDialog() {
    AppDialogs.showAction(
      context: context,
      title: 'premium_only_title'.tr(),
      message: 'premium_infographic_desc'.tr(),
      actionLabel: 'go_to_shop'.tr(),
      actionColor: Colors.amber,
      onAction: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ShopPage()),
        ).then((_) => _initSettings());
      },
    );
  }

  int _getDayNum(DateTime start, DateTime target) {
    return DateTime(
          target.year,
          target.month,
          target.day,
        ).difference(DateTime(start.year, start.month, start.day)).inDays +
        1;
  }

  Future<Map<int, List<_AlbumItem>>> _loadGroupedAlbum() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return {};
    final travelId = widget.travel['id']?.toString() ?? '';
    final userId = user.id.replaceAll(RegExp(r'[\s\n\r\t]+'), '');
    final startDate = DateTime.parse(widget.travel['start_date']);
    final endDate = DateTime.parse(widget.travel['end_date']);
    final totalDays = endDate.difference(startDate).inDays + 1;
    Map<int, List<_AlbumItem>> grouped = {
      for (int i = 1; i <= totalDays; i++) i: [],
    };
    try {
      final List<dynamic> diaries = await client
          .from('travel_days')
          .select('id, date, text, ai_summary')
          .eq('travel_id', travelId);
      for (var diary in diaries) {
        final String diaryId = diary['id'].toString().replaceAll(
          RegExp(r'[\s\n\r\t]+'),
          '',
        );
        final DateTime diaryDate = DateTime.parse(diary['date']);
        final int dayNum = _getDayNum(startDate, diaryDate);
        if (dayNum < 1 || dayNum > totalDays) continue;
        if ((diary['ai_summary'] ?? '').toString().trim().isNotEmpty) {
          grouped[dayNum]!.add(
            _AlbumItem(
              date: diaryDate,
              imageUrl: client.storage
                  .from('travel_images')
                  .getPublicUrl(
                    'users/$userId/travels/$travelId/diaries/$diaryId/ai_generated.jpg',
                  ),
              isAi: true,
              diaryText: diary['text'],
            ),
          );
        }
        final List<FileObject> momentFiles = await client.storage
            .from('travel_images')
            .list(
              path: 'users/$userId/travels/$travelId/diaries/$diaryId/moments',
            );
        for (var f in momentFiles.where((e) => !e.name.startsWith('.'))) {
          grouped[dayNum]!.add(
            _AlbumItem(
              date: diaryDate,
              imageUrl: client.storage
                  .from('travel_images')
                  .getPublicUrl(
                    'users/$userId/travels/$travelId/diaries/$diaryId/moments/${f.name}',
                  ),
              isAi: false,
              diaryText: diary['text'],
            ),
          );
        }
      }
      grouped.forEach((key, list) => list.sort((a, b) => a.isAi ? 1 : -1));
      return grouped;
    } catch (e) {
      return grouped;
    }
  }

  String _travelTitle() {
    // 1️⃣ 사용자가 직접 입력한 제목이 있으면 최우선 사용
    String title = (widget.travel['title'] ?? '').toString();
    if (title.isNotEmpty) return title.trim();

    final bool isKo = context.locale.languageCode == 'ko';
    final String type = widget.travel['travel_type'] ?? 'domestic';
    String? place;

    // 2️⃣ [개선된 로직] 언어/타입별 장소명 추출
    if (type == 'usa') {
      // 🇺🇸 미국: 'United States'가 나오는 것을 방지하기 위해 region_name을 최우선으로 사용
      place = widget.travel['region_name'] ?? 'USA';
    } else if (isKo) {
      // 🇰🇷 한국어 설정일 때
      place = (type == 'domestic')
          ? (widget.travel['region_name'] ?? widget.travel['city'])
          : (widget.travel['country_name_ko'] ??
                widget.travel['display_country_name']);
    } else {
      // 🇺🇸 영어 설정일 때
      if (type == 'domestic') {
        // 🏠 국내 여행 영어 버전: region_key의 마지막 값 추출 (예: KOR_JEJU -> JEJU)
        final String regKey = widget.travel['region_key']?.toString() ?? '';
        place = regKey.contains('_') ? regKey.split('_').last : 'KOREA';
      } else {
        // 🌏 기타 해외 여행
        place =
            widget.travel['display_country_name'] ??
            widget.travel['country_name_en'] ??
            widget.travel['country_code'] ??
            'TRAVEL';
      }
    }

    // 3️⃣ 번역 키 적용 및 최종 조립
    final String finalPlace = place?.trim() ?? (isKo ? '여행' : 'TRAVEL');

    // 'trip_with_place' 키가 정상 작동한다고 가정 (args 전달)
    String formattedTitle = 'trip_with_place'.tr(
      args: [isKo ? finalPlace : finalPlace.toUpperCase()],
    );

    // 🎯 [핵심 방어 로직] 번역 템플릿 실패 시 강제로 "Trip to [PLACE]" 형태 생성
    if (formattedTitle == finalPlace ||
        formattedTitle == finalPlace.toUpperCase()) {
      formattedTitle = isKo
          ? "$finalPlace 여행"
          : "Trip to ${finalPlace.toUpperCase()}";
    }

    return formattedTitle.trim();
  }

  // ==========================================
  // 🎯 [핵심 수정] 프리미엄 카드 컨테이너 로직
  // ==========================================
  Widget _buildPremiumCardContainer(Map<int, List<_AlbumItem>> groupedData) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      child: _isPremiumLoading
          ? _buildLoadingState() // 🎯 누락되었던 로딩 함수 호출
          : (!_isPremiumUser && !_isVipUser)
          ? _buildPremiumCard() // 🎯 일반 유저는 데이터 상관없이 업그레이드 카드 노출
          : (_premiumImageUrl == null && _premiumInfographic == null)
          ? Container(
              key: const ValueKey('no_image'),
              height: 100,
              child: Center(child: Text('no_infographic_yet'.tr())),
            )
          : _buildPremiumCard(), // 프리미엄 유저 + 데이터 있음
    );
  }

  // ==========================================
  // 🎯 [신규] 누락되었던 로딩 위젯 함수
  // ==========================================
  Widget _buildLoadingState() {
    return AspectRatio(
      key: const ValueKey('loading'),
      aspectRatio: 0.9,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Colors.amber),
            const SizedBox(height: 16),
            Text('generating_infographic'.tr(), style: AppTextStyles.bodyMuted),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumCard() {
    final bool hasImage =
        _premiumInfographic != null || _premiumImageUrl != null;

    return AspectRatio(
      aspectRatio: 0.9,
      child: GestureDetector(
        onTap: () {
          if (_isPremiumUser || _isVipUser) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => _PremiumViewerPage(
                  title: _travelTitle(),
                  imageBytes: _premiumInfographic,
                  imageUrl: _premiumImageUrl,
                  stickers: _stickerPlacements,
                  isPremiumUser: _isPremiumUser || _isVipUser,
                  showStickers: _showStickers,
                ),
              ),
            );
          } else {
            _showPremiumRequiredDialog();
          }
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100], // 데이터 없을 때의 배경색
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: hasImage
                      ? (_premiumInfographic != null
                            ? Image.memory(
                                _premiumInfographic!,
                                fit: BoxFit.cover,
                              )
                            : Image.network(
                                _premiumImageUrl!,
                                fit: BoxFit.cover,
                              ))
                      : const SizedBox.shrink(),
                ),
              ),
            ),
            if (hasImage)
              Positioned(
                top: 20,
                left: 20,
                right: 20,
                child: Builder(
                  builder: (context) {
                    final String type =
                        widget.travel['travel_type'] ?? 'domestic';
                    final bool isKo = context.locale.languageCode == 'ko';
                    String purePlace = "";

                    if (type == 'usa') {
                      // 🇺🇸 미국: United States 대신 지역명 우선 표시
                      purePlace = widget.travel['region_name'] ?? "USA";
                    } else if (type == 'overseas') {
                      purePlace =
                          widget.travel['region_name'] ??
                          (isKo
                              ? widget.travel['country_name_ko']
                              : widget.travel['country_name_en']) ??
                          "TRAVEL";
                    } else {
                      // 국내 여행 로직 (이전 수정안 반영)
                      if (!isKo) {
                        final String? regKey = widget.travel['region_key'];
                        purePlace = (regKey != null && regKey.contains('_'))
                            ? regKey.split('_').last
                            : (widget.travel['region_name'] ?? "KOREA");
                      } else {
                        purePlace =
                            widget.travel['region_name'] ??
                            widget.travel['city'] ??
                            "한국";
                      }
                    }

                    return Text(
                      purePlace.toUpperCase(), // 🎯 "Trip to" 없이 장소명만 대문자로 표시
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            offset: const Offset(0, 2),
                            blurRadius: 10.0,
                            color: Colors.black.withOpacity(0.6),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            if (!_isPremiumUser && !_isVipUser)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.lock_rounded,
                          color: Colors.white,
                          size: 48,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'premium_unlock_label'.tr(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            for (var sticker in _stickerPlacements)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutBack,
                top: _showStickers
                    ? sticker.top
                    : (sticker.top != null ? sticker.top! + 15 : null),
                bottom: _showStickers
                    ? sticker.bottom
                    : (sticker.bottom != null ? sticker.bottom! + 15 : null),
                left: sticker.left,
                right: sticker.right,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 500),
                  opacity: _showStickers ? 1.0 : 0.0,
                  child: Transform.rotate(
                    angle: sticker.angle,
                    child: _buildStickerFrame(sticker.url),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStickerFrame(String url) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(2, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: Image.network(url, width: 95, height: 95, fit: BoxFit.cover),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final overallSummary = (widget.travel['ai_cover_summary'] ?? '').toString();
    final startDate = DateTime.parse(widget.travel['start_date']);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_travelTitle(), style: AppTextStyles.pageTitle),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: FutureBuilder<Map<int, List<_AlbumItem>>>(
        future: _groupedFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done)
            return const Center(child: CircularProgressIndicator());
          final groupedData = snapshot.data ?? {};
          return CustomScrollView(
            slivers: [
              if (overallSummary.isNotEmpty)
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      overallSummary,
                      style: AppTextStyles.body.copyWith(
                        fontSize: 15,
                        height: 1.6,
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              for (var entry in groupedData.entries) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                    child: Row(
                      children: [
                        Text(
                          '${'day_label'.tr()} ${entry.key.toString().padLeft(2, '0')}',
                          style: AppTextStyles.sectionTitle,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat('yyyy.MM.dd').format(
                            startDate.add(Duration(days: entry.key - 1)),
                          ),
                          style: AppTextStyles.bodyMuted,
                        ),
                      ],
                    ),
                  ),
                ),
                if (entry.value.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 10,
                      ),
                      child: Text(
                        'no_photos_this_day'.tr(),
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                          ),
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final item = entry.value[index];
                        return GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => _AlbumViewerPage(
                                title: _travelTitle(),
                                items: groupedData.values
                                    .expand((e) => e)
                                    .toList(),
                                initialIndex: groupedData.values
                                    .expand((e) => e)
                                    .toList()
                                    .indexOf(item),
                                isPremiumUser: _isPremiumUser || _isVipUser,
                              ),
                            ),
                          ),
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    item.imageUrl,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              if (item.isAi)
                                const Positioned(
                                  top: 5,
                                  right: 5,
                                  child: Icon(
                                    Icons.auto_awesome,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                            ],
                          ),
                        );
                      }, childCount: entry.value.length),
                    ),
                  ),
              ],
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Divider(thickness: 2, indent: 50, endIndent: 50),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.stars,
                            color: Colors.amber,
                            size: 20,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'premium_infographic_title'.tr().toUpperCase(),
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.amber[800],
                              ),
                            ),
                          ),
                          if (_isPremiumUser || _isVipUser) ...[
                            const SizedBox(width: 4),
                            /*
                            SizedBox(
                              width: 24,
                              child: Checkbox(
                                value: _showStickers,
                                activeColor: Colors.amber,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                onChanged: (val) {
                                  final newValue = val ?? false;
                                  setState(() {
                                    _showStickers = newValue;
                                    _includePhotos = newValue;
                                    _prefs.setBool(
                                      'include_photos_option',
                                      newValue,
                                    );
                                    if (_showStickers &&
                                        _stickerPlacements.isEmpty)
                                      _extractAndShuffleStickers(groupedData);
                                  });
                                },
                              ),
                            ),
                            Text(
                              'include_photos'.tr(),
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[700],
                              ),
                            ),
                            */
                            const SizedBox(width: 4),
                            Flexible(
                              child: TextButton(
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed: () =>
                                    _generateAndSavePremiumInfographic(
                                      groupedData,
                                    ),
                                child: FittedBox(
                                  child: Text(
                                    'generate_with_count'.tr(
                                      args: [_remainingCount.toString()],
                                    ),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 25),
                      _buildPremiumCardContainer(groupedData),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// (이하 _AlbumViewerPage 및 _PremiumViewerPage 로직은 준님의 원본과 동일하게 유지 - 생략 없이 포함)

class _AlbumViewerPage extends StatefulWidget {
  final String title;
  final List<_AlbumItem> items;
  final int initialIndex;
  final bool isPremiumUser;
  const _AlbumViewerPage({
    required this.title,
    required this.items,
    required this.initialIndex,
    required this.isPremiumUser,
  });
  @override
  State<_AlbumViewerPage> createState() => _AlbumViewerPageState();
}

class _AlbumViewerPageState extends State<_AlbumViewerPage> {
  late final PageController _controller;
  late int _index;
  bool _isSharing = false;
  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _controller = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'album_index'.tr(
            args: [(_index + 1).toString(), widget.items.length.toString()],
          ),
        ),
        actions: [
          Builder(
            builder: (ctx) => IconButton(
              icon: _isSharing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.ios_share),
              onPressed: () async {
                setState(() => _isSharing = true);
                try {
                  final res = await http.get(
                    Uri.parse(widget.items[_index].imageUrl),
                  );
                  Uint8List imageBytes = res.bodyBytes;
                  if (!widget.isPremiumUser) {
                    final ByteData watermarkData = await rootBundle.load(
                      'assets/images/watermark.png',
                    );
                    final Uint8List watermarkBytes = watermarkData.buffer
                        .asUint8List();
                    img.Image? originalImg = img.decodeImage(imageBytes);
                    img.Image? watermarkImg = img.decodeImage(watermarkBytes);
                    if (originalImg != null && watermarkImg != null) {
                      int targetWidth = (originalImg.width * 0.15).toInt();
                      img.Image resizedWatermark = img.copyResize(
                        watermarkImg,
                        width: targetWidth,
                      );
                      for (var pixel in resizedWatermark) {
                        pixel.a = pixel.a * 0.5;
                      }
                      int x = originalImg.width - resizedWatermark.width - 20;
                      int y = originalImg.height - resizedWatermark.height - 20;
                      img.compositeImage(
                        originalImg,
                        resizedWatermark,
                        dstX: x,
                        dstY: y,
                      );
                      imageBytes = Uint8List.fromList(
                        img.encodePng(originalImg),
                      );
                    }
                  }
                  final temp = await getTemporaryDirectory();
                  final file = await File('${temp.path}/share.png').create();
                  await file.writeAsBytes(imageBytes);
                  final box = ctx.findRenderObject() as RenderBox?;
                  await Share.shareXFiles(
                    [XFile(file.path)],
                    sharePositionOrigin: box != null
                        ? box.localToGlobal(Offset.zero) & box.size
                        : null,
                  );
                } catch (e) {
                  AppToast.error(context, 'share_failed'.tr());
                }
                setState(() => _isSharing = false);
              },
            ),
          ),
        ],
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.items.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (_, i) => GestureDetector(
          onTap: () => Navigator.pop(context),
          behavior: HitTestBehavior.opaque,
          child: InteractiveViewer(
            child: Center(child: Image.network(widget.items[i].imageUrl)),
          ),
        ),
      ),
    );
  }
}

class _PremiumViewerPage extends StatefulWidget {
  final String title;
  final Uint8List? imageBytes;
  final String? imageUrl;
  final List<StickerPlacement> stickers;
  final bool isPremiumUser;
  final bool showStickers;
  const _PremiumViewerPage({
    required this.title,
    this.imageBytes,
    this.imageUrl,
    this.stickers = const [],
    required this.isPremiumUser,
    required this.showStickers,
  });
  @override
  State<_PremiumViewerPage> createState() => _PremiumViewerPageState();
}

class _PremiumViewerPageState extends State<_PremiumViewerPage> {
  bool _isSharing = false;
  final GlobalKey _boundaryKey = GlobalKey();
  Future<void> _shareImage(BuildContext ctx) async {
    setState(() => _isSharing = true);
    try {
      RenderRepaintBoundary boundary =
          _boundaryKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      Uint8List pngBytes = byteData!.buffer.asUint8List();
      final temp = await getTemporaryDirectory();
      final file = await File('${temp.path}/premium_full_report.png').create();
      await file.writeAsBytes(pngBytes);
      final box = ctx.findRenderObject() as RenderBox?;
      await Share.shareXFiles(
        [XFile(file.path)],
        sharePositionOrigin: box != null
            ? box.localToGlobal(Offset.zero) & box.size
            : null,
      );
    } catch (e) {
      AppToast.error(context, 'share_failed'.tr());
    } finally {
      setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(widget.title),
        actions: [
          Builder(
            builder: (ctx) => IconButton(
              icon: _isSharing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.ios_share),
              onPressed: _isSharing ? null : () => _shareImage(ctx),
            ),
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => Navigator.pop(context),
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 3.0,
            child: Container(
              color: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
              child: RepaintBoundary(
                key: _boundaryKey,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    widget.imageBytes != null
                        ? Image.memory(widget.imageBytes!)
                        : Image.network(widget.imageUrl!),
                    Positioned(
                      top: 15,
                      left: 20,
                      right: 20,
                      child: Text(
                        widget.title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              offset: const Offset(0, 2),
                              blurRadius: 10.0,
                              color: Colors.black.withOpacity(0.6),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (widget.showStickers)
                      for (var sticker in widget.stickers)
                        Positioned(
                          top: sticker.top,
                          bottom: sticker.bottom,
                          left: sticker.left,
                          right: sticker.right,
                          child: Transform.rotate(
                            angle: sticker.angle,
                            child: _buildSticker(sticker.url),
                          ),
                        ),
                    if (!widget.isPremiumUser)
                      Positioned(
                        bottom: 10,
                        right: 10,
                        child: Image.asset(
                          'assets/images/watermark.png',
                          width: 100,
                          opacity: const AlwaysStoppedAnimation(0.8),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSticker(String url) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 12,
            offset: const Offset(2, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: Image.network(url, width: 95, height: 95, fit: BoxFit.cover),
      ),
    );
  }
}
