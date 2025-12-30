import 'package:flutter/material.dart';

import 'package:travel_memoir/services/travel_service.dart';
import 'package:travel_memoir/services/travel_list_service.dart';
import 'package:travel_memoir/services/travel_day_service.dart';

import 'package:travel_memoir/features/travel_diary/pages/travel_diary_list_page.dart';

import 'package:travel_memoir/core/utils/date_utils.dart';
import 'package:travel_memoir/core/widgets/travel_map_pager.dart';

import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/shared/styles/text_styles.dart';

class HomePage extends StatefulWidget {
  final VoidCallback onGoToTravel;

  const HomePage({super.key, required this.onGoToTravel});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<Map<String, dynamic>?> _recentFuture;

  @override
  void initState() {
    super.initState();
    debugPrint('==============================');
    debugPrint('🧪 [HOME] initState');
    debugPrint('==============================');

    _recentFuture = _getRecentTravel();
  }

  void _refresh() {
    debugPrint('==============================');
    debugPrint('🧪 [HOME] _refresh called');
    debugPrint('==============================');

    setState(() {
      _recentFuture = _getRecentTravel();
    });
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('🧪 [HOME] build');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Travel Memoir'),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 📅 오늘 날짜
            Text(DateUtilsHelper.todayText(), style: AppTextStyles.bodyMuted),

            const SizedBox(height: 16),

            // ✍️ 오늘의 일기
            Text('오늘의 일기', style: AppTextStyles.sectionTitle),
            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () async {
                  debugPrint('==============================');
                  debugPrint('🧪 [HOME] 오늘의 일기 버튼 클릭');
                  debugPrint('==============================');

                  final travel = await TravelService.getTodayTravel();
                  debugPrint('🧪 [HOME] getTodayTravel = $travel');

                  if (travel == null) {
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        backgroundColor: AppColors.surface,
                        title: Text(
                          '여행이 없어요',
                          style: AppTextStyles.sectionTitle,
                        ),
                        content: Text(
                          '오늘은 여행 중이 아니에요.\n여행을 추가할까요?',
                          style: AppTextStyles.body,
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text('취소', style: AppTextStyles.bodyMuted),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              widget.onGoToTravel();
                            },
                            child: const Text('여행 추가'),
                          ),
                        ],
                      ),
                    );
                    return;
                  }

                  final diary = await TravelDayService.getDiaryByDate(
                    travelId: travel['id'],
                    date: DateTime.now(),
                  );

                  final hasDiary =
                      diary != null &&
                      (diary['text'] ?? '').toString().isNotEmpty;

                  debugPrint('🧪 [HOME] today diary = $diary');
                  debugPrint('🧪 [HOME] hasDiary = $hasDiary');

                  if (hasDiary) {
                    final action = await showDialog<String>(
                      context: context,
                      builder: (_) => AlertDialog(
                        backgroundColor: AppColors.surface,
                        title: Text(
                          '오늘의 일기가 있어요',
                          style: AppTextStyles.sectionTitle,
                        ),
                        content: Text(
                          '이미 작성한 일기가 있습니다.\n어떻게 할까요?',
                          style: AppTextStyles.body,
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, 'edit'),
                            child: const Text('수정하기'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, 'new'),
                            child: const Text('새로 작성하기'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, null),
                            child: Text('취소', style: AppTextStyles.bodyMuted),
                          ),
                        ],
                      ),
                    );

                    debugPrint('🧪 [HOME] dialog action = $action');
                    if (action == null) return;
                  }

                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TravelDiaryListPage(travel: travel),
                    ),
                  );

                  _refresh(); // 🔥 작성 후 홈 갱신
                },
                child: FutureBuilder<Map<String, dynamic>?>(
                  future: _getTodayDiaryStatus(),
                  builder: (context, snapshot) {
                    final hasDiary =
                        snapshot.data != null &&
                        (snapshot.data?['text'] ?? '').toString().isNotEmpty;

                    return Text(
                      hasDiary ? '✅ 오늘 일기 작성됨' : '✍️ 오늘 일기 쓰기',
                      style: AppTextStyles.button,
                    );
                  },
                ),
              ),
            ),

            const SizedBox(height: 40),

            // 🧳 최근 여행
            Text('최근 여행', style: AppTextStyles.sectionTitle),
            const SizedBox(height: 12),

            FutureBuilder<Map<String, dynamic>?>(
              future: _recentFuture,
              builder: (context, snapshot) {
                debugPrint('==============================');
                debugPrint(
                  '🧪 [HOME] recentFuture state=${snapshot.connectionState}',
                );
                debugPrint('🧪 [HOME] recentFuture data=${snapshot.data}');
                debugPrint('🧪 [HOME] recentFuture error=${snapshot.error}');
                debugPrint('==============================');

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  );
                }

                final travel = snapshot.data;
                if (travel == null) {
                  return _emptyRecentTravel();
                }

                final title = travel['travel_type'] == 'domestic'
                    ? (travel['city_name'] ?? travel['city'])
                    : travel['country_name'];

                return InkWell(
                  onTap: () async {
                    debugPrint(
                      '🧪 [HOME] recent travel tap -> travel=${travel['id']}',
                    );

                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TravelDiaryListPage(travel: travel),
                      ),
                    );
                    _refresh();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$title 여행',
                          style: AppTextStyles.body.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${travel['start_date']} ~ ${travel['end_date']}',
                          style: AppTextStyles.bodyMuted,
                        ),
                        const SizedBox(height: 24),
                        // ✅ 지도 미리보기 (travelId 전달)
                        TravelMapPager(travelId: travel['id']),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ================= helpers =================

  static Future<Map<String, dynamic>?> _getTodayDiaryStatus() async {
    debugPrint('🧪 [HOME] _getTodayDiaryStatus START');

    final travel = await TravelService.getTodayTravel();
    debugPrint('🧪 [HOME] _getTodayDiaryStatus travel=$travel');

    if (travel == null) return null;

    final diary = await TravelDayService.getDiaryByDate(
      travelId: travel['id'],
      date: DateTime.now(),
    );

    debugPrint('🧪 [HOME] _getTodayDiaryStatus diary=$diary');
    return diary;
  }

  Future<Map<String, dynamic>?> _getRecentTravel() async {
    debugPrint('==============================');
    debugPrint('🧪 [HOME] _getRecentTravel START');

    final travels = await TravelListService.getTravels();

    debugPrint('🧪 [HOME] travels.length = ${travels.length}');
    debugPrint('🧪 [HOME] travels raw = $travels');

    if (travels.isEmpty) {
      debugPrint('🧪 [HOME] travels EMPTY -> return null');
      debugPrint('==============================');
      return null;
    }

    for (final t in travels) {
      debugPrint(
        '🧪 [HOME] travel id=${t['id']} created_at=${t['created_at']}',
      );
    }

    // created_at 안전 정렬 (null/타입혼합 방지)
    travels.sort((a, b) {
      final ad = a['created_at']?.toString() ?? '';
      final bd = b['created_at']?.toString() ?? '';
      return bd.compareTo(ad);
    });

    debugPrint('🧪 [HOME] AFTER SORT -> first = ${travels.first}');
    debugPrint('==============================');

    return travels.first;
  }

  Widget _emptyRecentTravel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text('아직 여행이 없어요', style: AppTextStyles.bodyMuted),
    );
  }
}
