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
  // ✅ 0.85 비율 유지 (다음 카드가 약 15% 보임)
  final PageController _controller = PageController(viewportFraction: 0.85);
  final _supabase = Supabase.instance.client;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: _supabase
              .from('travels')
              .stream(primaryKey: ['id'])
              .order('end_date', ascending: false),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final travels = (snapshot.data ?? [])
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
              padEnds: false,
              // ✅ 중요: 카드들이 서로 겹치지 않게 clipBehavior를 설정
              clipBehavior: Clip.none,
              itemCount: travels.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return SummaryHeroCard(
                    totalCount: travels.length,
                    lastTravel: travels.first,
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
  final Map<String, dynamic> lastTravel;
  const SummaryHeroCard({
    super.key,
    required this.totalCount,
    required this.lastTravel,
  });

  @override
  Widget build(BuildContext context) {
    final end =
        DateTime.tryParse(lastTravel['end_date'] ?? '') ?? DateTime.now();
    return Padding(
      // ✅ 하단 마진을 30으로 늘려 다음 카드가 올라와도 텍스트가 겹치지 않게 함
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 30),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            colors: [Color(0xFF1A1A1A), Color(0xFF454B54)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '기억을 다시 꺼내볼까요?',
                style: AppTextStyles.pageTitle.copyWith(
                  color: Colors.white,
                  fontSize: 26,
                ),
              ),
              const SizedBox(height: 40),
              _infoTile('지금까지의 여행', '총 $totalCount번'),
              const SizedBox(height: 20),
              _infoTile('마지막 여행', DateUtilsHelper.formatYMD(end)),
              Text(
                DateUtilsHelper.memoryTimeAgo(end),
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
              const Spacer(),
              const Center(
                child: Icon(
                  Icons.keyboard_arrow_up,
                  color: Colors.white38,
                  size: 28,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoTile(String l, String v) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(l, style: TextStyle(color: Colors.white60, fontSize: 13)),
      Text(
        v,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 19,
          fontWeight: FontWeight.bold,
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

    // ✅ [복구] 지역명 로직 100% 원본 유지
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
      // ✅ [해결] 하단 패딩을 40 이상 넉넉히 줘야 다음 카드가 텍스트 요약을 안 가립니다.
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => TravelAlbumPage(travel: travel)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              Positioned.fill(
                child: finalImageUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: finalImageUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) =>
                            Container(color: AppColors.lightSurface),
                      )
                    : Container(color: AppColors.divider),
              ),
              Positioned(
                top: 32,
                left: 24,
                right: 24,
                child: Text(
                  destination,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    shadows: [
                      Shadow(
                        color: Colors.black87,
                        blurRadius: 10,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),

              // ✅ 하단 요약 (그라데이션 포함)
              if (summary.isNotEmpty)
                BottomLabel(text: summary, gradient: true),
              if (finalImageUrl.isNotEmpty && summary.isEmpty)
                const BottomLabel(text: 'AI가 여행을 정리하고 있어요...'),
            ],
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
        // ✅ 패딩을 조절해서 텍스트가 카드 안쪽으로 더 들어오게 함
        padding: const EdgeInsets.fromLTRB(20, 35, 20, 55),
        decoration: gradient
            ? const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.transparent, Colors.black87],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              )
            : const BoxDecoration(color: Colors.black45),
        child: Text(
          text,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.body.copyWith(color: Colors.white, fontSize: 14),
        ),
      ),
    );
  }
}
