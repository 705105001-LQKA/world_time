import 'dart:async';
import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;

class TimeRangeSelector extends StatefulWidget {
  final double hourWidth;
  final double minWidthMinutes;
  final double horizontalPadding;
  final double verticalPadding;

  final double Function() currentHorizontalOffsetPx;
  final tz.TZDateTime nowLocal;

  final ScrollController scrollController;
  final void Function(int startMinutes, int endMinutes)? onRangeChanged;

  final int resetCounter;

  const TimeRangeSelector({
    super.key,
    required this.hourWidth,
    required this.currentHorizontalOffsetPx,
    required this.scrollController,
    required this.nowLocal,
    required this.resetCounter,
    this.horizontalPadding = 0.0,
    this.verticalPadding = 0.0,
    this.minWidthMinutes = 60.0,
    this.onRangeChanged,
  });

  @override
  State<TimeRangeSelector> createState() => _TimeRangeSelectorState();
}

enum _DragHandle { none, left, right }

class _TimeRangeSelectorState extends State<TimeRangeSelector> {
  late int _startMin;
  late int _endMin;

  Timer? _autoScrollTimer;
  _DragHandle _dragging = _DragHandle.none;
  bool _autoScrollToRight = false;

  static const double _autoScrollStepPx = 10.0;
  static const Duration _autoScrollTick = Duration(milliseconds: 30);

  @override
  void initState() {
    super.initState();
    _resetToNow();
    widget.scrollController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(TimeRangeSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.resetCounter != oldWidget.resetCounter) {
      _resetToNow();
      setState(() {});
    }
  }

  void _resetToNow() {
    final curHour = widget.nowLocal.hour;
    _startMin = curHour * 60;
    _endMin = (_startMin + widget.minWidthMinutes.toInt()).clamp(0, 1440);
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    super.dispose();
  }

  int _snapMinutes(int minutes) {
    final hr = (minutes / 60.0).round();
    return (hr * 60).clamp(0, 1440);
  }

  int _pxDeltaToMinutes(double dx) {
    final hoursDelta = dx / widget.hourWidth;
    return (hoursDelta * 60).round();
  }

  double _minutesToViewportX(int minutes) {
    final contentX = (minutes / 60.0) * widget.hourWidth + widget.horizontalPadding;
    return contentX - widget.currentHorizontalOffsetPx();
  }

  void _emitRange() => widget.onRangeChanged?.call(_startMin, _endMin);

  void _startAutoScroll(bool toRight) {
    _autoScrollTimer?.cancel();
    _autoScrollToRight = toRight;

    _autoScrollTimer = Timer.periodic(_autoScrollTick, (_) {
      final scroll = widget.scrollController;
      if (!scroll.hasClients) return;

      double newOffset = scroll.offset + (_autoScrollToRight ? _autoScrollStepPx : -_autoScrollStepPx);

      if (newOffset <= 0 || newOffset >= scroll.position.maxScrollExtent) {
        _stopAutoScroll();
        return;
      }

      scroll.jumpTo(newOffset);

      final deltaMin = _pxDeltaToMinutes(_autoScrollToRight ? _autoScrollStepPx : -_autoScrollStepPx);
      setState(() {
        if (_dragging == _DragHandle.left) {
          final proposedStart = (_startMin + deltaMin)
              .clamp(0, _endMin - widget.minWidthMinutes.toInt());
          final startX = _minutesToViewportX(proposedStart);

          if (startX >= 0) {
            _startMin = proposedStart;
          }
        } else if (_dragging == _DragHandle.right) {
          final proposedEnd = (_endMin + deltaMin)
              .clamp(_startMin + widget.minWidthMinutes.toInt(), 1440);
          final endX = _minutesToViewportX(proposedEnd);

          if (endX <= context.size!.width) {
            _endMin = proposedEnd;
          }
        }
      });
    });
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
  }

  @override
  Widget build(BuildContext context) {
    final rawStartX = _minutesToViewportX(_startMin);
    final rawEndX = _minutesToViewportX(_endMin);
    final selectorWidth = (rawEndX - rawStartX).clamp(0.0, double.infinity);

    return Padding(
      padding: MediaQuery.of(context).padding, // 👈 thay SafeArea bằng Padding
      child: LayoutBuilder(
        builder: (context, constraints) {
          final viewportWidth = constraints.maxWidth;

          if (rawEndX < 0 || rawStartX > viewportWidth) {
            return const SizedBox.shrink();
          }

          const edgeThreshold = 60.0;

          bool _isNearLeftEdge() => rawStartX <= edgeThreshold && widget.scrollController.offset > 0;
          bool _isNearRightEdge() {
            final canScrollRight = widget.scrollController.hasClients &&
                widget.scrollController.offset < widget.scrollController.position.maxScrollExtent;
            return rawEndX >= viewportWidth - edgeThreshold && canScrollRight;
          }

          return Stack(
            clipBehavior: Clip.hardEdge, // 👈 đảm bảo không tràn ra ngoài
            children: [
              Positioned(
                top: widget.verticalPadding,
                bottom: widget.verticalPadding,
                left: rawStartX,
                width: selectorWidth,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.green, width: 2),
                    color: Colors.black.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),

              // Tay nắm trái
              Positioned(
                top: widget.verticalPadding,
                bottom: widget.verticalPadding,
                left: rawStartX - 10,
                width: 20,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onHorizontalDragStart: (_) {
                    _dragging = _DragHandle.left;
                  },
                  onHorizontalDragUpdate: (details) {
                    final deltaMin = _pxDeltaToMinutes(details.delta.dx);
                    final proposedStartMin = (_startMin + deltaMin)
                        .clamp(0, _endMin - widget.minWidthMinutes.toInt());
                    final proposedStartX = _minutesToViewportX(proposedStartMin);

                    if (proposedStartX >= 0) {
                      setState(() => _startMin = proposedStartMin);
                    }

                    if (_isNearLeftEdge()) {
                      _startAutoScroll(false);
                    } else if (_isNearRightEdge()) {
                      _startAutoScroll(true);
                    } else {
                      _stopAutoScroll();
                    }
                  },
                  onHorizontalDragEnd: (_) {
                    _dragging = _DragHandle.none;
                    _stopAutoScroll();
                    setState(() => _startMin = _snapMinutes(_startMin));
                    _emitRange();
                  },
                  child: MouseRegion(
                    cursor: SystemMouseCursors.resizeLeftRight,
                    child: Container(color: Colors.transparent),
                  ),
                ),
              ),

              // Tay nắm phải
              Positioned(
                top: widget.verticalPadding,
                bottom: widget.verticalPadding,
                left: rawEndX - 10,
                width: 20,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onHorizontalDragStart: (_) {
                    _dragging = _DragHandle.right;
                  },
                  onHorizontalDragUpdate: (details) {
                    final deltaMin = _pxDeltaToMinutes(details.delta.dx);
                    final proposedEndMin = (_endMin + deltaMin)
                        .clamp(_startMin + widget.minWidthMinutes.toInt(), 1440);
                    final proposedEndX = _minutesToViewportX(proposedEndMin);

                    if (proposedEndX <= viewportWidth) {
                      setState(() => _endMin = proposedEndMin);
                    }

                    if (_isNearRightEdge()) {
                      _startAutoScroll(true);
                    } else if (_isNearLeftEdge()) {
                      _startAutoScroll(false);
                    } else {
                      _stopAutoScroll();
                    }
                  },
                  onHorizontalDragEnd: (_) {
                    _dragging = _DragHandle.none;
                    _stopAutoScroll();
                    setState(() => _endMin = _snapMinutes(_endMin));
                    _emitRange();
                  },
                  child: MouseRegion(
                    cursor: SystemMouseCursors.resizeLeftRight,
                    child: Container(color: Colors.transparent),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}