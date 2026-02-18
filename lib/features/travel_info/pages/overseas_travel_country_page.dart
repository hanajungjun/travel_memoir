import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_svg/flutter_svg.dart'; // ✅ SVG 패키지 임포트 확인
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

    // 언어 설정에 따른 정렬
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
      backgroundColor: const Color(0xFFF6F6F6),
      body: SafeArea(
        child: Column(
          children: [
            // 1. 상단 헤더 영역 (닫기 버튼)
            Padding(
              padding: const EdgeInsets.fromLTRB(23, 15, 32, 7),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      size: 27,
                      color: Color(0xFF909090),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // 2. 🔍 검색 입력창 (그림자가 있는 카드 디자인)
            Padding(
              padding: const EdgeInsets.fromLTRB(27, 0, 27, 30),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: TextField(
                  onChanged: _search,
                  // ✅ 1. 입력되는 글자의 스타일 설정 (입력 시 나타나는 글자)
                  style: const TextStyle(
                    fontSize: 16, // 원하는 크기로 조절
                    color: Color(0xFF333333), // 원하는 색상으로 조절
                    fontWeight: FontWeight.w400,
                  ),
                  decoration: InputDecoration(
                    hintText: 'search_country_hint'.tr(),
                    // ✅ 2. 힌트 텍스트 스타일 설정 ("국가 검색" 가이드 글자)
                    hintStyle: const TextStyle(
                      fontSize: 16, // 입력 글자와 크기를 맞추는 것이 깔끔합니다
                      color: Color(0xFFBDBDBD), // 힌트는 보통 연한 회색
                      fontWeight: FontWeight.w400,
                    ),
                    prefixIconConstraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    prefixIcon: Padding(
                      padding: const EdgeInsets.only(left: 15, right: 8),
                      child: SvgPicture.asset(
                        'assets/icons/ico_search.svg',
                        width: 16,
                        height: 16,
                      ),
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ),

            // 3. 🌍 국가 리스트 영역
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 27,
                      ), // ✅ 좌우 여백 27로 변경
                      itemCount: _filtered.length,
                      separatorBuilder: (_, __) => const Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: 2,
                        ), // 도트 라인 위아래 간격
                        child: DottedDivider(), // ✅ 도트 라인 구분선 적용
                      ),
                      itemBuilder: (context, index) {
                        final c = _filtered[index];
                        return ListTile(
                          contentPadding: const EdgeInsets.only(left: 5),
                          minLeadingWidth: 48, // ✅ 추가
                          leading: c.flagUrl != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: Image.network(
                                    c.flagUrl!,
                                    width: 48,
                                    height: 32,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            const SizedBox(
                                              width: 48,
                                              child: Icon(Icons.flag),
                                            ),
                                  ),
                                )
                              : const SizedBox(width: 10),
                          title: Text(
                            isKo ? c.nameKo : c.nameEn,
                            style: AppTextStyles.body.copyWith(
                              fontSize: 15,
                              color: AppColors.textColor01,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: Text(
                            isKo ? '${c.nameEn} · ${c.continent}' : c.continent,
                            style: AppTextStyles.bodyMuted.copyWith(
                              fontSize: 12,
                              color: Color(0xFF686868),
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                          trailing: const Icon(
                            Icons.chevron_right,
                            color: Color(0xFFD1D1D1),
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
      ),
    );
  }
}

/// ✅ 도트 라인(점선)을 그리기 위한 위젯
class DottedDivider extends StatelessWidget {
  const DottedDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(double.infinity, 1),
      painter: DashPainter(),
    );
  }
}

class DashPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    double dashWidth = 2, dashSpace = 3, startX = 0;
    final paint = Paint()
      ..color =
          const Color(0xFFD1D1D1) // 이미지와 유사한 연한 회색 점선
      ..strokeWidth = 1;
    while (startX < size.width) {
      canvas.drawLine(Offset(startX, 0), Offset(startX + dashWidth, 0), paint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
