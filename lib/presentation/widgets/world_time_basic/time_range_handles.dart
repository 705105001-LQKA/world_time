// time_range_handles.dart
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../app/util/time_range_utils.dart';

enum _DragHandle { none, left, right }

class TimeRangeHandles extends StatefulWidget {
  final double hourWidth;
  final double minWidthMinutes;
  final double horizontalPadding;
  final double Function() currentHorizontalOffsetPx;
  final int startMin;
  final int endMin;
  final void Function(int startMinutes, int endMinutes) onRangeChanged;
  final void Function(int startMinutes, int endMinutes)? onDragging;
  final VoidCallback? onDragStart;
  final VoidCallback? onDragEnd;
  final double fixedTop;
  final double fixedHeight;
  final ScrollController horizontalController;

  const TimeRangeHandles({
    super.key,
    required this.hourWidth,
    required this.minWidthMinutes,
    required this.horizontalPadding,
    required this.currentHorizontalOffsetPx,
    required this.startMin,
    required this.endMin,
    required this.onRangeChanged,
    this.onDragging,
    this.onDragStart,
    this.onDragEnd,
    required this.fixedTop,
    required this.fixedHeight,
    required this.horizontalController,
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
    _endMin = normalizeEnd(_startMin, widget.endMin);
  }

  @override
  void didUpdateWidget(TimeRangeHandles oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.startMin != widget.startMin || oldWidget.endMin != widget.endMin) {
      _startMin = widget.startMin;
      _endMin = normalizeEnd(_startMin, widget.endMin, previousEnd: _endMin);
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    super.dispose();
  }

  int _pxToMin(double dx) => (dx / widget.hourWidth * 60).round();

  void _emit() => widget.onRangeChanged(_startMin, normalizeEndForEmit(_endMin));
  void _emitDragging() => widget.onDragging?.call(_startMin, normalizeEndForEmit(_endMin));

  void _startAutoScroll(bool toRight) {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = Timer.periodic(_autoScrollTick, (_) {
      final sc = widget.horizontalController;
      if (!sc.hasClients) { _stopAutoScroll(); return; }
      final max = sc.position.maxScrollExtent;
      double newOffset = sc.offset + (toRight ? _autoScrollStepPx : -_autoScrollStepPx);
      if (newOffset <= 0.0) newOffset = 0.0;
      if (newOffset >= max) newOffset = max;
      if ((newOffset <= 0 && sc.offset <= 0) || (newOffset >= max && sc.offset >= max)) {
        _stopAutoScroll();
        return;
      }
      sc.jumpTo(newOffset);
      final deltaMin = _pxToMin(toRight ? _autoScrollStepPx : -_autoScrollStepPx);
      setState(() {
        if (_dragging == _DragHandle.left) {
          _startMin = (_startMin + deltaMin).clamp(0, _endMin - widget.minWidthMinutes.toInt());
        } else if (_dragging == _DragHandle.right) {
          _endMin = (_endMin + deltaMin).clamp(_startMin + widget.minWidthMinutes.toInt(), 1440);
        }
      });
      _emitDragging();
    });
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
  }

  @override
  Widget build(BuildContext context) {
    const double touchW = 20.0, visualW = 20.0, visualH = 50.0;
    const double edgeThreshold = 80.0;
    final double handleHeight = math.max(widget.fixedHeight, visualH);

    return LayoutBuilder(builder: (ctx, constraints) {
      final vw = constraints.maxWidth;
      final offset = widget.currentHorizontalOffsetPx();

      final contentStartX = minutesToContentX(minutes: _startMin, hourWidth: widget.hourWidth, horizontalPadding: widget.horizontalPadding);
      final contentEndX = minutesToContentX(minutes: _endMin, hourWidth: widget.hourWidth, horizontalPadding: widget.horizontalPadding);

      // Không clamp ở đây — dùng raw positions để handles có thể đi ra ngoài
      final double startVX = contentStartX - offset;
      final double endVX = contentEndX - offset;

      bool canLeft() => widget.horizontalController.hasClients && widget.horizontalController.offset > 0.0;
      bool canRight() => widget.horizontalController.hasClients && widget.horizontalController.offset < widget.horizontalController.position.maxScrollExtent;

      Widget buildHandle({required bool isLeft}) {
        final double posX = (isLeft ? startVX : endVX);
        return Positioned(
          left: posX - touchW / 2, // left có thể âm hoặc > vw
          top: widget.fixedTop,
          height: handleHeight,
          width: touchW,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragStart: (_) {
              _dragging = isLeft ? _DragHandle.left : _DragHandle.right;
              widget.onDragStart?.call();
            },
            onHorizontalDragUpdate: (d) {
              final deltaMin = _pxToMin(d.delta.dx);
              setState(() {
                if (isLeft) {
                  _startMin = (_startMin + deltaMin).clamp(0, _endMin - widget.minWidthMinutes.toInt());
                } else {
                  _endMin = (_endMin + deltaMin).clamp(_startMin + widget.minWidthMinutes.toInt(), 1440);
                }
              });
              _emitDragging();

              // Recompute near-edge using current raw positions
              final bool nearLeft = startVX <= edgeThreshold && canLeft();
              final bool nearRight = endVX >= vw - edgeThreshold && canRight();

              if (isLeft && nearLeft) _startAutoScroll(false);
              else if (!isLeft && nearRight) _startAutoScroll(true);
              else _stopAutoScroll();
            },
            onHorizontalDragEnd: (_) {
              _dragging = _DragHandle.none;
              _stopAutoScroll();
              setState(() {
                if (isLeft) {
                  _startMin = snapToHour(_startMin);
                  final gap = widget.minWidthMinutes.toInt();
                  if (_endMin - _startMin < gap) _startMin = (_endMin - gap).clamp(0, 1440);
                } else {
                  _endMin = snapToHour(_endMin);
                  if (_endMin >= kAlmostEndMinutes) _endMin = 1440;
                  final gap = widget.minWidthMinutes.toInt();
                  if (_endMin - _startMin < gap) _endMin = (_startMin + gap).clamp(0, 1440);
                }
              });
              _emit();
              widget.onDragEnd?.call();
            },
            child: Align(
              alignment: isLeft ? Alignment.centerLeft : Alignment.centerRight,
              child: Container(
                width: visualW,
                height: visualH,
                decoration: BoxDecoration(
                  color: const Color(0xFF698FC5),
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                ),
                child: Icon(isLeft ? Icons.chevron_left : Icons.chevron_right, color: Colors.white, size: 18),
              ),
            ),
          ),
        );
      }

      return Stack(clipBehavior: Clip.none, children: [
        buildHandle(isLeft: true),
        buildHandle(isLeft: false),
      ]);
    });
  }
}