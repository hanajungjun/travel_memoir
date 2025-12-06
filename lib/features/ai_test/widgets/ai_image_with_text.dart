import 'dart:typed_data';
import 'package:flutter/material.dart';

class AiImageWithText extends StatelessWidget {
  final Uint8List imageBytes;
  final String title;

  const AiImageWithText({
    super.key,
    required this.imageBytes,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 🖼 이미지
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(
            imageBytes,
            width: double.infinity,
            fit: BoxFit.fitWidth,
          ),
        ),

        const SizedBox(height: 16),

        // 📝 제목 / 요약 문구
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
