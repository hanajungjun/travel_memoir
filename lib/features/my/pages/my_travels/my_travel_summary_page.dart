import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';

import 'package:travel_memoir/features/my/pages/my_travels/tabs/domestic_summary_tab.dart';
import 'package:travel_memoir/features/my/pages/my_travels/tabs/overseas_summary_tab.dart';
import 'package:travel_memoir/features/my/pages/my_travels/tabs/usa_summary_tab.dart';

class MyTravelSummaryPage extends StatefulWidget {
  const MyTravelSummaryPage({super.key});

  @override
  State<MyTravelSummaryPage> createState() => _MyTravelSummaryPageState();
}

class _MyTravelSummaryPageState extends State<MyTravelSummaryPage> {
  String? _userId;

  // 🎯 현재 선택된 지도 코드
  String _selectedCountryCode = 'WORLD';
  // 🎯 이름 대신 '번역 키(Key)'를 저장합니다.
  String _selectedCountryKey = 'world';

  @override
  void initState() {
    super.initState();
    // 로그인 유저 확인
    final currentUser = Supabase.instance.client.auth.currentUser;
    _userId = currentUser?.id;
  }

  // 🗺️ 통합 지도 선택 바텀 시트
  void _showCountryPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'select_map'.tr(), // "지도를 선택하세요"
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),

              // 🌍 다국어 키를 전달하도록 수정
              _buildCountryItem('WORLD', 'world', Icons.public),
              _buildCountryItem('KOREA', 'korea', Icons.map_outlined),
              _buildCountryItem('USA', 'usa', Icons.map_outlined),
              _buildCountryItem('JAPAN', 'japan', Icons.map_outlined),

              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  // 바텀 시트 내 각 국가 아이템
  // name 대신 nameKey를 받습니다.
  Widget _buildCountryItem(String code, String nameKey, IconData icon) {
    final bool isSelected = _selectedCountryCode == code;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      leading: Icon(icon, color: isSelected ? Colors.black : Colors.grey),
      title: Text(
        nameKey.tr(), // 🎯 여기서 번역 적용
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.black : Colors.black87,
        ),
      ),
      trailing: isSelected
          ? const Icon(Icons.check, color: Colors.black)
          : null,
      onTap: () {
        setState(() {
          _selectedCountryCode = code;
          _selectedCountryKey = nameKey; // 키를 저장
        });
        Navigator.pop(context);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_userId == null) {
      return Scaffold(
        appBar: AppBar(title: Text('my_travels'.tr())),
        body: Center(child: Text('login_required'.tr())),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        centerTitle: true,
        // 🎯 현재 선택된 키를 번역하여 타이틀 구성
        title: Text(
          '${_selectedCountryKey.tr()} ${'summary'.tr()}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.map_outlined, size: 26),
            onPressed: _showCountryPicker,
            tooltip: 'change_map'.tr(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _buildCurrentContent(),
      ),
    );
  }

  Widget _buildCurrentContent() {
    switch (_selectedCountryCode) {
      case 'KOREA':
        return DomesticSummaryTab(
          key: const ValueKey('KOREA_TAB'),
          userId: _userId!,
        );

      case 'USA':
        return UsaSummaryTab(key: const ValueKey('USA_TAB'), userId: _userId!);

      case 'WORLD':
      default:
        return OverseasSummaryTab(
          key: const ValueKey('WORLD_TAB'),
          userId: _userId!,
        );
    }
  }
}
