import 'package:flutter/material.dart';

import 'package:travel_memoir/services/travel_day_service.dart';
import 'package:travel_memoir/features/travel_day/pages/travel_day_page.dart'
    hide TravelDayService;

import 'package:travel_memoir/core/utils/date_utils.dart';
import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/shared/styles/text_styles.dart';
import 'package:travel_memoir/core/widgets/skeletons/travel_diary_list_skeleton.dart';

class TravelDiaryListPage extends StatefulWidget {
  final Map<String, dynamic> travel;

  const TravelDiaryListPage({super.key, required this.travel});

  @override
  State<TravelDiaryListPage> createState() => _TravelDiaryListPageState();
}

class _TravelDiaryListPageState extends State<TravelDiaryListPage> {
  late final Map<String, dynamic> _travel;

  /// 날짜별 일기 캐시 (느슨하게)
  final Map<String, Map<String, dynamic>?> _diaryCache = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _travel = widget.travel;
    _loadAllDiaries();
  }

  Future<void> _loadAllDiaries() async {
    setState(() => _loading = true);

    final startDate = DateTime.parse(_travel['start_date']);
    final endDate = DateTime.parse(_travel['end_date']);
    final totalDays = endDate.difference(startDate).inDays + 1;

    _diaryCache.clear();

    for (int i = 0; i < totalDays; i++) {
      final date = startDate.add(Duration(days: i));
      final diary = await TravelDayService.getDiaryByDate(
        travelId: _travel['id'],
        date: date,
      );

      _diaryCache[DateUtilsHelper.formatYMD(date)] = diary;
    }

    if (!mounted) return;
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final startDate = DateTime.parse(_travel['start_date']);
    final endDate = DateTime.parse(_travel['end_date']);
    final totalDays = endDate.difference(startDate).inDays + 1;

    final writtenDays = _diaryCache.values.where((e) {
      final text = e?['text']?.toString().trim() ?? '';
      return text.isNotEmpty;
    }).length;

    final isDomestic = _travel['travel_type'] == 'domestic';

    final title = (_travel['title'] ?? '여행').toString();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // =====================
          // 헤더
          // =====================
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 56, 20, 20),
            color: isDomestic ? AppColors.primary : AppColors.decoPurple,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _TypeBadge(label: isDomestic ? '국내' : '해외'),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: AppTextStyles.pageTitle.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Text(
                      '$writtenDays / $totalDays',
                      style: AppTextStyles.body.copyWith(color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${_travel['start_date']} ~ ${_travel['end_date']}',
                  style: AppTextStyles.bodyMuted.copyWith(
                    color: Colors.white.withOpacity(0.85),
                  ),
                ),
              ],
            ),
          ),

          // =====================
          // 리스트
          // =====================
          Expanded(
            child: _loading
                ? const TravelDiaryListSkeleton()
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: totalDays,
                    itemBuilder: (context, index) {
                      final date = startDate.add(Duration(days: index));
                      final dayIndex = index + 1;

                      final diary =
                          _diaryCache[DateUtilsHelper.formatYMD(date)];

                      final text = diary?['text']?.toString().trim() ?? '';

                      final hasDiary = text.isNotEmpty;

                      final imageUrl = hasDiary
                          ? TravelDayService.getAiImageUrl(
                              travelId: _travel['id'],
                              date: date,
                            )
                          : null;

                      return InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () async {
                          final changed = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TravelDayPage(
                                travelId: _travel['id'],
                                placeName: title,
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
                              imageUrl != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: Image.network(
                                        imageUrl,
                                        width: 56,
                                        height: 56,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            _emptyThumb(),
                                      ),
                                    )
                                  : _emptyThumb(),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${DateUtilsHelper.formatMonthDay(date)} · ${dayIndex}일차',
                                      style: AppTextStyles.bodyMuted,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      hasDiary
                                          ? text.split('\n').first
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
      child: const Icon(Icons.image, color: Colors.grey),
    );
  }
}

// =====================================================
// 🔖 국내 / 해외 뱃지
// =====================================================
class _TypeBadge extends StatelessWidget {
  final String label;

  const _TypeBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}
