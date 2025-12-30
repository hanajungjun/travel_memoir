import 'package:flutter/material.dart';

import 'package:travel_memoir/services/travel_service.dart';
import 'package:travel_memoir/services/travel_day_service.dart';
import 'package:travel_memoir/services/travel_list_service.dart';

import 'package:travel_memoir/features/travel_diary/pages/travel_diary_list_page.dart';

import 'package:travel_memoir/core/utils/date_utils.dart';
import 'package:travel_memoir/core/widgets/recent_travel_section.dart';
import 'package:travel_memoir/core/widgets/travel_map_pager.dart';
import 'package:travel_memoir/core/widgets/home_travel_status_header.dart';

import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/shared/styles/text_styles.dart';

class HomePage extends StatefulWidget {
  final VoidCallback onGoToTravel;

  const HomePage({super.key, required this.onGoToTravel});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    debugPrint('==============================');
    debugPrint('🧪 [HOME] initState');
    debugPrint('==============================');
  }

  void _refresh() {
    debugPrint('==============================');
    debugPrint('🧪 [HOME] _refresh called');
    debugPrint('==============================');
    setState(() {});
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

            const SizedBox(height: 12),

            // 🟦 여행 상태 헤더 (여행중 / 여행준비중 + +버튼)
            HomeTravelStatusHeader(onGoToTravel: widget.onGoToTravel),

            const SizedBox(height: 12),

            // 🧳 최신 여행 (카드 3개)
            RecentTravelSection(),

            // 🗺️ 최근 여행 지도
            FutureBuilder<List<Map<String, dynamic>>>(
              future: TravelListService.getTravels(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text('아직 여행이 없어요', style: AppTextStyles.bodyMuted),
                  );
                }

                final travels = snapshot.data!;

                // 최신 여행 1개
                travels.sort((a, b) {
                  final ad = a['created_at']?.toString() ?? '';
                  final bd = b['created_at']?.toString() ?? '';
                  return bd.compareTo(ad);
                });

                final recentTravel = travels.first;

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: TravelMapPager(travelId: recentTravel['id']),
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
}
