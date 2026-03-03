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
  // String _getAppBarIconPath() {
  //   switch (_selectedCountryCode) {
  //     case 'KOREA':
  //       return 'assets/icons/ico_Local.svg';
  //     case 'USA':
  //       return 'assets/icons/ico_State.svg';
  //     case 'WORLD':
  //     default:
  //       return 'assets/icons/ico_Abroad.svg';
  //   }
  // }

  // /// 🎨 현재 선택된 코드에 따른 테마 색상 반환
  // Color _getAppBarIconColor() {
  //   switch (_selectedCountryCode) {
  //     case 'KOREA':
  //       return const Color(0xFF3498DB); // Blue
  //     case 'USA':
  //       return const Color(0xFFE74C3C); // Red
  //     case 'WORLD':
  //     default:
  //       return const Color(0xFF6C5CE7); // Purple
  //   }
  // }

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
      backgroundColor: Colors.white, // 배경 흰색
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)), // 상단 라운드
      ),
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.fromLTRB(0, 24, 0, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            // 🎯 [수정] 자식들을 왼쪽(start)으로 정렬합니다.
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 타이틀: 지도 선택
              // 🎯 [수정] 타이틀이 리스트 아이템들과 줄이 맞도록 좌측 패딩을 줬어.
              Padding(
                padding: const EdgeInsets.only(left: 30),
                child: Text(
                  'select_map'.tr(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              // 점선 구분선
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 25),
                child: _DashedDivider(),
              ),
              const SizedBox(height: 12),

              // 지도 리스트 아이템들 (기존 로직 유지)
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

              const SizedBox(height: 13),

              // 하단 알약 모양 버튼 (새로운 지도 추가)
              Padding(
                padding: const EdgeInsets.all(0),
                child: Container(
                  // SizedBox 대신 Container나 Align을 써서 중앙 정렬 유지
                  alignment: Alignment.center,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MapManagementPage(),
                        ),
                      ).then((_) => _loadActiveMaps());
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFC2C2C2), // 회색 버튼
                      elevation: 0,
                      shape: const StadiumBorder(), // 알약 모양
                      // 🎯 [수정] 텍스트를 기준으로 안쪽 패딩을 설정합니다. (가로 20, 세로 10)
                      padding: const EdgeInsets.fromLTRB(17, 9, 20, 9),
                      minimumSize: Size.zero, // 기본 최소 크기 제한 해제
                      tapTargetSize:
                          MaterialTapTargetSize.shrinkWrap, // 클릭 영역을 버튼 크기에 맞춤
                    ),
                    child: Row(
                      // 🎯 [수정] Row가 가로를 꽉 채우지 않고 콘텐츠(텍스트+아이콘)만큼만 차지하게 합니다.
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.add, color: Colors.white, size: 19),
                        const SizedBox(width: 4),
                        Text(
                          'get_more_maps'.tr(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
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
      // 1️⃣ [좌우 패딩] 유지하면서 위아래 패딩은 0으로 고정
      contentPadding: const EdgeInsets.symmetric(horizontal: 30, vertical: 0),

      // 2️⃣ [아이콘-글자 간격] 기본값이 넓어서 10 정도로 줄여버려
      horizontalTitleGap: 10,

      // 3️⃣ [아이콘 영역 최소 너비] 이걸 0으로 잡아야 아이콘 너비만큼만 딱 차지해
      minLeadingWidth: 0,

      // 4️⃣ [전체적인 압축] dense를 true로 하고 visualDensity를 낮춰서 위아래 간격을 바싹 붙여
      dense: true,
      visualDensity: const VisualDensity(vertical: 0),

      leading: SvgPicture.asset(
        iconPath,
        width: 20,
        height: 20,
        // ignore: deprecated_member_use
        color: isSelected ? iconColor : const Color(0xFF949494),
      ),
      title: Text(
        nameKey.tr(),
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w300,
          color: isSelected ? const Color(0xFF2B2B2B) : const Color(0xFF949494),
          fontSize: 16,
        ),
      ),

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
      backgroundColor: const Color(0xFFF6F6F6), // ✅ 배경은 회색 (지도 영역)
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(27, 18, 20, 5),
              child: SizedBox(
                height: 48,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // 중앙 제목
                    Text(
                      _selectedCountryKey.tr(),
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                    // 우측 리스트 버튼
                    Positioned(
                      top: 1,
                      right: 0,
                      child: IconButton(
                        // ✅ 기존 Icons.menu 대신 직접 만드신 SVG 아이콘을 넣었습니다.
                        icon: SvgPicture.asset('assets/icons/ico_mapList.svg'),
                        onPressed: _showCountryPicker,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // ❷ 메인 영역 (진한 회색 위에 준의 진짜 로직이 바로 출력됨!)
            // ✅ 말씀하신 대로 중복되는 통계 정보는 빼고, 탭 내용만 바로 보여줍니다.
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, animation) =>
                    FadeTransition(opacity: animation, child: child),
                layoutBuilder: (currentChild, previousChildren) => Stack(
                  alignment: Alignment.topCenter, // ← 상단 정렬!
                  children: [
                    ...previousChildren,
                    if (currentChild != null) currentChild,
                  ],
                ),
                child: _buildCurrentContent(),
              ),
            ),
          ],
        ),
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

class _DashedDivider extends StatelessWidget {
  const _DashedDivider();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(0),
      child: CustomPaint(
        size: const Size(double.infinity, 1),
        painter: DashedLinePainter(),
      ),
    );
  }
}

class DashedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    double dashWidth = 3, dashSpace = 3, startX = 0;
    final paint = Paint()
      ..color = const Color(0xFFD9D9D9)
      ..strokeWidth = 1.2;
    while (startX < size.width) {
      canvas.drawLine(Offset(startX, 0), Offset(startX + dashWidth, 0), paint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
