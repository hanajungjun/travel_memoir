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

/**
 * 📱 Screen ID : TRAVEL_DIARY_LIST_PAGE
 * 📝 Name      : 내가쓴 여행일기 리스트
 * 🛠 Feature   : 
 * - ReorderableListView 기반의 일기 순서 변경 및 날짜 재할당 로직
 * - Slidable 위젯을 이용한 개별 일기 기록 삭제 (Storage 파일 포함)
 * - CachedNetworkImage 활용 메모리 최적화 및 서버 사이드 이미지 리사이징
 * - 여행 타입(국내/해외/미국)에 따른 유동적 헤더 컬러 및 배지 적용
 * * [ UI Structure ]
 * ----------------------------------------------------------
 * travel_diary_list_page.dart (Scaffold)
 * ├── Column (Body)
 * │    ├── _buildHeader [여행 정보, 작성률(0/0), 날짜 배지]
 * │    └── Expanded [일기 리스트 영역]
 * │         └── ReorderableListView.builder
 * │              └── Slidable [밀어서 삭제]
 * │                   └── _buildListItem [일기 썸네일, 날짜, 본문 요약]
 * └── Positioned (Stack)
 * └── FloatingActionButton [_isChanged 발생 시 '순서 저장' 버튼]
 * ----------------------------------------------------------
 */

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

  Future<void> _loadAllDiaries({bool silent = false}) async {
    if (!mounted) return;

    // 🎯 silent가 아닐 때만 로딩 스켈레톤을 보여줌
    if (!silent) setState(() => _loading = true);

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
      // 이제 _isChanged가 true가 되어도 UI에 버튼은 안 띄울 거야
      _isChanged = true;
    });
    // 🎯 드래그 끝나자마자 로딩 없이 뒤에서 저장
    _saveChanges(silent: true);
  }

  Future<void> _saveChanges({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);

    try {
      final startDate = DateTime.parse(_travel['start_date']);

      // 1단계: 겹치지 않게 임시 날짜와 인덱스로 싹 밀어내기 (미래로 보내버려!)
      for (int i = 0; i < _diaries.length; i++) {
        // 오늘로부터 약 13년 뒤 날짜로 설정해서 기존 날짜와 충돌 방지
        final tempDate = startDate.add(Duration(days: i + 5000));

        await Supabase.instance.client
            .from('travel_days')
            .update({
              'day_index': -(i + 1000),
              'date': DateUtilsHelper.formatYMD(tempDate),
            })
            .eq('id', _diaries[i]['id']);
      }

      // 2단계: 이제 깨끗해진 자리에 실제 순서와 날짜로 확정하기
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
      if (!silent) AppToast.show(context, 'save_reorder_success'.tr());

      await _loadAllDiaries(silent: true);
    } catch (e) {
      debugPrint('❌ 재정렬 최종 실패: $e');
      if (mounted && !silent) AppToast.error(context, 'reorder_failed'.tr());
    } finally {
      if (mounted && !silent) setState(() => _loading = false);
    }
  }

  // ✅ 드래그 시 카드와 그림자만 깔끔하게 보이도록 설정
  Widget _proxyDecorator(Widget child, int index, Animation<double> animation) {
    return AnimatedBuilder(
      animation: animation,
      builder: (BuildContext context, Widget? child) {
        return Material(
          elevation: 0,
          color: Colors.transparent, // 전체 배경을 투명하게 설정
          child: child,
        );
      },
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final startDate = DateTime.parse(_travel['start_date']);
    final travelType = _travel['travel_type'] ?? '';
    final isDomestic = travelType == 'domestic';
    final isUSA = travelType == 'usa';
    final bool isKo = context.locale.languageCode == 'ko';

    // ✅ [추가] build 시작 시점에 미리 추출
    final String currentLanguageCode = context.locale.languageCode;
    String title = _travel['display_name']?.toString() ?? '';

    // 만약 display_name이 없을 때만 (방어 로직) 직접 계산
    if (title.isEmpty) {
      if (isUSA || isDomestic) {
        if (isKo) {
          title = _travel['region_name'] ?? (isUSA ? '미국' : '국내');
        } else {
          final String regId =
              _travel['region_id']?.toString() ??
              _travel['region_key']?.toString() ??
              '';
          if (regId.contains('_')) {
            title = regId.split('_').last.toUpperCase();
          } else {
            title = (_travel['region_name'] ?? (isUSA ? 'USA' : 'Domestic'))
                .toString()
                .toUpperCase();
          }
        }
      } else {
        title = isKo
            ? (_travel['country_name_ko'] ?? 'travel'.tr())
            : (_travel['country_name_en'] ??
                      _travel['country_code'] ??
                      'travel'.tr())
                  .toString()
                  .toUpperCase();
      }
    }
    //print("Final Header Title: $title");
    //print("------------------------------");
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      body: Stack(
        // ✅ 버튼 위치 제약을 풀기 위해 Stack 사용
        children: [
          Column(
            children: [
              _buildHeader(travelType, title),
              Expanded(
                child: _loading
                    ? const TravelDiaryListSkeleton()
                    : SlidableAutoCloseBehavior(
                        child: ReorderableListView.builder(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 27,
                            vertical: 20,
                          ),
                          itemCount: _diaries.length,
                          buildDefaultDragHandles: false,
                          onReorder: _onReorder,
                          proxyDecorator:
                              _proxyDecorator, // 👈 이 줄을 꼭 추가해야 작동합니다!
                          itemBuilder: (context, index) {
                            // 🎯 [중요] 여기 있는 diary 변수는 '화면을 그릴 때'만 참고하는 용도야!
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
                                  imageUrl =
                                      '$rawUrl?t=$_imageTimestamp&width=100&quality=20';
                                }
                              }
                            }
                            return Slidable(
                              key: ValueKey(diary['id']),
                              // 🎯 [여기서부터 추가] 밀었을 때 나올 삭제 버튼 설정
                              endActionPane: ActionPane(
                                motion: const BehindMotion(),
                                extentRatio: 0.22, // 버튼이 차지할 넓이
                                children: [
                                  CustomSlidableAction(
                                    onPressed: (_) async {
                                      // 삭제 로직 실행
                                      await TravelDayService.clearDiaryRecord(
                                        userId: _travel['user_id'],
                                        travelId: _travel['id'],
                                        date: diary['date'],
                                        photoPaths: List<String>.from(
                                          diary['photo_urls'] ?? [],
                                        ),
                                      );
                                      if (!mounted) return;
                                      AppToast.show(
                                        context,
                                        'diary_clear_success'.tr(),
                                      );
                                      await _loadAllDiaries(silent: true);
                                    },
                                    backgroundColor: Colors.transparent,
                                    padding: const EdgeInsets.only(
                                      left: 6,
                                      bottom: 13,
                                    ),
                                    child: Center(
                                      child: Container(
                                        width: 52,
                                        height: 52,
                                        decoration: BoxDecoration(
                                          color: AppColors.error,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
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
                              // 🎯 [여기까지가 추가된 ActionPane]
                              child: GestureDetector(
                                onTap: () async {
                                  final currentDiary = _diaries[index];
                                  final updatedDiary = {
                                    ...currentDiary,
                                    'day_index': index + 1,
                                    'date': DateUtilsHelper.formatYMD(
                                      displayDate,
                                    ),
                                  };

                                  await Navigator.push(
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
                                        initialDiary: updatedDiary,
                                      ),
                                    ),
                                  );

                                  _loadAllDiaries(silent: true);
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
      margin: const EdgeInsets.only(bottom: 13),
      padding: const EdgeInsets.fromLTRB(15, 15, 0, 15),
      decoration: BoxDecoration(
        color: AppColors.background,
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
    final bool isEn = context.locale.languageCode == 'en';
    final String displayTitle = isEn ? title.toUpperCase() : title;
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
              Padding(
                padding: const EdgeInsets.only(top: 2), // 위쪽 패딩 추가
                child: _TypeBadge(label: badgeLabel),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  // 🎯 이 부분이 핵심!
                  // 영어일 때는 'POHANG Travel', 한국어일 때는 '포항 여행' 형식으로 나오게 함
                  isEn
                      ? "$displayTitle Travel"
                      : 'travel_diary_list_title'.tr(args: [displayTitle]),
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
          const SizedBox(height: 1),
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
      padding: const EdgeInsets.fromLTRB(6, 1, 6, 3),
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
