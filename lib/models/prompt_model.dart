class PromptModel {
  final String id;
  final String title;
  final String content;
  final bool isActive;

  PromptModel({
    required this.id,
    required this.title,
    required this.content,
    required this.isActive,
  });

  factory PromptModel.fromMap(Map<String, dynamic> map) {
    return PromptModel(
      id: map['id'],
      title: map['title'],
      content: map['content'],
      isActive: map['is_active'],
    );
  }
}
