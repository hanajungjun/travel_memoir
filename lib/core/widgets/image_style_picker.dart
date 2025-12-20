import 'package:flutter/material.dart';

import 'package:travel_memoir/models/image_style_model.dart';
import 'package:travel_memoir/services/image_style_service.dart';

import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/shared/styles/text_styles.dart';

class ImageStylePicker extends StatefulWidget {
  final ValueChanged<ImageStyleModel> onChanged;

  const ImageStylePicker({super.key, required this.onChanged});

  @override
  State<ImageStylePicker> createState() => _ImageStylePickerState();
}

class _ImageStylePickerState extends State<ImageStylePicker> {
  final PageController _controller = PageController(viewportFraction: 0.7);
  List<ImageStyleModel> _styles = [];
  int _current = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final styles = await ImageStyleService.fetchEnabled();
    if (!mounted) return;

    setState(() => _styles = styles);

    if (styles.isNotEmpty) {
      widget.onChanged(styles.first);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_styles.isEmpty) {
      return const SizedBox(
        height: 120,
        child: Center(child: Text('사용 가능한 스타일 없음')),
      );
    }

    return SizedBox(
      height: 160,
      child: PageView.builder(
        controller: _controller,
        itemCount: _styles.length,
        onPageChanged: (i) {
          setState(() => _current = i);
          widget.onChanged(_styles[i]);
        },
        itemBuilder: (_, i) {
          final style = _styles[i];
          final selected = i == _current;

          return AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.primary
                  : AppColors.background.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                style.title,
                textAlign: TextAlign.center,
                style: AppTextStyles.body.copyWith(
                  fontWeight: FontWeight.bold,
                  color: selected
                      ? AppColors.background
                      : AppColors.textPrimary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
