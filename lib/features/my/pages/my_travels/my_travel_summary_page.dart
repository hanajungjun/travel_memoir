import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';

// ✅ 기존 탭 임포트
import 'package:travel_memoir/features/my/pages/my_travels/tabs/domestic_summary_tab.dart';
import 'package:travel_memoir/features/my/pages/my_travels/tabs/overseas_summary_tab.dart';
import 'package:travel_memoir/features/my/pages/my_travels/tabs/usa_summary_tab.dart';

// ✅ 지도 관리 페이지 임포트 (목록 갱신 테스트용)
import 'package:travel_memoir/features/my/pages/map_management/map_management_page.dart';

class MyTravelSummaryPage extends StatefulWidget {
  const MyTravelSummaryPage({super.key});

  @override
  State<MyTravelSummaryPage> createState() => _MyTravelSummaryPageState();
}

class _MyTravelSummaryPageState extends State<MyTravelSummaryPage> {
  String? _userId;
  String _selectedCountryCode = 'WORLD';
  String _selectedCountryKey = 'world';

  // ✅ 유저가 구매/활성화한 지도 목록 저장
  Set<String> _activeMaps = {};

  @override
  void initState() {
    super.initState();
    final currentUser = Supabase.instance.client.auth.currentUser;
    _userId = currentUser?.id;

    // 🎯 초기 데이터 로드
    _loadActiveMaps();
  }

  /// ✅ Supabase에서 구매한 지도 목록 가져오기
  Future<void> _loadActiveMaps() async {
    if (_userId == null) return;

    try {
      final res = await Supabase.instance.client
          .from('users')
          .select('active_maps')
          .eq('auth_uid', _userId!)
          .maybeSingle();

      if (res != null && res['active_maps'] != null) {
        setState(() {
          _activeMaps = (res['active_maps'] as List)
              .map((e) => e.toString().toLowerCase())
              .toSet();
        });
      }
    } catch (e) {
      debugPrint('❌ 지도 목록 로드 에러: $e');
    }
  }

  /// 🗺️ 통합 지도 선택 바텀 시트 (구매 필터링 적용)
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
                'select_map'.tr(),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),

              // 🌍 기본 지도 (항상 노출)
              _buildCountryItem('WORLD', 'world', Icons.public),
              _buildCountryItem('KOREA', 'korea', Icons.map_outlined),

              // 🎯 구매한 지도만 리스트에 추가
              if (_activeMaps.contains('us'))
                _buildCountryItem('USA', 'usa', Icons.map_outlined),
              if (_activeMaps.contains('jp'))
                _buildCountryItem('JAPAN', 'japan', Icons.map_outlined),
              if (_activeMaps.contains('it'))
                _buildCountryItem('ITALY', 'italy', Icons.map_outlined),

              const SizedBox(height: 12),

              // 💡 지도가 더 필요할 때 바로 갈 수 있는 버튼 (선택사항)
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MapManagementPage(),
                    ),
                  ).then((_) => _loadActiveMaps()); // 돌아오면 목록 새로고침
                },
                child: Text(
                  'get_more_maps'.tr(),
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCountryItem(String code, String nameKey, IconData icon) {
    final bool isSelected = _selectedCountryCode == code;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      leading: Icon(icon, color: isSelected ? Colors.black : Colors.grey),
      title: Text(
        nameKey.tr(),
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
          _selectedCountryKey = nameKey;
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
