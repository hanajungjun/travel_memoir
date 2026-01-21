import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
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
  List<Map<String, dynamic>> _diaries = [];
  bool _loading = true;
  bool _isChanged = false;

  @override
  void initState() {
    super.initState();
    _travel = widget.travel;
    _loadAllDiaries();
  }

  Future<void> _loadAllDiaries() async {
    setState(() => _loading = true);
    try {
      final response = await Supabase.instance.client
          .from('travel_days')
          .select()
          .eq('travel_id', _travel['id'])
          .order('day_index', ascending: true);

      if (!mounted) return;

      setState(() {
        _diaries = List<Map<String, dynamic>>.from(response);
        _loading = false;
        _isChanged = false;
      });
    } catch (e) {
      debugPrint('❌ Data load error: $e');
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

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('save_reorder_success'.tr())));
      await _loadAllDiaries();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('save_reorder_error'.tr(args: [e.toString()])),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final startDate = DateTime.parse(_travel['start_date']);

    // ✅ 여행 타입 구분 (domestic, usa, overseas)
    final travelType = _travel['travel_type'] ?? '';
    final isDomestic = travelType == 'domestic';
    final isUSA = travelType == 'usa';

    final bool isKo = context.locale.languageCode == 'ko';

    String title = '';

    // ✅ 미국 여행이거나 한국 여행일 때 region_name(예: Colorado, 경기도)을 제목으로 사용
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
      backgroundColor: const Color(0xFFF8F9FA),
      body: Column(
        children: [
          _buildHeader(travelType, title), // ✅ travelType 전달하여 색상 결정
          Expanded(
            child: _loading
                ? const TravelDiaryListSkeleton()
                : ReorderableListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 27,
                      vertical: 21,
                    ),
                    itemCount: _diaries.length,
                    buildDefaultDragHandles: false,
                    onReorder: _onReorder,

                    // ✅ 드래그 중 카드 스타일 제어 (핵심)
                    proxyDecorator: (child, index, animation) {
                      return AnimatedBuilder(
                        animation: animation,
                        builder: (context, _) {
                          return Material(
                            color: Colors.transparent, // ❌ 배경 제거
                            elevation: 8, // ✅ 그림자만
                            shadowColor: Colors.black.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                            child: child,
                          );
                        },
                      );
                    },
                    itemBuilder: (context, index) {
                      final diary = _diaries[index];
                      final displayDate = startDate.add(Duration(days: index));
                      final dayIndex = index + 1;
                      final text = diary['text']?.toString().trim() ?? '';
                      final hasDiary = text.isNotEmpty;

                      String? imageUrl;
                      if (hasDiary) {
                        final rawUrl = TravelDayService.getAiImageUrl(
                          travelId: _travel['id'].toString(),
                          diaryId: diary['id'].toString(),
                        );

                        if (rawUrl != null) {
                          imageUrl =
                              '$rawUrl?t=${DateTime.now().millisecondsSinceEpoch}';
                        }
                      }

                      return Slidable(
                        key: ValueKey(diary['id']),
                        endActionPane: ActionPane(
                          motion: const StretchMotion(),
                          extentRatio: 0.22,
                          children: [
                            SlidableAction(
                              onPressed: (context) async {
                                final diaryData = _diaries[index];
                                final messenger = ScaffoldMessenger.of(context);

                                final bool? confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: Text('delete_diary_title'.tr()),
                                    content: Text('delete_diary_confirm'.tr()),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        child: Text('cancel'.tr()),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                        child: Text(
                                          'delete'.tr(),
                                          style: const TextStyle(
                                            color: Colors.red,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );

                                if (confirm != true || !mounted) return;

                                setState(() => _loading = true);
                                try {
                                  await TravelDayService.clearDiaryRecord(
                                    travelId: _travel['id'],
                                    date: diaryData['date'],
                                    photoUrls: diaryData['photo_urls'],
                                  );
                                  await _loadAllDiaries();
                                  if (mounted)
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'diary_reset_success'.tr(),
                                        ),
                                      ),
                                    );
                                } catch (e) {
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text('delete_error'.tr()),
                                    ),
                                  );
                                } finally {
                                  if (mounted) setState(() => _loading = false);
                                }
                              },
                              backgroundColor: AppColors.error,
                              foregroundColor: Colors.white,
                              icon: Icons.delete,
                              borderRadius: BorderRadius.circular(20),
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
                            if (changed == true && mounted)
                              await _loadAllDiaries();
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
        ],
      ),
      floatingActionButton: _isChanged
          ? Padding(
              padding: const EdgeInsets.only(
                bottom: 5, // ✅ ADD 버튼과 동일
                right: 2,
              ),
              child: Material(
                color: Colors.transparent,
                elevation: 14, // ✅ 그림자 동일
                shadowColor: Colors.black.withOpacity(0.25),
                shape: const CircleBorder(),
                child: FloatingActionButton(
                  elevation: 0, // Material이 그림자 담당
                  backgroundColor: travelType == 'domestic'
                      ? AppColors
                            .travelingBlue // 🇰🇷 국내
                      : travelType == 'usa'
                      ? const Color(0xFFE74C3C) // 🇺🇸 미국 레드
                      : AppColors.travelingPurple, // 🌍 해외 보라
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(50),
                  ),
                  onPressed: _saveChanges,
                  child: const Icon(Icons.check, color: Colors.white, size: 28),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildHeader(String travelType, String title) {
    final writtenCount = _diaries
        .where((e) => e['text'].toString().isNotEmpty)
        .length;
    final totalCount = _diaries.length;
    final isCompleted = totalCount > 0 && writtenCount == totalCount;

    // ✅ 미국(Red), 한국(Blue), 세계(Purple) 구분
    Color primaryColor;
    Color secondaryColor;
    String badgeLabel;

    if (travelType == 'usa') {
      primaryColor = const Color(0xFFE74C3C); // 미국 레드
      badgeLabel = 'usa'.tr();
    } else if (travelType == 'domestic') {
      primaryColor = AppColors.travelingBlue; // 한국 블루
      badgeLabel = 'domestic'.tr();
    } else {
      primaryColor = AppColors.travelingPurple; // 세계 퍼플
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
                  // ✅ Localization에서 {0} 여행 형태로 정의되어 있다면 Colorado 여행으로 표시됨
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
                    // ✅ 작성된 개수
                    TextSpan(
                      text: writtenCount.toString(),
                      style: TextStyle(
                        fontWeight: isCompleted
                            ? FontWeight.w300
                            : FontWeight.w700,
                        color: isCompleted
                            ? Colors.white.withOpacity(0.6)
                            : const Color(0xFFFFD64E), // ⭐ 작성 중 강조
                      ),
                    ),

                    // ✅ /
                    TextSpan(
                      text: '/',
                      style: TextStyle(color: Colors.white.withOpacity(0.6)),
                    ),

                    // ✅ 전체 개수
                    TextSpan(
                      text: totalCount.toString(),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontWeight: FontWeight.w300,
                      ),
                    ),

                    const TextSpan(text: ' '),

                    // ✅ "작성" / "written"
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
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
        ],
      ),
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
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          imageUrl != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: Image.network(
                    imageUrl,
                    width: 46,
                    height: 46,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) =>
                        loadingProgress == null ? child : _emptyThumb(),
                    errorBuilder: (_, __, ___) => _emptyThumb(),
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
                    fontWeight: FontWeight.w300, // 레귤러
                  ),
                ),
                const SizedBox(height: 0),
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
            child: Padding(
              padding: const EdgeInsets.all(5.20),
              child: Image.asset(
                'assets/icons/ico_Drag.png', // ✅ 네가 만든 드래그 아이콘
                width: 13, // 필요하면 조절
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
}

class _TypeBadge extends StatelessWidget {
  final String label;
  const _TypeBadge({required this.label});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 2, 6, 4),
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
