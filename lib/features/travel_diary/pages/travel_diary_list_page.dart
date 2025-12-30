import 'package:flutter/material.dart';

import 'package:travel_memoir/services/travel_day_service.dart';
import 'package:travel_memoir/features/travel_day/pages/travel_day_page.dart';
import 'package:travel_memoir/core/utils/date_utils.dart';

import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/shared/styles/text_styles.dart';

class TravelDiaryListPage extends StatefulWidget {
  final Map<String, dynamic> travel;

  const TravelDiaryListPage({super.key, required this.travel});

  @override
  State<TravelDiaryListPage> createState() => _TravelDiaryListPageState();
}

class _TravelDiaryListPageState extends State<TravelDiaryListPage> {
  late Map<String, dynamic> _travel;

  /// 🔥 날짜별 일기 캐시
  Map<String, Map<String, dynamic>?> _diaryCache = {};

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _travel = widget.travel;
    _loadAllDiaries();
  }

  // ======================
  // 🔥 모든 날짜 일기 한 번에 로드
  // ======================
  Future<void> _loadAllDiaries() async {
    setState(() => _loading = true);

    final startDate = DateTime.parse(_travel['start_date']);
    final endDate = DateTime.parse(_travel['end_date']);
    final totalDays = endDate.difference(startDate).inDays + 1;

    final Map<String, Map<String, dynamic>?> temp = {};

    for (int i = 0; i < totalDays; i++) {
      final date = startDate.add(Duration(days: i));
      final diary = await TravelDayService.getDiaryByDate(
        travelId: _travel['id'],
        date: date,
      );

      final key = DateUtilsHelper.formatYMD(date);
      temp[key] = diary;
    }

    if (!mounted) return;
    setState(() {
      _diaryCache = temp;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final startDate = DateTime.parse(_travel['start_date']);
    final endDate = DateTime.parse(_travel['end_date']);
    final totalDays = endDate.difference(startDate).inDays + 1;

    final isFinished = DateTime.now().isAfter(endDate);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pop(true);
          },
        ),
        title: Row(
          children: [
            Text(
              _travel['travel_type'] == 'domestic'
                  ? '${_travel['region_name']} 여행 기록'
                  : '${_travel['country_name']} 여행 기록',
              style: AppTextStyles.appBarTitle,
            ),
            const SizedBox(width: 8),
            if (isFinished) const _FinishedBadge(),
          ],
        ),
      ),

      // 🔥🔥🔥 여기부터 추가된 부분
      body: Column(
        children: [
          // ===== 디버그 페이지 라벨 =====
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 4),
            color: Colors.black.withOpacity(0.04),
            child: const Text(
              'PAGE: TravelDiaryListPage',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ),

          // ===== 기존 body =====
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: totalDays,
                    itemBuilder: (context, index) {
                      final date = startDate.add(Duration(days: index));
                      final dayIndex = index + 1;

                      final diary =
                          _diaryCache[DateUtilsHelper.formatYMD(date)];
                      final hasDiary =
                          diary != null &&
                          (diary['text'] ?? '').toString().isNotEmpty;

                      final imageUrl = diary == null
                          ? null
                          : TravelDayService.getAiImageUrl(
                              travelId: _travel['id'],
                              date: date,
                            );

                      return InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () async {
                          final placeName = _travel['travel_type'] == 'domestic'
                              ? _travel['region_name']
                              : _travel['country_name'];

                          final changed = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TravelDayPage(
                                travelId: _travel['id'],
                                placeName: placeName,
                                startDate: startDate,
                                endDate: endDate,
                                date: date,
                              ),
                            ),
                          );

                          if (changed == true && mounted) {
                            await _loadAllDiaries();
                          }
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              if (imageUrl != null)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.network(
                                    '$imageUrl?ts=${DateTime.now().millisecondsSinceEpoch}',
                                    width: 56,
                                    height: 56,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => _emptyThumb(),
                                  ),
                                )
                              else
                                _emptyThumb(),

                              const SizedBox(width: 14),

                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${DateUtilsHelper.formatMonthDay(date)} · ${dayIndex}일차',
                                      style: AppTextStyles.caption,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      hasDiary
                                          ? (diary!['text'] as String)
                                                .split('\n')
                                                .first
                                          : '아직 작성하지 않았어요',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: hasDiary
                                          ? AppTextStyles.body
                                          : AppTextStyles.bodyMuted,
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(width: 8),

                              Icon(
                                hasDiary ? Icons.check_circle : Icons.edit,
                                color: hasDiary
                                    ? AppColors.success
                                    : AppColors.textDisabled,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _emptyThumb() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: AppColors.divider,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(Icons.image_not_supported, color: Colors.grey),
    );
  }
}

// ==============================
// 🔒 여행 완료 배지
// ==============================
class _FinishedBadge extends StatelessWidget {
  const _FinishedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.divider,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '여행완료',
        style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}
