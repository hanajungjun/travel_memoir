import 'package:flutter/material.dart';
import 'domestic_travel_date_page.dart';

class TravelTypeSelectPage extends StatelessWidget {
  const TravelTypeSelectPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('여행 종류 선택')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 20),

            _TravelTypeCard(
              title: '국내 여행',
              subtitle: '대한민국 도시 여행',
              icon: Icons.map,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const DomesticTravelDatePage(),
                  ),
                );
              },
            ),

            const SizedBox(height: 20),

            _TravelTypeCard(
              title: '해외 여행',
              subtitle: '다른 나라로 떠나는 여행',
              icon: Icons.public,
              onTap: () {
                // TODO: 해외 여행 플로우
                print('해외 여행 선택');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _TravelTypeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _TravelTypeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 120,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, size: 36),
            const SizedBox(width: 20),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(subtitle, style: const TextStyle(color: Colors.grey)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
