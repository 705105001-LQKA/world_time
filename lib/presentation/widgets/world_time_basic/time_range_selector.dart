import 'dart:async';
import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;

class TimeRangeSelector extends StatefulWidget {
  final double hourWidth;
  final double minWidthMinutes;
  final double horizontalPadding;
  final double verticalPadding;

  final double Function() currentHorizontalOffsetPx;
  final DateTime nowUtc;
  final tz.Location timelineLocation;

  final ScrollController scrollController;
  final void Function(int startMinutes, int endMinutes)? onRangeChanged;

  final int resetCounter;

  final DateTime? selectedStartUtc;
  final DateTime? selectedEndUtc;

  const TimeRangeSelector({
    super.key,
    required this.hourWidth,
    required this.currentHorizontalOffsetPx,
    required this.scrollController,
    required this.nowUtc,
    required this.timelineLocation,
    required this.resetCounter,
    this.horizontalPadding = 0.0,
    this.verticalPadding = 0.0,
    this.minWidthMinutes = 60.0,
    this.onRangeChanged,
    this.selectedStartUtc,
    this.selectedEndUtc,
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

    // 👇 nếu selection thay đổi thì cập nhật thanh chọn
    if (widget.selectedStartUtc != oldWidget.selectedStartUtc ||
        widget.selectedEndUtc != oldWidget.selectedEndUtc) {
      if (widget.selectedStartUtc != null && widget.selectedEndUtc != null) {
        final localStart = tz.TZDateTime.from(widget.selectedStartUtc!, widget.timelineLocation);
        final localEnd   = tz.TZDateTime.from(widget.selectedEndUtc!, widget.timelineLocation);
        setState(() {
          _startMin = localStart.hour * 60 + localStart.minute;
          _endMin   = localEnd.hour * 60 + localEnd.minute;
        });
      }
    }

    if (widget.resetCounter != oldWidget.resetCounter) {
      _resetToNow();
      setState(() {});
    }

    final oldLocalHour = tz.TZDateTime.from(oldWidget.nowUtc, widget.timelineLocation).hour;
    final newLocalHour = tz.TZDateTime.from(widget.nowUtc, widget.timelineLocation).hour;
    if (newLocalHour != oldLocalHour) {
      _resetToNow();
      setState(() {});
    }
  }

  void _resetToNow() {
    final localNow = tz.TZDateTime.from(widget.nowUtc, widget.timelineLocation);
    final curHour = localNow.hour;
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

      final newOffset = scroll.offset + (_autoScrollToRight ? _autoScrollStepPx : -_autoScrollStepPx);

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
          _startMin = proposedStart;
        } else if (_dragging == _DragHandle.right) {
          final proposedEnd = (_endMin + deltaMin)
              .clamp(_startMin + widget.minWidthMinutes.toInt(), 1440);
          _endMin = proposedEnd;
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

    // Tay nắm: hiển thị nhỏ, vùng chạm rộng
    const double handleVisualW = 18;
    const double handleVisualH = 44;
    const double handleTouchW = 18;
    const double edgeThreshold = 80.0; // nới rộng để auto-scroll nhạy hơn

    return Padding(
      padding: MediaQuery.of(context).padding,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final viewportWidth = constraints.maxWidth;

          // ✅ In log để debug
          if (widget.scrollController.hasClients) {
            debugPrint(
              'TimeRangeSelector → rawStartX=$rawStartX rawEndX=$rawEndX viewport=$viewportWidth offset=${widget.scrollController.offset}',
            );
          } else {
            debugPrint('TimeRangeSelector → scrollController chưa có client');
          }

          // ✅ Không còn return SizedBox.shrink() nữa
          // Luôn vẽ thanh chọn, kể cả khi nằm ngoài viewport


          // if (rawEndX < 0 || rawStartX > viewportWidth) {
          //   return const SizedBox.shrink();
          // }

          final hasClients = widget.scrollController.hasClients;
          final offset = hasClients ? widget.scrollController.offset : 0.0;
          final maxExtent = hasClients ? widget.scrollController.position.maxScrollExtent : 0.0;

          bool _canScrollLeft() => hasClients && offset > 0.0;
          bool _canScrollRight() => hasClients && offset < maxExtent;

          bool _isNearLeftEdge() => rawStartX <= edgeThreshold && _canScrollLeft();
          bool _isNearRightEdge() => rawEndX >= viewportWidth - edgeThreshold && _canScrollRight();

          return Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              // Khung chọn chính
              Positioned(
                top: widget.verticalPadding,
                bottom: widget.verticalPadding,
                left: rawStartX,
                width: selectorWidth,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.green, width: 2),
                      color: Colors.black.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),

              // Tay nắm trái: vùng chạm rộng, UI nhỏ giữa cạnh trái
              Positioned(
                left: rawStartX - handleTouchW / 2,
                top: widget.verticalPadding,
                bottom: widget.verticalPadding,
                width: handleTouchW,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onHorizontalDragStart: (_) => _dragging = _DragHandle.left,
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
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: handleVisualW,
                      height: handleVisualH,
                      decoration: BoxDecoration(
                        color: Color(0xFF698FC5),
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                      ),
                      child: const Icon(Icons.chevron_left, color: Colors.white, size: 18),
                    ),
                  ),
                ),
              ),

              // Tay nắm phải: vùng chạm rộng, UI nhỏ giữa cạnh phải
              Positioned(
                left: rawEndX - handleTouchW / 2,
                top: widget.verticalPadding,
                bottom: widget.verticalPadding,
                width: handleTouchW,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onHorizontalDragStart: (_) => _dragging = _DragHandle.right,
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
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      width: handleVisualW,
                      height: handleVisualH,
                      decoration: BoxDecoration(
                        color: Color(0xFF698FC5),
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
      ),
    );
  }
}