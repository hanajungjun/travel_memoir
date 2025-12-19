import 'package:flutter/material.dart';

class DomesticMapPage extends StatelessWidget {
  const DomesticMapPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('한국 여행 지도')),
      body: const Center(
        child: Text(
          '🇰🇷 한국 지도 페이지\n(기존 기록탭 지도 여기로 옮길 예정)',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
