import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:travel_memoir/services/travel_create_service.dart';
import 'package:travel_memoir/features/travel_diary/pages/travel_diary_list_page.dart';
import 'package:travel_memoir/features/travel_info/sheets/domestic_city_select_sheet.dart';

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
  String? _city;

  bool get _canNext => _startDate != null && _endDate != null && _city != null;

  // =========================
  // 📅 날짜 선택
  // =========================
  Future<void> _pickDateRange() async {
    final now = DateTime.now();

    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: AppColors.primary,
              surface: AppColors.surface,
            ),
          ),
          child: child!,
        );
      },
    );

    if (range == null) return;

    setState(() {
      _startDate = range.start;
      _endDate = range.end;
    });
  }

  // =========================
  // 📍 도시 선택
  // =========================
  Future<void> _pickCity() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return DomesticCitySelectSheet(
          onSelected: (city) {
            setState(() => _city = city);
          },
        );
      },
    );
  }

  // =========================
  // 🚀 여행 생성
  // =========================
  Future<void> _createTravel() async {
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      throw Exception('로그인이 필요합니다');
    }

    final travel = await TravelCreateService.createDomesticTravel(
      userId: user.id,
      city: _city!,
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('국내 여행', style: AppTextStyles.appBarTitle),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ======================
            // 📅 날짜
            // ======================
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

            // ======================
            // 📍 도시
            // ======================
            Text('도시', style: AppTextStyles.sectionTitle),
            const SizedBox(height: 8),

            _SelectBox(text: _city ?? '도시를 선택해주세요', onTap: _pickCity),

            const Spacer(),

            // ======================
            // 🚀 여행 생성
            // ======================
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _canNext ? _createTravel : null,
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
// ==============================
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
