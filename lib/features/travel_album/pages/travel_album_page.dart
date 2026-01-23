import 'dart:io';
import 'dart:async';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'dart:math' as math; // ✅ 랜덤 배치를 위해 추가
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:travel_memoir/services/gemini_service.dart';
import 'package:travel_memoir/core/utils/date_utils.dart';
import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/shared/styles/text_styles.dart';

// ✅ 사진의 위치와 각도 정보를 담을 헬퍼 클래스
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

class _TravelAlbumPageState extends State<TravelAlbumPage> {
  late Future<Map<int, List<_AlbumItem>>> _groupedFuture;
  Uint8List? _premiumInfographic;
  String? _premiumImageUrl;
  bool _isPremiumLoading = false;

  // ✅ 변경: URL 리스트 대신 위치 정보가 포함된 스티커 리스트 사용
  List<StickerPlacement> _stickerPlacements = [];

  @override
  void initState() {
    super.initState();
    _groupedFuture = _loadGroupedAlbum();
    _initPremiumReport();
  }

  Future<void> _initPremiumReport() async {
    final client = Supabase.instance.client;
    final travelId = widget.travel['id']?.toString() ?? '';

    final groupedData = await _groupedFuture;
    _extractAndShuffleStickers(groupedData); // ✅ 랜덤 배치 로직 실행

    final res = await client
        .from('travels')
        .select('premium_report_url')
        .eq('id', travelId)
        .maybeSingle();

    if (res != null &&
        res['premium_report_url'] != null &&
        res['premium_report_url'].toString().isNotEmpty) {
      setState(() => _premiumImageUrl = res['premium_report_url']);
      return;
    }

    if (groupedData.values.any((l) => l.isNotEmpty)) {
      _generateAndSavePremiumInfographic(groupedData);
    }
  }

  // ✅ [핵심수정] 4방향 후보지 중 사진 개수만큼 랜덤하게 골라 배치
  void _extractAndShuffleStickers(Map<int, List<_AlbumItem>> data) {
    List<String> allPhotoUrls = [];
    data.forEach((day, items) {
      for (var item in items) {
        if (!item.isAi && item.imageUrl.isNotEmpty)
          allPhotoUrls.add(item.imageUrl);
      }
    });

    if (allPhotoUrls.isEmpty) return;

    // 1. 네 귀퉁이 후보지 설정 (안쪽으로 네모네모하게)
    List<Map<String, double>> positions = [
      {'top': 25, 'left': 25, 'angle': -0.1}, // 11시
      {'top': 25, 'right': 25, 'angle': 0.12}, // 1시
      {'bottom': 25, 'left': 25, 'angle': -0.08}, // 7시
      {'bottom': 25, 'right': 25, 'angle': 0.1}, // 5시
    ];

    // 2. 후보지를 무작위로 섞음
    positions.shuffle();

    // 3. 최대 4장까지 사진을 배정
    List<StickerPlacement> tempPlacements = [];
    int takeCount = math.min(allPhotoUrls.length, 4);

    // 사진도 랜덤하게 섞어서 뽑기 (중복 방지)
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
    if (_isPremiumLoading) return;
    setState(() => _isPremiumLoading = true);
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser!.id.replaceAll(
      RegExp(r'[\s\n\r\t]+'),
      '',
    );
    final travelId = widget.travel['id']?.toString() ?? '';

    try {
      final List<String> allTexts = [];
      data.forEach((day, items) {
        if (items.isNotEmpty && items.first.diaryText != null) {
          if (!allTexts.contains(items.first.diaryText))
            allTexts.add(items.first.diaryText!);
        }
      });

      final imageBytes = await GeminiService().generateFullTravelInfographic(
        travelTitle: _travelTitle(),
        allDiaryTexts: allTexts,
        photoUrls: _stickerPlacements.map((e) => e.url).toList(),
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
      final String publicUrl = client.storage
          .from('travel_images')
          .getPublicUrl(storagePath);
      await client
          .from('travels')
          .update({'premium_report_url': publicUrl})
          .eq('id', travelId);

      setState(() {
        _premiumInfographic = imageBytes;
        _premiumImageUrl = publicUrl;
        _isPremiumLoading = false;
      });
    } catch (e) {
      setState(() => _isPremiumLoading = false);
    }
  }

  // ... (getDayNum, loadGroupedAlbum, travelTitle 로직은 기존과 동일)
  int _getDayNum(DateTime start, DateTime target) {
    final s = DateTime(start.year, start.month, start.day);
    final t = DateTime(target.year, target.month, target.day);
    return t.difference(s).inDays + 1;
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
        final String text = diary['text'] ?? '';
        if (dayNum < 1 || dayNum > totalDays) continue;
        if ((diary['ai_summary'] ?? '').toString().trim().isNotEmpty) {
          grouped[dayNum]!.add(
            _AlbumItem(
              date: diaryDate,
              imageUrl: client.storage
                  .from('travel_images')
                  .getPublicUrl(
                    'users/$userId/travels/$travelId/diaries/$diaryId/ai_generated.png',
                  ),
              isAi: true,
              diaryText: text,
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
              diaryText: text,
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
    final isDomestic = widget.travel['travel_type'] == 'domestic';
    final place = isDomestic
        ? (widget.travel['region_name'] ?? widget.travel['city'])
        : (context.locale.languageCode == 'ko'
              ? widget.travel['country_name_ko']
              : widget.travel['country_name_en']);
    return (widget.travel['title'] ?? '').toString().isNotEmpty
        ? widget.travel['title']
        : 'trip_with_place'.tr(args: [place ?? 'overseas'.tr()]);
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
              // ... (Summary 및 Day 그리드 로직 동일)
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
                          'DAY ${entry.key.toString().padLeft(2, '0')}',
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
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.stars, color: Colors.amber),
                          const SizedBox(width: 8),
                          Text(
                            'PREMIUM INFOGRAPHIC',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber[800],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 25),
                      if (_isPremiumLoading)
                        const CircularProgressIndicator()
                      else if (_premiumImageUrl == null &&
                          _premiumInfographic == null)
                        ElevatedButton(
                          onPressed: () =>
                              _generateAndSavePremiumInfographic(groupedData),
                          child: const Text('인포그래픽 생성하기'),
                        )
                      else
                        _buildPremiumCard(),
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

  // ✅ [수정] 랜덤하게 정해진 스티커 리스트를 루프 돌려 화면에 표시
  Widget _buildPremiumCard() {
    if (_premiumInfographic == null &&
        (_premiumImageUrl == null || _premiumImageUrl!.isEmpty)) {
      return _buildEmptyPlaceholder();
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => _PremiumViewerPage(
              title: _travelTitle(),
              imageBytes: _premiumInfographic,
              imageUrl: _premiumImageUrl,
              stickers: _stickerPlacements,
            ),
          ),
        );
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: _premiumInfographic != null
                  ? Image.memory(_premiumInfographic!, fit: BoxFit.contain)
                  : Image.network(
                      _premiumImageUrl!,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.error),
                    ),
            ),
          ),
          // ✅ 랜덤하게 배정된 스티커들을 순회하며 표시
          for (var sticker in _stickerPlacements)
            Positioned(
              top: sticker.top,
              bottom: sticker.bottom,
              left: sticker.left,
              right: sticker.right,
              child: Transform.rotate(
                angle: sticker.angle,
                child: _buildStickerFrame(sticker.url),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyPlaceholder() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.auto_awesome,
            color: Colors.amber.withOpacity(0.5),
            size: 40,
          ),
          const SizedBox(height: 12),
          Text(
            '아직 인포그래픽이 없어요',
            style: AppTextStyles.sectionTitle.copyWith(color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Text(
            '여행 일기를 기록하면\nAI가 특별한 리포트를 만들어드려요!',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMuted.copyWith(fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildStickerFrame(String url) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(2, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.network(
          url,
          width: 85,
          height: 85,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              const Icon(Icons.broken_image),
        ),
      ),
    );
  }
}

// ... (AlbumViewerPage는 기존과 동일)
class _AlbumViewerPage extends StatefulWidget {
  final String title;
  final List<_AlbumItem> items;
  final int initialIndex;
  const _AlbumViewerPage({
    required this.title,
    required this.items,
    required this.initialIndex,
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
        title: Text('${_index + 1} / ${widget.items.length}'),
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
                final res = await http.get(
                  Uri.parse(widget.items[_index].imageUrl),
                );
                final temp = await getTemporaryDirectory();
                final file = await File('${temp.path}/share.png').create();
                await file.writeAsBytes(res.bodyBytes);
                final box = ctx.findRenderObject() as RenderBox?;
                await Share.shareXFiles(
                  [XFile(file.path)],
                  sharePositionOrigin: box != null
                      ? box.localToGlobal(Offset.zero) & box.size
                      : null,
                );
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
        itemBuilder: (_, i) => InteractiveViewer(
          child: Center(child: Image.network(widget.items[i].imageUrl)),
        ),
      ),
    );
  }
}

// ==========================================
// 4. 프리미엄 인포그래픽 전용 뷰어 (랜덤 배치 연동)
// ==========================================
class _PremiumViewerPage extends StatefulWidget {
  final String title;
  final Uint8List? imageBytes;
  final String? imageUrl;
  final List<StickerPlacement> stickers; // ✅ 연동

  const _PremiumViewerPage({
    required this.title,
    this.imageBytes,
    this.imageUrl,
    this.stickers = const [],
  }) : assert(imageBytes != null || imageUrl != null);

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
        text: '✨ 나만의 특별한 여행 리포트',
        sharePositionOrigin: box != null
            ? box.localToGlobal(Offset.zero) & box.size
            : null,
      );
    } catch (e) {
      debugPrint('프리미엄 공유 실패: $e');
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
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 3.0,
          child: RepaintBoundary(
            key: _boundaryKey,
            child: Container(
              color: Colors.black,
              padding: const EdgeInsets.all(40),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  widget.imageBytes != null
                      ? Image.memory(widget.imageBytes!)
                      : Image.network(widget.imageUrl!),
                  // ✅ 뷰어에서도 동일한 랜덤 위치에 스티커 표시
                  for (var sticker in widget.stickers)
                    Positioned(
                      top: sticker.top != null ? sticker.top! + 10 : null,
                      bottom: sticker.bottom != null
                          ? sticker.bottom! + 10
                          : null,
                      left: sticker.left != null ? sticker.left! + 10 : null,
                      right: sticker.right != null ? sticker.right! + 10 : null,
                      child: Transform.rotate(
                        angle: sticker.angle,
                        child: _buildSticker(sticker.url),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSticker(String url) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 10)],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: Image.network(
          url,
          width: 60,
          height: 60,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              const Icon(Icons.broken_image),
        ),
      ),
    );
  }
}
