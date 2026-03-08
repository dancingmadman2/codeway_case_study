import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:codeway_img_proc/app/theme/app_colors.dart';
import 'package:codeway_img_proc/shared/utils/ocr_search_utils.dart';

class SearchableOcrText extends StatefulWidget {
  final String text;
  final VoidCallback onCopy;
  final bool embedded;

  const SearchableOcrText({
    super.key,
    required this.text,
    required this.onCopy,
    this.embedded = false,
  });

  @override
  State<SearchableOcrText> createState() => _SearchableOcrTextState();
}

class _SearchableOcrTextState extends State<SearchableOcrText> {
  static const _highlightColor = Color(0x66FFEB3B); // yellow, 40% opacity
  static const _activeHighlightColor = Color(0xFFFF9800); // solid orange
  static const _highlightStyle = TextStyle(
    backgroundColor: _highlightColor,
    color: AppColors.onSurface,
    fontWeight: FontWeight.w600,
  );
  static const _activeHighlightStyle = TextStyle(
    backgroundColor: _activeHighlightColor,
    color: Colors.black,
    fontWeight: FontWeight.w700,
  );

  final _searchController = TextEditingController();
  final _textKey = GlobalKey();
  String _query = '';
  Timer? _debounce;
  int _currentMatchIndex = -1;

  // Cache fields
  String? _lastQuery;
  String? _lastText;
  int? _lastCurrentIndex;
  OcrSearchResult? _cachedResult;
  TextSpan? _cachedSpan;
  int _searchGeneration = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _query = value;
          _currentMatchIndex = -1;
        });
      }
    });
  }

  void _goToNext() {
    final count = _cachedResult?.matchCount ?? 0;
    if (count == 0) return;
    setState(() {
      _currentMatchIndex = (_currentMatchIndex + 1) % count;
    });
    _scrollToCurrentMatch();
  }

  void _goToPrevious() {
    final count = _cachedResult?.matchCount ?? 0;
    if (count == 0) return;
    setState(() {
      _currentMatchIndex =
          (_currentMatchIndex - 1 + count) % count;
    });
    _scrollToCurrentMatch();
  }

  void _scrollToCurrentMatch() {
    final result = _cachedResult;
    if (result == null || result.matchCount == 0 || _currentMatchIndex < 0) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final textContext = _textKey.currentContext;
      if (textContext == null) return;

      final renderBox = textContext.findRenderObject();
      if (renderBox == null) return;

      // Walk down to find the RenderEditable used internally by SelectableText.
      RenderEditable? renderEditable;
      void visitor(RenderObject child) {
        if (child is RenderEditable) {
          renderEditable = child;
          return;
        }
        child.visitChildren(visitor);
      }
      if (renderBox is RenderEditable) {
        renderEditable = renderBox;
      } else {
        renderBox.visitChildren(visitor);
      }
      if (renderEditable == null) return;

      final matchStart = result.matchStarts[_currentMatchIndex];
      final caretRect = renderEditable!
          .getLocalRectForCaret(TextPosition(offset: matchStart));

      final scrollable = Scrollable.maybeOf(textContext);
      if (scrollable == null) return;

      final scrollRenderBox =
          scrollable.context.findRenderObject() as RenderBox?;
      if (scrollRenderBox == null) return;

      // Convert caret position to the scrollable's coordinate space.
      final caretGlobal =
          renderEditable!.localToGlobal(caretRect.topLeft);
      final caretInScrollable =
          scrollRenderBox.globalToLocal(caretGlobal);

      final position = scrollable.position;
      final viewportHeight = position.viewportDimension;

      // Target: place the match at ~40% from the top of the viewport.
      final target =
          position.pixels + caretInScrollable.dy - viewportHeight * 0.4;
      final clamped =
          target.clamp(position.minScrollExtent, position.maxScrollExtent);

      position.animateTo(
        clamped,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
      );
    });
  }

  Future<void> _ensureComputed() async {
    final queryChanged = _lastQuery != _query || _lastText != widget.text;

    if (queryChanged) {
      _lastQuery = _query;
      _lastText = widget.text;
      _lastCurrentIndex = null;
      _cachedSpan = null;

      final generation = ++_searchGeneration;
      final result = await ocrSearch(widget.text, _query);

      // Guard against stale results from a previous isolate call
      if (generation != _searchGeneration) return;

      _cachedResult = result;

      // Auto-select first match when results arrive
      if (result.matchCount > 0 && _currentMatchIndex == -1) {
        _currentMatchIndex = 0;
        _scrollToCurrentMatch();
      }
    }

    if (_lastCurrentIndex != _currentMatchIndex || queryChanged) {
      _lastCurrentIndex = _currentMatchIndex;
      _cachedSpan = _buildSpanFromResult(_cachedResult ?? OcrSearchResult.empty);
    }
  }

  TextSpan _buildSpanFromResult(OcrSearchResult result) {
    const baseStyle = TextStyle(
      fontSize: 13,
      color: AppColors.onSurface,
      height: 1.5,
    );

    if (result.matchCount == 0) {
      return TextSpan(text: widget.text, style: baseStyle);
    }

    final spans = <TextSpan>[];
    var lastEnd = 0;

    for (var i = 0; i < result.matchCount; i++) {
      final start = result.matchStarts[i];
      final end = result.matchEnds[i];

      if (start > lastEnd) {
        spans.add(TextSpan(text: widget.text.substring(lastEnd, start)));
      }
      spans.add(TextSpan(
        text: widget.text.substring(start, end),
        style: i == _currentMatchIndex
            ? _activeHighlightStyle
            : _highlightStyle,
      ));
      lastEnd = end;
    }

    if (lastEnd < widget.text.length) {
      spans.add(TextSpan(text: widget.text.substring(lastEnd)));
    }

    return TextSpan(style: baseStyle, children: spans);
  }

  @override
  Widget build(BuildContext context) {
    // When embedded in a Card (surfaceVariant bg), use surface (black) for contrast.
    // When standalone, use surfaceVariant (dark gray) against the black background.
    final innerColor =
        widget.embedded ? AppColors.surface : AppColors.surfaceVariant;

    return FutureBuilder<void>(
      future: _ensureComputed(),
      builder: (context, _) {
        final matchCount = _cachedResult?.matchCount ?? 0;
        final span = _cachedSpan ??
            TextSpan(
              text: widget.text,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.onSurface,
                height: 1.5,
              ),
            );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                if (widget.embedded) ...[
                  const Icon(Icons.text_fields,
                      color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    'Extracted Text',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                          widget.embedded ? FontWeight.w400 : FontWeight.w600,
                      color: widget.embedded
                          ? AppColors.onSurface
                          : AppColors.onSurfaceVariant,
                    ),
                  ),
                ),
                if (_query.isNotEmpty && matchCount > 0) ...[
                  Padding(
                    padding: const EdgeInsets.only(right: 2),
                    child: Text(
                      '${_currentMatchIndex + 1} of $matchCount',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: IconButton(
                      icon: const Icon(Icons.keyboard_arrow_up, size: 18),
                      color: AppColors.onSurfaceVariant,
                      padding: EdgeInsets.zero,
                      onPressed: _goToPrevious,
                    ),
                  ),
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: IconButton(
                      icon: const Icon(Icons.keyboard_arrow_down, size: 18),
                      color: AppColors.onSurfaceVariant,
                      padding: EdgeInsets.zero,
                      onPressed: _goToNext,
                    ),
                  ),
                ] else if (_query.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Text(
                      '0 matches',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.copy, size: 18),
                  color: AppColors.onSurfaceVariant,
                  onPressed: widget.onCopy,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _searchController,
              style:
                  const TextStyle(fontSize: 13, color: AppColors.onSurface),
              decoration: InputDecoration(
                hintText: 'Search text...',
                hintStyle: const TextStyle(
                  fontSize: 13,
                  color: AppColors.onSurfaceVariant,
                ),
                prefixIcon: const Icon(
                  Icons.search,
                  size: 18,
                  color: AppColors.onSurfaceVariant,
                ),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 40,
                  minHeight: 0,
                ),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        color: AppColors.onSurfaceVariant,
                        visualDensity: VisualDensity.compact,
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _query = '';
                            _currentMatchIndex = -1;
                          });
                        },
                      )
                    : null,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                filled: true,
                fillColor: innerColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: _onSearchChanged,
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: innerColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: SelectableText.rich(span, key: _textKey),
            ),
          ],
        );
      },
    );
  }
}
