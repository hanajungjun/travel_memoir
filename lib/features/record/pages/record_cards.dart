import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/shared/styles/text_styles.dart';
import 'package:travel_memoir/core/utils/date_utils.dart';
import 'package:travel_memoir/features/travel_album/pages/travel_album_page.dart';

// =====================================================
// 🧭 [1] 상단 요약 히어로 카드
// =====================================================
class SummaryHeroCard extends StatelessWidget {
  final int totalCount;
  final Map<String, dynamic> lastTravel;

  const SummaryHeroCard({
    super.key,
    required this.totalCount,
    required this.lastTravel,
  });

  @override
  Widget build(BuildContext context) {
    // 마지막 여행 날짜 추출 및 포맷팅
    final endDateStr = lastTravel['end_date']?.toString() ?? '';
    final end = DateTime.tryParse(endDateStr) ?? DateTime.now();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Spacer(),
            // 페이지 타이틀 (예: "당신의 모든 기록")
            Text('memory_hero_title'.tr(), style: AppTextStyles.pageTitle),
            const SizedBox(height: 24),

            // 총 여행 횟수
            Text(
              'total_travels_format'.tr(args: [totalCount.toString()]),
              style: AppTextStyles.body,
            ),
            const SizedBox(height: 8),

            // 마지막 여행 일자
            Text(
              'last_travel_format'.tr(args: [DateUtilsHelper.formatYMD(end)]),
              style: AppTextStyles.body,
            ),

            // "방금 전", "3일 전" 등 시간 경과 표시
            Text(
              DateUtilsHelper.memoryTimeAgo(end),
              style: AppTextStyles.bodyMuted,
            ),
            const Spacer(),

            // 하단 스크롤 유도 아이콘
            const Center(
              child: Icon(
                Icons.keyboard_arrow_up,
                size: 28,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================
// 🧳 [2] 개별 여행 레코드 카드
// =====================================================
class TravelRecordCard extends StatelessWidget {
  final Map<String, dynamic> travel;
  final VoidCallback onReturn;

  const TravelRecordCard({
    super.key,
    required this.travel,
    required this.onReturn,
  });

  @override
  Widget build(BuildContext context) {
    final isKo = context.locale.languageCode == 'ko';
    final type = travel['travel_type'] ?? 'domestic';

    // 🎯 목적지 표시 이름 결정 로직 (국내/미국/해외 통합)
    String destination;
    if (type == 'usa') {
      // 🇺🇸 미국: 주 이름(Arizona 등) 우선 표시
      destination =
          travel['region_name'] ??
          travel['region_key'] ??
          (isKo ? '미국' : 'USA');
    } else if (type == 'domestic') {
      // 🇰🇷 국내: 지역명 표시
      if (isKo) {
        destination = travel['region_name'] ?? 'unknown_destination'.tr();
      } else {
        final String rawKey = travel['region_key'] ?? '';
        destination = rawKey.isNotEmpty ? rawKey.split('_').last : 'Korea';
      }
    } else {
      // 🌍 기타 해외: 국가명 표시
      destination = isKo
          ? (travel['country_name_ko'] ?? 'unknown_destination'.tr())
          : (travel['country_name_en'] ??
                travel['country_code'] ??
                'unknown_destination'.tr());
    }

    // 이미지 및 요약 데이터 준비
    final String? coverUrl = travel['cover_image_url'] as String?;
    final String summary = (travel['ai_cover_summary'] ?? '').toString().trim();

    // 🎯 이미지 주소 생성 (타임스탬프를 통한 캐시 갱신 대응)
    String finalImageUrl = coverUrl ?? '';
    if (finalImageUrl.isNotEmpty && travel['completed_at'] != null) {
      finalImageUrl = '$finalImageUrl?t=${travel['completed_at']}';
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TravelAlbumPage(travel: travel),
              ),
            ).then((_) => onReturn());
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                // 🎯 [이미지 영역] CachedNetworkImage 적용 및 띄어쓰기 인코딩
                Positioned.fill(
                  child: finalImageUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: Uri.encodeFull(
                            finalImageUrl,
                          ), // 띄어쓰기 안전하게 변환
                          fit: BoxFit.cover,
                          // 로딩 중 표시
                          placeholder: (context, url) => Container(
                            color: AppColors.lightSurface,
                            child: const Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.divider,
                              ),
                            ),
                          ),
                          // 에러 발생 시 처리
                          errorWidget: (context, url, error) => Container(
                            color: AppColors.divider,
                            child: const Icon(
                              Icons.broken_image,
                              color: Colors.white,
                            ),
                          ),
                        )
                      : Container(color: AppColors.divider),
                ),

                // 🏷️ 여행지 이름 레이블 (상단 고정)
                Positioned(
                  top: 24,
                  left: 20,
                  right: 20,
                  child: Text(
                    destination,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.0,
                      shadows: [
                        Shadow(
                          color: Colors.black87,
                          offset: Offset(0, 2),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  ),
                ),

                // 🤖 AI 요약 정보 레이블 (하단 고정)
                if (finalImageUrl.isNotEmpty && summary.isEmpty)
                  BottomLabel(text: 'ai_organizing'.tr()),
                if (summary.isNotEmpty)
                  BottomLabel(text: summary, gradient: true),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =====================================================
// 🏷️ [3] 하단 텍스트 라벨 (공통 위젯)
// =====================================================
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
        padding: const EdgeInsets.all(18),
        decoration: gradient
            ? const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black87],
                ),
              )
            : const BoxDecoration(color: Colors.black45),
        child: Text(
          text,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.body.copyWith(color: Colors.white, fontSize: 15),
        ),
      ),
    );
  }
}
