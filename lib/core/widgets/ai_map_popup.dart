import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/shared/styles/text_styles.dart';

class AiMapPopup extends StatelessWidget {
  final String imageUrl;
  final String regionName;
  final String summary;

  const AiMapPopup({
    super.key,
    required this.imageUrl,
    required this.regionName,
    required this.summary,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFFF4EBD0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      contentPadding: EdgeInsets.zero,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: Image.network(
              imageUrl,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return const SizedBox(
                  height: 250,
                  child: Center(
                    child: CircularProgressIndicator(color: Color(0xFF6D4C41)),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) => const SizedBox(
                height: 250,
                child: Center(
                  child: Icon(Icons.broken_image, size: 80, color: Colors.grey),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text(
                  'travel_record_with_region'.tr(args: [regionName]),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF6D4C41),
                    fontFamily: 'Cafe24',
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "\"$summary\"",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    fontStyle: FontStyle.italic,
                    color: Color(0xFF8D6E63),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6D4C41),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text('close_memory'.tr()),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
