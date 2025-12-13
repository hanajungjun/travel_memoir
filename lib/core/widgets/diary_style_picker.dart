import 'package:flutter/material.dart';
import '../../models/diary_style.dart';

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
              color: selected ? Colors.black : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  style.title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selected ? Colors.white : Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  style.description,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selected ? Colors.white70 : Colors.grey.shade600,
                    fontSize: 13,
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
