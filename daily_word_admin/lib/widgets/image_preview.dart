import 'dart:typed_data';
import 'package:flutter/material.dart';

class ImagePreview extends StatelessWidget {
  final Uint8List? bytes;

  const ImagePreview({super.key, this.bytes});

  @override
  Widget build(BuildContext context) {
    if (bytes == null) {
      return Container(
        height: 220,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white24),
          color: const Color(0xFF181818),
        ),
        alignment: Alignment.center,
        child: const Text('이미지 미리보기', style: TextStyle(color: Colors.white54)),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 220,
        width: double.infinity,
        color: const Color(0xFF181818),
        child: Image.memory(bytes!, fit: BoxFit.contain),
      ),
    );
  }
}
