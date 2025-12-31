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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('여행 종류 선택', style: AppTextStyles.pageTitle),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 20),

            // ======================
            // 🇰🇷 국내 여행
            // ======================
            _TravelTypeCard(
              title: '국내 여행',
              subtitle: '대한민국 도시 여행',
              icon: Icons.map,
              accent: AppColors.primary,
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
            // 🌍 해외 여행
            // ======================
            _TravelTypeCard(
              title: '해외 여행',
              subtitle: '다른 나라로 떠나는 여행',
              icon: Icons.public,
              accent: AppColors.accent,
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
// 🧭 여행 타입 카드 위젯
class _TravelTypeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  const _TravelTypeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 120,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: accent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, size: 30, color: accent),
            ),

            const SizedBox(width: 20),

            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.sectionTitle.copyWith(fontSize: 20),
                  ),
                  const SizedBox(height: 6),
                  Text(subtitle, style: AppTextStyles.bodyMuted),
                ],
              ),
            ),

            const Icon(Icons.chevron_right, color: AppColors.textDisabled),
          ],
        ),
      ),
    );
  }
}
