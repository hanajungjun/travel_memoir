import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:travel_memoir/core/constants/korea/korea_all.dart';
import 'package:travel_memoir/core/constants/korea/korea_region.dart';
import 'package:flutter_svg/flutter_svg.dart';

class DomesticCitySelectSheet extends StatefulWidget {
  const DomesticCitySelectSheet({super.key, required this.onSelected});
  final ValueChanged<KoreaRegion> onSelected;

  @override
  State<DomesticCitySelectSheet> createState() =>
      _DomesticCitySelectSheetState();
}

class _DomesticCitySelectSheetState extends State<DomesticCitySelectSheet> {
  String _query = '';
  // 🎯 여기에 이 블록을 통째로 넣으세요!
  @override
  void initState() {
    super.initState();

    // 대표 도시로 필터링된 리스트 뽑기
    // final filtered = koreaRegions.where(_isRepresentativeCity).toList();

    // debugPrint('====================================================');
    // debugPrint('📍 [CITY_LIST] 필터링된 총 도시 개수: ${filtered.length}개');
    // debugPrint('----------------------------------------------------');

    // for (var region in filtered) {
    //   // region.id가 바로 형이 궁금해한 regionKey야!
    //   debugPrint('ID(Key): ${region.id.padRight(18)} | 이름: ${region.name}');
    // }

    // debugPrint('====================================================');
  }

  bool _isRepresentativeCity(KoreaRegion region) {
    if (region.province.endsWith('광역시') || region.province.endsWith('특별시')) {
      final provinceName = region.province
          .replaceAll('광역시', '')
          .replaceAll('특별시', '');
      return region.name == provinceName;
    }
    // city와 county(군) 모두 포함
    return region.type == KoreaRegionType.city ||
        region.type == KoreaRegionType.county;
  }

  @override
  Widget build(BuildContext context) {
    // 현재 앱의 언어 설정 확인
    final bool isKo = context.locale.languageCode == 'ko';

    final regions =
        koreaRegions.where(_isRepresentativeCity).where((e) {
            final searchTarget = _query.toLowerCase();
            // 한국어 이름이나 영어 이름 중 하나라도 포함되면 검색 결과에 표시
            return e.name.contains(searchTarget) ||
                e.nameEn.toLowerCase().contains(searchTarget);
          }).toList()
          // 언어 설정에 따라 가나다순 혹은 ABC순 정렬
          ..sort(
            (a, b) =>
                isKo ? a.name.compareTo(b.name) : a.nameEn.compareTo(b.nameEn),
          );

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      body: SafeArea(
        child: Column(
          children: [
            // 1. 상단 헤더 영역 (닫기 버튼 위치 조정)
            Padding(
              padding: const EdgeInsets.fromLTRB(23, 64, 32, 7),
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

            // 2. 🔍 검색 입력창 (첫 번째 소스 스타일 적용)
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
                  autofocus: false,
                  onChanged: (value) => setState(() => _query = value),
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF333333),
                    fontWeight: FontWeight.w400,
                  ),
                  decoration: InputDecoration(
                    hintText: 'search_city_hint'.tr(),
                    hintStyle: const TextStyle(
                      fontSize: 16,
                      color: Color(0xFFBDBDBD),
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

            // 3. 🌍 리스트 영역 (좌우 여백 27px 및 도트 라인 적용)
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 27),
                itemCount: regions.length,
                separatorBuilder: (_, __) => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 2),
                  child: DottedDivider(), // ✅ 도트 라인 구분선 적용
                ),
                itemBuilder: (context, index) {
                  final region = regions[index];
                  return ListTile(
                    contentPadding: const EdgeInsets.only(left: 5),
                    title: Text(
                      // 언어 설정에 따라 이름 표시 (한국어/대문자 영어)
                      isKo ? region.name : region.nameEn,
                      style: const TextStyle(
                        fontSize: 15,
                        color: Color(0xFF333333),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      // 한국어면 기존 province(경기도 등), 영어면 추출한 코드(GG 등) 표시
                      isKo ? region.province : _getProvinceCode(region),
                      style: const TextStyle(
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
                      widget.onSelected(region);
                      Navigator.pop(context);
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
      ..color = const Color(0xFFD1D1D1)
      ..strokeWidth = 1;
    while (startX < size.width) {
      canvas.drawLine(Offset(startX, 0), Offset(startX + dashWidth, 0), paint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

// 💡 함수 추가 (State 클래스 내부에 작성)
String _getProvinceCode(KoreaRegion region) {
  final String id = region.id; // KR_GG_ANYANG 등

  if (id.contains('_')) {
    final parts = id.split('_');
    if (parts.length >= 2) {
      final String code = parts[1].toUpperCase();

      // 🎯 코드를 풀네임으로 변환하는 매핑 테이블
      const Map<String, String> provinceMap = {
        'GG': 'GYEONGGI',
        'GW': 'GANGWON',
        'CB': 'CHUNGBUK',
        'CN': 'CHUNGNAM',
        'JB': 'JEONBUK',
        'JN': 'JEONNAM',
        'GB': 'GYEONGBUK',
        'GN': 'GYEONGNAM',
        'JJ': 'JEJU',
      };

      return provinceMap[code] ?? code; // 매핑 없으면 그냥 코드(예: JB) 출력
    }
  }

  // _가 없는 특별시/광역시는 METRO 리턴
  return 'KOREA';
}
