import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;
import '../../controllers/time_controller.dart';
import 'time_cell_basic.dart';
import 'package:get/get.dart';

class TimelineRowBasic extends StatelessWidget {
  final tz.TZDateTime hcmStart;
  final tz.Location location;
  final DateTime utcNow;
  final ScrollController scrollController;

  // Các giá trị selection từ controller
  final DateTime? selStart;
  final DateTime? selEnd;
  final DateTime? selectedDateUtc;

  const TimelineRowBasic({
    super.key,
    required this.hcmStart,
    required this.location,
    required this.utcNow,
    required this.scrollController,
    required this.selStart,
    required this.selEnd,
    required this.selectedDateUtc,
  });

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<TimeController>();

    final children = <Widget>[];
    for (int i = 0; i < 24; i++) {
      final utcBase = hcmStart.toUtc();
      final localBase = tz.TZDateTime.from(utcBase, location);

      final localStart = localBase.add(Duration(hours: i));
      final utcStart = localStart.toUtc();
      final utcEnd = utcStart.add(const Duration(hours: 1));

      children.add(TimeCellBasic(
        utcStart: utcStart,
        utcEnd: utcEnd,
        location: location,
        utcNow: utcNow,
        selStart: selStart,
        selEnd: selEnd,
        selectedDateUtc: selectedDateUtc,
        onDoubleTap: () {
          controller.selectedStartUtc.value = utcStart;
          controller.selectedEndUtc.value   = utcEnd;
          controller.selectedDate.value     = utcStart;

          // 👇 Tính offset dựa trên giờ
          const hourWidth = 50.0; // phải khớp với hourWidth bạn set trong TimeRangeSelector
          final offset = utcStart.hour * hourWidth;

          scrollController.animateTo(
            offset,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        },
      ));
    }

    return SingleChildScrollView(
      controller: scrollController,
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        height: 48, // 👈 ép row cao hơn để tránh bị constraint 43px
        child: Row(children: children),
      ),
    );
  }
}