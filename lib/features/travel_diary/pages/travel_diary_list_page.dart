import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
      debugPrint('❌ 데이터 로드 에러: $e');
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

      // 🚀 [1단계] 충돌 방지를 위한 대피 (인덱스 음수 & 미래 날짜)
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

      // 🚀 [2단계] 실제 순서 주입
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
      ).showSnackBar(const SnackBar(content: Text('순서 변경사항이 저장되었습니다.')));
      await _loadAllDiaries();
    } catch (e) {
      debugPrint('❌ 저장 에러: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('저장 오류: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final startDate = DateTime.parse(_travel['start_date']);
    final isDomestic = _travel['travel_type'] == 'domestic';
    final bool isKo =
        View.of(context).platformDispatcher.locale.languageCode == 'ko';

    final title =
        _travel['region_name'] ??
        (isKo ? _travel['country_name_ko'] : _travel['country_name_en']) ??
        '여행';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Column(
        children: [
          _buildHeader(isDomestic, title),
          Expanded(
            child: _loading
                ? const TravelDiaryListSkeleton()
                : ReorderableListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 20,
                    ),
                    itemCount: _diaries.length,
                    buildDefaultDragHandles: false,
                    onReorder: _onReorder,
                    itemBuilder: (context, index) {
                      final diary = _diaries[index];
                      final displayDate = startDate.add(Duration(days: index));
                      final dayIndex = index + 1;
                      final text = diary['text']?.toString().trim() ?? '';
                      final hasDiary = text.isNotEmpty;

                      String? imageUrl;
                      if (hasDiary) {
                        final rawUrl = TravelDayService.getAiImageUrl(
                          travelId: _travel['id'],
                          diaryId: diary['id'],
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
                              // 🔥 [수정 핵심] onPressed 로직 전면 개편
                              onPressed: (context) async {
                                final diaryData = _diaries[index];
                                // ✅ 1. 비동기 작업 전 Messenger 미리 확보 (에러 방지)
                                final messenger = ScaffoldMessenger.of(context);

                                // 2. 삭제 확인 창
                                final bool? confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('기록 삭제'),
                                    content: const Text(
                                      '해당 일의 일기 내용과 이미지가 모두 삭제됩니다.\n정말 삭제하시겠습니까?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        child: const Text('취소'),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                        child: const Text(
                                          '삭제',
                                          style: TextStyle(color: Colors.red),
                                        ),
                                      ),
                                    ],
                                  ),
                                );

                                if (confirm != true || !mounted) return;

                                setState(() => _loading = true);

                                try {
                                  // ✅ 3. DB 로우는 남기고 내용만 초기화 (removeAt 제거)
                                  // TravelDayService 내부에서 is_completed: false 처리 필수
                                  await TravelDayService.clearDiaryRecord(
                                    travelId: _travel['id'],
                                    date: diaryData['date'],
                                    photoUrls: diaryData['photo_urls'],
                                  );

                                  // 4. 데이터 새로고침
                                  await _loadAllDiaries();

                                  // ✅ 5. 미리 받아둔 messenger로 스낵바 표시 (안전)
                                  if (mounted) {
                                    messenger.showSnackBar(
                                      const SnackBar(
                                        content: Text('일기 기록이 초기화되었습니다.'),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  debugPrint('❌ 초기화 에러: $e');
                                  messenger.showSnackBar(
                                    const SnackBar(
                                      content: Text('삭제 중 오류가 발생했습니다.'),
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
          ? FloatingActionButton.extended(
              onPressed: _saveChanges,
              backgroundColor: AppColors.travelingBlue,
              elevation: 4,
              icon: const Icon(Icons.check, color: Colors.white),
              label: const Text(
                '변경사항 저장',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : null,
    );
  }

  // _buildHeader, _buildListItem, _emptyThumb, _TypeBadge 등은 기존과 동일하므로 코드 양 조절을 위해 생략 가능하나,
  // 전체 요청이셨으므로 그대로 포함하여 제공합니다.

  Widget _buildHeader(bool isDomestic, String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 30),
      color: isDomestic ? AppColors.travelingBlue : AppColors.decoPurple,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _TypeBadge(label: isDomestic ? '국내' : '해외'),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.pageTitle.copyWith(
                    color: Colors.white,
                    fontSize: 22,
                  ),
                ),
              ),
              Text(
                '${_diaries.where((e) => e['text'].toString().isNotEmpty).length}/${_diaries.length} 작성',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${_travel['start_date']} ~ ${_travel['end_date']}',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
            ),
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
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          imageUrl != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    imageUrl,
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) =>
                        loadingProgress == null ? child : _emptyThumb(),
                    errorBuilder: (_, __, ___) => _emptyThumb(),
                  ),
                )
              : _emptyThumb(),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${DateUtilsHelper.formatMonthDay(date)} · $dayIndex일차',
                  style: AppTextStyles.bodyMuted.copyWith(fontSize: 13),
                ),
                const SizedBox(height: 6),
                Text(
                  hasDiary ? text.split('\n').first : '일기를 작성해주세요',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body.copyWith(
                    fontWeight: hasDiary ? FontWeight.bold : FontWeight.normal,
                    color: hasDiary ? Colors.black87 : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          ReorderableDragStartListener(
            index: index,
            child: const Padding(
              padding: EdgeInsets.all(8.0),
              child: Icon(Icons.menu, color: Color(0xFFE0E0E0), size: 24),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyThumb() => Container(
    width: 64,
    height: 64,
    decoration: BoxDecoration(
      color: const Color(0xFFF1F3F5),
      borderRadius: BorderRadius.circular(12),
    ),
    child: const Icon(Icons.image_outlined, color: Color(0xFFADB5BD), size: 28),
  );
}

class _TypeBadge extends StatelessWidget {
  final String label;
  const _TypeBadge({required this.label});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }
}
