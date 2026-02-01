import 'dart:async';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/shared/styles/text_styles.dart';
import 'package:travel_memoir/core/utils/date_utils.dart';
import 'package:travel_memoir/features/travel_album/pages/travel_album_page.dart';

class RecordTabPage extends StatefulWidget {
  const RecordTabPage({super.key});

  @override
  State<RecordTabPage> createState() => _RecordTabPageState();
}

class _RecordTabPageState extends State<RecordTabPage> {
  final PageController _controller = PageController();
  final _supabase = Supabase.instance.client;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: ValueKey(context.locale.toString()),
      backgroundColor: AppColors.background,
      // ✅ FutureBuilder를 StreamBuilder로 교체하여 실시간 감시 시작!
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _supabase
            .from('travels')
            .stream(primaryKey: ['id'])
            .order('end_date', ascending: false),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          // ✅ 완료된 여행만 실시간으로 필터링
          final allTravels = snapshot.data ?? [];
          final travels = allTravels
              .where((t) => t['is_completed'] == true)
              .toList();

          if (travels.isEmpty) {
            return Center(
              child: Text(
                'no_completed_travels'.tr(),
                style: AppTextStyles.bodyMuted,
              ),
            );
          }

          return PageView.builder(
            controller: _controller,
            scrollDirection: Axis.vertical,
            itemCount: travels.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return SummaryHeroCard(
                  totalCount: travels.length,
                  lastTravel: travels.first,
                );
              }
              final travel = travels[index - 1];
              return TravelRecordCard(
                key: ValueKey(travel['id']), // ✅ 키를 지정하여 개별 카드 식별
                travel: travel,
              );
            },
          );
        },
      ),
    );
  }
}

// =====================================================
// 🧳 개별 여행 레코드 카드 (최적화 버전)
// =====================================================
class TravelRecordCard extends StatelessWidget {
  final Map<String, dynamic> travel;

  const TravelRecordCard({super.key, required this.travel});

  @override
  Widget build(BuildContext context) {
    final isKo = context.locale.languageCode == 'ko';
    final type = travel['travel_type'] ?? 'domestic';

    String destination;
    if (type == 'usa') {
      destination =
          travel['region_name'] ??
          travel['region_key'] ??
          (isKo ? '미국' : 'USA');
    } else if (type == 'domestic') {
      destination = isKo
          ? (travel['region_name'] ?? '알 수 없음')
          : (travel['region_key']?.split('_').last ?? 'Korea');
    } else {
      destination = isKo
          ? (travel['country_name_ko'] ?? '알 수 없음')
          : (travel['country_name_en'] ?? 'Unknown');
    }

    final String? coverUrl = travel['cover_image_url'] as String?;
    final String summary = (travel['ai_cover_summary'] ?? '').toString().trim();

    String finalImageUrl = '';
    if (coverUrl != null && coverUrl.isNotEmpty) {
      finalImageUrl = coverUrl.startsWith('http')
          ? coverUrl
          : Supabase.instance.client.storage
                .from('travel_images')
                .getPublicUrl(coverUrl);

      // ✅ 썸네일 최적화 파라미터 추가 (여기도 적용!)
      finalImageUrl =
          '$finalImageUrl?t=${travel['completed_at']}&width=400&quality=70';
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
            );
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                Positioned.fill(
                  child: finalImageUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: Uri.encodeFull(finalImageUrl),
                          fit: BoxFit.cover,
                          memCacheWidth: 800, // 커버니까 썸네일보다는 조금 더 크게 캐싱
                          placeholder: (_, __) =>
                              Container(color: AppColors.lightSurface),
                          errorWidget: (_, __, ___) =>
                              Container(color: AppColors.divider),
                        )
                      : Container(color: AppColors.divider),
                ),
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
                if (finalImageUrl.isNotEmpty && summary.isEmpty)
                  const BottomLabel(text: 'AI가 여행을 정리하고 있어요...'),
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

// SummaryHeroCard와 BottomLabel 위젯은 기존과 동일하므로 생략하거나 그대로 유지하시면 됩니다.
// =====================================================
// 🧭 상단 요약 히어로 카드
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
    final endDateStr = lastTravel['end_date']?.toString() ?? '';
    final end = DateTime.tryParse(endDateStr) ?? DateTime.now();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Spacer(),
            Text('memory_hero_title'.tr(), style: AppTextStyles.pageTitle),
            const SizedBox(height: 24),
            Text(
              'total_travels_format'.tr(args: [totalCount.toString()]),
              style: AppTextStyles.body,
            ),
            const SizedBox(height: 8),
            Text(
              'last_travel_format'.tr(args: [DateUtilsHelper.formatYMD(end)]),
              style: AppTextStyles.body,
            ),
            Text(
              DateUtilsHelper.memoryTimeAgo(end),
              style: AppTextStyles.bodyMuted,
            ),
            const Spacer(),
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
