import 'package:flutter/material.dart';
import '../../../app/util/time_range_utils.dart';

class TimeRangeSelectorBox extends StatefulWidget {
  final double hourWidth;
  final double horizontalPadding;
  final double verticalPadding;

  final double Function() currentHorizontalOffsetPx;

  final int startMin;
  final int endMin;

  const TimeRangeSelectorBox({
    super.key,
    required this.hourWidth,
    required this.horizontalPadding,
    required this.verticalPadding,
    required this.currentHorizontalOffsetPx,
    required this.startMin,
    required this.endMin,
  });

  @override
  State<TimeRangeSelectorBox> createState() => _TimeRangeSelectorBoxState();
}

class _TimeRangeSelectorBoxState extends State<TimeRangeSelectorBox> {
  late int _startMin;
  late int _endMin;

  @override
  void initState() {
    super.initState();
    _startMin = widget.startMin.clamp(0, 1440);
    _endMin = widget.endMin.clamp(0, 1440);
  }

  @override
  void didUpdateWidget(covariant TimeRangeSelectorBox oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.startMin != widget.startMin || oldWidget.endMin != widget.endMin) {
      final newStart = widget.startMin.clamp(0, 1440);
      final newEnd = widget.endMin.clamp(0, 1440);
      if (newStart != _startMin || newEnd != _endMin) {
        setState(() {
          _startMin = newStart;
          _endMin = newEnd;
        });
      }
    }
  }

  int _normalizeEnd(int start, int end) {
    if (end >= 1430) return 1440;
    if (end == 0 && start > 0) return 1440;
    if (end < 0) return 0;
    if (end > 1440) return 1440;
    return end;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) {
        final double viewportWidth = constraints.maxWidth;
        final double offset = widget.currentHorizontalOffsetPx();

        final int normStart = _startMin.clamp(0, 1440);
        final int normEnd = _normalizeEnd(normStart, _endMin);

        if (normEnd <= normStart) return const SizedBox.shrink();

        final double contentStartX = minutesToContentX(
          minutes: normStart,
          hourWidth: widget.hourWidth,
          horizontalPadding: widget.horizontalPadding,
        );
        final double contentEndX = minutesToContentX(
          minutes: normEnd,
          hourWidth: widget.hourWidth,
          horizontalPadding: widget.horizontalPadding,
        );

        final double rawLeft = contentStartX - offset;
        final double rawRight = contentEndX - offset;
        final double width = rawRight - rawLeft;

        // Nếu hoàn toàn nằm ngoài viewport, không vẽ (giữ hiệu năng)
        if (rawRight <= 0.0 || rawLeft >= viewportWidth) return const SizedBox.shrink();
        if (width <= 0) return const SizedBox.shrink();

        // Parent Stack phải có clipBehavior: Clip.none để phần overflow hiển thị
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: widget.verticalPadding,
              bottom: widget.verticalPadding,
              left: rawLeft, // đặt trực tiếp theo toạ độ thô (có thể âm)
              width: width,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.green, width: 2),
                  color: const Color(0x0A000000),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}