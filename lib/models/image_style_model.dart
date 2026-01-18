class ImageStyleModel {
  final String id;
  final String title;
  final String titleEn;
  final String prompt;
  final bool isEnabled;

  // ✅ 추가
  final bool isPremium; // 🔥 프리미엄 여부
  final String? thumbnailUrl;
  final int sortOrder;

  ImageStyleModel({
    required this.id,
    required this.title,
    required this.titleEn,
    required this.prompt,
    required this.isEnabled,
    required this.isPremium, // ✅ 추가
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

      // ✅ 여기 핵심
      isPremium: map['is_premium'] as bool? ?? false,

      thumbnailUrl: map['thumbnail_url'] as String?,
      sortOrder: map['sort_order'] as int? ?? 0,
    );
  }

  ImageStyleModel copyWith({
    String? title,
    String? titleEn,
    String? prompt,
    bool? isEnabled,
    bool? isPremium,
    String? thumbnailUrl,
    int? sortOrder,
  }) {
    return ImageStyleModel(
      id: id,
      title: title ?? this.title,
      titleEn: titleEn ?? this.titleEn,
      prompt: prompt ?? this.prompt,
      isEnabled: isEnabled ?? this.isEnabled,
      isPremium: isPremium ?? this.isPremium,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  // ✨ 현재 언어에 맞는 제목
  String getLocalizedTitle(String languageCode) {
    if (languageCode == 'en') {
      return titleEn.isNotEmpty ? titleEn : title;
    }
    return title;
  }
}
