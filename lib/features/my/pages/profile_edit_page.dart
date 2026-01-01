import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  // =========================
  // 📥 프로필 로드
  // =========================
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

  // =========================
  // 📸 이미지 선택
  // =========================
  Future<void> _pickImage() async {
    if (_saving) return;

    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (picked == null) return;

    setState(() {
      _pickedImage = File(picked.path);
    });
  }

  // =========================
  // ☁️ Storage 업로드
  // =========================
  Future<String> _uploadImage(File file) async {
    final user = supabase.auth.currentUser!;
    final path = 'profiles/${user.id}.jpg';

    await supabase.storage
        .from('travel_images')
        .upload(path, file, fileOptions: const FileOptions(upsert: true));

    // 🔥 캐시 깨기용 timestamp
    return supabase.storage.from('travel_images').getPublicUrl(path) +
        '?t=${DateTime.now().millisecondsSinceEpoch}';
  }

  // =========================
  // 💾 저장
  // =========================
  Future<void> _save() async {
    if (_saving) return;

    if (nicknameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('닉네임을 입력해주세요')));
      return;
    }

    setState(() => _saving = true);

    String? finalImageUrl = _imageUrl;

    if (_pickedImage != null) {
      finalImageUrl = await _uploadImage(_pickedImage!);
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

    Navigator.pop(context, true); // ✅ 저장 완료 후에만 복귀
  }

  @override
  void dispose() {
    nicknameController.dispose();
    bioController.dispose();
    super.dispose();
  }

  // =========================
  // 🖼️ UI
  // =========================
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => !_saving, // 🔥 저장 중 뒤로가기 차단
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          title: Text('프로필 수정', style: AppTextStyles.pageTitle),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: TextButton(
                onPressed: _saving ? null : () async => await _save(),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary, // 🔥 글자색 고정
                ),
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        '저장',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // =========================
                    // 👤 프로필 이미지
                    // =========================
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

                    // =========================
                    // ✏️ 닉네임
                    // =========================
                    TextField(
                      controller: nicknameController,
                      maxLength: 10,
                      decoration: InputDecoration(
                        labelText: '닉네임',
                        counterText: '',
                        filled: true,
                        fillColor: AppColors.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // =========================
                    // ✍️ 한줄 소개
                    // =========================
                    TextField(
                      controller: bioController,
                      maxLength: 40,
                      decoration: InputDecoration(
                        labelText: '한줄 소개',
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
      ),
    );
  }
}
