import 'dart:async';
import 'package:flutter/material.dart';

enum _DragHandle { none, left, right }

class TimeRangeHandles extends StatefulWidget {
  final double hourWidth;
  final double minWidthMinutes;
  final double horizontalPadding;

  final double Function() currentHorizontalOffsetPx;

  final int startMin;
  final int endMin;

  final void Function(int startMinutes, int endMinutes) onRangeChanged;

  final double fixedTop;      // vị trí cố định theo trục dọc
  final double fixedHeight;   // chiều cao vùng chạm tay nắm

  const TimeRangeHandles({
    super.key,
    required this.hourWidth,
    required this.minWidthMinutes,
    required this.horizontalPadding,
    required this.currentHorizontalOffsetPx,
    required this.startMin,
    required this.endMin,
    required this.onRangeChanged,
    required this.fixedTop,
    required this.fixedHeight,
  });

  @override
  State<TimeRangeHandles> createState() => _TimeRangeHandlesState();
}

class _TimeRangeHandlesState extends State<TimeRangeHandles> {
  late int _startMin;
  late int _endMin;

  _DragHandle _dragging = _DragHandle.none;
  Timer? _autoScrollTimer;
  static const double _autoScrollStepPx = 10.0;
  static const Duration _autoScrollTick = Duration(milliseconds: 30);

  @override
  void initState() {
    super.initState();
    _startMin = widget.startMin;
    _endMin = widget.endMin;
  }

  @override
  void didUpdateWidget(TimeRangeHandles oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync khi props thay đổi từ ngoài
    if (oldWidget.startMin != widget.startMin || oldWidget.endMin != widget.endMin) {
      _startMin = widget.startMin;
      _endMin = widget.endMin;
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    super.dispose();
  }

  int _pxDeltaToMinutes(double dx) {
    final hoursDelta = dx / widget.hourWidth;
    return (hoursDelta * 60).round();
  }

  void _emit() => widget.onRangeChanged(_startMin, _endMin);

  // Nếu muốn auto-scroll ngang: để trang cung cấp callback scroll jump; ở đây bỏ qua để đơn giản

  @override
  Widget build(BuildContext context) {
    const double handleTouchW = 18;
    const double handleVisualW = 18;
    const double handleVisualH = 44;

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportWidth = constraints.maxWidth;
        final offset = widget.currentHorizontalOffsetPx();

        // Tọa độ content của handles
        final contentStartX = (_startMin / 60.0) * widget.hourWidth + widget.horizontalPadding;
        final contentEndX   = (_endMin   / 60.0) * widget.hourWidth + widget.horizontalPadding;

        // Chuyển sang viewport
        double startVX = contentStartX - offset;
        double endVX   = contentEndX   - offset;

        // Clamp theo viewport
        startVX = startVX.clamp(0.0, viewportWidth);
        endVX   = endVX.clamp(0.0, viewportWidth);

        return Stack(
          clipBehavior: Clip.none, // để tay nắm “nổi” theo trục dọc
          children: [
            // Tay nắm trái (cố định theo trục dọc)
            Positioned(
              left: startVX - handleTouchW / 2,
              top: widget.fixedTop,
              height: widget.fixedHeight,
              width: handleTouchW,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onHorizontalDragStart: (_) => _dragging = _DragHandle.left,
                onHorizontalDragUpdate: (details) {
                  final deltaMin = _pxDeltaToMinutes(details.delta.dx);
                  final proposedStartMin = (_startMin + deltaMin)
                      .clamp(0, _endMin - widget.minWidthMinutes.toInt());
                  setState(() => _startMin = proposedStartMin);
                },
                onHorizontalDragEnd: (_) {
                  _dragging = _DragHandle.none;
                  _emit();
                },
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: handleVisualW,
                    height: handleVisualH,
                    decoration: BoxDecoration(
                      color: const Color(0xFF698FC5),
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                    ),
                    child: const Icon(Icons.chevron_left, color: Colors.white, size: 18),
                  ),
                ),
              ),
            ),

            // Tay nắm phải (cố định theo trục dọc)
            Positioned(
              left: endVX - handleTouchW / 2,
              top: widget.fixedTop,
              height: widget.fixedHeight,
              width: handleTouchW,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onHorizontalDragStart: (_) => _dragging = _DragHandle.right,
                onHorizontalDragUpdate: (details) {
                  final deltaMin = _pxDeltaToMinutes(details.delta.dx);
                  final proposedEndMin = (_endMin + deltaMin)
                      .clamp(_startMin + widget.minWidthMinutes.toInt(), 1440);
                  setState(() => _endMin = proposedEndMin);
                },
                onHorizontalDragEnd: (_) {
                  _dragging = _DragHandle.none;
                  // Snap tránh wrap 24:00 → 0
                  if (_endMin >= 1430) _endMin = 1440;
                  _emit();
                },
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    width: handleVisualW,
                    height: handleVisualH,
                    decoration: BoxDecoration(
                      color: const Color(0xFF698FC5),
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                    ),
                    child: const Icon(Icons.chevron_right, color: Colors.white, size: 18),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}