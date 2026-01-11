import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

class MyStickerPage extends StatelessWidget {
  const MyStickerPage({super.key});

  @override
  Widget build(BuildContext context) {
    // 1. 전체 국가 리스트 (나중에는 DB에서 전체 국가 목록을 가져오면 됩니다)
    final List<Map<String, dynamic>> allCountries = [
      {
        'name': 'France',
        'asset': 'assets/images/france.png',
        'isUnlocked': true,
      },
      {'name': 'Korea', 'asset': null, 'isUnlocked': false},
      {'name': 'Japan', 'asset': null, 'isUnlocked': false},
      {'name': 'USA', 'asset': null, 'isUnlocked': false},
      {'name': 'Italy', 'asset': null, 'isUnlocked': false},
      {'name': 'UK', 'asset': null, 'isUnlocked': false},
      {'name': 'Spain', 'asset': 'assets/images/spain.png', 'isUnlocked': true},
      {'name': 'Canada', 'asset': null, 'isUnlocked': false},
      {'name': 'Germany', 'asset': null, 'isUnlocked': false},
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5), // 약간 회색빛 바닥면 (스티커 판 느낌)
      appBar: AppBar(
        title: Text('my_stickers'.tr()),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(25),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, // 3열 배치
          mainAxisSpacing: 25, // 세로 간격
          crossAxisSpacing: 20, // 가로 간격
          childAspectRatio: 0.9, // 육각형 모양에 최적화된 비율
        ),
        itemCount: allCountries.length,
        itemBuilder: (context, index) {
          final country = allCountries[index];
          return _buildSticker(country);
        },
      ),
    );
  }

  Widget _buildSticker(Map<String, dynamic> country) {
    bool isUnlocked = country['isUnlocked'];

    return Column(
      children: [
        Expanded(
          child: AspectRatio(
            aspectRatio: 1,
            child: ClipPath(
              clipper: HexagonClipper(), // 육각형으로 깎기
              child: Container(
                decoration: BoxDecoration(
                  color: isUnlocked ? Colors.white : Colors.grey.shade300,
                  // 획득 못 한 곳은 연한 회색 실루엣 느낌
                ),
                child: isUnlocked
                    ? Image.asset(country['asset'], fit: BoxFit.cover)
                    : Center(
                        child: Icon(
                          Icons.add_photo_alternate_outlined,
                          color: Colors.white.withOpacity(0.5),
                          size: 30,
                        ),
                      ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          country['name'],
          style: TextStyle(
            fontSize: 12,
            fontWeight: isUnlocked ? FontWeight.bold : FontWeight.normal,
            color: isUnlocked ? Colors.black87 : Colors.grey.shade500,
          ),
        ),
      ],
    );
  }
}

class HexagonClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    // 👈 getPath를 getClip으로 수정했습니다!
    final path = Path();
    final w = size.width;
    final h = size.height;

    path.moveTo(w * 0.5, 0); // 상단 중앙
    path.lineTo(w, h * 0.25); // 우측 상단
    path.lineTo(w, h * 0.75); // 우측 하단
    path.lineTo(w * 0.5, h); // 하단 중앙
    path.lineTo(0, h * 0.75); // 좌측 하단
    path.lineTo(0, h * 0.25); // 좌측 상단
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
