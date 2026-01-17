import 'dart:io';
import 'dart:async';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart'; // ✅ 이거 없어서 에러 났던 겁니다! 추가 완료.
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:travel_memoir/core/utils/date_utils.dart';
import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/shared/styles/text_styles.dart';

// ==========================================
// 모델 클래스
// ==========================================
class _AlbumItem {
  final DateTime date;
  final String imageUrl;
  _AlbumItem({required this.date, required this.imageUrl});
}

class TravelAlbumPage extends StatefulWidget {
  final Map<String, dynamic> travel;
  const TravelAlbumPage({super.key, required this.travel});

  @override
  State<TravelAlbumPage> createState() => _TravelAlbumPageState();
}

class _TravelAlbumPageState extends State<TravelAlbumPage> {
  late Future<List<_AlbumItem>> _future;
  final GlobalKey _globalKey = GlobalKey(); // 이미지 캡처용 키
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _future = _loadAlbum();
  }

  Future<List<_AlbumItem>> _loadAlbum() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return [];

    final travelId = widget.travel['id']?.toString() ?? '';
    final userId = user.id;

    try {
      final files = await client.storage
          .from('travel_images')
          .list(path: 'users/$userId/travels/$travelId/days');

      if (files.isEmpty) return [];

      return files.where((f) => f.name.endsWith('.png')).map((f) {
        final dateStr = f.name.replaceAll('.png', '');
        final date = DateTime.tryParse(dateStr) ?? DateTime.now();
        final imageUrl = client.storage
            .from('travel_images')
            .getPublicUrl('users/$userId/travels/$travelId/days/${f.name}');

        return _AlbumItem(date: date, imageUrl: imageUrl);
      }).toList()..sort((a, b) => a.date.compareTo(b.date));
    } catch (e) {
      debugPrint('앨범 로드 오류: $e');
      return [];
    }
  }

  String _travelTitle() {
    final isDomestic = widget.travel['travel_type'] == 'domestic';
    final currentLocale = context.locale.languageCode;
    final place = isDomestic
        ? (widget.travel['region_name'] ?? widget.travel['city'])
        : (currentLocale == 'ko'
              ? widget.travel['country_name_ko']
              : widget.travel['country_name_en']);
    final title = (widget.travel['title'] ?? '').toString();
    return title.isNotEmpty
        ? title
        : 'trip_with_place'.tr(args: [place ?? 'overseas'.tr()]);
  }

  // ✅ 인포그래픽 생성 및 표시 함수
  Future<void> _generateAndShowInfographic(List<_AlbumItem> items) async {
    setState(() => _isGenerating = true);

    final title = _travelTitle();
    final summary = (widget.travel['ai_cover_summary'] ?? '여행의 추억을 기록해보세요.')
        .toString();
    final selectedPhotos = items.take(3).map((e) => e.imageUrl).toList();

    // 캡처용 히든 위젯 빌드
    final widgetToCapture = RepaintBoundary(
      key: _globalKey,
      child: InfographicDiaryLayout(
        title: title,
        summary: summary,
        photoUrls: selectedPhotos,
      ),
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Transform.translate(
          offset: const Offset(0, -10000), // 화면 밖에서 렌더링
          child: widgetToCapture,
        ),
      ),
    );

    try {
      await Future.delayed(const Duration(milliseconds: 600));

      // 📸 캡처 실행 (이제 에러 안 날 겁니다!)
      RenderRepaintBoundary? boundary =
          _globalKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;

      if (boundary == null) throw Exception("Boundary is null");

      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      if (mounted) Navigator.pop(context); // 렌더링용 다이얼로그 닫기

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text("✨ 나만의 여행 일기"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(pngBytes),
              ),
              const SizedBox(height: 16),
              const Text("예쁘게 완성되었습니다!"),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("닫기"),
            ),
            ElevatedButton(
              onPressed: () async {
                final tempDir = await getTemporaryDirectory();
                final file = await File('${tempDir.path}/diary.png').create();
                await file.writeAsBytes(pngBytes);
                await Share.shareXFiles([XFile(file.path)], text: '나의 여행 일기 ✨');
              },
              child: const Text("공유하기"),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) Navigator.pop(context);
      debugPrint("이미지 생성 에러: $e");
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _travelTitle();
    final overallSummary = (widget.travel['ai_cover_summary'] ?? '').toString();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(title, style: AppTextStyles.pageTitle),
        elevation: 0,
        backgroundColor: AppColors.background,
        actions: [
          FutureBuilder<List<_AlbumItem>>(
            future: _future,
            builder: (context, snapshot) {
              final hasData = snapshot.hasData && snapshot.data!.isNotEmpty;
              return IconButton(
                icon: _isGenerating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(
                        Icons.auto_awesome,
                        color: Colors.orangeAccent,
                        size: 28,
                      ),
                onPressed: hasData && !_isGenerating
                    ? () => _generateAndShowInfographic(snapshot.data!)
                    : null,
              );
            },
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: FutureBuilder<List<_AlbumItem>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return Center(
              child: Text(
                'no_diary_images_yet'.tr(),
                style: AppTextStyles.bodyMuted,
              ),
            );
          }

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
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
                  child: Row(
                    children: [
                      Text(
                        'painting_album'.tr(),
                        style: AppTextStyles.sectionTitle,
                      ),
                      const Spacer(),
                      Text(
                        'image_count_format'.tr(
                          args: [items.length.toString()],
                        ),
                        style: AppTextStyles.bodyMuted,
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  delegate: SliverChildBuilderDelegate((context, index) {
                    return GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => _AlbumViewerPage(
                            title: title,
                            items: items,
                            initialIndex: index,
                            overallSummary: overallSummary,
                          ),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          items[index].imageUrl,
                          fit: BoxFit.cover,
                        ),
                      ),
                    );
                  }, childCount: items.length),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 50)),
            ],
          );
        },
      ),
    );
  }
}

// ==========================================
// 🎨 인포그래픽 레이아웃 (삐딱 + 모눈종이)
// ==========================================
class InfographicDiaryLayout extends StatelessWidget {
  final String title;
  final String summary;
  final List<String> photoUrls;

  const InfographicDiaryLayout({
    super.key,
    required this.title,
    required this.summary,
    required this.photoUrls,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 380,
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: const Color(0xFFFCFBF7),
        // ✅ 모눈종이 패턴 느낌을 주는 배경 (CustomPaint로도 가능하지만 간단하게 테두리로 처리)
        border: Border.all(color: Colors.grey.shade300, width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 10),
          const Divider(thickness: 1, color: Colors.black12),
          const SizedBox(height: 20),

          // 삐딱한 사진들
          SizedBox(
            height: 300,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (photoUrls.isNotEmpty)
                  Positioned(
                    left: 0,
                    top: 10,
                    child: TiltedPhotoFrame(
                      imageUrl: photoUrls[0],
                      angle: -0.15,
                    ),
                  ),
                if (photoUrls.length > 1)
                  Positioned(
                    right: 0,
                    bottom: 20,
                    child: TiltedPhotoFrame(
                      imageUrl: photoUrls[1],
                      angle: 0.12,
                    ),
                  ),
                if (photoUrls.length > 2)
                  Positioned(
                    top: 80,
                    child: TiltedPhotoFrame(
                      imageUrl: photoUrls[2],
                      angle: -0.05,
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 30),

          // AI 요약글 (모눈종이 위에 포스트잇 느낌)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                ),
              ],
              border: Border.all(color: Colors.orangeAccent.withOpacity(0.3)),
            ),
            child: Text(
              summary,
              style: const TextStyle(
                fontSize: 15,
                height: 1.7,
                color: Colors.black87,
                fontFamily: 'serif',
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            "Travel Memoir with AI",
            style: TextStyle(
              color: Colors.grey,
              fontSize: 11,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class TiltedPhotoFrame extends StatelessWidget {
  final String imageUrl;
  final double angle;
  const TiltedPhotoFrame({
    super.key,
    required this.imageUrl,
    required this.angle,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle,
      child: Container(
        width: 170,
        height: 170,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 8,
              offset: const Offset(3, 5),
            ),
          ],
        ),
        child: Image.network(imageUrl, fit: BoxFit.cover),
      ),
    );
  }
}

// 뷰어 페이지 (기존 그대로 유지)
class _AlbumViewerPage extends StatefulWidget {
  final String title;
  final List<_AlbumItem> items;
  final int initialIndex;
  final String overallSummary;
  const _AlbumViewerPage({
    required this.title,
    required this.items,
    required this.initialIndex,
    required this.overallSummary,
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
          '${_index + 1} / ${widget.items.length}',
          style: const TextStyle(color: Colors.white, fontSize: 17),
        ),
        actions: [
          Builder(
            builder: (innerContext) => IconButton(
              icon: _isSharing
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.ios_share, color: Colors.white),
              onPressed: _isSharing
                  ? null
                  : () async {
                      setState(() => _isSharing = true);
                      final currentItem = widget.items[_index];
                      final String location = widget.title;
                      final String dateStr = DateUtilsHelper.formatYMD(
                        currentItem.date,
                      );
                      final String memo = widget.overallSummary.isNotEmpty
                          ? '\n${'share_memo'.tr()} ${widget.overallSummary}'
                          : '';
                      final String shareText =
                          '${'share_location'.tr()} $location\n${'share_date'.tr()} $dateStr$memo';
                      try {
                        final RenderBox? box =
                            innerContext.findRenderObject() as RenderBox?;
                        final tempDir = await getTemporaryDirectory();
                        final file = File(
                          '${tempDir.path}/${currentItem.date.millisecondsSinceEpoch}.png',
                        );
                        final response = await http.get(
                          Uri.parse(currentItem.imageUrl),
                        );
                        await file.writeAsBytes(response.bodyBytes);
                        await Share.shareXFiles(
                          [XFile(file.path)],
                          text: shareText,
                          sharePositionOrigin: box != null
                              ? box.localToGlobal(Offset.zero) & box.size
                              : null,
                        );
                      } catch (e) {
                        debugPrint('Share Error: $e');
                      } finally {
                        if (mounted) setState(() => _isSharing = false);
                      }
                    },
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.items.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) => InteractiveViewer(
              child: Center(
                child: Image.network(
                  widget.items[i].imageUrl,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          if (widget.overallSummary.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(24, 80, 24, 50),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.8),
                        Colors.black,
                      ],
                    ),
                  ),
                  child: Text(
                    widget.overallSummary,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      height: 1.6,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
