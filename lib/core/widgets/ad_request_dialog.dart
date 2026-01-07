import 'package:flutter/material.dart';

// TODO: [설명] 일기 생성 광고 팝업
class AdRequestDialog extends StatelessWidget {
  final VoidCallback onAccept; // 광고 보기 클릭 시 실행할 함수

  const AdRequestDialog({super.key, required this.onAccept});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      contentPadding: const EdgeInsets.all(24),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 반짝이는 아이콘이나 로티(Lottie) 애니메이션이 들어가면 좋습니다
          const Icon(Icons.auto_awesome, size: 48, color: Color(0xFF2196F3)),
          const SizedBox(height: 20),
          const Text(
            "AI 여행 일기 생성",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          const Text(
            "정성스러운 일기를 생성하고 있어요.\n약 15초의 광고 시청 후\n결과를 바로 확인하실 수 있습니다.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54, height: 1.5),
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
                child: const Text("취소", style: TextStyle(color: Colors.grey)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  onAccept(); // 여기서 광고 로직 실행
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2196F3),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  elevation: 0,
                ),
                child: const Text(
                  "광고 보기",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
