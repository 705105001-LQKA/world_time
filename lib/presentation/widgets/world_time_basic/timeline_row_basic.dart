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
          DateTime newStart;
          DateTime newEnd;
          final curStart = controller.selectedStartUtc.value;
          final curEnd = controller.selectedEndUtc.value;

          if (curStart == null && curEnd == null) {
            newStart = utcStart;
            newEnd = utcEnd;
          } else {
            DateTime s = curStart!;
            DateTime e = curEnd!;
            if (e.isBefore(s)) {
              final tmp = s;
              s = e;
              e = tmp;
            }
            newStart = s;
            newEnd = utcEnd;
            if (newEnd.isBefore(newStart)) {
              DateTime swappedStart = newEnd;
              DateTime swappedEnd = newStart;
              swappedStart = swappedStart.subtract(const Duration(hours: 1));
              swappedEnd = swappedEnd.add(const Duration(hours: 1));
              newStart = swappedStart;
              newEnd = swappedEnd;
            }
          }

          controller.selectedStartUtc.value = newStart;
          controller.selectedEndUtc.value = newEnd;
        },
      ));
    }

    return SingleChildScrollView(
      controller: scrollController,
      scrollDirection: Axis.horizontal,
      child: Row(children: children),
    );
  }
}