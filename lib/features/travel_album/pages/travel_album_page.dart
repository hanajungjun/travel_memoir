import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';

import 'package:travel_memoir/services/travel_day_service.dart';
import 'package:travel_memoir/core/utils/date_utils.dart';
import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/shared/styles/text_styles.dart';

// 1. 데이터 모델 클래스 (파일 하단에 정의되어 있어야 함)
class _AlbumItem {
  final DateTime date;
  final String summary;
  final String imageUrl;

  _AlbumItem({
    required this.date,
    required this.summary,
    required this.imageUrl,
  });
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

    final travelId = widget.travel['id']?.toString();
    if (travelId == null || travelId.isEmpty) return [];

    final userId = user.id;

    final files = await client.storage
        .from('travel_images')
        .list(path: 'users/$userId/travels/$travelId/days');

    if (files.isEmpty) return [];

    final daySummaries = await TravelDayService.getAlbumDays(
      travelId: travelId,
    );

    final summaryMap = {
      for (final d in daySummaries)
        d['date']?.toString(): (d['ai_summary'] ?? '').toString(),
    };

    // ⭐ 에러 해결: _AlbumItem 생성자를 명확히 호출
    return files.where((f) => f.name.endsWith('.png')).map((f) {
      final dateStr = f.name.replaceAll('.png', '');
      final date =
          DateTime.tryParse(dateStr) ?? DateTime.fromMillisecondsSinceEpoch(0);

      final imageUrl = client.storage
          .from('travel_images')
          .getPublicUrl('users/$userId/travels/$travelId/days/${f.name}');

      return _AlbumItem(
        date: date,
        summary: summaryMap[dateStr] ?? '',
        imageUrl: imageUrl,
      );
    }).toList()..sort((a, b) => a.date.compareTo(b.date));
  }

  String _travelTitle() {
    final isDomestic = widget.travel['travel_type'] == 'domestic';
    final String currentLocale = context.locale.languageCode;

    final place = isDomestic
        ? (widget.travel['city_name'] ?? widget.travel['city'])
        : (currentLocale == 'ko'
              ? widget.travel['country_name_ko']
              : widget.travel['country_name_en']);

    final title = (widget.travel['title'] ?? '').toString();
    if (title.isNotEmpty) return title;

    return 'trip_with_place'.tr(args: [place ?? 'overseas'.tr()]);
  }

  @override
  Widget build(BuildContext context) {
    final title = _travelTitle();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(title, style: AppTextStyles.pageTitle)),
      body: FutureBuilder<List<_AlbumItem>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          // ⭐ 에러 해결: Null check 및 기본 리스트 할당
          final List<_AlbumItem> items = snapshot.data ?? [];

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
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
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
                padding: const EdgeInsets.all(20),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final item = items[index];
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => _AlbumViewerPage(
                              title: title,
                              items: items,
                              initialIndex: index,
                            ),
                          ),
                        );
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(item.imageUrl, fit: BoxFit.cover),
                      ),
                    );
                  }, childCount: items.length),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------
// 🖼️ 앨범 뷰어 페이지 (에러 방지를 위해 하단 배치)
// ---------------------------------------------------------
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

  void _share() {
    final item = widget.items[_index];
    final text = [
      '${'share_location'.tr()} ${widget.title}',
      '${'share_date'.tr()} ${DateUtilsHelper.formatYMD(item.date)}',
      if (item.summary.isNotEmpty) '${'share_memo'.tr()} ${item.summary}',
      '',
      item.imageUrl,
    ].join('\n');
    Share.share(text);
  }

  @override
  Widget build(BuildContext context) {
    // ⭐ 에러 해결: 현재 index의 아이템을 안전하게 가져옴
    final currentItem = widget.items[_index];

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          '${currentItem.date.month}/${currentItem.date.day}',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share, color: Colors.white),
            onPressed: _share,
          ),
        ],
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.items.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (_, i) {
          final item = widget.items[i];
          return InteractiveViewer(
            minScale: 1,
            maxScale: 4,
            child: Center(
              child: Image.network(
                item.imageUrl,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Text(
                  'failed_to_load_image'.tr(),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
