import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:scrollable_clean_calendar/scrollable_clean_calendar.dart';
import 'package:scrollable_clean_calendar/controllers/clean_calendar_controller.dart';
import 'package:scrollable_clean_calendar/utils/enums.dart';
import 'package:travel_memoir/core/constants/app_colors.dart';

class CustomRangeCalendarPage extends StatefulWidget {
  // ✅ 여행 타입을 외부에서 받기 위한 필드 추가 (기존 생성자 유지하며 추가)
  final String travelType;

  const CustomRangeCalendarPage({
    super.key,
    required this.travelType, // 'domestic', 'overseas', 'us'
  });

  @override
  State<CustomRangeCalendarPage> createState() =>
      _CustomRangeCalendarPageState();
}

class _CustomRangeCalendarPageState extends State<CustomRangeCalendarPage> {
  late CleanCalendarController calendarController;
  DateTime? rangeMin;
  DateTime? rangeMax;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // locale 설정 반영을 위해 여기서 초기화
    calendarController = CleanCalendarController(
      minDate: DateTime(2024, 1, 1),
      maxDate: DateTime(2027, 12, 31),
      onRangeSelected: (min, max) {
        setState(() {
          rangeMin = min;
          rangeMax = max;
        });
      },
      initialFocusDate: DateTime.now(),
      weekdayStart: DateTime.sunday,
    );
  }

  @override
  Widget build(BuildContext context) {
    // ✅ 여행 타입별 색상 결정 로직 추가 (기존 themeColor 변수 활용)
    Color themeColor;
    if (widget.travelType == 'overseas') {
      themeColor = AppColors.travelingPurple; // 해외
    } else if (widget.travelType == 'us') {
      themeColor = AppColors.travelingRed; // 미국
    } else {
      themeColor = AppColors.travelingBlue; // 국내
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(23, 15, 32, 7),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      size: 27,
                      color: const Color(0xFF909090),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  GestureDetector(
                    onTap: () {
                      if (rangeMin != null && rangeMax != null) {
                        Navigator.pop(
                          context,
                          DateTimeRange(start: rangeMin!, end: rangeMax!),
                        );
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: themeColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(27, 0, 27, 45),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(25, 22, 25, 22),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_outlined,
                          size: 12,
                          color: AppColors.textColor01,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'select_date'.tr(),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: AppColors.textColor01,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      rangeMin == null || rangeMax == null
                          ? 'please_select_travel_period'.tr()
                          : '${DateFormat('yyyy. MM. dd').format(rangeMin!)} ~ ${DateFormat('yyyy. MM. dd').format(rangeMax!)}',
                      style: const TextStyle(
                        fontSize: 20,
                        color: const Color(0xFF7f7f7f),
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 10, right: 10),
                child: ScrollableCleanCalendar(
                  calendarController: calendarController,
                  layout: Layout.BEAUTY,
                  locale: 'en',
                  calendarCrossAxisSpacing: 0,
                  showWeekdays: false,
                  monthBuilder: (context, month) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 12, top: 5),
                          child: Text(
                            month,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textColor01,
                            ),
                          ),
                        ),
                        const SizedBox(height: 25),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children:
                              [
                                'Sun',
                                'Mon',
                                'Tue',
                                'Wed',
                                'Thu',
                                'Fri',
                                'Sat',
                              ].map((d) {
                                return Expanded(
                                  child: Center(
                                    child: Text(
                                      d,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textColor01,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                        ),
                        const SizedBox(height: 13),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Row(
                            children: List.generate(
                              100,
                              (index) => Expanded(
                                child: Container(
                                  color: index % 2 == 0
                                      ? const Color(0xFFD1D1D1)
                                      : Colors.transparent,
                                  height: 1,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 0),
                      ],
                    );
                  },
                  dayBuilder: (context, values) {
                    final date = values.day;

                    bool isStart =
                        rangeMin != null &&
                        date.year == rangeMin!.year &&
                        date.month == rangeMin!.month &&
                        date.day == rangeMin!.day;
                    bool isEnd =
                        rangeMax != null &&
                        date.year == rangeMax!.year &&
                        date.month == rangeMax!.month &&
                        date.day == rangeMax!.day;
                    bool isBetween =
                        rangeMin != null &&
                        rangeMax != null &&
                        date.isAfter(rangeMin!) &&
                        date.isBefore(rangeMax!);

                    Color textColor = (isStart || isEnd || isBetween)
                        ? Colors.white
                        : (date.weekday == DateTime.sunday
                              ? AppColors.travelingRed
                              : (date.weekday == DateTime.saturday
                                    ? AppColors.travelingBlue
                                    : Colors.black));

                    // ✅ 터치 영역 확장을 위해 Container로 감싸고 HitTestBehavior 추가
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      child: Transform.translate(
                        offset: const Offset(0, -18),
                        child: Container(
                          // ✅ 중요: 투명색이라도 배경색이 있어야 전체 영역이 터치됩니다.
                          color: Colors.transparent,
                          width: double.infinity,
                          height: double.infinity,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              if (isStart || isEnd || isBetween)
                                Positioned.fill(
                                  top: 3,
                                  bottom: 3,
                                  left: 0,
                                  right: 0,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: themeColor,
                                      borderRadius: BorderRadius.only(
                                        topLeft: isStart
                                            ? const Radius.circular(50)
                                            : Radius.zero,
                                        bottomLeft: isStart
                                            ? const Radius.circular(50)
                                            : Radius.zero,
                                        topRight: isEnd
                                            ? const Radius.circular(50)
                                            : Radius.zero,
                                        bottomRight: isEnd
                                            ? const Radius.circular(50)
                                            : Radius.zero,
                                      ),
                                    ),
                                  ),
                                ),
                              Text(
                                values.text,
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
