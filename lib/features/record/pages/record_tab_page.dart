import 'package:flutter/material.dart';

import 'package:travel_memoir/services/travel_list_service.dart';
import 'package:travel_memoir/services/travel_day_service.dart';
import 'package:travel_memoir/features/travel_diary/pages/travel_diary_list_page.dart';
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

  @override
  void initState() {
    super.initState();
    _future = _getCompletedTravels();
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
                return _AnimatedPage(
                  child: _SummaryHeroCard(
                    totalCount: travels.length,
                    lastTravel: travels.first,
                  ),
                );
              }

              final travel = travels[index - 1];
              return _AnimatedPage(child: _TravelRecordCard(travel: travel));
            },
          );
        },
      ),
    );
  }

  // ==============================
  // 🔒 모든 일기 작성 완료된 여행만
  // ==============================
  Future<List<Map<String, dynamic>>> _getCompletedTravels() async {
    final travels = await TravelListService.getTravels();
    final List<Map<String, dynamic>> completed = [];

    for (final travel in travels) {
      if (travel['is_completed'] != true) continue;
      completed.add(travel);
    }

    completed.sort((a, b) => b['end_date'].compareTo(a['end_date']));
    return completed;
  }
}

// ==============================
// 🎞️ 페이지 애니메이션
// ==============================
class _AnimatedPage extends StatelessWidget {
  final Widget child;

  const _AnimatedPage({required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOut,
      builder: (context, value, _) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 40 * (1 - value)),
            child: child,
          ),
        );
      },
    );
  }
}

// ==============================
// 0️⃣ 요약 카드
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

            Center(
              child: Column(
                children: [
                  Icon(
                    Icons.keyboard_arrow_up,
                    size: 28,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(height: 4),
                  Text('위로 올려 여행 기록 보기', style: AppTextStyles.caption),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==============================
// 🧳 여행 기록 카드 (🔥 여기 핵심)
// ==============================
class _TravelRecordCard extends StatelessWidget {
  final Map<String, dynamic> travel;

  const _TravelRecordCard({required this.travel});

  @override
  Widget build(BuildContext context) {
    final coverUrl = travel['cover_image_url'];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TravelDiaryListPage(travel: travel),
              ),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: coverUrl == null
                      ? Container(color: AppColors.surface)
                      : Image.network(
                          coverUrl,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              Container(color: AppColors.surface),
                        ),
                ),
              ),

              const SizedBox(height: 16),

              Text('${travel['city']} 여행', style: AppTextStyles.sectionTitle),

              const SizedBox(height: 6),

              Text(
                '${travel['start_date']} ~ ${travel['end_date']}',
                style: AppTextStyles.bodyMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
