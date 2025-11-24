import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_html/flutter_html.dart';
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
        .replaceAll('<pink>', '<span style="color:#FF5FA2; font-weight:bold;">')
        .replaceAll('</pink>', '</span>');
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
              print("🔥 snapshot.error:");
              print(snapshot.error);
              return Center(
                child: Text(
                  //  '데이터 불러오기 실패 🥲\n${snapshot.error}',
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
                const SizedBox(height: 20),

                // 🔥 제목 (중앙 정렬)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.title,
                  ),
                ),

                const SizedBox(height: 20),

                // 🔥 본문 HTML
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Html(
                      data: htmlBody,
                      style: {
                        "body": Style(
                          color: AppColors.textcolor01,
                          fontSize: FontSize(18),
                          lineHeight: const LineHeight(1.6),
                        ),
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // 🔥 이미지 — 절대 안짤리고, 비율 유지 + 크기 조절
                if (imageUrl != null && imageUrl.toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: SizedBox(
                        height: 400, // ✔ 이거만 조절하면 됨. 300~360 추천.
                        child: Image.network(
                          imageUrl,
                          width: double.infinity,
                          fit: BoxFit.contain, // ✔ 절대 짤리지 않음
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
