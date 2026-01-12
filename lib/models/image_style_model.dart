class ImageStyleModel {
  final String id;
  final String title;
  final String titleEn;
  final String prompt;
  final bool isEnabled;

  // ✅ 추가
  final String? thumbnailUrl;
  final int sortOrder;

  ImageStyleModel({
    required this.id,
    required this.title,
    required this.titleEn,
    required this.prompt,
    required this.isEnabled,
    this.thumbnailUrl,
    required this.sortOrder,
  });

  factory ImageStyleModel.fromMap(Map<String, dynamic> map) {
    return ImageStyleModel(
      id: map['id'] as String,
      title: (map['title'] ?? '') as String,
      titleEn: (map['title_en'] ?? '') as String,
      prompt: (map['prompt'] ?? '') as String,
      isEnabled: map['is_enabled'] as bool? ?? true,

      // ✅ DB 컬럼명 그대로
      thumbnailUrl: map['thumbnail_url'] as String?,
      sortOrder: map['sort_order'] as int? ?? 0,
    );
  }

  ImageStyleModel copyWith({
    String? title,
    String? titleEn,
    String? prompt,
    bool? isEnabled,
    String? thumbnailUrl,
    int? sortOrder,
  }) {
    return ImageStyleModel(
      id: id,
      title: title ?? this.title,
      titleEn: titleEn ?? this.titleEn,
      prompt: prompt ?? this.prompt,
      isEnabled: isEnabled ?? this.isEnabled,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  // ✨ 현재 언어에 맞는 제목을 가져오는 헬퍼 함수
  String getLocalizedTitle(String languageCode) {
    if (languageCode == 'en') {
      return titleEn.isNotEmpty ? titleEn : title; // 영어 없으면 한국어라도 노출
    }
    return title;
  }
}
