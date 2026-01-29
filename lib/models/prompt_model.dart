class PromptModel {
  final String id;
  final String title;
  final String contentKo;
  final String contentEn;
  final bool isActive;

  PromptModel({
    required this.id,
    required this.title,
    required this.contentKo,
    required this.contentEn,
    required this.isActive,
  });

  factory PromptModel.fromMap(Map<String, dynamic> map) {
    return PromptModel(
      id: map['id'] as String? ?? '', // 만약 ID도 Null일 수 있다면 대비
      title: map['title'] as String? ?? '제목 없음',
      // 🔥 핵심: DB에서 content_ko나 content_en이 Null이어도 에러 안 나게 방어
      contentKo: map['content_ko'] as String? ?? '',
      contentEn: map['content_en'] as String? ?? '',
      isActive: map['is_active'] as bool? ?? false,
    );
  }
}
