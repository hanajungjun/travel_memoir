import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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

    calendarController = CleanCalendarController(
      minDate: DateTime(2024, 1, 1), // 과거 날짜 선택 허용
      maxDate: DateTime(2027, 12, 31),
      onRangeSelected: (min, max) {
        setState(() {
          rangeMin = min;
          rangeMax = max;
        });
      },
      initialFocusDate: DateTime.now(), // 2026년 현재 기준
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
            // -----------------------------------------------------
            // 1️⃣ 상단 바 (X 버튼 및 파란색 원형 체크 버튼)
            // -----------------------------------------------------
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

            // -----------------------------------------------------
            // 2️⃣ 날짜 선택 카드 (디자인 유지)
            // -----------------------------------------------------
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
                    const Row(
                      children: [
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 18,
                          color: Colors.black54,
                        ),
                        SizedBox(width: 8),
                        Text(
                          '날짜 선택',
                          style: TextStyle(
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
                          ? '여행 기간을 선택해주세요'
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

            // -----------------------------------------------------
            // 3️⃣ 세로 스크롤 달력 (직접 범위 계산 로직 적용)
            // -----------------------------------------------------
            Expanded(
              child: ScrollableCleanCalendar(
                calendarController: calendarController,
                layout: Layout.BEAUTY,
                locale: 'ko',
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

                // ⭐ 에러 해결: dayBuilder 내에서 직접 범위 체크
                dayBuilder: (context, values) {
                  final date = values.day;

                  // 1. 시작일 또는 종료일인지 확인
                  bool isStartOrEnd =
                      (rangeMin != null &&
                          date.year == rangeMin!.year &&
                          date.month == rangeMin!.month &&
                          date.day == rangeMin!.day) ||
                      (rangeMax != null &&
                          date.year == rangeMax!.year &&
                          date.month == rangeMax!.month &&
                          date.day == rangeMax!.day);

                  // 2. 선택된 범위 사이인지 확인
                  bool isBetween =
                      rangeMin != null &&
                      rangeMax != null &&
                      date.isAfter(rangeMin!) &&
                      date.isBefore(rangeMax!);

                  // 배경 디자인 설정
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

                  // 텍스트 색상 설정 (토요일-파란색, 일요일-빨간색, 선택시-흰색)
                  Color textColor = Colors.black;
                  if (isStartOrEnd || isBetween) {
                    textColor = Colors.white; // 선택 시 무조건 흰색
                  } else if (date.weekday == DateTime.saturday) {
                    textColor = Colors.blue; // 토요일
                  } else if (date.weekday == DateTime.sunday) {
                    textColor = Colors.red; // 일요일
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
