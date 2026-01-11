import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:lottie/lottie.dart';

class AdRequestDialog extends StatelessWidget {
  final VoidCallback onAccept;

  const AdRequestDialog({super.key, required this.onAccept});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      contentPadding: const EdgeInsets.all(24),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.auto_awesome, size: 48, color: Color(0xFF2196F3)),
          const SizedBox(height: 20),
          Text(
            "ad_dialog_title".tr(), // ✅ 번역 적용
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Lottie.asset(
            'assets/lottie/pray.json',
            width: 180, // 다이얼로그 안에 들어가기 적당한 크기
            height: 180,
            fit: BoxFit.contain,
            repeat: true, // 계속 움직이게
          ),
        ],
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: const BorderSide(color: Colors.grey),
                ),
                child: Text(
                  "cancel".tr(), // ✅ 번역 적용
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  onAccept();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2196F3),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  elevation: 0,
                ),
                child: Text(
                  "watch_ad".tr(), // ✅ 번역 적용
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
