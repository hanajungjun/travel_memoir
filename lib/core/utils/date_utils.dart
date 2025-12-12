/// 📅 날짜/시간 관련 유틸리티 모음
/// UI에서 반복적으로 사용하는 날짜 포맷, 요일, 여행 n일차 계산을 담당한다.
class DateUtilsHelper {
  /// 🗓 오늘 날짜를 "12월 12일 금요일" 형태로 반환
  /// 홈 화면 상단 날짜 표시용
  static String todayText() {
    final now = DateTime.now();
    return '${now.month}월 ${now.day}일 ${weekday(now.weekday)}';
  }

  /// 📆 요일 숫자(DateTime.weekday)를
  /// 한글 요일 문자열로 변환
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
  /// TravelDayPage, 카드 헤더 등에 사용
  static String formatMonthDay(DateTime date) {
    return '${date.month}.${date.day}';
  }

  /// 🧳 여행 n일차 계산
  /// 예) 시작일: 12/03, 오늘: 12/12 → DAY 10
  static int calculateDayNumber({
    required DateTime startDate,
    required DateTime currentDate,
  }) {
    return currentDate.difference(startDate).inDays + 1;
  }
}
