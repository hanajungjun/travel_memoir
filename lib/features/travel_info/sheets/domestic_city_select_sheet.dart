import 'package:flutter/material.dart';
import 'package:travel_memoir/core/constants/korea/korea_all.dart';
import 'package:travel_memoir/core/constants/korea/korea_region.dart';

class DomesticCitySelectSheet extends StatefulWidget {
  const DomesticCitySelectSheet({super.key, required this.onSelected});
  final ValueChanged<KoreaRegion> onSelected;

  @override
  State<DomesticCitySelectSheet> createState() =>
      _DomesticCitySelectSheetState();
}

class _DomesticCitySelectSheetState extends State<DomesticCitySelectSheet> {
  String _query = '';

  bool _isRepresentativeCity(KoreaRegion region) {
    if (region.province.endsWith('광역시') || region.province.endsWith('특별시')) {
      final provinceName = region.province
          .replaceAll('광역시', '')
          .replaceAll('특별시', '');
      return region.name == provinceName;
    }
    return region.type == KoreaRegionType.city;
  }

  @override
  Widget build(BuildContext context) {
    final regions =
        koreaRegions
            .where(_isRepresentativeCity)
            .where((e) => e.name.contains(_query))
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));

    return Container(
      // 🚀 화면 꽉 채우기: 높이를 전체로 설정
      height: MediaQuery.of(context).size.height,
      decoration: const BoxDecoration(
        color: Color(0xFFF8F9FA),
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      child: Column(
        children: [
          // 1. 상단 'X' 버튼 (이미지 스타일)
          Padding(
            padding: const EdgeInsets.only(left: 8, top: 12),
            child: Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.black45, size: 28),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),

          // 2. 검색 바 (그림자 있는 둥근 스타일)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                autofocus: true, // 시트 열리자마자 키보드 활성화
                onChanged: (value) => setState(() => _query = value),
                decoration: const InputDecoration(
                  hintText: '도시를 검색하세요',
                  hintStyle: TextStyle(color: Colors.black26),
                  prefixIcon: Icon(Icons.search, color: Colors.black26),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 15),
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // 3. 리스트 영역 (Expanded로 남은 공간 꽉 채움)
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: regions.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 1, color: Colors.black.withOpacity(0.05)),
              itemBuilder: (context, index) {
                final region = regions[index];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 8,
                  ),
                  title: Text(
                    region.name,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    region.province,
                    style: const TextStyle(color: Colors.black38, fontSize: 14),
                  ),
                  onTap: () {
                    widget.onSelected(region);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
