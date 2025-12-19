import 'package:flutter/material.dart';
import 'package:travel_memoir/models/diary_style.dart';
import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/shared/styles/text_styles.dart';

class DiaryStylePicker extends StatefulWidget {
  final ValueChanged<DiaryStyle> onChanged;

  const DiaryStylePicker({super.key, required this.onChanged});

  @override
  State<DiaryStylePicker> createState() => _DiaryStylePickerState();
}

class _DiaryStylePickerState extends State<DiaryStylePicker> {
  final PageController _controller = PageController(viewportFraction: 0.7);
  int _current = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onChanged(diaryStyles[0]);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 160,
      child: PageView.builder(
        controller: _controller,
        itemCount: diaryStyles.length,
        onPageChanged: (index) {
          setState(() => _current = index);
          widget.onChanged(diaryStyles[index]);
        },
        itemBuilder: (context, index) {
          final style = diaryStyles[index];
          final selected = index == _current;

          return AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.primary
                  : AppColors.background.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  style.title,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.bold,
                    color: selected
                        ? AppColors.background
                        : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  style.description,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMuted.copyWith(
                    color: selected
                        ? AppColors.background.withOpacity(0.8)
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
