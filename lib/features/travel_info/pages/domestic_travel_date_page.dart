import 'package:flutter/material.dart';

import 'package:travel_memoir/services/travel_create_service.dart';
import 'package:travel_memoir/features/travel_diary/pages/travel_diary_list_page.dart';
import 'package:travel_memoir/features/travel_info/sheets/domestic_city_select_sheet.dart';

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

  // ===== 날짜 선택 =====
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

  // ===== 도시 선택 =====
  Future<void> _pickCity() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) {
        return DomesticCitySelectSheet(
          onSelected: (city) {
            setState(() {
              _city = city;
            });
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('국내 여행')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 📅 날짜
            const Text(
              '여행 날짜',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: _pickDateRange,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _startDate == null || _endDate == null
                      ? '날짜를 선택해주세요'
                      : '${_startDate!.year}.${_startDate!.month}.${_startDate!.day}'
                            ' ~ '
                            '${_endDate!.year}.${_endDate!.month}.${_endDate!.day}',
                ),
              ),
            ),

            const SizedBox(height: 32),

            // 📍 도시
            const Text(
              '도시',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: _pickCity,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(_city ?? '도시를 선택해주세요'),
              ),
            ),

            const Spacer(),

            // 👉 다음 → 여행 기록 목록으로
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _canNext
                    ? () async {
                        final travel =
                            await TravelCreateService.createDomesticTravel(
                              city: _city!,
                              startDate: _startDate!,
                              endDate: _endDate!,
                            );

                        if (!mounted) return;

                        // 🔥 여기 핵심 수정
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TravelDiaryListPage(travel: travel),
                          ),
                        );
                      }
                    : null,
                child: const Text('여행 생성', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
