import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'my_sticker_page.dart'; // 🎯 MyStickerPage import 완료

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
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleOpen() {
    if (_isOpened) return;
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
          width: MediaQuery.of(context).size.width * 0.88,
          height: MediaQuery.of(context).size.height * 0.75,
          child: Stack(
            children: [
              // 속지 페이지 (MyStickerPage 호출)
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(15),
                  bottomRight: Radius.circular(15),
                ),
                child: const MyStickerPage(),
              ),

              // 3D 회전 앞표지
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  final double angle = _controller.value * math.pi;
                  return Transform(
                    alignment: Alignment.centerLeft,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.001)
                      ..rotateY(-angle * 0.9),
                    child: angle > (math.pi / 2)
                        ? const SizedBox.shrink()
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

  Widget _buildCoverFront() {
    return Container(
      // 🎯 width/height를 지정하지 않아도 부모가 주는 크기를 꽉 채우도록 설정
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        image: const DecorationImage(
          image: AssetImage('assets/images/passport_cover_front.png'),
          // 🎯 BoxFit.fill은 이미지 비율과 상관없이 컨테이너를 무조건 꽉 채웁니다.
          // 만약 이미지가 잘려도 비율 유지가 중요하다면 BoxFit.cover를 유지하세요.
          fit: BoxFit.fill,
        ),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(15),
          bottomRight: Radius.circular(15),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 20,
            offset: const Offset(10, 10),
          ),
        ],
      ),
    );
  }
}
