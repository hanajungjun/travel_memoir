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
  /// 🔄 홈 리프레시용 키
  int _refreshKey = 0;

  /// 🔁 홈 다시 그리기
  void _refreshHome() {
    setState(() {
      _refreshKey++;
    });
  }

  @override
  void initState() {
    super.initState();
    debugPrint('==============================');
    debugPrint('🧪 [HOME] initState');
    debugPrint('==============================');
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('🧪 [HOME] build ($_refreshKey)');

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: Column(
        children: [
          // =====================================================
          // 🔵 상단 풀블리드 헤더
          // =====================================================
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 56, 20, 20),
            color: AppColors.lightSurface,
            child: HomeTravelStatusHeader(onGoToTravel: widget.onGoToTravel),
          ),

          // =====================================================
          // ⬇️ 아래 스크롤 영역
          // =====================================================
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ===============================
                  // 🧳 최근 여행 카드
                  // ===============================
                  RecentTravelSection(
                    key: ValueKey('recent-$_refreshKey'),
                    onSeeAll: widget.onGoToTravel,
                  ),

                  const SizedBox(height: 24),

                  // ===============================
                  // 🗺️ 최근 여행 지도
                  // ===============================
                  FutureBuilder<List<Map<String, dynamic>>>(
                    key: ValueKey('map-$_refreshKey'),
                    future: TravelListService.getTravels(),
                    builder: (context, snapshot) {
                      final travels = snapshot.data ?? [];

                      final String? travelId = travels.isNotEmpty
                          ? travels.first['id']
                          : null;

                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.lightSurface,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: SizedBox(
                          height: 380,
                          child: TravelMapPager(
                            travelId: travelId ?? 'preview',
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
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
