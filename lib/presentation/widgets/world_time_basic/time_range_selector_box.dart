import 'package:flutter/material.dart';

class TimeRangeSelectorBox extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) {
        final viewportWidth = constraints.maxWidth;
        final offset = currentHorizontalOffsetPx();

        // Tọa độ theo content
        final contentStartX = (startMin / 60.0) * hourWidth + horizontalPadding;
        final contentEndX   = (endMin   / 60.0) * hourWidth + horizontalPadding;

        // Chuyển sang viewport
        double startVX = contentStartX - offset;
        double endVX   = contentEndX   - offset;

        // Clamp theo viewport
        startVX = startVX.clamp(0.0, viewportWidth);
        endVX   = endVX.clamp(0.0, viewportWidth);

        return Stack(
          children: [
            Positioned(
              top: verticalPadding,
              bottom: verticalPadding,
              left: startVX,
              width: (endVX - startVX).clamp(0.0, viewportWidth),
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