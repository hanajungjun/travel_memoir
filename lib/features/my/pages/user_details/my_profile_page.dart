import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart'; // 추가

import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/shared/styles/text_styles.dart';

import 'package:flutter_svg/flutter_svg.dart';

class MyProfilePage extends StatelessWidget {
  const MyProfilePage({super.key});

  Future<Map<String, dynamic>> _fetchUserProfile() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser!;

    final profile = await supabase
        .from('users')
        .select('profile_image_url, nickname, provider_nickname, bio, email')
        .eq('auth_uid', user.id)
        .single();

    final provider = user.appMetadata['provider']?.toString().toUpperCase();

    return {...profile, 'provider': provider};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _fetchUserProfile(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!;
          final imageUrl = data['profile_image_url'] as String?;
          final nickname = data['nickname'] as String?;
          final providerNickname = data['provider_nickname'] as String?;
          final bio = data['bio'] as String?;
          final email = data['email'] as String?;
          final provider = data['provider'] as String?;

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(27, 18, 27, 27),
              child: Column(
                children: [
                  // ❶ 화면 맨 위 제목 (가운데 정렬)
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: Center(
                      child: Text(
                        'login_info'.tr(),
                        style: AppTextStyles.pageTitle.copyWith(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textColor01,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),

                  // ❷ 예쁜 하얀색 상자 시작!
                  Container(
                    width: double.infinity,
                    // 🌟 이 constraints가 추가되었어!
                    constraints: BoxConstraints(
                      minHeight:
                          MediaQuery.of(context).size.height -
                          MediaQuery.of(context).padding.top -
                          MediaQuery.of(context).padding.bottom -
                          18 -
                          48 -
                          15 -
                          19,
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: 40,
                      horizontal: 25,
                    ),
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
                      children: [
                        // 동그란 프로필 사진
                        CircleAvatar(
                          radius: 55,
                          backgroundColor: const Color(0xFFE4E4E4),
                          backgroundImage: imageUrl != null
                              ? NetworkImage(imageUrl)
                              : null,
                          child: imageUrl == null
                              ? SvgPicture.asset(
                                  'assets/icons/ico_imgUser.svg',
                                  width: 45,
                                )
                              : null,
                        ),
                        const SizedBox(height: 35),

                        // ❸ 네가 만든 if문 로직들 (여기부터 중요!)
                        if (providerNickname != null &&
                            providerNickname.isNotEmpty) ...[
                          _buildField('username'.tr(), providerNickname),
                          _buildDashedDivider(),
                        ],

                        if (email != null && email.isNotEmpty) ...[
                          _buildField('email'.tr(), email),
                          _buildDashedDivider(),
                        ],

                        if (provider != null) ...[
                          _buildField('connected_account'.tr(), provider),
                          _buildDashedDivider(),
                        ],

                        if (nickname != null && nickname.isNotEmpty) ...[
                          _buildField('nickname'.tr(), nickname),
                          _buildDashedDivider(),
                        ],

                        if (bio != null && bio.isNotEmpty) ...[
                          _buildField('bio'.tr(), bio),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  } // 이름표와 내용을 예쁘게 그려주는 도구

  Widget _buildField(String label, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF6B6B6B),
              fontSize: 12,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  // 점선을 그려주는 도우미야!
  Widget _buildDashedDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: CustomPaint(
        size: const Size(double.infinity, 1),
        painter: DashedLinePainter(),
      ),
    );
  }
}

class DashedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    double dashWidth = 3; // 점의 길이
    double dashSpace = 3; // 점 사이의 간격
    double startX = 0; // ❶ 시작 지점을 27에서 0으로 바꿨어요!

    final paint = Paint()
      ..color = const Color(0xFFD9D9D9)
      ..strokeWidth = 1.2;

    // ❷ size.width 전체를 다 쓰도록 조건을 바꿨어요!
    while (startX < size.width) {
      canvas.drawLine(Offset(startX, 0), Offset(startX + dashWidth, 0), paint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
