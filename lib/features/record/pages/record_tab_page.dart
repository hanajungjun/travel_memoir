import 'dart:async';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
  final PageController _controller = PageController(viewportFraction: 0.85);
  final _supabase = Supabase.instance.client;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 🎯 1. build 시작점에 이 한 줄을 넣어주면 로케일 변경을 구독하게 됩니다.
    final currentLocale = context.locale.toString();

    return Scaffold(
      backgroundColor: const Color(0xFF373B3E),
      body: SafeArea(
        top: false,
        bottom: false,
        child: StreamBuilder<List<Map<String, dynamic>>>(
          // 🎯 2. key를 부여해서 언어 변경 시 스트림 빌더를 강제로 다시 태웁니다.
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

            // 로딩 상태 처리 (기존 로직 유지)
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
            // 이렇게 해야 travels.first를 호출할 일이 없어서 앱이 안 터져!
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
            return PageView.builder(
              controller: _controller,
              scrollDirection: Axis.vertical,
              padEnds: false,
              clipBehavior: Clip.none,
              physics: const ClampingScrollPhysics(),
              itemCount: travels.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return SummaryHeroCard(
                    totalCount: travels.length,
                    travels: travels,
                  );
                }
                return TravelRecordCard(
                  key: ValueKey(travels[index - 1]['id']),
                  travel: travels[index - 1],
                );
              },
            );
          },
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

    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 60, 0, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'memory_hero_title'.tr(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'memory_hero_label'.tr(),
                    style: const TextStyle(
                      color: Color(0xFFFFC107),
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'memory_hero_subtitle'.tr(),
                    style: const TextStyle(color: Colors.white60, fontSize: 18),
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
            const SizedBox(height: 40),
            SizedBox(
              height: 240,
              child: ListView.builder(
                scrollDirection: Axis.horizontal, // 🎯 괄호 지우고 쉼표로 수정 완료!
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: travels.length,
                itemBuilder: (context, index) {
                  // 🎯 이제 itemBuilder를 정상적으로 인식해
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
                      width: 200,
                      margin: const EdgeInsets.only(right: 20, bottom: 15),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(2, 4),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
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
            const SizedBox(height: 40),
            const Center(
              child: Icon(
                Icons.keyboard_arrow_down,
                color: Colors.white24,
                size: 32,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoTile(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Container(
            width: 4,
            height: 4,
            decoration: const BoxDecoration(
              color: Colors.white38,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(color: Colors.white38, fontSize: 14),
          ),
        ],
      ),
      const SizedBox(height: 6),
      Padding(
        padding: const EdgeInsets.only(left: 12),
        child: Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.bold,
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
    Color badgeColor = const Color(0xFF42A5F5);

    if (type == 'domestic') {
      badgeText = 'domestic'.tr();
      badgeColor = const Color(0xFF66BB6A);
    } else if (type == 'usa') {
      badgeText = 'usa'.tr();
      badgeColor = const Color(0xFFEF5350);
    }

    String destination;
    // 🎯 [핵심 수정] 언어 설정 및 DB 데이터에 따른 목적지 명칭 결정
    if (isKo) {
      // 한국어 모드: 기존처럼 한국어 명칭 우선
      if (type == 'domestic') {
        destination = travel['region_name'] ?? '알 수 없는 지역';
      } else {
        destination =
            travel['country_name_ko'] ??
            travel['display_country_name'] ??
            '해외 여행';
      }
    } else {
      // 영어 모드: 우리가 서비스에서 저장한 display_country_name을 최우선으로 사용
      // 이게 없으면 region_key나 country_name_en에서 추출
      final String? savedEnName = travel['display_country_name'];

      if (savedEnName != null && savedEnName.isNotEmpty) {
        destination = savedEnName;
      } else if (type == 'domestic') {
        // KR_GB_BONGHWA -> BONGHWA
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
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 40),
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => TravelAlbumPage(travel: travel)),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.zero,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 15,
                offset: const Offset(0, 10),
              ),
            ],
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

                // ✅ 수정된 타이틀 영역 (Summary 위로 이동)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: summary.isNotEmpty
                      ? 120
                      : 60, // summary 존재 여부에 따라 위치 조정
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: badgeColor.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          badgeText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          destination.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                            shadows: [
                              Shadow(
                                color: Colors.black54,
                                blurRadius: 10,
                                offset: Offset(0, 2),
                              ),
                            ],
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
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 80), // 마지막 40을 20으로 변경
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
