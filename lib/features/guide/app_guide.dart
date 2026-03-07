import 'package:flutter/material.dart';
import 'guide_painter.dart';
import 'tutorial_manager.dart';

class AppGuide {
  static bool isVisible = false;

  static void show({
    required BuildContext context,
    required GlobalKey targetKey,
    required String message,
    required VoidCallback onTargetClick,
    Rect? manualRect,
  }) {
    if (isVisible) return;

    Rect rect;

    if (manualRect != null) {
      rect = manualRect;
    } else {
      final renderBox =
          targetKey.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox == null) return;
      final offset = renderBox.localToGlobal(Offset.zero);
      final size = renderBox.size;
      rect = Rect.fromLTWH(offset.dx, offset.dy, size.width, size.height);
    }

    isVisible = true;

    final screenHeight = MediaQuery.of(context).size.height;
    final bool isBottom = (rect.top + rect.height / 2) > (screenHeight / 2);

    late OverlayEntry overlay;
    overlay = OverlayEntry(
      builder: (ctx) => Stack(
        children: [
          CustomPaint(
            size: MediaQuery.of(ctx).size,
            painter: GuideOverlayPainter(targetRect: rect),
          ),

          Positioned(
            top: rect.top,
            left: rect.left,
            width: rect.width,
            height: rect.height,
            child: GestureDetector(
              onTap: () {
                overlay.remove();
                isVisible = false;
                onTargetClick();
              },
              child: Container(color: Colors.transparent),
            ),
          ),

          if (isBottom)
            Positioned(
              bottom: screenHeight - rect.top + 16,
              left: 0,
              right: 0,
              child: Material(
                color: Colors.transparent,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              message,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.arrow_downward,
                            color: Colors.white,
                            size: 26,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildSkipButton(() {
                      overlay.remove();
                      isVisible = false;
                      TutorialManager.skipAll(); // ✅ 완전 종료
                    }),
                  ],
                ),
              ),
            )
          else
            Positioned(
              top: rect.bottom + 16,
              left: 0,
              right: 0,
              child: Material(
                color: Colors.transparent,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.arrow_upward,
                            color: Colors.white,
                            size: 26,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              message,
                              textAlign: TextAlign.start,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildSkipButton(() {
                      overlay.remove();
                      isVisible = false;
                      TutorialManager.skipAll(); // ✅ 완전 종료
                    }),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
    Overlay.of(context).insert(overlay);
  }

  static Widget _buildSkipButton(VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white54),
        ),
        child: const Text(
          "Skip",
          style: TextStyle(
            color: Colors.white,
            fontSize: 13,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }
}
