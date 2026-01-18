class AiPremiumPromptModel {
  final String key;
  final String title;
  final String prompt;
  final bool isActive;
  final DateTime? updatedAt;

  AiPremiumPromptModel({
    required this.key,
    required this.title,
    required this.prompt,
    required this.isActive,
    this.updatedAt,
  });

  factory AiPremiumPromptModel.fromMap(Map<String, dynamic> map) {
    return AiPremiumPromptModel(
      key: map['key'],
      title: map['title'],
      prompt: map['prompt'],
      isActive: map['is_active'] ?? false,
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'])
          : null,
    );
  }
}
