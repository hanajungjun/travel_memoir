import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart'; // 추가

import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/shared/styles/text_styles.dart';

class ProfileEditPage extends StatefulWidget {
  const ProfileEditPage({super.key});

  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  final supabase = Supabase.instance.client;
  final picker = ImagePicker();

  final nicknameController = TextEditingController();
  final bioController = TextEditingController();

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
    _imageUrl = data['profile_image_url'];

    setState(() => _loading = false);
  }

  Future<void> _pickImage() async {
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (picked == null) return;
    setState(() => _pickedImage = File(picked.path));
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('please_enter_nickname'.tr())), // ✅ 번역 적용
      );
      return;
    }

    setState(() => _saving = true);
    String? finalImageUrl = _imageUrl;

    if (_pickedImage != null) {
      final uploadedUrl = await _uploadImage(_pickedImage!);
      finalImageUrl = '$uploadedUrl?t=${DateTime.now().millisecondsSinceEpoch}';
    }

    final user = supabase.auth.currentUser!;
    await supabase
        .from('users')
        .update({
          'nickname': nicknameController.text.trim(),
          'bio': bioController.text.trim(),
          'profile_image_url': finalImageUrl,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('auth_uid', user.id);

    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.pop(context, true);
  }

  @override
  void dispose() {
    nicknameController.dispose();
    bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(
          'edit_profile'.tr(),
          style: AppTextStyles.pageTitle,
        ), // ✅ 번역 적용
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
                : Text('save'.tr()), // ✅ 번역 적용
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
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
                  TextField(
                    controller: nicknameController,
                    maxLength: 10,
                    decoration: InputDecoration(
                      labelText: 'nickname'.tr(), // ✅ 번역 적용
                      counterText: '',
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: bioController,
                    maxLength: 40,
                    decoration: InputDecoration(
                      labelText: 'bio_label'.tr(), // ✅ 번역 적용
                      counterText: '',
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
