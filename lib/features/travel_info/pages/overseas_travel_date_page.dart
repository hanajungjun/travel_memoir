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
                        Icons.public_rounded,
                        color: themeColor,
                        size: 32,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'overseas_travel'.tr(), // ✅ 번역 적용
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          color: themeColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
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
                          'when_is_trip'.tr(), // ✅ 번역 적용
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildInputField(
                          text: _startDate == null || _endDate == null
                              ? 'select_date_hint'
                                    .tr() // ✅ 번역 적용
                              : '${DateFormat('yyyy.MM.dd').format(_startDate!)} - ${DateFormat('yyyy.MM.dd').format(_endDate!)}',
                          isSelected: _startDate != null,
                          onTap: _pickDateRange,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'where_did_you_go'.tr(), // ✅ 번역 적용
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
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
              height: 70,
              color: _canCreate ? themeColor : themeColor.withOpacity(0.4),
              child: Center(
                child: Text(
                  'save_as_memory'.tr(), // ✅ 번역 적용
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
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
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
