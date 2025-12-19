import 'package:flutter/material.dart';

class GlobalMapPage extends StatelessWidget {
  const GlobalMapPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('해외 여행 지도')),
      body: const Center(
        child: Text(
          '🌍 해외 지도 페이지\n(기존 기록탭 지도 여기로 옮길 예정)',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
