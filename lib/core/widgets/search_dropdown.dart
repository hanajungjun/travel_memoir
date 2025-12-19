import 'package:flutter/material.dart';
import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/shared/styles/text_styles.dart';

enum SearchMode { local, remote }

class SearchDropdown<T> extends StatefulWidget {
  final List<T> items;
  final String Function(T) displayString;
  final void Function(T) onSelected;

  final String label;
  final String hintText;

  final bool enabled;
  final bool loading;

  final SearchMode mode;
  final void Function(String)? onQueryChanged;

  const SearchDropdown({
    super.key,
    required this.items,
    required this.displayString,
    required this.onSelected,
    required this.label,
    required this.hintText,
    this.enabled = true,
    this.loading = false,
    this.mode = SearchMode.local,
    this.onQueryChanged,
  });

  @override
  State<SearchDropdown<T>> createState() => _SearchDropdownState<T>();
}

class _SearchDropdownState<T> extends State<SearchDropdown<T>>
    with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final LayerLink _layerLink = LayerLink();

  OverlayEntry? _overlayEntry;
  bool _isOpen = false;

  List<T> _filtered = [];
  int _hoveredIndex = -1;

  late AnimationController _focusController;
  late Animation<double> _focusAnim;

  @override
  void initState() {
    super.initState();
    _filtered = widget.items;

    _focusController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );

    _focusAnim = CurvedAnimation(
      parent: _focusController,
      curve: Curves.easeOut,
    );

    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        _focusController.forward();
        _openOverlay();
      } else {
        _focusController.reverse();
        _removeOverlay();
      }
    });
  }

  @override
  void didUpdateWidget(covariant SearchDropdown<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    setState(() => _filtered = widget.items);
    _refreshOverlay();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _focusController.dispose();
    _removeOverlay();
    super.dispose();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _isOpen = false;
  }

  void _refreshOverlay() {
    if (_isOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _overlayEntry?.markNeedsBuild();
      });
    }
  }

  void _openOverlay() {
    if (_isOpen) return;

    final overlay = Overlay.of(context);
    final size = (context.findRenderObject() as RenderBox).size;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: size.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          offset: Offset(0, size.height + 8),
          child: Material(
            elevation: 10,
            borderRadius: BorderRadius.circular(16),
            color: AppColors.background,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260),
              child: widget.loading
                  ? Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 12),
                          Text('검색 중...', style: AppTextStyles.bodyMuted),
                        ],
                      ),
                    )
                  : _filtered.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        '검색 결과가 없습니다.',
                        style: AppTextStyles.bodyMuted,
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: _filtered.length,
                      itemBuilder: (_, index) {
                        final item = _filtered[index];
                        final hovered = index == _hoveredIndex;

                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          color: hovered
                              ? AppColors.primary.withOpacity(0.08)
                              : Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              _controller.text = widget.displayString(item);
                              widget.onSelected(item);
                              _focusNode.unfocus();
                            },
                            onHover: (v) {
                              setState(() => _hoveredIndex = v ? index : -1);
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              child: Text(
                                widget.displayString(item),
                                style: AppTextStyles.body,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(_overlayEntry!);
    _isOpen = true;
  }

  void _filterLocal(String query) {
    final lower = query.toLowerCase();
    setState(() {
      _filtered = widget.items
          .where((e) => widget.displayString(e).toLowerCase().contains(lower))
          .toList();
    });
    _refreshOverlay();
  }

  void _onChanged(String text) {
    if (widget.mode == SearchMode.local) {
      _filterLocal(text);
    } else {
      widget.onQueryChanged?.call(text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.label, style: AppTextStyles.sectionTitle),
          const SizedBox(height: 6),
          AnimatedBuilder(
            animation: _focusAnim,
            builder: (context, _) {
              return Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    if (_focusAnim.value > 0)
                      BoxShadow(
                        color: AppColors.primary.withOpacity(
                          0.25 * _focusAnim.value,
                        ),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                  ],
                ),
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  enabled: widget.enabled,
                  onChanged: _onChanged,
                  style: AppTextStyles.body,
                  decoration: InputDecoration(
                    hintText: widget.hintText,
                    hintStyle: AppTextStyles.bodyMuted,
                    filled: true,
                    fillColor: AppColors.background,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: Color.lerp(
                          AppColors.textDisabled,
                          AppColors.primary,
                          _focusAnim.value,
                        )!,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
