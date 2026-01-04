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
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return [];

    final travelId = widget.travel['id']?.toString();
    if (travelId == null || travelId.isEmpty) return [];

    final userId = user.id;

    // 1️⃣ storage에서 실제 이미지 파일 목록을 가져온다 (🔥 핵심)
    final files = await client.storage
        .from('travel_images')
        .list(path: 'users/$userId/travels/$travelId/days');

    if (files.isEmpty) return [];

    // 2️⃣ travel_days에서 요약 정보만 가져온다 (date, ai_summary)
    final daySummaries = await TravelDayService.getAlbumDays(
      travelId: travelId,
    );

    final summaryMap = {
      for (final d in daySummaries)
        d['date']?.toString(): (d['ai_summary'] ?? '').toString(),
    };

    // 3️⃣ storage 파일 기준으로 앨범 구성
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
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return Center(
              child: Text('아직 생성된 그림일기가 없어요', style: AppTextStyles.bodyMuted),
            );
          }

          return CustomScrollView(
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
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(16),
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
      '📅 ${DateUtilsHelper.formatYMD(item.date)}',
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
