import 'dart:io';
import 'package:flutter/material.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:travel_memoir/features/log/pages/travel_album_page.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';
import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/shared/styles/text_styles.dart';
import 'package:travel_memoir/core/widgets/popup/app_toast.dart';

import 'package:flutter_svg/flutter_svg.dart';

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
      backgroundColor: const Color(0xFFF6F6F6),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  27,
                  18,
                  27,
                  27,
                ), // 상단 여유 공간 확보
                child: Column(
                  children: [
                    // 1. 커스텀 상단 바 (제목은 정중앙, 저장 버튼은 우측 끝)
                    SizedBox(
                      width: double.infinity,
                      height: 48, // 상단 바의 높이를 잡아줍니다.
                      child: Stack(
                        alignment: Alignment.center, // 모든 자식들을 일단 중앙에 모읍니다.
                        children: [
                          // ❶ 제목: Stack의 중앙 정렬 덕분에 무조건 정중앙에 옵니다.
                          Text(
                            'edit_profile'.tr(),
                            style: AppTextStyles.pageTitle.copyWith(
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textColor01,
                            ),
                          ),
                          // ❷ 저장 버튼: Positioned를 써서 오른쪽 끝으로 보냅니다.
                          Positioned(
                            right: 0,
                            child: _saving
                                ? const SizedBox(
                                    width: 48,
                                    child: Center(
                                      child: SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    ),
                                  )
                                : TextButton(
                                    onPressed: _save,
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero, // 내부 여백 0!
                                      minimumSize: Size.zero, // 최소 크기 제한 0!
                                    ),
                                    child: Text(
                                      'save'.tr(),
                                      style: const TextStyle(
                                        color: Color(0xFF289AEB),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        decoration: TextDecoration.underline,
                                        decorationColor: Color(
                                          0xFF289AEB,
                                        ), // 밑줄 색상 깔맞춤
                                      ),
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 15),
                    // 2. 메인 프로필 카드
                    Container(
                      width: double
                          .infinity, // 💡 아래 constraints를 추가하면 화면 높이에 맞춰서 늘어납니다!
                      constraints: BoxConstraints(
                        minHeight:
                            MediaQuery.of(context).size.height -
                            18 // 상단 여백 (padding top)
                            -
                            55 // 상단 바(Row) 대략적인 높이
                            -
                            27 // 요청하신 하단 여백 27px
                            -
                            MediaQuery.of(context)
                                .padding
                                .top // 노치(상단 바) 영역
                                -
                            MediaQuery.of(context).padding.bottom, // 하단 바 영역
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: 40,
                        horizontal: 25,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFFFF),
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
                          // 프로필 이미지 영역
                          GestureDetector(
                            onTap: _pickImage,
                            child: Stack(
                              children: [
                                CircleAvatar(
                                  radius: 55,
                                  backgroundColor: const Color(0xFFE4E4E4),
                                  backgroundImage: _pickedImage != null
                                      ? FileImage(_pickedImage!)
                                      : (_imageUrl != null
                                                ? NetworkImage(_imageUrl!)
                                                : null)
                                            as ImageProvider?,
                                  child:
                                      _pickedImage == null && _imageUrl == null
                                      ? SvgPicture.asset(
                                          'assets/icons/ico_imgUser.svg',
                                          width: 45,
                                          height: 47,
                                        )
                                      : null,
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: const BoxDecoration(
                                      color: AppColors.primary,
                                      shape: BoxShape.circle,
                                    ),
                                    child: SvgPicture.asset(
                                      'assets/icons/ico_photo.svg',
                                      width: 16,
                                      height: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 35),

                          // 닉네임 필드
                          _buildTextField(
                            controller: nicknameController,
                            label: 'nickname'.tr(),
                            maxLength: 10,
                          ),
                          _buildDashedDivider(), // 점선 쓱-
                          // ✅ 국적 필드 (새로 추가됨)
                          _buildTextField(
                            controller: nationalityController,
                            label: 'nationality'.tr(),
                            // hint: '예: 방구석 공화국, 지구 방위대',
                            maxLength: 15,
                          ),
                          _buildDashedDivider(), // 점선 쓱-
                          // 자기소개 필드
                          _buildTextField(
                            controller: bioController,
                            label: 'bio_label'.tr(),
                            maxLength: 40,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
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
    return Padding(
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
          ), // 라벨
          TextField(
            controller: controller,
            maxLength: maxLength,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 5),
              border: InputBorder.none, // 테두리 삭제
              counterText: '', // 숫자 숨김
            ),
          ),
        ],
      ),
    );
  }

  // ❷ 점선을 그려주는 헬퍼 위젯 (새로 추가)
  Widget _buildDashedDivider() {
    return Padding(
      padding: const EdgeInsets.only(
        top: 4,
        bottom: 10,
      ), // 위(top)는 0, 아래(bottom)만 10!
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
