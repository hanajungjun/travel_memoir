import 'package:flutter/material.dart';

import 'package:travel_memoir/services/travel_service.dart';
import 'package:travel_memoir/services/travel_day_service.dart';
import 'package:travel_memoir/services/travel_list_service.dart';

import 'package:travel_memoir/features/travel_diary/pages/travel_diary_list_page.dart';

import 'package:travel_memoir/core/utils/date_utils.dart';
import 'package:travel_memoir/core/widgets/recent_travel_section.dart';
import 'package:travel_memoir/core/widgets/travel_map_pager.dart';
import 'package:travel_memoir/core/widgets/home_travel_status_header.dart';

import 'package:travel_memoir/core/widgets/skeletons/travel_map_skeleton.dart';
import 'package:travel_memoir/core/widgets/skeletons/recent_travel_section_skeleton.dart';

import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/shared/styles/text_styles.dart';

class HomePage extends StatefulWidget {
  final VoidCallback onGoToTravel;

  const HomePage({super.key, required this.onGoToTravel});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _refreshKey = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: Column(
        children: [
          // 🔵 Header
          HomeTravelStatusHeader(onGoToTravel: widget.onGoToTravel),

          // ⬇️ Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 🧳 Recent Travel
                  FutureBuilder(
                    key: ValueKey('recent-$_refreshKey'),
                    future: TravelListService.getRecentTravels(),
                    builder: (context, snapshot) {
                      return AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child:
                            snapshot.connectionState == ConnectionState.waiting
                            ? const RecentTravelSectionSkeleton(
                                key: ValueKey('recent-skeleton'),
                              )
                            : RecentTravelSection(
                                key: const ValueKey('recent-content'),
                                onSeeAll: widget.onGoToTravel,
                              ),
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  // 🗺️ Travel Map
                  FutureBuilder<List<Map<String, dynamic>>>(
                    key: ValueKey('map-$_refreshKey'),
                    future: TravelListService.getTravels(),
                    builder: (context, snapshot) {
                      final travels = snapshot.data ?? [];
                      final String? travelId = travels.isNotEmpty
                          ? travels.first['id']
                          : null;

                      return AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child:
                            snapshot.connectionState == ConnectionState.waiting
                            ? const TravelMapSkeleton(
                                key: ValueKey('map-skeleton'),
                              )
                            : Container(
                                key: const ValueKey('map-content'),
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
    final travel = await TravelService.getTodayTravel();
    if (travel == null) return null;

    return await TravelDayService.getDiaryByDate(
      travelId: travel['id'],
      date: DateTime.now(),
    );
  }
}
