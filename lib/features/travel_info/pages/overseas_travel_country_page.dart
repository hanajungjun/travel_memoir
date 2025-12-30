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

    setState(() {
      _countries = list;
      _filtered = list;
      _loading = false;
    });
  }

  void _search(String q) {
    setState(() {
      _filtered = _countries
          .where(
            (c) =>
                c.displayName().toLowerCase().contains(q.toLowerCase()) ||
                c.code.toLowerCase().contains(q.toLowerCase()),
          )
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('국가 선택', style: AppTextStyles.appBarTitle),
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
                                ),
                              )
                            : const SizedBox(width: 36),

                        title: Text(
                          c.displayName(),
                          style: AppTextStyles.body.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                        subtitle: Text(
                          c.continent,
                          style: AppTextStyles.caption,
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
