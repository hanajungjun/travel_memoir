import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/core/constants/korea/korea_region.dart';
import 'package:travel_memoir/core/constants/korea/korea_region_master.dart';

import 'package:travel_memoir/shared/styles/text_styles.dart';

import 'package:travel_memoir/features/map/pages/domestic_map_page.dart';
import 'package:travel_memoir/features/map/pages/global_map_page.dart';

import 'package:travel_memoir/services/domestic_travel_summary_service.dart';
import 'package:travel_memoir/services/overseas_travel_summary_service.dart';

class MyTravelSummaryPage extends StatefulWidget {
  const MyTravelSummaryPage({super.key});

  @override
  State<MyTravelSummaryPage> createState() => _MyTravelSummaryPageState();
}

class _MyTravelSummaryPageState extends State<MyTravelSummaryPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final String _userId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _userId = Supabase.instance.client.auth.currentUser!.id;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('내 여행'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '국내'),
            Tab(text: '해외'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _DomesticTab(userId: _userId),
          const _WorldTab(),
        ],
      ),
    );
  }
}

// =======================================================
// 🌍 해외 탭 (🔥 여기 인덱스 오류 수정됨)
// =======================================================
class _WorldTab extends StatelessWidget {
  const _WorldTab();

  @override
  Widget build(BuildContext context) {
    final userId = Supabase.instance.client.auth.currentUser!.id;

    return FutureBuilder<List<Object>>(
      future: Future.wait([
        OverseasTravelSummaryService.getTotalCountryCount(), // 0
        OverseasTravelSummaryService.getVisitedCountryCount(
          userId: userId,
        ), // 1
        OverseasTravelSummaryService.getTravelCount(userId: userId), // 2
        OverseasTravelSummaryService.getTotalTravelDays(userId: userId), // 3
        OverseasTravelSummaryService.getMostVisitedCountry(userId: userId), // 4
      ]),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final total = snapshot.data![0] as int;
        final visited = snapshot.data![1] as int;
        final travelCount = snapshot.data![2] as int;
        final travelDays = snapshot.data![3] as int;
        final mostVisitedCountry = snapshot.data![4] as String;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TotalDonutCard(
                visited: visited,
                total: total,
                title: 'In Total',
                sub: 'Countries',
                percent: total == 0 ? 0 : (visited / total * 100).round(),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 350,
                child: GlobalMapPage(isReadOnly: true),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.lightSurface,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('여행 요약', style: AppTextStyles.sectionTitle),
                    const SizedBox(height: 12),
                    Text('여행 횟수: $travelCount회'),
                    Text('총 여행 일수: $travelDays일'),
                    Text('가장 많이 간 국가: $mostVisitedCountry'),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// =======================================================
// 🇰🇷 국내 탭 (기존 그대로)
// =======================================================
class _DomesticTab extends StatelessWidget {
  final String userId;

  const _DomesticTab({required this.userId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: Future.wait([
        DomesticTravelSummaryService.getVisitedCityCount(userId: userId),
        DomesticTravelSummaryService.getVisitedCountByArea(
          userId: userId,
          isDomestic: true,
          isCompleted: true,
        ),
      ]),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final visitedCityCount = snapshot.data![0] as int;
        final areaCounts = snapshot.data![1] as Map<String, int>;

        final totalCityCount = koreaRegionMaster
            .where(
              (r) =>
                  r.type == KoreaRegionType.city ||
                  r.type == KoreaRegionType.county ||
                  r.mapRegionType == MapRegionType.special,
            )
            .length;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TotalDonutCard(
                visited: visitedCityCount,
                total: totalCityCount,
                sub: '방문한 도시',
                percent: (visitedCityCount / totalCityCount * 100).round(),
              ),
              const SizedBox(height: 20),
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: SizedBox(
                  height: 350,
                  child: AbsorbPointer(child: DomesticMapPage()),
                ),
              ),
              const SizedBox(height: 24),
              _TravelSummaryCard(userId: userId),
            ],
          ),
        );
      },
    );
  }
}

// =======================================================
// 🇰🇷 국내 여행 요약 카드 (그대로)
// =======================================================
class _TravelSummaryCard extends StatelessWidget {
  final String userId;

  const _TravelSummaryCard({required this.userId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _getTravelSummary(userId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final summary = snapshot.data!;

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.lightSurface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('여행 요약', style: AppTextStyles.sectionTitle),
              const SizedBox(height: 12),
              Text('여행 횟수: ${summary['travelCount']}회'),
              Text('총 여행 일수: ${summary['travelDays']}일'),
              Text('가장 많이 간 지역: ${summary['mostVisitedRegion']}'),
            ],
          ),
        );
      },
    );
  }

  Future<Map<String, dynamic>> _getTravelSummary(String userId) async {
    final travelCount = await DomesticTravelSummaryService.getTravelCount(
      userId: userId,
      isDomestic: true,
      isCompleted: true,
    );

    final totalTravelDays =
        await DomesticTravelSummaryService.getTotalTravelDays(
          userId: userId,
          isDomestic: true,
          isCompleted: true,
        );

    final mostVisitedRegion =
        await DomesticTravelSummaryService.getMostVisitedRegion(
          userId: userId,
          isDomestic: true,
          isCompleted: true,
        );

    return {
      'travelCount': travelCount,
      'travelDays': totalTravelDays,
      'mostVisitedRegion': mostVisitedRegion,
    };
  }
}

// =======================================================
// 🧩 도넛 카드 (그대로)
// =======================================================
class _TotalDonutCard extends StatelessWidget {
  final int visited;
  final int total;
  final String title;
  final String sub;
  final int percent;

  const _TotalDonutCard({
    required this.visited,
    required this.total,
    this.title = 'In Total',
    required this.sub,
    required this.percent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.lightSurface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.caption),
                const SizedBox(height: 8),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '$visited',
                        style: AppTextStyles.pageTitle.copyWith(fontSize: 32),
                      ),
                      TextSpan(
                        text: ' / $total',
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(sub, style: AppTextStyles.caption),
              ],
            ),
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: total == 0 ? 0 : visited / total,
                strokeWidth: 8,
                backgroundColor: Colors.grey.shade300,
                color: AppColors.primary,
              ),
              Text('$percent%'),
            ],
          ),
        ],
      ),
    );
  }
}
