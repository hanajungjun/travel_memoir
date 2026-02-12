import 'dart:async';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/shared/styles/text_styles.dart';
import 'package:travel_memoir/core/utils/date_utils.dart';
import 'package:travel_memoir/features/travel_album/pages/travel_album_page.dart';
import 'package:travel_memoir/storage_urls.dart';

class RecordTabPage extends StatefulWidget {
  const RecordTabPage({super.key});

  @override
  State<RecordTabPage> createState() => _RecordTabPageState();
}

class _RecordTabPageState extends State<RecordTabPage> {
  // 🎯 로직 유지: 컨트롤러는 필요에 따라 유지하거나 제거해도 무방합니다.
  final _supabase = Supabase.instance.client;

  @override
  Widget build(BuildContext context) {
    // 🎯 1. build 시작점에 이 한 줄을 넣어주면 로케일 변경을 구독하게 됩니다.
    final currentLocale = context.locale.toString();
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0.5, 1],
            colors: [Color(0xFF474D51), Color(0xFF393E41)],
          ),
        ),
        child: SafeArea(
          top: false,
          bottom: false,
          child: StreamBuilder<List<Map<String, dynamic>>>(
            key: ValueKey(currentLocale),
            stream: _supabase
                .from('travels')
                .stream(primaryKey: ['id'])
                .order('end_date', ascending: false),
            builder: (context, snapshot) {
              // 1️⃣ [디버깅] 실제 스트림으로 들어오는 원본 데이터 개수를 확인해봐
              if (snapshot.hasData) {
                debugPrint(
                  "🔍 [RECORD_DEBUG] Raw Data Count: ${snapshot.data?.length}",
                );
              }

              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              // 1️⃣ [수정] 완료된 여행만 필터링
              final rawData = snapshot.data ?? [];
              final travels = rawData
                  .where((t) => t['is_completed'] == true)
                  .toList();

              // 2️⃣ [핵심] 완료된 여행이 하나도 없다면 "기록 없음" 표시
              if (travels.isEmpty) {
                return Center(
                  child: Text(
                    'no_completed_travels'.tr(),
                    style: AppTextStyles.bodyMuted.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                );
              }

              // 🎯 MediaQuery 대신 LayoutBuilder를 사용하여 실제 가용 높이에 맞춥니다.
              return LayoutBuilder(
                builder: (context, constraints) {
                  final availableHeight = constraints.maxHeight;

                  // 🎯 디자인 최종 수정: 첫 페이지 100% + 이후 70% 카드들이 '딱딱' 붙게 구현
                  // 🎯 마지막 카드도 70%를 유지하되 메뉴바 위로 올리기 위해 CustomScrollView 구조를 조정합니다.
                  return CustomScrollView(
                    physics: const PageScrollPhysics(), // 🎯 스냅 효과 유지
                    slivers: [
                      // 1. 첫 번째 페이지: 디바이스 높이 100% (메뉴바 포함 전체 기준)
                      SliverToBoxAdapter(
                        child: SizedBox(
                          height: MediaQuery.of(context).size.height,
                          child: SummaryHeroCard(
                            totalCount: travels.length,
                            travels: travels,
                          ),
                        ),
                      ),
                      // 2. 이후 여행 카드 리스트 (70% 높이 유지)
                      SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          return SizedBox(
                            height: MediaQuery.of(context).size.height * 0.7,
                            child: TravelRecordCard(
                              key: ValueKey(travels[index]['id']),
                              travel: travels[index],
                            ),
                          );
                        }, childCount: travels.length),
                      ),
                      // 🎯 핵심 수정: 마지막 카드 뒤에 메뉴바 높이만큼의 여백(Sliver)을 추가합니다.
                      // 이렇게 하면 마지막 70% 카드가 메뉴바 위로 밀려 올라오게 됩니다.
                      SliverToBoxAdapter(
                        child: SizedBox(
                          height: MediaQuery.of(context).padding.bottom,
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class SummaryHeroCard extends StatelessWidget {
  final int totalCount;
  final List<Map<String, dynamic>> travels;

  const SummaryHeroCard({
    super.key,
    required this.totalCount,
    required this.travels,
  });

  @override
  Widget build(BuildContext context) {
    final lastTravel = travels.first;
    final end =
        DateTime.tryParse(lastTravel['end_date'] ?? '') ?? DateTime.now();

    // 🎯 디자인 수정: Spacer 사용 시 발생할 수 있는 런타임 오류 방지를 위해 LayoutBuilder 사용
    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(45, 120, 45, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'memory_hero_title'.tr(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    'memory_hero_label'.tr(),
                    style: const TextStyle(
                      color: Color(0xFFFFC669),
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    'memory_hero_subtitle'.tr(),
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 22,
                      fontWeight: FontWeight.w100,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 50),
                  _infoTile(
                    'total_travels_format1'.tr(),
                    'total_travels_format2'.tr(args: [totalCount.toString()]),
                  ),
                  const SizedBox(height: 35),
                  _infoTile(
                    'last_travel_format1'.tr(),
                    'last_travel_format2'.tr(
                      args: [DateUtilsHelper.formatYMD(end)],
                    ),
                  ),
                ],
              ),
            ),

            // 🎯 디자인 핵심: Spacer를 통해 하단 카드 리스트를 바닥으로 밀착시킵니다.
            const Spacer(),

            SizedBox(
              height: 250,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 30),
                itemCount: travels.length,
                itemBuilder: (context, index) {
                  final travel = travels[index];
                  final String type = travel['travel_type'] ?? 'domestic';
                  final String countryCode = (travel['country_code'] ?? '')
                      .toString()
                      .toUpperCase();
                  final String rawPath = (travel['map_image_url'] ?? '')
                      .toString();

                  String finalUrl = (type == 'usa' || countryCode == 'US')
                      ? StorageUrls.usaMapFromPath(rawPath)
                      : (type == 'domestic')
                      ? StorageUrls.domesticMapFromPath(rawPath)
                      : StorageUrls.globalMapFromPath('$countryCode.png');

                  return GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TravelAlbumPage(travel: travel),
                      ),
                    ),
                    child: Container(
                      width: 250,
                      margin: const EdgeInsets.only(right: 18),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: CachedNetworkImage(
                          imageUrl: finalUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            color: Colors.grey[200],
                            child: const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                          errorWidget: (_, __, ___) => Container(
                            color: Colors.grey[200],
                            child: const Icon(
                              Icons.map_outlined,
                              color: Colors.grey,
                              size: 40,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            // 🎯 수정 후 (SummaryHeroCard 맨 하단 아이콘 부분)
            Container(
              padding: EdgeInsets.fromLTRB(
                27,
                20,
                27,
                MediaQuery.of(context).padding.bottom, // 🎯 요청하신 정밀 수치
              ),
              child: Center(
                child: SvgPicture.asset(
                  'assets/icons/ico_arrowdown.svg',
                  width: 18,
                  height: 11,
                  color: Colors.white24, // 1.1.6 버전은 colorFilter 대신 color 사용
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }

  Widget _infoTile(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Container(
            width: 3,
            height: 3,
            decoration: const BoxDecoration(
              color: Color(0xFFC6C7C9),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFC6C7C9),
              fontSize: 12,
              fontWeight: FontWeight.w200,
            ),
          ),
        ],
      ),
      const SizedBox(height: 4),
      Padding(
        padding: const EdgeInsets.only(left: 12),
        child: Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ],
  );
}

class TravelRecordCard extends StatelessWidget {
  final Map<String, dynamic> travel;
  const TravelRecordCard({super.key, required this.travel});

  @override
  Widget build(BuildContext context) {
    final isKo = context.locale.languageCode == 'ko';
    final type = travel['travel_type'] ?? 'domestic';

    String badgeText = 'overseas'.tr();
    Color badgeColor = AppColors.travelingPurple;

    if (type == 'domestic') {
      badgeText = 'domestic'.tr();
      badgeColor = AppColors.travelingBlue;
    } else if (type == 'usa') {
      badgeText = 'usa'.tr();
      badgeColor = AppColors.travelingRed;
    }

    String destination;
    // 🎯 [수정] 미국(usa) 여행도 국내(domestic)처럼 지역명을 우선하도록 변경
    if (isKo) {
      // 한국어 설정일 때
      if (type == 'domestic' || type == 'usa') {
        // 국내 또는 미국 여행이면 지역명(region_name) 사용
        destination =
            travel['region_name'] ?? (type == 'usa' ? '미국 여행' : '알 수 없는 지역');
      } else {
        // 그 외 해외 여행은 국가명 사용
        destination =
            travel['country_name_ko'] ??
            travel['display_country_name'] ??
            '해외 여행';
      }
    } else {
      // 영어 설정일 때
      final String? savedEnName = travel['display_country_name'];

      if (type == 'usa') {
        // 미국 여행일 때 지역명(region_name)이나 미리 저장된 영어 이름 사용
        destination = savedEnName ?? travel['region_name'] ?? 'USA';
      } else if (savedEnName != null && savedEnName.isNotEmpty) {
        destination = savedEnName;
      } else if (type == 'domestic') {
        final String regKey = travel['region_key']?.toString() ?? '';
        destination = regKey.contains('_') ? regKey.split('_').last : 'KOREA';
      } else {
        destination =
            travel['country_name_en'] ?? travel['country_code'] ?? 'Global';
      }
    }
    final String coverUrl = (travel['cover_image_url'] ?? '').toString();
    final String summary = (travel['ai_cover_summary'] ?? '').toString().trim();
    String finalImageUrl = coverUrl.isEmpty
        ? ''
        : (coverUrl.startsWith('http')
              ? coverUrl
              : Supabase.instance.client.storage
                    .from('travel_images')
                    .getPublicUrl(coverUrl));
    if (finalImageUrl.isNotEmpty)
      finalImageUrl =
          '$finalImageUrl?t=${travel['completed_at']}&width=500&quality=70';

    return Padding(
      padding: const EdgeInsets.all(0), // 🎯 여백 완전 제거
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => TravelAlbumPage(travel: travel)),
        ),
        child: Container(
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.zero,
            // 🎯 기존 BoxShadow 대신 배경색을 지정하거나 비워둡니다.
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.zero,
            child: Stack(
              children: [
                Positioned.fill(
                  child: finalImageUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: finalImageUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, __) =>
                              Container(color: const Color(0xFF454B54)),
                        )
                      : Container(color: const Color(0xFF454B54)),
                ),

                // 🎯 [신규 추가] 카드의 하단 절반 정도를 덮는 어두운 그라데이션 영역
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        // 🎯 0.5(절반) 지점부터 검은색이 시작되어 바닥으로 갈수록 진해집니다.
                        stops: const [0.5, 1.0],
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.75), // 농도는 0.6 정도로 조절 가능
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: summary.isEmpty
                      ? 60 // 1. 내용이 아예 없을 때
                      : (summary.length > 40
                            ? 103 // 2. 글이 길 때 (약 2줄 이상)
                            : 80), // 3. 글이 짧을 때 (1줄)
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: badgeColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          badgeText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          destination.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 27,
                            fontWeight: FontWeight.w700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                if (summary.isNotEmpty)
                  BottomLabel(text: summary, gradient: true),
                if (finalImageUrl.isNotEmpty && summary.isEmpty)
                  BottomLabel(text: 'ai_organizing'.tr()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class BottomLabel extends StatelessWidget {
  final String text;
  final bool gradient;
  const BottomLabel({super.key, required this.text, this.gradient = false});
  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          20,
          20,
          20,
          50,
        ), // 🎯 하단 여백 제거 (80 -> 20)
        decoration: gradient
            ? BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              )
            : BoxDecoration(color: Colors.black.withOpacity(0.4)),
        child: Text(
          text,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
