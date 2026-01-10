import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart'; // ✅ 추가

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

    // ✅ 언어 설정에 따른 정렬 (한국어면 가나다, 영어면 ABC)
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
        return c.nameKo.contains(query) ||
            c.nameEn.toLowerCase().contains(query) ||
            c.code.toLowerCase().contains(query);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isKo = context.locale.languageCode == 'ko';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'select_country'.tr(),
          style: AppTextStyles.pageTitle,
        ), // ✅ 번역 적용
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
                      hintText: 'search_country_hint'.tr(), // ✅ 번역 적용
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
                                  errorBuilder: (context, error, stackTrace) =>
                                      const SizedBox(
                                        width: 36,
                                        child: Icon(Icons.flag),
                                      ),
                                ),
                              )
                            : const SizedBox(width: 36),

                        title: Text(
                          // ✅ 사용자의 언어 설정에 맞춰 이름 표시 (한국어면 한국어 이름, 아니면 영어 이름)
                          isKo ? c.nameKo : c.nameEn,
                          style: AppTextStyles.body.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(
                          // ✅ 한국어일 때는 영문을 병기, 영어일 때는 대륙 정보를 우선 표시
                          isKo ? '${c.nameEn} · ${c.continent}' : c.continent,
                          style: AppTextStyles.bodyMuted.copyWith(fontSize: 12),
                        ),

                        trailing: const Icon(
                          Icons.chevron_right,
                          color: AppColors.textDisabled,
                        ),

                        onTap: () {
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
