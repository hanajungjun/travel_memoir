import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';

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
  String? _userId;

  @override
  void initState() {
    super.initState();

    // 탭: 해외 / 국내
    _tabController = TabController(length: 2, vsync: this);

    // 로그인 유저 확인
    final currentUser = Supabase.instance.client.auth.currentUser;
    _userId = currentUser?.id;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ❗ 유저 없으면 요약 페이지 자체를 그리지 않음
    if (_userId == null) {
      return Scaffold(
        appBar: AppBar(title: Text('my_travels'.tr())),
        body: Center(
          child: Text(
            'login_required'.tr(),
            style: const TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        centerTitle: true,
        title: Text(
          'my_travels'.tr(),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.black,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.black,
          indicatorWeight: 3,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
          tabs: [
            Tab(text: 'overseas'.tr()),
            Tab(text: 'domestic'.tr()),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        physics: const BouncingScrollPhysics(),
        children: [
          // 🌏 해외 요약
          OverseasSummaryTab(userId: _userId!),

          // 🇰🇷 국내 요약
          DomesticSummaryTab(userId: _userId!),
        ],
      ),
    );
  }
}
