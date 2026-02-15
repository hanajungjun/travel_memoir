import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';

import 'package:travel_memoir/models/country_model.dart';
import 'package:travel_memoir/services/travel_create_service.dart';
import 'package:travel_memoir/core/widgets/range_calendar_page.dart';
import 'package:travel_memoir/features/travel_diary/pages/travel_diary_list_page.dart';

import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/shared/styles/text_styles.dart';
import 'package:flutter_svg/flutter_svg.dart'; // SVG 아이콘을 사용하기 위해 추가

class USTravelDatePage extends StatefulWidget {
  const USTravelDatePage({super.key});

  @override
  State<USTravelDatePage> createState() => _USTravelDatePageState();
}

class _USTravelDatePageState extends State<USTravelDatePage> {
  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedState; // 🎯 여기서 선택된 주 이름이 저장됩니다.

  final CountryModel _usa = CountryModel(
    code: 'US',
    nameEn: 'United States',
    nameKo: '미국',
    lat: 37.0902,
    lng: -95.7129,
    continent: 'North America',
    flagUrl: 'https://flagcdn.com/w320/us.png',
  );

  bool get _canCreate =>
      _startDate != null && _endDate != null && _selectedState != null;

  Future<void> _pickState() async {
    try {
      final String response = await rootBundle.loadString(
        'assets/geo/processed/usa_states_standard.json',
      );
      final dynamic decodedData = json.decode(response);
      List<dynamic> stateFeatures =
          (decodedData is Map && decodedData.containsKey('features'))
          ? decodedData['features']
          : decodedData;

      if (!mounted) return;

      final String? result = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        useSafeArea: false,
        backgroundColor: Colors.transparent,
        builder: (context) => _StateSearchBottomSheet(features: stateFeatures),
      );

      if (result != null) setState(() => _selectedState = result);
    } catch (e) {
      debugPrint("❌ Error loading states: $e");
    }
  }

  Future<void> _pickDateRange() async {
    final DateTimeRange? range = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CustomRangeCalendarPage(travelType: 'us'),
        fullscreenDialog: true,
      ),
    );
    if (range != null) {
      setState(() {
        _startDate = range.start;
        _endDate = range.end;
      });
    }
  }

  Future<void> _createTravel() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    // 🎯 [핵심 수정] widget.stateName 대신 로컬 변수 _selectedState를 사용합니다.
    final travel = await TravelCreateService.createUSATravel(
      userId: user.id,
      country: _usa,
      regionKey: _selectedState!, // 👈 선택된 주 이름 (예: Arizona)
      stateName: _selectedState!, // 👈 화면 표시용 이름
      startDate: _startDate!,
      endDate: _endDate!,
    );

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => TravelDiaryListPage(travel: travel)),
    );
  }

  @override
  Widget build(BuildContext context) {
    const themeColor = AppColors.travelingRed;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(27, 75, 27, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const SizedBox(width: 5),
                      SvgPicture.asset(
                        'assets/icons/ico_State.svg', // 원하는 위치 아이콘으로 변경
                        color: themeColor,
                        width: 24,
                        height: 24,
                      ),
                      const SizedBox(width: 6),
                      Padding(
                        padding: const EdgeInsets.only(
                          bottom: 2,
                        ), // 하단 패딩값을 줄여줌
                        child: Text(
                          'us_travel'.tr(),
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                            color: themeColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(25),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('when_is_trip'.tr()),
                        _buildInputField(
                          text: _startDate == null
                              ? 'select_date_hint'.tr()
                              : '${DateFormat('yyyy.MM.dd').format(_startDate!)} - ${DateFormat('yyyy.MM.dd').format(_endDate!)}',
                          isSelected: _startDate != null,
                          onTap: _pickDateRange,
                        ),
                        const SizedBox(height: 20),
                        _buildLabel('select_state'.tr()),
                        _buildInputField(
                          text: _selectedState ?? 'select_state_hint'.tr(),
                          isSelected: _selectedState != null,
                          onTap: _pickState,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          _buildSubmitButton(themeColor),
        ],
      ),
    );
  }

  Widget _buildLabel(String label) => Padding(
    padding: const EdgeInsets.only(left: 6, bottom: 8),
    child: Text(
      label,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
    ),
  );

  Widget _buildInputField({
    required String text,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFE7E7E7), width: 1),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 14,
            color: isSelected ? AppColors.textColor01 : const Color(0xFFAAAAAA),
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Widget _buildSubmitButton(Color color) {
    return GestureDetector(
      onTap: _canCreate ? _createTravel : null,
      child: Container(
        width: double.infinity,
        color: _canCreate ? color : const Color(0xFFCACBCC),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 58,
              alignment: Alignment.center,
              child: Text(
                'save_as_memory'.tr(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
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
      ),
    );
  }
}

class _StateSearchBottomSheet extends StatefulWidget {
  final List<dynamic> features;
  const _StateSearchBottomSheet({required this.features});
  @override
  State<_StateSearchBottomSheet> createState() =>
      _StateSearchBottomSheetState();
}

class _StateSearchBottomSheetState extends State<_StateSearchBottomSheet> {
  late List<dynamic> _filteredFeatures;
  final TextEditingController _searchController = TextEditingController();
  @override
  void initState() {
    super.initState();
    _filteredFeatures = widget.features;
  }

  void _runFilter(String query) {
    setState(
      () => _filteredFeatures = query.isEmpty
          ? widget.features
          : widget.features
                .where(
                  (f) =>
                      f['properties']?['NAME']
                          ?.toString()
                          .toLowerCase()
                          .contains(query.toLowerCase()) ??
                      false,
                )
                .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6), // ✅ 배경색 통일
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // 1. 상단 헤더 영역 (닫기 버튼 위치 및 디자인 교체)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                23,
                64,
                32,
                7,
              ), // ✅ 상단 여백 64 반영
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      size: 27,
                      color: Color(0xFF909090),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // 2. 🔍 검색 입력창 (그림자가 있는 카드 디자인 반영)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                27,
                0,
                27,
                30,
              ), // ✅ 좌우 여백 27 반영
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: _runFilter,
                  autofocus: false, // ✅ 자동 포커스 해제 (필요시 true로 변경 가능)
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF333333),
                    fontWeight: FontWeight.w400,
                  ),
                  decoration: InputDecoration(
                    hintText: 'search_state_hint'.tr(),
                    hintStyle: const TextStyle(
                      fontSize: 16,
                      color: Color(0xFFBDBDBD),
                      fontWeight: FontWeight.w400,
                    ),
                    prefixIconConstraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    prefixIcon: Padding(
                      padding: const EdgeInsets.only(left: 15, right: 8),
                      child: SvgPicture.asset(
                        'assets/icons/ico_search.svg', // ✅ SVG 아이콘 적용
                        width: 16,
                        height: 16,
                      ),
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ),

            // 3. 🌍 리스트 영역 (도트 라인 및 여백 반영)
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: 27,
                ), // ✅ 좌우 여백 27 반영
                itemCount: _filteredFeatures.length,
                separatorBuilder: (context, index) => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 2),
                  child: DottedDivider(), // ✅ 도트 라인 적용
                ),
                itemBuilder: (context, index) {
                  final String name =
                      _filteredFeatures[index]['properties']?['NAME'] ??
                      'Unknown';
                  return ListTile(
                    contentPadding: const EdgeInsets.only(
                      left: 5,
                    ), // ✅ 요청하신 왼쪽 여백 5px
                    title: Text(
                      name,
                      style: const TextStyle(
                        fontSize: 15, // ✅ 디자인 가이드에 맞춘 크기
                        color: Color(0xFF333333),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right, // ✅ 디자인 가이드 아이콘
                      color: Color(0xFFD1D1D1),
                    ),
                    onTap: () => Navigator.pop(context, name),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ✅ 도트 라인(점선)을 그리기 위한 위젯
class DottedDivider extends StatelessWidget {
  const DottedDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(double.infinity, 1),
      painter: DashPainter(),
    );
  }
}

class DashPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    double dashWidth = 2, dashSpace = 3, startX = 0;
    final paint = Paint()
      ..color =
          const Color(0xFFD1D1D1) // 이미지와 유사한 연한 회색 점선
      ..strokeWidth = 1;
    while (startX < size.width) {
      canvas.drawLine(Offset(startX, 0), Offset(startX + dashWidth, 0), paint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
