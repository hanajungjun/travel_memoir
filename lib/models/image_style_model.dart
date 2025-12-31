class ImageStyleModel {
  final String id;
  final String title;
  final String prompt;
  final bool isEnabled;

  // ✅ 추가
  final String? thumbnailUrl;
  final int sortOrder;

  ImageStyleModel({
    required this.id,
    required this.title,
    required this.prompt,
    required this.isEnabled,
    this.thumbnailUrl,
    required this.sortOrder,
  });

  factory ImageStyleModel.fromMap(Map<String, dynamic> map) {
    return ImageStyleModel(
      id: map['id'] as String,
      title: (map['title'] ?? '') as String,
      prompt: (map['prompt'] ?? '') as String,
      isEnabled: map['is_enabled'] as bool? ?? true,

      // ✅ DB 컬럼명 그대로
      thumbnailUrl: map['thumbnail_url'] as String?,
      sortOrder: map['sort_order'] as int? ?? 0,
    );
  }

  ImageStyleModel copyWith({
    String? title,
    String? prompt,
    bool? isEnabled,
    String? thumbnailUrl,
    int? sortOrder,
  }) {
    return ImageStyleModel(
      id: id,
      title: title ?? this.title,
      prompt: prompt ?? this.prompt,
      isEnabled: isEnabled ?? this.isEnabled,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}
