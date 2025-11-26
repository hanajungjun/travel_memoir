import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:my_app/core/constants/app_colors.dart';
import 'package:my_app/shared/styles/text_styles.dart';

class WordPagerPage extends StatelessWidget {
  static const routeName = '/words';

  const WordPagerPage({super.key});

  /// 오늘 날짜 키 생성 (예: 20251119)
  String _todayKey() {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${now.year}${two(now.month)}${two(now.day)}';
  }

  /// <pink> 태그를 HTML span 으로 바꿔주기
  String htmlProcessed(String raw) {
    return raw
        .replaceAll('<pb>', '<span style="color:#EA6AA3; font-weight:bold;">')
        .replaceAll('</pb>', '</span>')
        .replaceAll('<p>', '<span style="color:#EA6AA3;">')
        .replaceAll('</p>', '</span>');
  }

  @override
  Widget build(BuildContext context) {
    final today = _todayKey();
    final supabase = Supabase.instance.client;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: supabase
              .from('daily_words')
              .select()
              .eq('date', today)
              .order('updated_at', ascending: false)
              .limit(1),
          builder: (context, snapshot) {
            // 로딩
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.white),
              );
            }

            // 오류
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  '데이터 불러오기 실패 🥲\n${snapshot.error.toString()}',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body,
                ),
              );
            }

            // 데이터 없음
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Center(
                child: Text(
                  '오늘의 단어가 아직 없어요.\n($today)',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMuted,
                ),
              );
            }

            // 데이터 있음
            final data = snapshot.data!.first;
            final title = data['title'] ?? '제목 없음';
            final description = data['description'] ?? '';
            final imageUrl = data['image_url'];

            final htmlBody = htmlProcessed(description);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 70),

                // 🔥 제목 (중앙)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: 40,
                  ),
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.title.copyWith(
                      shadows: [
                        Shadow(
                          color: AppColors.textcolor02.withOpacity(
                            0.1,
                          ), // 그림자 색상 (파란색)
                          offset: Offset(6, 6), // 그림자 위치
                          blurRadius: 4, // 그림자 번짐 정도
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // 🔥 본문 HTML
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 30),
                    child: Html(
                      data: htmlBody,
                      style: {"body": Style.fromTextStyle(AppTextStyles.body)},
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // 🔥 라운드 깨끗하게 — 확실히 보이도록
                if (imageUrl != null && imageUrl.toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 30),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22), // 1. 외부 컨테이너 라운드
                      child: Container(
                        color: Colors.black26,
                        padding: const EdgeInsets.all(8),
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: ClipRRect(
                            // 2. 추가: 이미지 자체에 라운드 적용
                            borderRadius: BorderRadius.circular(
                              14,
                            ), // 외부 라운드(22)보다 작게 설정
                            child: CachedNetworkImage(
                              imageUrl: imageUrl,
                              fit: BoxFit
                                  .cover, // Contain 대신 Cover 사용 (둥근 모서리 최적화)
                              progressIndicatorBuilder:
                                  (context, url, progress) => Center(
                                    child: CircularProgressIndicator(
                                      value: progress.progress,
                                      color: Colors.white70,
                                    ),
                                  ),
                              errorWidget: (context, url, error) => Container(
                                alignment: Alignment.center,
                                color: Colors.black26,
                                child: const Icon(
                                  Icons.error,
                                  color: Colors.red,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 20),
              ],
            );
          },
        ),
      ),
    );
  }
}
