import 'package:flutter/material.dart';

/// 나라(local 검색), 도시(remote 검색) 구분
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

class _SearchDropdownState<T> extends State<SearchDropdown<T>> {
  final TextEditingController _controller = TextEditingController();
  final LayerLink _layerLink = LayerLink();

  OverlayEntry? _overlayEntry;
  bool _isOpen = false;

  List<T> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = widget.items;
  }

  @override
  void didUpdateWidget(covariant SearchDropdown<T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    // remote 검색: items 갱신되면 바로 overlay 갱신
    if (widget.mode == SearchMode.remote) {
      setState(() => _filtered = widget.items);
      _refreshOverlay();
    } else {
      // local 검색: 필터 재적용
      setState(() => _filtered = widget.items);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
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
    _removeOverlay();

    final overlay = Overlay.of(context);
    final size = (context.findRenderObject() as RenderBox).size;

    _overlayEntry = OverlayEntry(
      builder: (context) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _removeOverlay,
        child: Stack(
          children: [
            Positioned(
              width: size.width,
              child: CompositedTransformFollower(
                link: _layerLink,
                offset: Offset(0, size.height + 4),
                child: Material(
                  elevation: 6,
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.white,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 260),
                    child: widget.loading
                        ? const Padding(
                            padding: EdgeInsets.all(16),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text("검색 중..."),
                              ],
                            ),
                          )
                        : _filtered.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text("검색 결과가 없습니다."),
                          )
                        : ListView.builder(
                            padding: EdgeInsets.zero,
                            itemCount: _filtered.length,
                            itemBuilder: (_, index) {
                              final item = _filtered[index];
                              return InkWell(
                                onTap: () {
                                  _controller.text = widget.displayString(item);
                                  widget.onSelected(item);
                                  _removeOverlay();
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  child: Text(widget.displayString(item)),
                                ),
                              );
                            },
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      overlay.insert(_overlayEntry!);
      _isOpen = true;
    });
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
    if (!_isOpen) _openOverlay();

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
          Text(
            widget.label,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _controller,
            enabled: widget.enabled,
            onTap: () {
              if (!_isOpen) _openOverlay();
            },
            onChanged: _onChanged,
            decoration: InputDecoration(
              hintText: widget.hintText,
              filled: true,
              fillColor: widget.enabled ? Colors.white : Colors.grey.shade200,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
