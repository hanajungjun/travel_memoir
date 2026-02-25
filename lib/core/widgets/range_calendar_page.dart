import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:scrollable_clean_calendar/scrollable_clean_calendar.dart';
import 'package:scrollable_clean_calendar/controllers/clean_calendar_controller.dart';
import 'package:scrollable_clean_calendar/utils/enums.dart';
import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:flutter_svg/flutter_svg.dart'; // ✅ SVG 사용을 위한 임포트 추가

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
  late DateTime focusedYear;

  @override
  void initState() {
    super.initState();
    focusedYear = DateTime.now(); // 🎯 초기값 할당
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initController(DateTime.now());
  }

  void _initController(DateTime focusDate) {
    setState(() {
      focusedYear = focusDate; // 🎯 상단 버튼의 년도를 현재 포커스된 날짜로 업데이트
    });
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

  void _showYearPicker(BuildContext context, Color themeColor) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.background,
          surfaceTintColor: Colors.transparent, // 배경색 유지
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          contentPadding: EdgeInsets.zero,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start, // 왼쪽 정렬
            children: [
              Text(
                "select_year".tr(),
                style: const TextStyle(
                  fontSize: 15, // 🎯 타이틀 사이즈 축소
                  fontWeight: FontWeight.w700,
                  color: AppColors.textColor01,
                ),
              ),
              const SizedBox(height: 18), // 글자와 라인 사이 간격
              // 🎯 타이틀 밑 도트 라인
              CustomPaint(
                size: const Size(double.infinity, 2),
                painter: DotLinePainter(
                  color: AppColors.textColor01.withOpacity(0.8),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 300,
            height: 190,
            child: Theme(
              data: Theme.of(context).copyWith(
                // 🎯 추가: 기본 Divider(가로선)를 투명하게 만듦
                dividerTheme: const DividerThemeData(color: Colors.transparent),
                dividerColor: Colors.transparent,
                textButtonTheme: TextButtonThemeData(
                  style: ButtonStyle(
                    // 🎯 클릭 시 배경색(Overlay) 투명하게 제거
                    overlayColor: WidgetStateProperty.all(Colors.transparent),
                  ),
                ),
                textTheme: const TextTheme(
                  bodyLarge: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textColor01,
                  ),
                ),
                colorScheme: ColorScheme.light(
                  primary: themeColor, // 선택된 년도 강조색
                  onSurface: AppColors.textColor01, // 일반 글자색
                ),
              ),
              child: YearPicker(
                firstDate: DateTime(2000),
                lastDate: DateTime(2027),
                // 🎯 에러 해결: 파라미터명을 정확히 입력 (initialDate, selectedDate)
                initialDate: focusedYear, // 팝업 열었을 때 초기 위치
                selectedDate: focusedYear, // 현재 선택된 연도 강조
                onChanged: (DateTime dateTime) {
                  setState(() {
                    _initController(dateTime);
                  });
                  Navigator.pop(context);
                },
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // ✅ 1. 언어코드 + 요일 리스트
    final String locale = context.locale.languageCode;
    final List<String> weekdays = locale == 'ko'
        ? ['일', '월', '화', '수', '목', '금', '토']
        : ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

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
                  Container(
                    height: 33,
                    decoration: BoxDecoration(
                      color: const Color(0xFFB7BABB),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: TextButton.icon(
                      onPressed: () => _showYearPicker(context, themeColor),
                      icon: Text(
                        DateFormat('yyyy').format(focusedYear),
                        style: const TextStyle(
                          color: AppColors.textColor02,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      label: const Icon(
                        Icons.keyboard_arrow_down,
                        color: AppColors.textColor02,
                        size: 18,
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.fromLTRB(12, 0, 6, 0),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    height: 33,
                    decoration: BoxDecoration(
                      color: themeColor.withOpacity(0.45),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: TextButton(
                      onPressed: _jumpToToday,
                      child: Text(
                        'today'.tr().toUpperCase(),
                        style: const TextStyle(
                          color: AppColors.textColor02,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
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
                            blurRadius: 18,
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
                        SvgPicture.asset(
                          'assets/icons/ico_calendar.svg',
                          width: 12,
                          height: 12,
                          color: AppColors.textColor01,
                          colorBlendMode: BlendMode.srcIn,
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

            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 10, right: 10),
                child: KeyedSubtree(
                  key: ValueKey(calendarController),
                  child: ScrollableCleanCalendar(
                    calendarController: calendarController,
                    layout: Layout.DEFAULT,
                    locale: locale, // ✅ 2. 하드코딩 → 변수로
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
                          // ✅ 3. 요일 변수로
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: weekdays.map((d) {
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
                          const SizedBox(height: 10),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: CustomPaint(
                              size: const Size(double.infinity, 1),
                              painter: DotLinePainter(
                                color: AppColors.textColor01.withOpacity(0.2),
                              ),
                            ),
                          ),
                          const SizedBox(height: 0),
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

                      // ✅ 4. textColor 변수 정의
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
                                    width: 45,
                                    height: 45,
                                    decoration: BoxDecoration(
                                      color: themeColor.withOpacity(0.45),
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
                                // ✅ 4. textColor 변수 사용
                                Text(
                                  values.text,
                                  style: TextStyle(
                                    color: (isStart || isEnd || isBetween)
                                        ? Colors.white
                                        : isToday
                                        ? AppColors.textColor02
                                        : textColor,
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
            ),
          ],
        ),
      ),
    );
  }
}

// 🎨 도트 라인을 그리는 클래스
class DotLinePainter extends CustomPainter {
  final Color color;
  DotLinePainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    double dashWidth = 2, dashSpace = 3, startX = 0;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    while (startX < size.width) {
      canvas.drawCircle(Offset(startX, 0), 0.5, paint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
