import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // 📅 날짜 포맷을 위해 필요
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:travel_memoir/models/country_model.dart';
import 'package:travel_memoir/services/travel_create_service.dart';
import 'package:travel_memoir/features/travel_info/pages/overseas_travel_country_page.dart';

// ✅ 국내여행과 동일한 커스텀 달력 페이지 import
import 'package:travel_memoir/core/widgets/range_calendar_page.dart';

import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/shared/styles/text_styles.dart';

class OverseasTravelDatePage extends StatefulWidget {
  const OverseasTravelDatePage({super.key});

  @override
  State<OverseasTravelDatePage> createState() => _OverseasTravelDatePageState();
}

class _OverseasTravelDatePageState extends State<OverseasTravelDatePage> {
  DateTime? _startDate;
  DateTime? _endDate;
  CountryModel? _country;

  // 생성 가능 조건: 날짜와 국가가 모두 선택되었을 때
  bool get _canCreate =>
      _startDate != null && _endDate != null && _country != null;

  // =====================================================
  // 📅 날짜 선택 (국내여행과 동일한 커스텀 달력 연결)
  // =====================================================
  Future<void> _pickDateRange() async {
    final DateTimeRange? range = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CustomRangeCalendarPage(),
        fullscreenDialog: true, // 아래에서 위로 올라오는 애니메이션
      ),
    );

    if (range == null) return;

    setState(() {
      _startDate = range.start;
      _endDate = range.end;
    });
  }

  // =====================================================
  // 🌍 국가 선택 (아래에서 위로 올라오는 모달 방식)
  // =====================================================
  Future<void> _pickCountry() async {
    final result = await Navigator.push<CountryModel>(
      context,
      MaterialPageRoute(
        builder: (_) => const OverseasTravelCountryPage(),
        fullscreenDialog: true, // 🔥 다음 장이 아닌 모달(아래->위)로 띄움
      ),
    );

    if (result != null) {
      setState(() => _country = result);
    }
  }

  // 🚀 여행 생성
  Future<void> _createTravel() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final travel = await TravelCreateService.createOverseasTravel(
      userId: user.id,
      country: _country!,
      startDate: _startDate!,
      endDate: _endDate!,
    );

    if (!mounted) return;
    Navigator.pop(context, travel);
  }

  @override
  Widget build(BuildContext context) {
    const themeColor = Color(0xFF4A90E2); // 해외여행 포인트 컬러

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
                  // 상단 헤더 (아이콘 + 타이틀)
                  Row(
                    children: [
                      const Icon(
                        Icons.public_rounded, // 지구본 아이콘
                        color: themeColor,
                        size: 32,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        '해외여행',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: themeColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),

                  // 🏳️‍🌈 입력 카드 영역
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
                          onTap: _pickDateRange,
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
                          text: _country?.displayName() ?? '기억에 남길 국가를 선택해주세요',
                          isSelected: _country != null,
                          onTap: _pickCountry,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 하단 고정 버튼
          GestureDetector(
            onTap: _canCreate ? _createTravel : null,
            child: Container(
              width: double.infinity,
              height: 70,
              color: _canCreate ? themeColor : themeColor.withOpacity(0.4),
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

  // 공통 입력 필드 위젯 (국내여행 소스 스타일 적용)
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
