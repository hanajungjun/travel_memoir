import 'package:flutter/material.dart';

import 'package:travel_memoir/services/travel_day_service.dart';
import 'package:travel_memoir/features/travel_day/pages/travel_day_page.dart';
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
  late Map<String, dynamic> _travel;

  /// 날짜별 일기 캐시
  Map<String, Map<String, dynamic>?> _diaryCache = {};
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

    final writtenDays = _diaryCache.values
        .where((e) => e != null && (e['text'] ?? '').toString().isNotEmpty)
        .length;

    final isDomestic = _travel['travel_type'] == 'domestic';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // =====================================================
          // 🔵 헤더
          // =====================================================
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
                        isDomestic
                            ? _travel['region_name']
                            : _travel['country_name'],
                        style: AppTextStyles.pageTitle.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ),
                    RichText(
                      text: TextSpan(
                        style: AppTextStyles.body.copyWith(color: Colors.white),
                        children: [
                          TextSpan(
                            text: '$writtenDays',
                            style: TextStyle(
                              color: writtenDays == totalDays
                                  ? Colors.white
                                  : const Color(0xFFFFD54F),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const TextSpan(text: ' / '),
                          TextSpan(text: '$totalDays 작성'),
                        ],
                      ),
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

          // =====================================================
          // 📓 일차 리스트
          // =====================================================
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
                      final hasDiary =
                          diary != null &&
                          (diary['text'] ?? '').toString().isNotEmpty;

                      final imageUrl = diary == null
                          ? null
                          : TravelDayService.getAiImageUrl(
                              travelId: _travel['id'],
                              date: date,
                            );

                      return Column(
                        children: [
                          InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () async {
                              final placeName = isDomestic
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
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                children: [
                                  imageUrl != null
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          child: Image.network(
                                            '$imageUrl?ts=${DateTime.now().millisecondsSinceEpoch}',
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${DateUtilsHelper.formatMonthDay(date)} · ${dayIndex}일차',
                                          style: AppTextStyles.bodyMuted,
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
                                        : (isDomestic
                                              ? AppColors.textDisabled
                                              : AppColors.decoPurple),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (index != totalDays - 1)
                            Divider(
                              height: 16,
                              thickness: 0.6,
                              color: AppColors.divider,
                            ),
                        ],
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
