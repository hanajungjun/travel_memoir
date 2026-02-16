import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:io';
import 'package:travel_memoir/features/my/pages/my_travels/tabs/domestic_summary_tab.dart';
import 'package:travel_memoir/features/my/pages/my_travels/tabs/overseas_summary_tab.dart';
import 'package:travel_memoir/features/my/pages/my_travels/tabs/usa_summary_tab.dart';
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
    _loadActiveMaps();
  }

  /// 🗺️ 현재 선택된 코드에 따른 아이콘 경로 반환
  String _getAppBarIconPath() {
    switch (_selectedCountryCode) {
      case 'KOREA':
        return 'assets/icons/ico_Local.svg';
      case 'USA':
        return 'assets/icons/ico_State.svg';
      case 'WORLD':
      default:
        return 'assets/icons/ico_Abroad.svg';
    }
  }

  /// 🎨 현재 선택된 코드에 따른 테마 색상 반환
  Color _getAppBarIconColor() {
    switch (_selectedCountryCode) {
      case 'KOREA':
        return const Color(0xFF3498DB); // Blue
      case 'USA':
        return const Color(0xFFE74C3C); // Red
      case 'WORLD':
      default:
        return const Color(0xFF6C5CE7); // Purple
    }
  }

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

  void _showCountryPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      // ✅ 추가: SafeArea 영역까지 포함
      isScrollControlled: true,
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
              _buildCountryItem(
                'WORLD',
                'world',
                'assets/icons/ico_Abroad.svg',
                const Color(0xFF6C5CE7),
              ),
              _buildCountryItem(
                'KOREA',
                'korea',
                'assets/icons/ico_Local.svg',
                const Color(0xFF3498DB),
              ),
              if (_activeMaps.contains('us'))
                _buildCountryItem(
                  'USA',
                  'usa',
                  'assets/icons/ico_State.svg',
                  const Color(0xFFE74C3C),
                ),
              if (_activeMaps.contains('jp'))
                _buildCountryItem(
                  'JAPAN',
                  'japan',
                  'assets/icons/ico_Local.svg',
                  Colors.teal,
                ),
              if (_activeMaps.contains('it'))
                _buildCountryItem(
                  'ITALY',
                  'italy',
                  'assets/icons/ico_Local.svg',
                  Colors.teal,
                ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MapManagementPage(),
                    ),
                  ).then((_) => _loadActiveMaps());
                },
                child: Text(
                  'get_more_maps'.tr(),
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
              // ✅ 기존 패턴 그대로!
              SizedBox(
                height: Platform.isIOS
                    ? 0
                    : MediaQuery.of(context).padding.bottom,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCountryItem(
    String code,
    String nameKey,
    String iconPath,
    Color iconColor,
  ) {
    final bool isSelected = _selectedCountryCode == code;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      leading: SvgPicture.asset(
        iconPath,
        width: 24,
        height: 24,
        // ignore: deprecated_member_use
        color: isSelected ? iconColor : Colors.grey.withOpacity(0.5),
      ),
      title: Text(
        nameKey.tr(),
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.black : Colors.black87,
          fontSize: 16,
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
            // 🎯 현재 선택된 지도에 맞춰 아이콘과 색상이 바뀝니다.
            icon: SvgPicture.asset(
              _getAppBarIconPath(),
              width: 24,
              height: 24,
              // ignore: deprecated_member_use
              color: _getAppBarIconColor(),
            ),
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
