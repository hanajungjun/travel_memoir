import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';

import 'package:travel_memoir/core/constants/korea/korea_region.dart';
import 'package:travel_memoir/services/travel_create_service.dart';
import 'package:travel_memoir/features/travel_diary/pages/travel_diary_list_page.dart';
import 'package:travel_memoir/features/travel_info/sheets/domestic_city_select_sheet.dart';

import 'package:travel_memoir/core/widgets/range_calendar_page.dart';
import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/shared/styles/text_styles.dart';

class DomesticTravelDatePage extends StatefulWidget {
  const DomesticTravelDatePage({super.key});

  // ❌ [주의] StatefulWidget 클래스 내부의 build 메서드는 삭제해야 합니다.
  // 여기서 자기 자신을 return하면 무한 루프가 발생해서 앱이 터집니다.

  @override
  State<DomesticTravelDatePage> createState() => _DomesticTravelDatePageState();
}

class _DomesticTravelDatePageState extends State<DomesticTravelDatePage> {
  DateTime? _startDate;
  DateTime? _endDate;
  KoreaRegion? _region;

  bool get _canNext =>
      _startDate != null && _endDate != null && _region != null;

  // 📅 날짜 선택 (커스텀 달력 페이지 연결)
  Future<void> _pickDateRange() async {
    final DateTimeRange? range = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CustomRangeCalendarPage(),
        fullscreenDialog: true,
      ),
    );

    if (range == null) return;

    setState(() {
      _startDate = range.start;
      _endDate = range.end;
    });
  }

  // 📍 도시 선택 (BottomSheet)
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

  // 🚀 여행 생성 및 이동
  Future<void> _createTravel() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    // TravelCreateService 내부에서 이제 region_key(YEOJU 등)를
    // 자동으로 추출해서 DB와 Storage 경로를 만듭니다.
    final travel = await TravelCreateService.createDomesticTravel(
      userId: user.id,
      region: _region!,
      startDate: _startDate!,
      endDate: _endDate!,
    );

    if (!mounted) return;

    // 메인으로 돌아갔다가 일기 목록으로 이동
    Navigator.of(context).popUntil((route) => route.isFirst);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TravelDiaryListPage(travel: travel)),
    );
  }

  @override
  Widget build(BuildContext context) {
    const themeColor = Color(0xFF3498DB);
    final bool isKo = context.locale.languageCode == 'ko';

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
                        'domestic_travel'.tr(),
                        style: const TextStyle(
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
                        Text(
                          'when_is_trip'.tr(),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildInputField(
                          text: _startDate == null || _endDate == null
                              ? 'select_date_hint'.tr()
                              : '${DateFormat('yyyy.MM.dd').format(_startDate!)} - ${DateFormat('yyyy.MM.dd').format(_endDate!)}',
                          isSelected: _startDate != null,
                          onTap: _pickDateRange,
                        ),

                        const SizedBox(height: 24),

                        Text(
                          'where_did_you_go'.tr(),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildInputField(
                          // ✅ [다국어 대응] 한국어면 name, 영어면 nameEn(대문자) 표시
                          text: _region == null
                              ? 'select_city_hint'.tr()
                              : (isKo ? _region!.name : _region!.nameEn),
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
              child: Center(
                child: Text(
                  'save_as_memory'.tr(),
                  style: const TextStyle(
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
