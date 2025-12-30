import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:travel_memoir/services/travel_list_service.dart';
import 'package:travel_memoir/features/travel_album/pages/travel_album_page.dart';
import 'package:travel_memoir/core/utils/date_utils.dart';

import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/shared/styles/text_styles.dart';

class RecordTabPage extends StatefulWidget {
  const RecordTabPage({super.key});

  @override
  State<RecordTabPage> createState() => _RecordTabPageState();
}

class _RecordTabPageState extends State<RecordTabPage> {
  final PageController _controller = PageController();
  late Future<List<Map<String, dynamic>>> _future;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _reload();

    _pollingTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _reload(),
    );
  }

  void _reload() {
    setState(() {
      _future = _getCompletedTravels();
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final travels = snapshot.data!;
          if (travels.isEmpty) {
            return Center(
              child: Text('아직 기록된 여행이 없어요', style: AppTextStyles.bodyMuted),
            );
          }

          return PageView.builder(
            controller: _controller,
            scrollDirection: Axis.vertical,
            itemCount: travels.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return _SummaryHeroCard(
                  totalCount: travels.length,
                  lastTravel: travels.first,
                );
              }

              final travel = travels[index - 1];
              return _TravelRecordCard(travel: travel, onReturn: _reload);
            },
          );
        },
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _getCompletedTravels() async {
    final travels = await TravelListService.getTravels();
    final completed = travels.where((t) => t['is_completed'] == true).toList();

    completed.sort((a, b) => b['end_date'].compareTo(a['end_date']));

    final stillProcessing = completed.any(
      (t) =>
          (t['cover_image_url'] == null ||
          (t['ai_cover_summary'] ?? '').toString().isEmpty),
    );

    if (!stillProcessing) {
      _pollingTimer?.cancel();
      HapticFeedback.lightImpact();
    }

    return completed;
  }
}

// ==============================
// 🧭 요약 카드
// ==============================
class _SummaryHeroCard extends StatelessWidget {
  final int totalCount;
  final Map<String, dynamic> lastTravel;

  const _SummaryHeroCard({required this.totalCount, required this.lastTravel});

  @override
  Widget build(BuildContext context) {
    final end = DateTime.parse(lastTravel['end_date']);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Spacer(),
            Text('기억을 다시 꺼내볼까요?', style: AppTextStyles.title),
            const SizedBox(height: 24),
            Text('지금까지의 여행 · 총 $totalCount번', style: AppTextStyles.body),
            const SizedBox(height: 8),
            Text(
              '마지막 여행 · ${DateUtilsHelper.formatYMD(end)}',
              style: AppTextStyles.body,
            ),
            Text(
              DateUtilsHelper.memoryTimeAgo(end),
              style: AppTextStyles.bodyMuted,
            ),
            const Spacer(),
            const Center(child: Icon(Icons.keyboard_arrow_up, size: 28)),
          ],
        ),
      ),
    );
  }
}

// ==============================
// 🧳 여행 카드
// ==============================
class _TravelRecordCard extends StatelessWidget {
  final Map<String, dynamic> travel;
  final VoidCallback onReturn;

  const _TravelRecordCard({required this.travel, required this.onReturn});

  @override
  Widget build(BuildContext context) {
    final coverUrl = travel['cover_image_url'];
    final summary = (travel['ai_cover_summary'] ?? '').toString().trim();

    final hasCover = coverUrl != null && coverUrl.isNotEmpty;
    final hasSummary = summary.isNotEmpty;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TravelAlbumPage(travel: travel),
              ),
            ).then((_) => onReturn());
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                Positioned.fill(
                  child: hasCover
                      ? Image.network(
                          coverUrl,
                          fit: BoxFit.cover,
                          loadingBuilder: (_, child, progress) {
                            if (progress == null) return child;
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          },
                        )
                      : const Center(child: CircularProgressIndicator()),
                ),

                if (hasCover && !hasSummary) _BottomLabel(text: 'AI 여행 정리중…'),

                if (hasSummary) _BottomLabel(text: summary, gradient: true),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomLabel extends StatelessWidget {
  final String text;
  final bool gradient;

  const _BottomLabel({required this.text, this.gradient = false});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: gradient
            ? const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black54],
                ),
              )
            : const BoxDecoration(color: Colors.black45),
        child: Text(
          text,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.body.copyWith(color: Colors.white),
        ),
      ),
    );
  }
}
