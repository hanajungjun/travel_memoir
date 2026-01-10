import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart'; // 추가
import 'package:travel_memoir/features/my/pages/my_travels/tabs/domestic_summary_tab.dart';
import 'package:travel_memoir/features/my/pages/my_travels/tabs/overseas_summary_tab.dart';

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
        title: Text('my_travels'.tr()), // ✅ 번역 적용
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'domestic'.tr()), // ✅ 번역 적용
            Tab(text: 'overseas'.tr()), // ✅ 번역 적용
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          DomesticSummaryTab(userId: _userId),
          OverseasSummaryTab(userId: _userId),
        ],
      ),
    );
  }
}
