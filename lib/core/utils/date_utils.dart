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

  // =====================================================
  // 🔒 미래 일기 잠금 문구
  // =====================================================
  static String getLockLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);

    final diff = target.difference(today).inDays;

    if (diff <= 0) return ''; // 오늘 or 과거
    if (diff == 1) return '내일 열려요';
    return '${diff}일 후 열려요';
  }

  // =====================================================
  // 🗓 yyyy.MM.dd 포맷
  // 기록 탭 / 감성 요약 카드 날짜 표시용
  // =====================================================
  static String formatYMD(DateTime date) {
    return '${date.year}.${_two(date.month)}.${_two(date.day)}';
  }

  // =====================================================
  // ✨ 감성 상대 날짜 (기억용)
  // 예) 오늘 / 어제 / 3일 전 / 1주 전 / 2주 전 / n달 전
  // 기록 탭 상단 "마지막으로 떠났던 날" 표시용
  // =====================================================
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

  // =====================================================
  // 🔢 내부 유틸: 두 자리 숫자 보정
  // =====================================================
  static String _two(int n) => n.toString().padLeft(2, '0');
}
