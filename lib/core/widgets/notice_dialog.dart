import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NoticeDialog extends StatefulWidget {
  final Map<String, dynamic> notice;
  final String today;
  final SharedPreferences prefs;

  const NoticeDialog({
    super.key,
    required this.notice,
    required this.today,
    required this.prefs,
  });

  @override
  State<NoticeDialog> createState() => _NoticeDialogState();
}

class _NoticeDialogState extends State<NoticeDialog> {
  bool _dontShowToday = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 10),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      title: Text(
        widget.notice['title'] ?? '공지사항',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🎯 이미지가 있다면 상단에 노출
          if (widget.notice['image_url'] != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(widget.notice['image_url']),
            ),
            const SizedBox(height: 16),
          ],
          Text(
            widget.notice['content'] ?? '',
            style: const TextStyle(fontSize: 15, height: 1.5),
          ),
          const SizedBox(height: 10),
          // 오늘 하루 보지 않기 체크박스
          InkWell(
            onTap: () => setState(() => _dontShowToday = !_dontShowToday),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: _dontShowToday,
                    onChanged: (val) => setState(() => _dontShowToday = val!),
                  ),
                ),
                const SizedBox(width: 8),
                const Text("오늘 하루 보지 않기", style: TextStyle(fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () async {
            if (_dontShowToday) {
              await widget.prefs.setString('hide_until_date', widget.today);
            }
            await widget.prefs.setInt('last_notice_id', widget.notice['id']);
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text(
            "닫기",
            style: TextStyle(
              color: Colors.blueAccent,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
