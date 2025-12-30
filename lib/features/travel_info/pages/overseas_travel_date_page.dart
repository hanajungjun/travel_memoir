import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:travel_memoir/models/country_model.dart';
import 'package:travel_memoir/services/travel_create_service.dart';

import 'package:travel_memoir/features/travel_info/pages/overseas_travel_country_page.dart';

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

  // =========================
  // 📅 날짜 선택
  // =========================
  Future<void> _pickDateRange() async {
    final now = DateTime.now();

    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
    );

    if (range == null) return;

    setState(() {
      _startDate = range.start;
      _endDate = range.end;
    });
  }

  // =========================
  // 🌍 국가 선택
  // =========================
  Future<void> _pickCountry() async {
    final result = await Navigator.push<CountryModel>(
      context,
      MaterialPageRoute(builder: (_) => const OverseasTravelCountryPage()),
    );

    if (result != null) {
      setState(() => _country = result);
    }
  }

  // =========================
  // 🚀 여행 생성 (🔥 핵심 수정)
  // =========================
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

    // ❗❗ 절대 push 하지 말 것
    // ❗❗ 스택을 건드리지 말고 결과만 반환
    Navigator.pop(context, travel);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('해외 여행', style: AppTextStyles.appBarTitle),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('여행 날짜', style: AppTextStyles.sectionTitle),
            const SizedBox(height: 8),

            _SelectBox(
              text: _startDate == null || _endDate == null
                  ? '날짜를 선택해주세요'
                  : '${_startDate!.year}.${_startDate!.month}.${_startDate!.day}'
                        ' ~ '
                        '${_endDate!.year}.${_endDate!.month}.${_endDate!.day}',
              onTap: _pickDateRange,
            ),

            const SizedBox(height: 32),

            Text('국가', style: AppTextStyles.sectionTitle),
            const SizedBox(height: 8),

            _SelectBox(
              text: _country == null ? '국가를 선택해주세요' : _country!.displayName(),
              onTap: _pickCountry,
            ),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _canCreate ? _createTravel : null,
                child: const Text('여행 생성', style: AppTextStyles.button),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==============================
// 🔹 공통 선택 박스
class _SelectBox extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const _SelectBox({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider),
        ),
        child: Text(text, style: AppTextStyles.body),
      ),
    );
  }
}
