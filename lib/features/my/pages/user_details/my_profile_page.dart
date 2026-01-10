import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart'; // 추가

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
        title: Text('login_info'.tr()), // ✅ 번역 적용
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

                if (providerNickname != null &&
                    providerNickname.isNotEmpty) ...[
                  Text(
                    'username'.tr(),
                    style: AppTextStyles.caption,
                  ), // ✅ 번역 적용
                  const SizedBox(height: 6),
                  Text(providerNickname, style: AppTextStyles.body),
                  const SizedBox(height: 16),
                ],

                if (email != null && email.isNotEmpty) ...[
                  Text('email'.tr(), style: AppTextStyles.caption), // ✅ 번역 적용
                  const SizedBox(height: 6),
                  Text(email, style: AppTextStyles.body),
                  const SizedBox(height: 16),
                ],

                if (provider != null) ...[
                  Text(
                    'connected_account'.tr(),
                    style: AppTextStyles.caption,
                  ), // ✅ 번역 적용
                  const SizedBox(height: 6),
                  Text(provider, style: AppTextStyles.body),
                  const SizedBox(height: 16),
                ],

                if (nickname != null && nickname.isNotEmpty) ...[
                  Text(
                    'nickname'.tr(),
                    style: AppTextStyles.caption,
                  ), // ✅ 번역 적용
                  const SizedBox(height: 6),
                  Text(nickname, style: AppTextStyles.body),
                  const SizedBox(height: 16),
                ],

                if (bio != null && bio.isNotEmpty) ...[
                  Text('bio'.tr(), style: AppTextStyles.caption), // ✅ 번역 적용
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
