import 'package:flutter/material.dart';

class GuideOverlayPainter extends CustomPainter {
  final Rect targetRect;
  final double borderRadius;

  GuideOverlayPainter({required this.targetRect, this.borderRadius = 12.0});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Colors.black.withOpacity(0.72)
      ..style = PaintingStyle.fill;

    // 전체 화면 Path
    final Path fullScreen = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    // 타겟 구멍 Path
    final Path hole = Path()
      ..addRRect(
        RRect.fromRectAndRadius(targetRect, Radius.circular(borderRadius)),
      );

    // 전체화면 - 구멍 = 구멍 뚫린 어두운 배경
    final Path combined = Path.combine(
      PathOperation.difference,
      fullScreen,
      hole,
    );

    canvas.drawPath(combined, paint);
  }

  @override
  bool shouldRepaint(covariant GuideOverlayPainter oldDelegate) {
    return oldDelegate.targetRect != targetRect;
  }
}
