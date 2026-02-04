import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/shared/styles/text_styles.dart';
import 'package:travel_memoir/core/widgets/popup/app_toast.dart';

class DataSettingsPage extends StatefulWidget {
  const DataSettingsPage({super.key});

  @override
  State<DataSettingsPage> createState() => _DataSettingsPageState();
}

class _DataSettingsPageState extends State<DataSettingsPage> {
  bool _isAnalysisEnabled = true;
  bool _isPersonalizedAdsEnabled = true;
  bool _isLoading = false;

  String get _userId => Supabase.instance.client.auth.currentUser!.id;

  @override
  void initState() {
    super.initState();
    _loadUserPrivacySettings();
  }

  // 1. 초기 설정값 로드
  Future<void> _loadUserPrivacySettings() async {
    setState(() => _isLoading = true);
    try {
      final userData = await Supabase.instance.client
          .from('users')
          .select('is_analysis_enabled, is_personalized_ads_enabled')
          .eq('auth_uid', _userId)
          .single();

      setState(() {
        _isAnalysisEnabled = userData['is_analysis_enabled'] ?? true;
        _isPersonalizedAdsEnabled =
            userData['is_personalized_ads_enabled'] ?? true;
      });
    } catch (e) {
      debugPrint("❌ 설정 로드 실패: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 2. [병렬유지] 업데이트 로직 (UI 즉시 반영 + 백그라운드 저장)
  void _updateSetting(String column, bool value) {
    setState(() {
      if (column == 'is_analysis_enabled')
        _isAnalysisEnabled = value;
      else
        _isPersonalizedAdsEnabled = value;
    });

    Supabase.instance.client
        .from('users')
        .update({column: value})
        .eq('auth_uid', _userId)
        .then((_) => debugPrint("✅ DB 업데이트 완료"))
        .catchError((e) => debugPrint("❌ 업데이트 실패: $e"));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'data_settings'.tr(),
          style: const TextStyle(color: Colors.black),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ℹ️ 안내 섹션
                  Text(
                    'data_privacy_title'.tr(),
                    style: AppTextStyles.sectionTitle,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'data_privacy_desc'.tr(),
                    style: AppTextStyles.body.copyWith(
                      color: Colors.grey[700],
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 30),

                  // 📊 데이터 활용 동의 섹션 (통합됨)
                  _buildSectionHeader('privacy_consent'.tr()),

                  // 필수 데이터 (On 전용)
                  _buildDisabledToggleTile(
                    title: 'essential_data'.tr(),
                    desc: 'essential_data_desc'.tr(),
                  ),
                  const _CustomDivider(),

                  // 분석 데이터
                  _buildSwitchTile(
                    title: 'experience_improvement'.tr(),
                    desc: 'experience_improvement_desc'.tr(),
                    value: _isAnalysisEnabled,
                    onChanged: (val) =>
                        _updateSetting('is_analysis_enabled', val),
                  ),
                  const _CustomDivider(),

                  // 맞춤 광고 데이터
                  _buildSwitchTile(
                    title: 'personalized_info'.tr(),
                    desc: 'personalized_info_desc'.tr(),
                    value: _isPersonalizedAdsEnabled,
                    onChanged: (val) =>
                        _updateSetting('is_personalized_ads_enabled', val),
                  ),

                  const _CustomDivider(),

                  // 🗑 [수정] 이미지 캐시 삭제를 이 섹션 하단으로 이동
                  _buildActionTile(
                    title: 'clear_image_cache'.tr(),
                    onTap: () {
                      PaintingBinding.instance.imageCache.clear();
                      AppToast.show(context, 'cache_cleared'.tr());
                    },
                  ),
                  const SizedBox(height: 50),
                ],
              ),
            ),
    );
  }

  // --- 위젯 빌더 (생략 없음) ---

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title,
        style: AppTextStyles.landingTitle.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String desc,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                title,
                style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeColor: AppColors.primary,
            ),
          ],
        ),
        Text(
          desc,
          style: AppTextStyles.caption.copyWith(color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildDisabledToggleTile({
    required String title,
    required String desc,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                title,
                style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            const Switch(value: true, onChanged: null),
          ],
        ),
        Text(
          desc,
          style: AppTextStyles.caption.copyWith(color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildActionTile({
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: AppTextStyles.body),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: onTap,
    );
  }
}

class _CustomDivider extends StatelessWidget {
  const _CustomDivider();
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Divider(height: 1, thickness: 0.5),
    );
  }
}
