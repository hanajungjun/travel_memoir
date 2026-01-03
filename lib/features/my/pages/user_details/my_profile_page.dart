import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/shared/styles/text_styles.dart';

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
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('로그인 정보'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
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

          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// =====================
                /// 프로필 이미지
                /// =====================
                Center(
                  child: CircleAvatar(
                    radius: 48,
                    backgroundColor: AppColors.surface,
                    backgroundImage: imageUrl != null
                        ? NetworkImage(imageUrl)
                        : null,
                    child: imageUrl == null
                        ? Icon(
                            Icons.person,
                            size: 40,
                            color: AppColors.textDisabled,
                          )
                        : null,
                  ),
                ),

                const SizedBox(height: 24),

                /// =====================
                /// 사용자명 (provider 닉네임)
                /// =====================
                if (providerNickname != null &&
                    providerNickname.isNotEmpty) ...[
                  Text('사용자명', style: AppTextStyles.caption),
                  const SizedBox(height: 6),
                  Text(providerNickname, style: AppTextStyles.body),
                  const SizedBox(height: 16),
                ],

                /// =====================
                /// 이메일 (있을 때만)
                /// =====================
                if (email != null && email.isNotEmpty) ...[
                  Text('이메일', style: AppTextStyles.caption),
                  const SizedBox(height: 6),
                  Text(email, style: AppTextStyles.body),
                  const SizedBox(height: 16),
                ],

                /// =====================
                /// 연결된 계정 (kakao / apple / google)
                /// =====================
                if (provider != null) ...[
                  Text('연결된 계정', style: AppTextStyles.caption),
                  const SizedBox(height: 6),
                  Text(provider, style: AppTextStyles.body),
                  const SizedBox(height: 16),
                ],

                /// =====================
                /// 닉네임
                /// =====================
                if (nickname != null && nickname.isNotEmpty) ...[
                  Text('닉네임', style: AppTextStyles.caption),
                  const SizedBox(height: 6),
                  Text(nickname, style: AppTextStyles.body),
                  const SizedBox(height: 16),
                ],

                /// =====================
                /// 소개
                /// =====================
                if (bio != null && bio.isNotEmpty) ...[
                  Text('소개', style: AppTextStyles.caption),
                  const SizedBox(height: 6),
                  Text(bio, style: AppTextStyles.body.copyWith(height: 1.4)),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
