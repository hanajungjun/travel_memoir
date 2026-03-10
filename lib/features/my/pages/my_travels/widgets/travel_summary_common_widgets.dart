import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/shared/styles/text_styles.dart';
import 'package:travel_memoir/core/widgets/skeletons/skeleton_box.dart';

// 🧩 1. 공통 도넛 카드 (수정 없음)
class TotalDonutCard extends StatelessWidget {
  final int visited;
  final int total;
  final String? title;
  final String sub;
  final int percent;
  final Color? activeColor; // ✅ 테마 색상을 받기 위해 파라미터를 추가했습니다.

  const TotalDonutCard({
    super.key,
    required this.visited,
    required this.total,
    this.title,
    required this.sub,
    required this.percent,
    this.activeColor, // ✅ 추가된 부분
  });

  @override
  Widget build(BuildContext context) {
    final themeColor =
        activeColor ??
        AppColors.travelingBlue; // ✅ 전달된 색상이 없으면 기본 파란색 사용// ✅ 여기에 추가!

    final bool isKorean = context.locale.languageCode == 'ko';
    final int leftFlex = isKorean ? 1 : 3;
    final int rightFlex = isKorean ? 3 : 5;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(bottom: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ❶ 기존 상단에 있던 title(전체) 텍스트를 제거하고 아래로 옮겼습니다.
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 왼쪽: 방문 수 / 전체 수
              Flexible(
                // ✅ SizedBox(width:100) → Flexible로 변경하여 영문 긴 텍스트 overflow 방지
                flex: leftFlex,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: '$visited',
                            style: AppTextStyles.pageTitle.copyWith(
                              fontSize: 30,
                              fontWeight: FontWeight.w700,
                              color: themeColor,
                            ),
                          ),
                          TextSpan(
                            text: ' / $total',
                            style: const TextStyle(
                              fontSize: 20,
                              color: AppColors.textColor01,
                              fontWeight: FontWeight.w100,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        Flexible(
                          // ✅ Flexible 추가: 영문 텍스트가 길어져도 sub 텍스트를 밀어내지 않도록
                          child: Text(
                            '${title ?? 'in_total'.tr()} ', // "전체"
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w300,
                              color: Color(0xFF949494),
                            ),
                            // overflow: TextOverflow.ellipsis, // ✅ 넘칠 경우 ... 처리
                            maxLines: 1,
                          ),
                        ),
                        Text(
                          sub, // "(개국)"
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w300,
                            color: Color(0xFF949494),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // 오른쪽: 가로형 진행 바 및 퍼센트
              Expanded(
                flex: rightFlex, // ✅ progressbar 영역이 더 넓게 확보되도록 flex 지정
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        // const SizedBox(width: 10),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 9),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: total == 0 ? 0 : visited / total,
                                minHeight: 22,
                                backgroundColor: const Color(0xFFE4E4E4),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  themeColor,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: '$percent',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.black,
                            ),
                          ),
                          const TextSpan(
                            text: ' %  ',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w300,
                              color: Color(0xFF949494),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// 🧩 2. 공통 여행 요약 카드 (에러 수정 완료)
class CommonTravelSummaryCard extends StatelessWidget {
  final int travelCount;
  final int completedCount;
  final int travelDays;
  final String mostVisited;
  final String mostVisitedLabel;

  const CommonTravelSummaryCard({
    super.key,
    required this.travelCount,
    required this.completedCount,
    required this.travelDays,
    required this.mostVisited,
    required this.mostVisitedLabel,
  });

  // ✅ 최다 방문 지역 가공 로직
  String _formatMostVisited(String rawText) {
    if (rawText.isEmpty || rawText == "-") return "-";
    List<String> locations = rawText.split(',').map((e) => e.trim()).toList();

    if (locations.length <= 2) {
      return rawText;
    } else {
      return "${locations[0]}, ${locations[1]} ...";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(25, 22, 23, 22),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'travel_summary'.tr(),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),

          // 🎯 이미지 아이콘(이모지) 적용
          _buildSummaryItem(
            '✈️',
            'trip_count_label'.tr(),
            'count_unit'.tr(args: [travelCount.toString()]),
          ),
          const SizedBox(height: 12),
          _buildSummaryItem(
            '🌎',
            'diary_completed_label'.tr(),
            'count_unit'.tr(args: [completedCount.toString()]),
          ),
          const SizedBox(height: 12),
          _buildSummaryItem(
            '📅',
            'total_days_label'.tr(),
            'day_unit'.tr(args: [travelDays.toString()]),
          ),
          const SizedBox(height: 12),
          _buildSummaryItem(
            '📍',
            'most_visited_format'.tr(args: [mostVisitedLabel]),
            _formatMostVisited(mostVisited),
          ),
        ],
      ),
    );
  }

  // 🎯 디자인 헬퍼 함수
  Widget _buildSummaryItem(String emoji, String label, String value) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 13)),
        const SizedBox(width: 5),
        Flexible(
          // ✅ label을 Flexible로 감싸서 value에 공간 양보
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: Color(0xFF2B2B2B)),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
        const SizedBox(width: 8), // ✅ Spacer → SizedBox로 교체
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ],
    );
  }
}

// 🧩 3. 공통 스켈레톤 (기존 유지)
class MyTravelSummarySkeleton extends StatelessWidget {
  const MyTravelSummarySkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        children: [
          SkeletonBox(width: double.infinity, height: 120, radius: 20),
          SizedBox(height: 20),
          SkeletonBox(width: double.infinity, height: 350, radius: 20),
          SizedBox(height: 24),
          SkeletonBox(width: double.infinity, height: 140, radius: 20),
        ],
      ),
    );
  }
}
