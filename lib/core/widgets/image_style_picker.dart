import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
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
      return SizedBox(
        height: 80,
        child: Center(child: Text('no_available_styles'.tr())),
      );
    }

    // 현재 언어 코드 확인
    final String currentLang = context.locale.languageCode;

    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: _styles.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final style = _styles[i];
          final selected = i == _selectedIndex;

          // 영어일 때 titleEn이 있으면 사용, 없으면 기본 title 사용
          final String displayTitle =
              (currentLang == 'en' && style.titleEn.isNotEmpty)
              ? style.titleEn
              : style.title;

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
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: selected
                          ? AppColors.travelingBlue
                          : Colors.transparent,
                      width: 2,
                    ),
                    color: Colors.white,
                  ),
                  clipBehavior: Clip.hardEdge,
                  child:
                      style.thumbnailUrl != null &&
                          style.thumbnailUrl!.isNotEmpty
                      ? Image.network(style.thumbnailUrl!, fit: BoxFit.cover)
                      : const Icon(Icons.image, color: Colors.grey),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: 72, // 텍스트 영역 고정
                  child: Text(
                    displayTitle,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyMuted.copyWith(
                      fontSize: 12,
                      color: selected ? Colors.black87 : Colors.grey,
                      fontWeight: selected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
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
