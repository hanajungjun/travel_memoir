class ImageStyleModel {
  final String id;
  final String title;
  final String prompt;
  final bool isEnabled;

  ImageStyleModel({
    required this.id,
    required this.title,
    required this.prompt,
    required this.isEnabled,
  });

  factory ImageStyleModel.fromMap(Map<String, dynamic> map) {
    return ImageStyleModel(
      id: map['id'] as String,
      title: map['title'] as String,
      prompt: map['prompt'] as String,
      isEnabled: map['is_enabled'] as bool? ?? true,
    );
  }
}
