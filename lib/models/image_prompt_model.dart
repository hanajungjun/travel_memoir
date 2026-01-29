class ImagePromptModel {
  final String id;
  final String title;
  final String contentKo; // 한글 가이드용
  final String contentEn; // 실제 AI 생성용 (영문)
  final bool isActive;

  ImagePromptModel({
    required this.id,
    required this.title,
    required this.contentKo,
    required this.contentEn,
    required this.isActive,
  });

  factory ImagePromptModel.fromMap(Map<String, dynamic> map) {
    return ImagePromptModel(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      // 🔥 핵심: DB 컬럼명 변경에 맞추고, 데이터가 Null이어도 빈 문자열로 처리
      contentKo: map['content_ko'] as String? ?? '',
      contentEn: map['content_en'] as String? ?? '',
      isActive: map['is_active'] as bool? ?? false,
    );
  }

  // 저장이나 업데이트 시 사용할 Map 변환
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'content_ko': contentKo,
      'content_en': contentEn,
      'is_active': isActive,
    };
  }
}
