class ImagePromptModel {
  final String id;
  final String title;
  final String content;
  final bool isActive;

  ImagePromptModel({
    required this.id,
    required this.title,
    required this.content,
    required this.isActive,
  });

  factory ImagePromptModel.fromMap(Map<String, dynamic> map) {
    return ImagePromptModel(
      id: map['id'] as String,
      title: map['title'] as String,
      content: map['content'] as String,
      isActive: map['is_active'] as bool,
    );
  }
}
