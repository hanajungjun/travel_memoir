import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:scrollable_clean_calendar/scrollable_clean_calendar.dart';
import 'package:scrollable_clean_calendar/controllers/clean_calendar_controller.dart';
import 'package:scrollable_clean_calendar/utils/enums.dart';
import 'package:travel_memoir/core/constants/app_colors.dart';

class CustomRangeCalendarPage extends StatefulWidget {
  final String travelType;

  const CustomRangeCalendarPage({super.key, required this.travelType});

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
    _initController(DateTime.now());
  }

  void _initController(DateTime focusDate) {
    calendarController = CleanCalendarController(
      minDate: DateTime(2000, 1, 1),
      maxDate: DateTime(2027, 12, 31),
      onRangeSelected: (min, max) {
        setState(() {
          rangeMin = min;
          rangeMax = max;
        });
      },
      initialFocusDate: focusDate,
      weekdayStart: DateTime.sunday,
    );
  }

  void _jumpToToday() {
    setState(() {
      _initController(DateTime.now());
    });
  }

  void _showYearPicker(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("select_year".tr()),
          content: SizedBox(
            width: 300,
            height: 300,
            child: YearPicker(
              firstDate: DateTime(2000), // 범위 확장
              lastDate: DateTime(2027),
              initialDate: rangeMin ?? DateTime.now(),
              selectedDate: rangeMin ?? DateTime.now(),
              onChanged: (DateTime dateTime) {
                setState(() {
                  _initController(dateTime);
                });
                Navigator.pop(context);
              },
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    Color themeColor;
    if (widget.travelType == 'overseas') {
      themeColor = AppColors.travelingPurple;
    } else if (widget.travelType == 'us') {
      themeColor = AppColors.travelingRed;
    } else {
      themeColor = AppColors.travelingBlue;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      body: SafeArea(
        child: Column(
          children: [
            // 1. 상단 앱바 (X - 연달력 - 오늘 - V)
            Padding(
              padding: const EdgeInsets.fromLTRB(23, 15, 32, 7),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      size: 27,
                      color: Color(0xFF909090),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(
                      Icons.calendar_month,
                      size: 24,
                      color: themeColor,
                    ),
                    onPressed: () => _showYearPicker(context),
                  ),
                  TextButton(
                    onPressed: _jumpToToday,
                    child: Text(
                      'today'.tr(),
                      style: TextStyle(
                        color: themeColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
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

            // 2. 날짜 표시 요약 카드
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
                        color: Color(0xFF7f7f7f),
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 3. 달력 본체 (여기가 비어있어서 아무것도 안 나왔던 거야!)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 10, right: 10),
                child: KeyedSubtree(
                  key: ValueKey(calendarController),
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
                        ],
                      );
                    },
                    dayBuilder: (context, values) {
                      final date = values.day;
                      final now = DateTime.now();
                      final bool isToday =
                          date.year == now.year &&
                          date.month == now.month &&
                          date.day == now.day;

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

                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        child: Transform.translate(
                          offset: const Offset(0, -18),
                          child: Container(
                            color: Colors.transparent,
                            width: double.infinity,
                            height: double.infinity,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                if (isToday && !isStart && !isEnd && !isBetween)
                                  Container(
                                    width: 35,
                                    height: 35,
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.05),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
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
                                    fontWeight: isToday
                                        ? FontWeight.bold
                                        : FontWeight.w500,
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
            ),
          ],
        ),
      ),
    );
  }
}
