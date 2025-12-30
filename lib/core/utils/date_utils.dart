/// 📅 날짜/시간 관련 유틸리티 모음
/// UI에서 반복적으로 사용하는 날짜 포맷, 요일, 여행 기간 계산을 담당한다.
class DateUtilsHelper {
  /// 🗓 오늘 날짜를 "12월 12일 금요일" 형태로 반환
  static String todayText() {
    final now = DateTime.now();
    return '${now.month}월 ${now.day}일 ${weekday(now.weekday)}';
  }

  /// 📆 요일 숫자를 한글 요일로 변환
  static String weekday(int day) {
    switch (day) {
      case DateTime.monday:
        return '월요일';
      case DateTime.tuesday:
        return '화요일';
      case DateTime.wednesday:
        return '수요일';
      case DateTime.thursday:
        return '목요일';
      case DateTime.friday:
        return '금요일';
      case DateTime.saturday:
        return '토요일';
      case DateTime.sunday:
        return '일요일';
      default:
        return '';
    }
  }

  /// 📌 날짜를 "12.12" 형태로 포맷
  static String formatMonthDay(DateTime date) {
    return '${date.month}.${date.day}';
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
    if (diff == 1) return '내일 열려요';
    return '${diff}일 후 열려요';
  }

  /// 🗓 yyyy.MM.dd 포맷
  static String formatYMD(DateTime date) {
    return '${date.year}.${_two(date.month)}.${_two(date.day)}';
  }

  /// ✨ 감성 상대 날짜
  static String memoryTimeAgo(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);

    final diff = today.difference(target).inDays;

    if (diff <= 0) return '오늘';
    if (diff == 1) return '어제';
    if (diff < 7) return '$diff일 전';
    if (diff < 14) return '1주 전';
    if (diff < 28) return '2주 전';
    return '${(diff / 30).floor()}달 전';
  }

  /// 🧾 여행 기간 텍스트
  /// - 0박 1일 → 당일치기
  /// - 그 외 → n박 n+1일
  static String periodText({
    required String? startDate,
    required String? endDate,
  }) {
    final start = DateTime.tryParse(startDate ?? '');
    final end = DateTime.tryParse(endDate ?? '');

    if (start == null || end == null) return '';

    final nights = end.difference(start).inDays;

    if (nights <= 0) {
      return '당일치기';
    }

    return '${nights}박 ${nights + 1}일';
  }

  static String _two(int n) => n.toString().padLeft(2, '0');
}
