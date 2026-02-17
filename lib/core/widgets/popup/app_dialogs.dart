import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:easy_localization/easy_localization.dart';
import 'package:travel_memoir/core/constants/app_colors.dart';

class AppDialogs {
  // 1️⃣ [알림형] 확인 버튼 1개 (단순 안내용)
  static void showAlert({
    required BuildContext context,
    required String title,
    required String message,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          title.tr(),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        content: Text(
          message.tr(),
          style: const TextStyle(fontSize: 14, color: AppColors.textColor03),
        ),
        actions: [
          // 기존 TextButton 대신 배경이 있는 ElevatedButton 적용
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC2C2C2), // 버튼 배경색
              foregroundColor: AppColors.textColor03, // 버튼 텍스트 기본색
              elevation: 0, // 그림자 제거
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'confirm'.tr(),
              style: const TextStyle(
                color: AppColors.textColor02, // 요청하신 텍스트 색상
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 2️⃣ [액션형] 취소 + 강조 버튼 (페이지 이동, 권한 요청 등)
  static void showAction({
    required BuildContext context,
    required String title,
    required String message,
    required String actionLabel,
    Color actionColor = const Color(0xFF1C2328),
    Color actionTextColor = AppColors.textColor02,
    required VoidCallback onAction,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          title.tr(),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        content: Text(
          message.tr(),
          style: const TextStyle(fontSize: 14, color: AppColors.textColor03),
        ),
        actions: [
          // 닫기 버튼: ElevatedButton으로 변경하여 배경색 적용
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC2C2C2), // 닫기 버튼용 연한 배경색 (예시)
              foregroundColor: AppColors.textColor03,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'close'.tr(),
              style: const TextStyle(
                color: AppColors.textColor02,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: actionColor,
              foregroundColor: actionTextColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            onPressed: () {
              Navigator.pop(context);
              onAction();
            },
            child: Text(
              actionLabel.tr(),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  // 3️⃣ [반환형] 예/아니오 선택 후 결과값(bool) 리턴 (계정 삭제, 구독 취소 등)
  static Future<bool?> showConfirm({
    required BuildContext context,
    required String title,
    required String message,
    String? confirmLabel,
    Color confirmColor = const Color(0xFF1C2328),
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          title.tr(),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        content: Text(
          message.tr(),
          style: const TextStyle(fontSize: 14, color: AppColors.textColor03),
        ),
        actions: [
          // 취소 버튼
          ElevatedButton(
            onPressed: () => Navigator.pop(context, false),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC2C2C2),
              foregroundColor: AppColors.textColor03,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'cancel'.tr(),
              style: const TextStyle(
                color: AppColors.textColor02,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          // 확인 버튼
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor,
              foregroundColor: AppColors.textColor02,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              confirmLabel?.tr() ?? 'confirm'.tr(),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  // 4️⃣ [입력형] 텍스트 필드 포함 (이메일 로그인 등)
  static void showInput({
    required BuildContext context,
    required String title,
    required String hintText,
    required TextEditingController controller,
    required String confirmLabel,
    required Function(String) onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          title.tr(),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: hintText.tr()),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC2C2C2),
              foregroundColor: AppColors.textColor03,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'cancel'.tr(),
              style: const TextStyle(
                color: AppColors.textColor02,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1C2328),
              foregroundColor: AppColors.textColor02,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              final val = controller.text.trim();
              if (val.isNotEmpty) onConfirm(val);
            },
            child: Text(confirmLabel.tr()),
          ),
        ],
      ),
    );
  }

  // 5️⃣ [선택형] 두 버튼 모두 각각의 비즈니스 로직을 가짐 (코인 부족 팝업 등)
  static void showChoice({
    required BuildContext context,
    required String title,
    required String message,
    required String firstLabel,
    required VoidCallback onFirstAction,
    required String secondLabel,
    required VoidCallback onSecondAction,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          title.tr(),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        content: Text(
          message.tr(),
          style: const TextStyle(fontSize: 14, color: AppColors.textColor03),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onFirstAction();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC2C2C2), // 닫기 버튼용 연한 배경색 (예시)
              foregroundColor: AppColors.textColor03,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              firstLabel.tr(),
              style: const TextStyle(
                color: AppColors.textColor02,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1C2328),
              foregroundColor: AppColors.textColor02,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            onPressed: () {
              Navigator.pop(context);
              onSecondAction();
            },
            child: Text(
              secondLabel.tr(),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  // 6️⃣ [아이콘형] 중앙 아이콘 + 하단 와이드 버튼 (성공/보상 알림용)
  static void showIconAlert({
    required BuildContext context,
    required String title,
    required String message,
    IconData icon = Icons.stars,
    Color iconColor = const Color(0xFFFFB338),
    bool barrierDismissible = false,
    required VoidCallback onClose,
  }) {
    showDialog(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Center(
          child: Text(
            title.tr(),
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Icon(icon, size: 60, color: iconColor),
            const SizedBox(height: 20),
            Text(
              message.tr(),
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textColor03,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                onClose();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1C2328), // 강조된 와이드 버튼 스타일
                foregroundColor: AppColors.textColor02,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text(
                "close".tr(),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
  // lib/core/widgets/popup/app_dialogs.dart 에 추가

  static void showImagePreview({
    required BuildContext context,
    String? imageUrl,
    Uint8List? imageBytes,
    required bool isSharing, // 👈 외부의 공유 상태 전달
    required Function(StateSetter setPopupState) onShare, // 👈 공유 로직 전달
  }) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.9),
      builder: (context) => StatefulBuilder(
        builder: (context, setPopupState) => Stack(
          children: [
            // 1. 이미지 영역 (탭하면 닫힘)
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Dialog(
                insetPadding: EdgeInsets.zero,
                backgroundColor: Colors.transparent,
                child: SizedBox(
                  width: double.infinity,
                  height: double.infinity,
                  child: InteractiveViewer(
                    minScale: 1.0,
                    maxScale: 4.0,
                    child: imageUrl != null
                        ? Image.network(imageUrl, fit: BoxFit.contain)
                        : (imageBytes != null
                              ? Image.memory(imageBytes, fit: BoxFit.contain)
                              : const SizedBox()),
                  ),
                ),
              ),
            ),
            // 2. 우측 상단 공유 버튼
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              right: 20,
              child: Material(
                color: Colors.transparent,
                child: GestureDetector(
                  onTap: isSharing ? null : () => onShare(setPopupState),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: isSharing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(
                              Icons.ios_share,
                              color: Colors.white,
                              size: 24,
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🎯 [신규] DB 데이터 및 동적 문구 전용 (내부에 .tr()이 없음)
  static void showDynamicIconAlert({
    required BuildContext context,
    required String title,
    required String message,
    IconData icon = Icons.stars,
    Color iconColor = const Color(0xFFFFB338),
    bool barrierDismissible = false,
    required VoidCallback onClose,
  }) {
    showDialog(
      context: context,
      useRootNavigator: true, // 탭바 위로 띄우기
      barrierDismissible: barrierDismissible,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Center(
          child: Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Icon(icon, size: 60, color: iconColor),
            const SizedBox(height: 20),
            Text(
              message,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textColor03,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () {
                Navigator.pop(context);
                onClose();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1C2328), // 강조된 와이드 버튼 스타일
                foregroundColor: AppColors.textColor02,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text(
                "close".tr(),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
