import 'dart:io';
import 'dart:async';
import 'dart:ui' as ui;
import 'dart:typed_data';
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

// ==========================================
// 1. 모델 클래스
// ==========================================
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

// ==========================================
// 2. 메인 페이지 위젯
// ==========================================
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

  @override
  void initState() {
    super.initState();
    _groupedFuture = _loadGroupedAlbum();
    _initPremiumReport();
  }

  Future<void> _initPremiumReport() async {
    final client = Supabase.instance.client;
    final travelId = widget.travel['id']?.toString() ?? '';
    final res = await client
        .from('travels')
        .select('premium_report_url')
        .eq('id', travelId)
        .maybeSingle();

    if (res != null && res['premium_report_url'] != null) {
      setState(() => _premiumImageUrl = res['premium_report_url']);
      return;
    }

    // [주석] 프리미엄 유저 체크 로직
    // final bool isPremium = true; if (!isPremium) return;

    final groupedData = await _groupedFuture;
    if (groupedData.values.any((l) => l.isNotEmpty)) {
      _generateAndSavePremiumInfographic(groupedData);
    }
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
        if (items.isNotEmpty && items.first.diaryText != null)
          allTexts.add(items.first.diaryText!);
      });

      final imageBytes = await GeminiService().generateFullTravelInfographic(
        travelTitle: _travelTitle(),
        allDiaryTexts: allTexts,
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
        actions: const [SizedBox(width: 12)],
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
                  padding: EdgeInsets.symmetric(vertical: 40),
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
                              fontSize: 16,
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

  // ✅ 수정됨: 이미지를 터치하면 프리미엄 전용 뷰어로 이동
  Widget _buildPremiumCard() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => _PremiumViewerPage(
              title: _travelTitle(),
              imageBytes: _premiumInfographic,
              imageUrl: _premiumImageUrl,
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: _premiumInfographic != null
              ? Image.memory(_premiumInfographic!, fit: BoxFit.contain)
              : Image.network(_premiumImageUrl!, fit: BoxFit.contain),
        ),
      ),
    );
  }
}

// ==========================================
// 3. 일반 앨범 뷰어 페이지 (기존 동일)
// ==========================================
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
// 4. ✅ [신규] 프리미엄 인포그래픽 전용 뷰어
// ==========================================
class _PremiumViewerPage extends StatefulWidget {
  final String title;
  final Uint8List? imageBytes;
  final String? imageUrl;

  const _PremiumViewerPage({
    required this.title,
    this.imageBytes,
    this.imageUrl,
  }) : assert(imageBytes != null || imageUrl != null);

  @override
  State<_PremiumViewerPage> createState() => _PremiumViewerPageState();
}

class _PremiumViewerPageState extends State<_PremiumViewerPage> {
  bool _isSharing = false;

  Future<void> _shareImage(BuildContext ctx) async {
    setState(() => _isSharing = true);
    try {
      final temp = await getTemporaryDirectory();
      final file = await File('${temp.path}/premium_share.png').create();

      if (widget.imageBytes != null) {
        await file.writeAsBytes(widget.imageBytes!);
      } else if (widget.imageUrl != null) {
        final res = await http.get(Uri.parse(widget.imageUrl!));
        await file.writeAsBytes(res.bodyBytes);
      }

      final box = ctx.findRenderObject() as RenderBox?;
      await Share.shareXFiles(
        [XFile(file.path)],
        text: '나의 여행 인포그래픽 ✨',
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
          child: widget.imageBytes != null
              ? Image.memory(widget.imageBytes!)
              : Image.network(widget.imageUrl!),
        ),
      ),
    );
  }
}
