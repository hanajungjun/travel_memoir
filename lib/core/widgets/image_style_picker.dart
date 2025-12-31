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
  List<ImageStyleModel> _styles = [];
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final styles = await ImageStyleService.fetchEnabled();
    if (!mounted) return;

    setState(() {
      _styles = styles;
      _selectedIndex = 0;
    });

    if (styles.isNotEmpty) {
      widget.onChanged(styles.first);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_styles.isEmpty) {
      return const SizedBox(
        height: 80,
        child: Center(child: Text('사용 가능한 스타일 없음')),
      );
    }

    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemCount: _styles.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final style = _styles[i];
          final selected = i == _selectedIndex;

          return GestureDetector(
            onTap: () {
              setState(() => _selectedIndex = i);
              widget.onChanged(style);
            },
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primary : AppColors.surface,
                  ),
                  child: const Icon(Icons.brush, color: Colors.white),
                ),
                const SizedBox(height: 6),
                Text(
                  style.title,
                  style: AppTextStyles.bodyMuted.copyWith(
                    color: selected
                        ? AppColors.textPrimary
                        : AppColors.textDisabled,
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
