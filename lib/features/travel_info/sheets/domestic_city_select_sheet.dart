import 'package:flutter/material.dart';
import '../../../core/constants/korea/korea_all.dart';
import '../../../core/constants/korea/korea_region.dart';

class DomesticCitySelectSheet extends StatefulWidget {
  const DomesticCitySelectSheet({super.key, required this.onSelected});

  final ValueChanged<String> onSelected;

  @override
  State<DomesticCitySelectSheet> createState() =>
      _DomesticCitySelectSheetState();
}

class _DomesticCitySelectSheetState extends State<DomesticCitySelectSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final cities =
        koreaRegions
            .where((e) => e.type == KoreaRegionType.city)
            .map((e) => e.name)
            .where((name) => name.contains(_query))
            .toSet()
            .toList()
          ..sort(); // ⭐ 가나다순 정렬

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          decoration: const BoxDecoration(
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
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // 🔍 검색창 (컴팩트)
              TextField(
                onChanged: (value) {
                  setState(() => _query = value);
                },
                decoration: InputDecoration(
                  hintText: '도시 검색',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  isDense: true, // ⭐ 핵심
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  itemCount: cities.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final city = cities[index];
                    return ListTile(
                      title: Text(city),
                      onTap: () {
                        widget.onSelected(city);
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
