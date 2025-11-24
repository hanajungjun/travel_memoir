import 'package:flutter/material.dart';

class DatePickerRow extends StatelessWidget {
  final String dateLabel;
  final VoidCallback onPickDate;
  final VoidCallback onPickImage;
  final String? imageName;

  const DatePickerRow({
    super.key,
    required this.dateLabel,
    required this.onPickDate,
    required this.onPickImage,
    this.imageName,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '날짜: $dateLabel',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(width: 12),
        OutlinedButton(onPressed: onPickDate, child: const Text('날짜 선택')),
        const Spacer(),
        OutlinedButton.icon(
          onPressed: onPickImage,
          icon: const Icon(Icons.image_outlined),
          label: Text(imageName ?? '이미지 선택'),
        ),
      ],
    );
  }
}
