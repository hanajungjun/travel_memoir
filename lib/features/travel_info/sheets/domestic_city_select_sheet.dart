import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart'; // ✅ 추가
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

  // ✅ 행정구역 명칭 기반 로직은 데이터 구조(koreaRegions)에 종속되므로 그대로 유지합니다.
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
      height: MediaQuery.of(context).size.height,
      decoration: const BoxDecoration(
        color: Color(0xFFF8F9FA),
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      child: Column(
        children: [
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
                autofocus: true,
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  hintText: 'search_city_hint'.tr(), // ✅ 번역 적용
                  hintStyle: const TextStyle(color: Colors.black26),
                  prefixIcon: const Icon(Icons.search, color: Colors.black26),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 15),
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

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
