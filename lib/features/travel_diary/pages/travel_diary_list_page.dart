import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cached_network_image/cached_network_image.dart'; // ✅ 추가
import 'package:travel_memoir/services/travel_day_service.dart';
import 'package:travel_memoir/services/travel_complete_service.dart'; // ✅ 추가
import 'package:travel_memoir/features/travel_day/pages/travel_day_page.dart'
    hide TravelDayService;
import 'package:travel_memoir/core/utils/date_utils.dart';
import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/shared/styles/text_styles.dart';
import 'package:travel_memoir/core/widgets/skeletons/travel_diary_list_skeleton.dart';
import 'package:travel_memoir/core/widgets/popup/app_toast.dart';

class TravelDiaryListPage extends StatefulWidget {
  final Map<String, dynamic> travel;
  const TravelDiaryListPage({super.key, required this.travel});

  @override
  State<TravelDiaryListPage> createState() => _TravelDiaryListPageState();
}

class _TravelDiaryListPageState extends State<TravelDiaryListPage> {
  late final Map<String, dynamic> _travel;
  List<Map<String, dynamic>> _diaries = [];
  bool _loading = true;
  bool _isChanged = false;
  late String _imageTimestamp;

  @override
  void initState() {
    super.initState();
    _travel = widget.travel;
    _updateTimestamp();
    _loadAllDiaries();
  }

  void _updateTimestamp() {
    _imageTimestamp = DateTime.now().millisecondsSinceEpoch.toString();
  }

  Future<void> _loadAllDiaries() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final response = await Supabase.instance.client
          .from('travel_days')
          .select()
          .eq('travel_id', _travel['id'])
          .order('day_index', ascending: true);

      if (!mounted) return;

      _updateTimestamp();
      setState(() {
        _diaries = List<Map<String, dynamic>>.from(response);
        _loading = false;
        _isChanged = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _diaries.removeAt(oldIndex);
      _diaries.insert(newIndex, item);
      _isChanged = true;
    });
  }

  Future<void> _saveChanges() async {
    setState(() => _loading = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final startDate = DateTime.parse(_travel['start_date']);

      for (int i = 0; i < _diaries.length; i++) {
        final tempDate = startDate.add(Duration(days: i + 5000));
        await Supabase.instance.client
            .from('travel_days')
            .update({
              'day_index': -(i + 1000),
              'date': DateUtilsHelper.formatYMD(tempDate),
            })
            .eq('id', _diaries[i]['id']);
      }

      for (int i = 0; i < _diaries.length; i++) {
        final newDate = startDate.add(Duration(days: i));
        await Supabase.instance.client
            .from('travel_days')
            .update({
              'day_index': i + 1,
              'date': DateUtilsHelper.formatYMD(newDate),
            })
            .eq('id', _diaries[i]['id']);
      }
      // ✅ [방어 코드 추가] 모든 비동기 작업이 끝난 후 체크
      if (!mounted) return;

      AppToast.show(context, 'save_reorder_success'.tr());
      await _loadAllDiaries();
    } catch (e) {
      // 에러 발생 시에도 화면이 살아있을 때만 토스트 노출
      if (!mounted) return;
      AppToast.error(context, 'save_reorder_error'.tr(args: [e.toString()]));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final startDate = DateTime.parse(_travel['start_date']);
    final travelType = _travel['travel_type'] ?? '';
    final isDomestic = travelType == 'domestic';
    final isUSA = travelType == 'usa';
    final bool isKo = context.locale.languageCode == 'ko';

    String title = '';
    if (isUSA || isDomestic) {
      title =
          _travel['region_name'] ??
          (isKo ? (isUSA ? '미국' : '국내') : (isUSA ? 'USA' : 'Domestic'));
    } else {
      title = isKo
          ? (_travel['country_name_ko'] ?? 'travel'.tr())
          : (_travel['country_name_en'] ??
                _travel['country_code'] ??
                'travel'.tr());
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      body: Column(
        children: [
          _buildHeader(travelType, title),
          Expanded(
            child: _loading
                ? const TravelDiaryListSkeleton()
                : SlidableAutoCloseBehavior(
                    child: ReorderableListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 27,
                        vertical: 21,
                      ),
                      itemCount: _diaries.length,
                      buildDefaultDragHandles: false,
                      onReorder: _onReorder,
                      itemBuilder: (context, index) {
                        final diary = _diaries[index];
                        final displayDate = startDate.add(
                          Duration(days: index),
                        );
                        final dayIndex = index + 1;
                        final text = diary['text']?.toString().trim() ?? '';
                        final hasDiary = text.isNotEmpty;

                        String? imageUrl;
                        if (hasDiary) {
                          final userId = _travel['user_id']?.toString();
                          final travelId = _travel['id']?.toString();
                          final diaryId = diary['id']?.toString();

                          if (userId != null &&
                              travelId != null &&
                              diaryId != null) {
                            final rawUrl = TravelDayService.getAiImageUrl(
                              userId: userId,
                              travelId: travelId,
                              diaryId: diaryId,
                            );
                            if (rawUrl != null && rawUrl.isNotEmpty) {
                              // ✅ [해결 1] 서버 측 리사이징 적용 (width=100)
                              imageUrl =
                                  '$rawUrl?t=$_imageTimestamp&width=100&quality=20';
                            }
                          }
                        }

                        return Slidable(
                          key: ValueKey(diary['id']),
                          endActionPane: ActionPane(
                            motion: const BehindMotion(),
                            extentRatio: 0.22,
                            children: [
                              CustomSlidableAction(
                                onPressed: (_) async {
                                  final messenger = ScaffoldMessenger.of(
                                    context,
                                  );
                                  await TravelDayService.clearDiaryRecord(
                                    userId: _travel['user_id'],
                                    travelId: _travel['id'],
                                    date: diary['date'],
                                    photoPaths: List<String>.from(
                                      diary['photo_urls'] ?? [],
                                    ),
                                  );
                                  // 🎯 [핵심 수정] 삭제 작업이 끝난 후 화면이 아직 살아있는지 확인합니다.
                                  if (!mounted) return;

                                  AppToast.show(
                                    context,
                                    'diary_clear_success'.tr(),
                                  );
                                  await _loadAllDiaries();
                                },
                                backgroundColor: Colors.transparent,
                                padding: const EdgeInsets.only(left: 6),
                                child: Center(
                                  child: Container(
                                    width: 52,
                                    height: 52,
                                    decoration: BoxDecoration(
                                      color: AppColors.error,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    alignment: Alignment.center,
                                    child: Image.asset(
                                      'assets/icons/ico_delete.png',
                                      width: 19,
                                      height: 19,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          child: GestureDetector(
                            onTap: () async {
                              final changed = await Navigator.push<bool>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => TravelDayPage(
                                    travelId: _travel['id'],
                                    placeName: title,
                                    startDate: startDate,
                                    endDate: startDate.add(
                                      Duration(days: _diaries.length - 1),
                                    ),
                                    date: displayDate,
                                    initialDiary: diary,
                                  ),
                                ),
                              );
                              if (changed == true && mounted) {
                                await _loadAllDiaries();
                                // ✅ [해결 2] 돌아오자마자 여행 완료 여부 체크!
                                await TravelCompleteService.tryCompleteTravel(
                                  travelId: _travel['id'],
                                  startDate: startDate,
                                  endDate: startDate.add(
                                    Duration(days: _diaries.length - 1),
                                  ),
                                );
                              }
                            },
                            child: _buildListItem(
                              diary,
                              displayDate,
                              dayIndex,
                              hasDiary,
                              text,
                              imageUrl,
                              index,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: _isChanged
          ? FloatingActionButton(
              backgroundColor: isDomestic
                  ? AppColors.travelingBlue
                  : isUSA
                  ? AppColors.travelingRed
                  : AppColors.travelingPurple,
              onPressed: _saveChanges,
              child: const Icon(Icons.check, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildListItem(
    Map<String, dynamic> diary,
    DateTime date,
    int dayIndex,
    bool hasDiary,
    String text,
    String? imageUrl,
    int index,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.fromLTRB(15, 15, 0, 15),
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
      child: Row(
        children: [
          imageUrl != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: CachedNetworkImage(
                    // ✅ [해결 3] CachedNetworkImage로 교체
                    imageUrl: imageUrl,
                    width: 46,
                    height: 46,
                    fit: BoxFit.cover,
                    memCacheWidth: 92, // ✅ [해결 4] 메모리 다이어트 (약 2.5배수)
                    placeholder: (context, url) => _emptyThumb(),
                    errorWidget: (context, url, error) => _emptyThumb(),
                    fadeInDuration: const Duration(milliseconds: 300),
                  ),
                )
              : _emptyThumb(),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${DateUtilsHelper.formatMonthDay(date)} · ${'travel_day_unit'.tr(args: [dayIndex.toString()])}',
                  style: AppTextStyles.bodyMuted.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w300,
                  ),
                ),
                Text(
                  hasDiary ? text.split('\n').first : 'please_write_diary'.tr(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body.copyWith(
                    fontWeight: hasDiary ? FontWeight.w700 : FontWeight.w300,
                    color: hasDiary
                        ? AppColors.textColor01
                        : AppColors.textColor07,
                  ),
                ),
              ],
            ),
          ),
          ReorderableDragStartListener(
            index: index,
            child: Container(
              color: Colors.transparent,
              padding: const EdgeInsets.fromLTRB(20, 20, 27, 20),
              child: Image.asset(
                'assets/icons/ico_Drag.png',
                width: 13,
                height: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyThumb() => Container(
    width: 46,
    height: 46,
    decoration: BoxDecoration(borderRadius: BorderRadius.circular(5)),
    child: Image.asset('assets/icons/noImage.png', width: 46, height: 46),
  );

  Widget _buildHeader(String travelType, String title) {
    final writtenCount = _diaries
        .where((e) => e['text'].toString().isNotEmpty)
        .length;
    final totalCount = _diaries.length;
    final isCompleted = totalCount > 0 && writtenCount == totalCount;

    Color primaryColor;
    String badgeLabel;

    if (travelType == 'usa') {
      primaryColor = AppColors.travelingRed;
      badgeLabel = 'usa'.tr();
    } else if (travelType == 'domestic') {
      primaryColor = AppColors.travelingBlue;
      badgeLabel = 'domestic'.tr();
    } else {
      primaryColor = AppColors.travelingPurple;
      badgeLabel = 'overseas'.tr();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(27, 70, 30, 20),
      decoration: BoxDecoration(color: primaryColor),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _TypeBadge(label: badgeLabel),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'travel_diary_list_title'.tr(args: [title]),
                  style: AppTextStyles.pageTitle.copyWith(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              RichText(
                text: TextSpan(
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w300,
                  ),
                  children: [
                    TextSpan(
                      text: writtenCount.toString(),
                      style: TextStyle(
                        fontWeight: isCompleted
                            ? FontWeight.w300
                            : FontWeight.w700,
                        color: isCompleted
                            ? Colors.white.withOpacity(0.6)
                            : const Color(0xFFFFD64E),
                      ),
                    ),
                    TextSpan(
                      text: '/',
                      style: TextStyle(color: Colors.white.withOpacity(0.6)),
                    ),
                    TextSpan(
                      text: totalCount.toString(),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                    const TextSpan(text: ' '),
                    TextSpan(
                      text: 'written_suffix'.tr(),
                      style: TextStyle(color: Colors.white.withOpacity(0.6)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '${_travel['start_date'].toString().replaceAll('-', '.')} ~ ${_travel['end_date'].toString().replaceAll('-', '.')}',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 14,
              fontWeight: FontWeight.w200,
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final String label;
  const _TypeBadge({required this.label});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 3, 6, 1),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.15),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: Colors.white,
        ),
      ),
    );
  }
}
