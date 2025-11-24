import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';

class HtmlPreview extends StatelessWidget {
  final String text;

  const HtmlPreview({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    final html = text
        .replaceAll('<pink>', '<span style="color:#FF5FA2; font-weight:bold;">')
        .replaceAll('</pink>', '</span>');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
        color: const Color(0xFF1B1B1B),
      ),
      child: Html(
        data: html,
        style: {
          "body": Style(
            color: Colors.white,
            fontSize: FontSize(18),
            lineHeight: const LineHeight(1.6),
          ),
        },
      ),
    );
  }
}
