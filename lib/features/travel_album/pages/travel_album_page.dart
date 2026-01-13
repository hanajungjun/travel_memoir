import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:travel_memoir/core/utils/date_utils.dart';
import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/shared/styles/text_styles.dart';

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
  }

  String _travelTitle() {
    final isDomestic = widget.travel['travel_type'] == 'domestic';
    final currentLocale = context.locale.languageCode;
    final place = isDomestic
        ? (widget.travel['city_name'] ?? widget.travel['city'])
        : (currentLocale == 'ko'
              ? widget.travel['country_name_ko']
              : widget.travel['country_name_en']);
    final title = (widget.travel['title'] ?? '').toString();
    return title.isNotEmpty
        ? title
        : 'trip_with_place'.tr(args: [place ?? 'overseas'.tr()]);
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 22,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      overallSummary,
                      style: AppTextStyles.body.copyWith(
                        fontSize: 15,
                        height: 1.6,
                        color: Colors.black87,
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
        // ✅ [수정] 날짜 대신 "현재 페이지 / 전체 페이지"를 제목으로 표시
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
                          '${'share_location'.tr()} $location\n'
                          '${'share_date'.tr()} $dateStr'
                          '$memo';

                      try {
                        final RenderBox? box =
                            innerContext.findRenderObject() as RenderBox?;
                        final tempDir = await getTemporaryDirectory();
                        final fileName =
                            '${currentItem.date.millisecondsSinceEpoch}.png';
                        final file = File('${tempDir.path}/$fileName');

                        final response = await http.get(
                          Uri.parse(currentItem.imageUrl),
                        );
                        if (response.statusCode != 200)
                          throw Exception('Failed download');
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
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('failed_to_share_image'.tr())),
                        );
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
              minScale: 1,
              maxScale: 4,
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
