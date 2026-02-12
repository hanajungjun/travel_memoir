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
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(message.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'confirm'.tr(),
              style: const TextStyle(color: Colors.blue),
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
    Color actionTextColor = Colors.white,
    required VoidCallback onAction,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          title.tr(),
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
        ),
        content: Text(
          message.tr(),
          style: const TextStyle(fontSize: 14, color: AppColors.textColor03),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style:
                TextButton.styleFrom(
                  // 클릭 시 발생하는 하이라이트/스플래시 효과를 투명하게 설정
                  backgroundColor: Colors.transparent, // 기본 배경색 투명
                ).copyWith(
                  // 모든 상태(눌림, 호버 등)에서 배경색이 생기지 않도록 처리
                  overlayColor: WidgetStateProperty.all(Colors.transparent),
                ),
            child: Text(
              'close'.tr(),
              style: const TextStyle(color: AppColors.textColor03),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: actionColor,
              foregroundColor: actionTextColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
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
    Color confirmColor = Colors.blue,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          title.tr(),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(message.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'cancel'.tr(),
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: confirmColor),
            child: Text(
              confirmLabel?.tr() ?? 'confirm'.tr(),
              style: const TextStyle(fontWeight: FontWeight.bold),
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
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: hintText.tr()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'cancel'.tr(),
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
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
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(message.tr()),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onFirstAction();
            },
            child: Text(
              firstLabel.tr(),
              style: const TextStyle(
                color: Colors.blue,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onSecondAction();
            },
            child: Text(secondLabel.tr()),
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
    Color iconColor = Colors.orangeAccent,
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
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 60, color: iconColor),
            const SizedBox(height: 20),
            Text(message.tr(), textAlign: TextAlign.center),
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
              child: Text(
                "close".tr(),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
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
    Color iconColor = Colors.orangeAccent,
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
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 60, color: iconColor),
            const SizedBox(height: 20),
            Text(message, textAlign: TextAlign.center),
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
              child: Text(
                "close".tr(), // 버튼 글자는 공통 번역 사용
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
