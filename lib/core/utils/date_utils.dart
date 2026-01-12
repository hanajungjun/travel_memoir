import 'package:easy_localization/easy_localization.dart';
import 'package:intl/intl.dart';

class DateUtilsHelper {
  /// 🗓 오늘 날짜를 언어 설정에 맞게 반환 (예: 12월 12일 금요일 / Friday, Dec 12)
  static String todayText() {
    final now = DateTime.now();
    // 언어별로 최적화된 포맷 사용 (ko: M월 d일 E요일 / en: E, MMM d)
    return DateFormat.MMMEd().format(now);
  }

  /// 📆 요일 숫자를 해당 언어의 요일로 변환
  static String weekday(int day) {
    final now = DateTime.now();
    final firstDayOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final targetDay = firstDayOfWeek.add(Duration(days: day - 1));
    return DateFormat.EEEE().format(targetDay); // 월요일, Monday 등 자동 변환
  }

  /// 📌 날짜를 "12.12" 형태로 포맷
  static String formatMonthDay(DateTime date) {
    return DateFormat('M.d').format(date);
  }

  /// 🧳 여행 n일차 계산
  static int calculateDayNumber({
    required DateTime startDate,
    required DateTime currentDate,
  }) {
    return currentDate.difference(startDate).inDays + 1;
  }

  /// 🔒 미래 일기 잠금 문구
  static String getLockLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);

    final diff = target.difference(today).inDays;

    if (diff <= 0) return '';
    if (diff == 1) return 'lock_tomorrow'.tr(); // 내일 열려요
    return 'lock_days_later'.tr(args: [diff.toString()]); // n일 후 열려요
  }

  /// 🗓 yyyy.MM.dd 포맷
  static String formatYMD(DateTime date) {
    return DateFormat('yyyy.MM.dd').format(date);
  }

  /// ✨ 감성 상대 날짜
  static String memoryTimeAgo(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);

    final diff = today.difference(target).inDays;

    if (diff <= 0) return 'today'.tr();
    if (diff == 1) return 'yesterday'.tr();
    if (diff < 7) return 'days_ago'.tr(args: [diff.toString()]);
    if (diff < 14) return 'weeks_ago'.tr(args: ['1']);
    if (diff < 28) return 'weeks_ago'.tr(args: ['2']);

    final months = (diff / 30).floor();
    return 'months_ago'.tr(args: [months.toString()]);
  }

  /// 🧾 여행 기간 텍스트
  static String periodText({
    required String? startDate,
    required String? endDate,
  }) {
    final start = DateTime.tryParse(startDate ?? '');
    final end = DateTime.tryParse(endDate ?? '');

    if (start == null || end == null) return '';

    final nights = end.difference(start).inDays;

    if (nights <= 0) {
      return 'day_trip'.tr(); // 당일치기
    }

    // ko: n박 n+1일 / en: nN n+1D
    return 'period_format'.tr(
      args: [nights.toString(), (nights + 1).toString()],
    );
  }
}
