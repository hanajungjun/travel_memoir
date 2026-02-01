import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';

import 'package:travel_memoir/models/country_model.dart';
import 'package:travel_memoir/services/travel_create_service.dart';
import 'package:travel_memoir/features/travel_info/pages/overseas_travel_country_page.dart';

import 'package:travel_memoir/core/widgets/range_calendar_page.dart';
import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/shared/styles/text_styles.dart';

import 'package:flutter_svg/flutter_svg.dart'; // SVG 아이콘을 사용하기 위해 추가

class OverseasTravelDatePage extends StatefulWidget {
  const OverseasTravelDatePage({super.key});

  @override
  State<OverseasTravelDatePage> createState() => _OverseasTravelDatePageState();
}

class _OverseasTravelDatePageState extends State<OverseasTravelDatePage> {
  DateTime? _startDate;
  DateTime? _endDate;
  CountryModel? _country;

  bool get _canCreate =>
      _startDate != null && _endDate != null && _country != null;

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

  Future<void> _pickCountry() async {
    final result = await Navigator.push<CountryModel>(
      context,
      MaterialPageRoute(
        builder: (_) => const OverseasTravelCountryPage(),
        fullscreenDialog: true,
      ),
    );

    if (result != null) {
      setState(() => _country = result);
    }
  }

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
    const themeColor = AppColors.travelingPurple;

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
                        'assets/icons/ico_Abroad.svg', // 원하는 위치 아이콘으로 변경
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
                          'overseas_travel'.tr(),
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
                        Padding(
                          padding: const EdgeInsets.only(
                            left: 6,
                          ), // 하단 패딩값을 줄여줌
                          child: Text(
                            'when_is_trip'.tr(),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 7),
                        _buildInputField(
                          text: _startDate == null || _endDate == null
                              ? 'select_date_hint'
                                    .tr() // ✅ 번역 적용
                              : '${DateFormat('yyyy.MM.dd').format(_startDate!)} - ${DateFormat('yyyy.MM.dd').format(_endDate!)}',
                          isSelected: _startDate != null,
                          onTap: _pickDateRange,
                        ),

                        const SizedBox(height: 20),
                        Padding(
                          padding: const EdgeInsets.only(
                            left: 6,
                          ), // 하단 패딩값을 줄여줌
                          child: Text(
                            'where_did_you_go'.tr(),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildInputField(
                          text:
                              _country?.displayName() ??
                              'select_country_hint'.tr(), // ✅ 번역 적용
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

          GestureDetector(
            onTap: _canCreate ? _createTravel : null,
            child: Container(
              width: double.infinity,
              height: 58,
              color: _canCreate ? themeColor : const Color(0xFFCACBCC),
              child: Center(
                child: Text(
                  'save_as_memory'.tr(), // ✅ 번역 적용
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
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
}
