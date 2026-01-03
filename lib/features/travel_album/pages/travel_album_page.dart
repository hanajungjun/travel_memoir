import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:travel_memoir/services/travel_day_service.dart';
import 'package:travel_memoir/core/utils/date_utils.dart';
import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/shared/styles/text_styles.dart';

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
    final travelId = widget.travel['id'] as String;
    final userId = widget.travel['user_id'] as String;

    final days = await TravelDayService.getAlbumDays(travelId: travelId);

    return days.map((d) {
      final rawDate = d['date'];
      if (rawDate == null) {
        throw Exception('date is null: $d');
      }

      final date = DateTime.parse(rawDate.toString());

      final imageUrl = _dayImageUrl(
        userId: userId,
        travelId: travelId,
        date: date,
      );

      return _AlbumItem(
        date: date,
        summary: (d['ai_summary'] ?? '').toString(),
        imageUrl: imageUrl,
      );
    }).toList();
  }

  // 🔥 days 이미지 public url 생성
  String _dayImageUrl({
    required String userId,
    required String travelId,
    required DateTime date,
  }) {
    final ymd = DateUtilsHelper.formatYMD(date); // yyyy-MM-dd

    final path = 'users/$userId/travels/$travelId/days/$ymd.png';

    return Supabase.instance.client.storage
        .from('travel_images')
        .getPublicUrl(path);
  }

  String _travelTitle() {
    final isDomestic = widget.travel['travel_type'] == 'domestic';
    final place = isDomestic
        ? (widget.travel['city_name'] ?? widget.travel['city'])
        : widget.travel['country_name'];
    final title = (widget.travel['title'] ?? '').toString();

    return title.isNotEmpty ? title : '${place ?? ''} 여행';
  }

  String _dateRangeText() {
    final s = (widget.travel['start_date'] ?? '').toString();
    final e = (widget.travel['end_date'] ?? '').toString();
    return (s.isNotEmpty && e.isNotEmpty) ? '$s ~ $e' : '';
  }

  String _topSummary() {
    return (widget.travel['ai_cover_summary'] ??
            widget.travel['cover_summary'] ??
            '')
        .toString();
  }

  @override
  Widget build(BuildContext context) {
    final title = _travelTitle();
    final dateRange = _dateRangeText();
    final summary = _topSummary();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(title, style: AppTextStyles.pageTitle)),
      body: FutureBuilder<List<_AlbumItem>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final items = snapshot.data!;
          if (items.isEmpty) {
            return Center(
              child: Text('아직 생성된 그림일기가 없어요', style: AppTextStyles.bodyMuted),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              setState(() => _future = _loadAlbum());
              await _future;
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (dateRange.isNotEmpty)
                          Text(dateRange, style: AppTextStyles.bodyMuted),

                        if (summary.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.divider),
                            ),
                            child: Text(summary, style: AppTextStyles.body),
                          ),
                        ],

                        const SizedBox(height: 14),

                        Row(
                          children: [
                            Text('그림 앨범', style: AppTextStyles.sectionTitle),
                            const Spacer(),
                            Text(
                              '${items.length}장',
                              style: AppTextStyles.bodyMuted,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
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
                          child: Image.network(
                            item.imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: AppColors.surface,
                              alignment: Alignment.center,
                              child: Text(
                                DateUtilsHelper.formatMonthDay(item.date),
                                style: AppTextStyles.bodyMuted,
                              ),
                            ),
                          ),
                        ),
                      );
                    }, childCount: items.length),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

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

// =====================
// 전체화면 뷰어 + 공유
// =====================
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
      '📍 ${widget.title}',
      '📅 ${DateTime(item.date.year, item.date.month, item.date.day).toString()}',
      if (item.summary.isNotEmpty) '📝 ${item.summary}',
      '',
      item.imageUrl,
    ].join('\n');

    Share.share(text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          '${widget.items[_index].date.month}/${widget.items[_index].date.day}',
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
                errorBuilder: (_, __, ___) => const Text(
                  '이미지를 불러오지 못했어요',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
