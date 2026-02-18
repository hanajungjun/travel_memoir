import 'dart:io';
import 'package:flutter/material.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';
import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/shared/styles/text_styles.dart';
import 'package:travel_memoir/core/widgets/popup/app_toast.dart';

class ProfileEditPage extends StatefulWidget {
  const ProfileEditPage({super.key});

  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  final supabase = Supabase.instance.client;

  final nicknameController = TextEditingController();
  final bioController = TextEditingController();
  final nationalityController = TextEditingController(); // ✅ 국적 컨트롤러 추가

  File? _pickedImage;
  String? _imageUrl;

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = supabase.auth.currentUser!;
    final data = await supabase
        .from('users')
        .select()
        .eq('auth_uid', user.id)
        .single();

    nicknameController.text = data['nickname'] ?? '';
    bioController.text = data['bio'] ?? '';
    nationalityController.text = data['nationality'] ?? ''; // ✅ 국적 로드
    _imageUrl = data['profile_image_url'];

    setState(() => _loading = false);
  }

  Future<void> _pickImage() async {
    // ✅ 재생성 방지 딜레이
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;

    final List<AssetEntity>? result = await AssetPicker.pickAssets(
      context,
      pickerConfig: AssetPickerConfig(
        maxAssets: 1,
        requestType: RequestType.image,
        // ✅ 플랫폼별 설정 (pageSize는 gridCount의 배수)
        pageSize: Platform.isIOS ? 60 : 120,
        gridCount: 3,
        gridThumbnailSize: Platform.isIOS
            ? const ThumbnailSize.square(200)
            : const ThumbnailSize.square(300),
      ),
    );

    if (result == null || result.isEmpty) return;

    final File? file = await result.first.file;
    if (file != null && mounted) {
      setState(() => _pickedImage = file);
    }
  }

  Future<String> _uploadImage(File file) async {
    final user = supabase.auth.currentUser!;
    final path = 'profiles/${user.id}.jpg';

    await supabase.storage
        .from('travel_images')
        .upload(path, file, fileOptions: const FileOptions(upsert: true));

    return supabase.storage.from('travel_images').getPublicUrl(path);
  }

  Future<void> _save() async {
    if (nicknameController.text.trim().isEmpty) {
      AppToast.error(context, 'please_enter_nickname'.tr());
      return;
    }

    setState(() => _saving = true);

    try {
      String? finalImageUrl = _imageUrl;
      if (_pickedImage != null) {
        final uploadedUrl = await _uploadImage(_pickedImage!);
        finalImageUrl =
            '$uploadedUrl?t=${DateTime.now().millisecondsSinceEpoch}';
      }

      final user = supabase.auth.currentUser!;
      await supabase
          .from('users')
          .update({
            'nickname': nicknameController.text.trim(),
            'bio': bioController.text.trim(),
            'nationality': nationalityController.text.trim(),
            'profile_image_url': finalImageUrl,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('auth_uid', user.id);

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        AppToast.error(context, 'save_failed'.tr());
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    nicknameController.dispose();
    bioController.dispose();
    nationalityController.dispose(); // ✅ 컨트롤러 해제
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text('edit_profile'.tr(), style: AppTextStyles.pageTitle),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text('save'.tr()),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // 프로필 이미지 영역
                  GestureDetector(
                    onTap: _pickImage,
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 48,
                          backgroundColor: AppColors.surface,
                          backgroundImage: _pickedImage != null
                              ? FileImage(_pickedImage!)
                              : (_imageUrl != null
                                        ? NetworkImage(_imageUrl!)
                                        : null)
                                    as ImageProvider?,
                          child: _pickedImage == null && _imageUrl == null
                              ? Icon(
                                  Icons.person,
                                  size: 48,
                                  color: AppColors.textDisabled,
                                )
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.camera_alt,
                              size: 16,
                              color: AppColors.background,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // 닉네임 필드
                  _buildTextField(
                    controller: nicknameController,
                    label: 'nickname'.tr(),
                    maxLength: 10,
                  ),
                  const SizedBox(height: 20),
                  // 자기소개 필드
                  _buildTextField(
                    controller: bioController,
                    label: 'bio_label'.tr(),
                    maxLength: 40,
                  ),
                  const SizedBox(height: 20),
                  // ✅ 국적 필드 (새로 추가됨)
                  _buildTextField(
                    controller: nationalityController,
                    label: 'nationality'.tr(),
                    // hint: '예: 방구석 공화국, 지구 방위대',
                    maxLength: 15,
                  ),
                ],
              ),
            ),
    );
  }

  // 재사용 가능한 입력 필드 위젯
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    required int maxLength,
  }) {
    return TextField(
      controller: controller,
      maxLength: maxLength,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        counterText: '',
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }
}
