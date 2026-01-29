class ImageStyleModel {
  final String id;
  final String title;
  final String titleEn;
  final String prompt;
  final String? thumbnailUrl;
  final int sortOrder;
  final bool isEnabled;
  final bool isPremium;

  ImageStyleModel({
    required this.id,
    required this.title,
    required this.titleEn,
    required this.prompt,
    this.thumbnailUrl,
    required this.sortOrder,
    required this.isEnabled,
    required this.isPremium,
  });

  factory ImageStyleModel.fromMap(Map<String, dynamic> map) {
    return ImageStyleModel(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      titleEn: map['title_en'] as String? ?? '',
      prompt: map['prompt'] as String? ?? '',
      thumbnailUrl: map['thumbnail_url'] as String?,
      sortOrder: map['sort_order'] as int? ?? 0,
      isEnabled: map['is_enabled'] as bool? ?? true,
      isPremium: map['is_premium'] as bool? ?? false,
    );
  }
}
