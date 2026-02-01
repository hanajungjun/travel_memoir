import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:scrollable_clean_calendar/scrollable_clean_calendar.dart';
import 'package:scrollable_clean_calendar/controllers/clean_calendar_controller.dart';
import 'package:scrollable_clean_calendar/utils/enums.dart';
import 'package:travel_memoir/core/constants/app_colors.dart';

class CustomRangeCalendarPage extends StatefulWidget {
  const CustomRangeCalendarPage({super.key});

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
      weekdayStart: DateTime.monday,
    );
  }

  @override
  Widget build(BuildContext context) {
    const themeColor = AppColors.travelActiveBlue;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
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
                      padding: const EdgeInsets.all(10),
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
                        size: 17,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 27, vertical: 0),
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
              child: ScrollableCleanCalendar(
                calendarController: calendarController,
                layout: Layout.BEAUTY,
                locale: context.locale.languageCode, // ✅ 현재 언어 자동 반영
                calendarCrossAxisSpacing: 0,
                showWeekdays: true,
                weekdayTextStyle: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textColor01,
                  fontWeight: FontWeight.w400,
                ),
                monthTextStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textColor01,
                ),
                dayBuilder: (context, values) {
                  final date = values.day;

                  bool isStartOrEnd =
                      (rangeMin != null &&
                          date.year == rangeMin!.year &&
                          date.month == rangeMin!.month &&
                          date.day == rangeMin!.day) ||
                      (rangeMax != null &&
                          date.year == rangeMax!.year &&
                          date.month == rangeMax!.month &&
                          date.day == rangeMax!.day);

                  bool isBetween =
                      rangeMin != null &&
                      rangeMax != null &&
                      date.isAfter(rangeMin!) &&
                      date.isBefore(rangeMax!);

                  BoxDecoration? decoration;
                  if (isStartOrEnd) {
                    decoration = const BoxDecoration(
                      color: themeColor,
                      shape: BoxShape.circle,
                    );
                  } else if (isBetween) {
                    decoration = BoxDecoration(
                      color: themeColor.withOpacity(0.15),
                      shape: BoxShape.rectangle,
                    );
                  }

                  Color textColor = Colors.black;
                  if (isStartOrEnd) {
                    textColor = Colors.white;
                  } else if (isBetween) {
                    textColor = themeColor;
                  } else if (date.weekday == DateTime.saturday) {
                    textColor = Colors.blue;
                  } else if (date.weekday == DateTime.sunday) {
                    textColor = Colors.red;
                  }

                  return Container(
                    alignment: Alignment.center,
                    decoration: decoration,
                    child: Text(
                      values.text,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 16,
                        fontWeight: (isStartOrEnd || isBetween)
                            ? FontWeight.bold
                            : FontWeight.w500,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
