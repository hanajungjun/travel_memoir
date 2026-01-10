import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:scrollable_clean_calendar/scrollable_clean_calendar.dart';
import 'package:scrollable_clean_calendar/controllers/clean_calendar_controller.dart';
import 'package:scrollable_clean_calendar/utils/enums.dart';

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
    const themeColor = Color(0xFF3498DB);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      size: 28,
                      color: Colors.black45,
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
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: themeColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Colors.black12, blurRadius: 10),
                        ],
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
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
                          size: 18,
                          color: Colors.black54,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'select_date'.tr(),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      rangeMin == null || rangeMax == null
                          ? 'please_select_travel_period'.tr()
                          : '${DateFormat('yyyy. MM. dd').format(rangeMin!)} ~ ${DateFormat('yyyy. MM. dd').format(rangeMax!)}',
                      style: const TextStyle(
                        fontSize: 22,
                        color: Colors.black87,
                        fontWeight: FontWeight.w400,
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
                  fontSize: 14,
                  color: Colors.black45,
                  fontWeight: FontWeight.w600,
                ),
                monthTextStyle: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
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
