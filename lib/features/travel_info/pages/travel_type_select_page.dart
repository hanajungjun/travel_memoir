import 'package:flutter/material.dart';
import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/shared/styles/text_styles.dart';

import 'domestic_travel_date_page.dart';
import 'overseas_travel_date_page.dart';

class TravelTypeSelectPage extends StatelessWidget {
  const TravelTypeSelectPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), // 스크린샷의 연한 배경색
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            // ✨ 상단 메인 타이틀
            RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 26,
                  color: Colors.black87,
                  height: 1.4,
                ),
                children: [
                  const TextSpan(
                    text: '어떤 여행',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const TextSpan(text: '을 기록할까요?'),
                ],
              ),
            ),
            const SizedBox(height: 40),

            // ======================
            // 🇰🇷 국내 여행 카드
            // ======================
            _TravelTypeCard(
              title: '국내여행, ',
              subTitleSuffix: 'Local',
              description: '한국 곳곳을 기록하는 여행',
              icon: Icons.location_on_rounded,
              iconColor: const Color(0xFF3498DB), // 국내여행 블루
              onTap: () async {
                final createdTravel =
                    await Navigator.push<Map<String, dynamic>>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const DomesticTravelDatePage(),
                      ),
                    );
                if (createdTravel != null && context.mounted) {
                  Navigator.pop(context, createdTravel);
                }
              },
            ),

            const SizedBox(height: 20),

            // ======================
            // 🌍 해외 여행 카드
            // ======================
            _TravelTypeCard(
              title: '해외여행, ',
              subTitleSuffix: 'Abroad',
              description: '낯선 곳에서의 하루 기록',
              icon: Icons.public_rounded,
              iconColor: const Color(0xFF6C5CE7), // 해외여행 퍼플
              onTap: () async {
                final createdTravel =
                    await Navigator.push<Map<String, dynamic>>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const OverseasTravelDatePage(),
                      ),
                    );
                if (createdTravel != null && context.mounted) {
                  Navigator.pop(context, createdTravel);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ==============================
// 🧭 리뉴얼된 여행 타입 카드 위젯
// ==============================
class _TravelTypeCard extends StatelessWidget {
  final String title;
  final String subTitleSuffix;
  final String description;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;

  const _TravelTypeCard({
    required this.title,
    required this.subTitleSuffix,
    required this.description,
    required this.icon,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25), // 피그마 스타일의 큰 곡률
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04), // 아주 연한 그림자
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            // 아이콘 박스
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 28),
            ),
            const SizedBox(width: 20),
            // 텍스트 영역
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        fontSize: 20,
                        color: Colors.black87,
                        fontWeight: FontWeight.bold,
                      ),
                      children: [
                        TextSpan(text: title),
                        TextSpan(
                          text: subTitleSuffix,
                          style: TextStyle(
                            color: Colors.black45,
                            fontWeight: FontWeight.normal,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: const TextStyle(color: Colors.black45, fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
