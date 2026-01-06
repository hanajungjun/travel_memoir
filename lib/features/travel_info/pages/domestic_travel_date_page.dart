import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:travel_memoir/core/constants/korea/korea_region.dart';
import 'package:travel_memoir/services/travel_create_service.dart';
import 'package:travel_memoir/features/travel_diary/pages/travel_diary_list_page.dart';
import 'package:travel_memoir/features/travel_info/sheets/domestic_city_select_sheet.dart';

import 'package:travel_memoir/core/widgets/range_calendar_page.dart';
import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/shared/styles/text_styles.dart';

class DomesticTravelDatePage extends StatefulWidget {
  const DomesticTravelDatePage({super.key});

  @override
  State<DomesticTravelDatePage> createState() => _DomesticTravelDatePageState();
}

class _DomesticTravelDatePageState extends State<DomesticTravelDatePage> {
  DateTime? _startDate;
  DateTime? _endDate;
  KoreaRegion? _region;

  bool get _canNext =>
      _startDate != null && _endDate != null && _region != null;

  // =====================================================
  // 📅 날짜 선택 (🔥 새로 만든 커스텀 달력 페이지 연결)
  // =====================================================
  Future<void> _pickDateRange() async {
    // 🚀 Navigator.push를 통해 우리가 만든 예쁜 달력 화면으로 이동합니다.
    final DateTimeRange? range = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CustomRangeCalendarPage(),
        fullscreenDialog: true, // 밑에서 위로 올라오는 모달 애니메이션
      ),
    );

    if (range == null) return;

    setState(() {
      _startDate = range.start;
      _endDate = range.end;
    });
  }

  // =========================
  // 📍 도시 선택 (BottomSheet)
  // =========================
  Future<void> _pickCity() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (_) {
        return DomesticCitySelectSheet(
          onSelected: (region) {
            setState(() => _region = region);
          },
        );
      },
    );
  }

  // =========================
  // 🚀 여행 생성 및 이동
  // =========================
  Future<void> _createTravel() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final travel = await TravelCreateService.createDomesticTravel(
      userId: user.id,
      region: _region!,
      startDate: _startDate!,
      endDate: _endDate!,
    );

    if (!mounted) return;

    Navigator.of(context).popUntil((route) => route.isFirst);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TravelDiaryListPage(travel: travel)),
    );
  }

  @override
  Widget build(BuildContext context) {
    const themeColor = Color(0xFF3498DB);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_rounded,
                        color: themeColor,
                        size: 32,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '국내여행',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: themeColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),

                  // 🏳️‍🌈 메인 입력 카드
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '언제의 여행인가요?',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildInputField(
                          text: _startDate == null || _endDate == null
                              ? '이 여행의 날짜를 골라주세요'
                              : '${DateFormat('yyyy.MM.dd').format(_startDate!)} - ${DateFormat('yyyy.MM.dd').format(_endDate!)}',
                          isSelected: _startDate != null,
                          onTap: _pickDateRange, // 🔥 수정된 함수 호출
                        ),

                        const SizedBox(height: 24),

                        const Text(
                          '어디로 떠났나요?',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildInputField(
                          text: _region?.name ?? '기억에 남길 도시를 선택해주세요',
                          isSelected: _region != null,
                          onTap: _pickCity,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          GestureDetector(
            onTap: _canNext ? _createTravel : null,
            child: Container(
              width: double.infinity,
              height: 70,
              color: _canNext ? themeColor : themeColor.withOpacity(0.4),
              child: const Center(
                child: Text(
                  '기억으로 남기기',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required String text,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: const Color(0xFFEEEEEE), width: 1.5),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 15,
            color: isSelected ? Colors.black87 : Colors.black26,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
