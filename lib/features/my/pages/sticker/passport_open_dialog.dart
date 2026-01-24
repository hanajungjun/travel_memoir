import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
// ✅ MyStickerPage가 있는 경로를 프로젝트 구조에 맞게 확인하세요.
import 'package:travel_memoir/features/my/pages/sticker/my_sticker_page.dart';

class PassportOpeningDialog extends StatefulWidget {
  const PassportOpeningDialog({super.key});

  @override
  State<PassportOpeningDialog> createState() => _PassportOpeningDialogState();
}

class _PassportOpeningDialogState extends State<PassportOpeningDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isOpened = false;

  @override
  void initState() {
    super.initState();
    // 애니메이션 속도 조절 (800ms가 가장 적당히 묵직합니다)
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleOpen() {
    if (_isOpened) return; // 이미 열렸다면 클릭 무시 (내부 스와이프를 위해)
    setState(() {
      _isOpened = true;
      _controller.forward();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: SizedBox(
          // 아이폰 15 프로 맥스 등 대화면에서도 보기 좋은 비율
          width: MediaQuery.of(context).size.width * 0.85,
          height: MediaQuery.of(context).size.height * 0.7,
          child: Stack(
            children: [
              // 1. [바닥] 실제 여권 내용 (신원정보 + 스티커들)
              // 표지가 열리면 바로 이 녀석이 보입니다.
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(15),
                  bottomRight: Radius.circular(15),
                ),
                child: const MyStickerPage(),
              ),

              // 2. [덮개] 3D 회전하는 애니메이션 표지
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  final double angle = _controller.value * math.pi;

                  return Transform(
                    alignment: Alignment.centerLeft, // 왼쪽 세로선을 축으로 회전
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.001) // 원근감(Perspective) 주입
                      ..rotateY(-angle * 0.9), // 왼쪽으로 약 160도 회전
                    child: angle > (math.pi / 2)
                        ? const SizedBox.shrink() // 90도 넘어가면 표지 앞면을 완전히 숨김
                        : GestureDetector(
                            onTap: _toggleOpen,
                            child: _buildCoverFront(),
                          ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 여권 앞표지 디자인 (초록 가죽 느낌)
  Widget _buildCoverFront() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A3D2F), // 대한민국 여권 특유의 짙은 초록색
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(15),
          bottomRight: Radius.circular(15),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 15,
            offset: const Offset(8, 8),
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 여권 중앙 로고 (지구본 형태)
            const Icon(Icons.public, color: Color(0xFFE5C100), size: 80),
            const SizedBox(height: 20),
            // 여권 텍스트
            const Text(
              'PASSPORT',
              style: TextStyle(
                color: Color(0xFFE5C100),
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: 8,
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(height: 50),
            // 하단 전자여권 아이콘 느낌의 장식
            Container(
              width: 40,
              height: 25,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE5C100), width: 2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Center(
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE5C100),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
