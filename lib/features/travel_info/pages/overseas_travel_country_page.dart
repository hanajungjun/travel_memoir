import 'package:flutter/material.dart';

import 'package:travel_memoir/models/country_model.dart';
import 'package:travel_memoir/services/country_service.dart';

import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/shared/styles/text_styles.dart';

class OverseasTravelCountryPage extends StatefulWidget {
  const OverseasTravelCountryPage({super.key});

  @override
  State<OverseasTravelCountryPage> createState() =>
      _OverseasTravelCountryPageState();
}

class _OverseasTravelCountryPageState extends State<OverseasTravelCountryPage> {
  List<CountryModel> _countries = [];
  List<CountryModel> _filtered = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await CountryService.fetchAll();

    if (!mounted) return;

    // ✅ [추가] 가나다/ABC 순으로 정렬
    list.sort((a, b) => a.displayName().compareTo(b.displayName()));

    setState(() {
      _countries = list;
      _filtered = list;
      _loading = false;
    });
  }

  void _search(String q) {
    final query = q.trim().toLowerCase();
    setState(() {
      _filtered = _countries.where((c) {
        // ✅ [개선] 한국어 이름, 영어 이름, 국가 코드를 모두 검색 대상에 포함
        return c.nameKo.contains(query) ||
            c.nameEn.toLowerCase().contains(query) ||
            c.code.toLowerCase().contains(query);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('국가 선택', style: AppTextStyles.pageTitle),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 🔍 검색
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    onChanged: _search,
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: '국가 검색',
                      hintStyle: AppTextStyles.bodyMuted,
                      prefixIcon: const Icon(
                        Icons.search,
                        color: AppColors.textSecondary,
                      ),
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),

                // 🌍 국가 리스트
                Expanded(
                  child: ListView.separated(
                    itemCount: _filtered.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: AppColors.divider),
                    itemBuilder: (context, index) {
                      final c = _filtered[index];

                      return ListTile(
                        leading: c.flagUrl != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: Image.network(
                                  c.flagUrl!,
                                  width: 36,
                                  height: 24,
                                  fit: BoxFit.cover,
                                  // 💡 이미지가 로딩되지 않을 때를 대비한 처리
                                  errorBuilder: (context, error, stackTrace) =>
                                      const SizedBox(
                                        width: 36,
                                        child: Icon(Icons.flag),
                                      ),
                                ),
                              )
                            : const SizedBox(width: 36),

                        title: Text(
                          // ✅ displayName() 대신 직접 한국어 이름을 우선적으로 보여주고 싶다면:
                          c.nameKo,
                          // 만약 "한국어(영어)" 형태를 원하신다면: '${c.nameKo} (${c.nameEn})'
                          style: AppTextStyles.body.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(
                          // ✅ 영문 이름을 부제목으로 넣으면 더 가독성이 좋아집니다.
                          '${c.nameEn} · ${c.continent}',
                          style: AppTextStyles.bodyMuted.copyWith(fontSize: 12),
                        ),

                        trailing: const Icon(
                          Icons.chevron_right,
                          color: AppColors.textDisabled,
                        ),

                        onTap: () {
                          // ✅ 선택 결과 반환
                          Navigator.pop(context, c);
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
