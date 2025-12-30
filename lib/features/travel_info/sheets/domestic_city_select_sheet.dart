import 'package:flutter/material.dart';
import 'package:travel_memoir/core/constants/korea/korea_all.dart';
import 'package:travel_memoir/core/constants/korea/korea_region.dart';

class DomesticCitySelectSheet extends StatefulWidget {
  const DomesticCitySelectSheet({super.key, required this.onSelected});

  // ✅ KoreaRegion 그대로 반환
  final ValueChanged<KoreaRegion> onSelected;

  @override
  State<DomesticCitySelectSheet> createState() =>
      _DomesticCitySelectSheetState();
}

class _DomesticCitySelectSheetState extends State<DomesticCitySelectSheet> {
  String _query = '';

  /// =========================
  /// ⭐ 대표 도시만 필터링
  /// =========================
  bool _isRepresentativeCity(KoreaRegion region) {
    // 광역시 / 특별시는 "대표 도시"만 허용
    if (region.province.endsWith('광역시') || region.province.endsWith('특별시')) {
      final provinceName = region.province
          .replaceAll('광역시', '')
          .replaceAll('특별시', '');

      return region.name == provinceName;
    }

    // 도 단위는 city 전부 허용 (경산, 경주, 포항 등)
    return region.type == KoreaRegionType.city;
  }

  @override
  Widget build(BuildContext context) {
    // ✅ 대표 도시 + 검색
    final regions =
        koreaRegions
            .where(_isRepresentativeCity)
            .where((e) => e.name.contains(_query))
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          decoration: const BoxDecoration(
            color: Color(0xFF111827),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // 🔽 손잡이
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // 🔍 검색
              TextField(
                style: const TextStyle(color: Colors.white),
                onChanged: (value) {
                  setState(() => _query = value);
                },
                decoration: InputDecoration(
                  hintText: '도시 검색',
                  hintStyle: const TextStyle(color: Colors.white54),
                  prefixIcon: const Icon(
                    Icons.search,
                    size: 20,
                    color: Colors.white70,
                  ),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 12,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.white24),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.white),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // 📍 도시 리스트
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  itemCount: regions.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, color: Colors.white12),
                  itemBuilder: (context, index) {
                    final region = regions[index];
                    return ListTile(
                      title: Text(
                        region.name,
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        region.province,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
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
      },
    );
  }
}
