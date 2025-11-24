class DailyWord {
  final String id; // uuid (DB 자동 생성)
  final String date; // YYYYMMDD
  final DateTime dateTimestamp;
  final String title;
  final String description;
  final String imageUrl;
  final DateTime updatedAt;

  DailyWord({
    required this.id,
    required this.date,
    required this.dateTimestamp,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.updatedAt,
  });

  /// 날짜 문자열 정규화
  static String normalizeDate(String input) {
    return input
        .trim()
        .replaceAll('\n', '')
        .replaceAll('\r', '')
        .replaceAll(' ', '');
  }

  factory DailyWord.fromMap(Map<String, dynamic> map) {
    return DailyWord(
      id: map['id'].toString(),
      date: normalizeDate(map['date'] ?? ''),
      dateTimestamp: map['date_timestamp'] != null
          ? DateTime.parse(map['date_timestamp'])
          : DateTime.now(),
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      imageUrl: map['image_url'] ?? '',
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'])
          : DateTime.now(),
    );
  }

  /// INSERT용 Map → id 포함 ❌
  Map<String, dynamic> toInsertMap() {
    return {
      'date': normalizeDate(date),
      'date_timestamp': dateTimestamp.toIso8601String(),
      'title': title,
      'description': description,
      'image_url': imageUrl,
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
