import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;
import '../../controllers/time_controller.dart';
import 'time_cell_basic.dart';
import 'package:get/get.dart';

class TimelineRowBasic extends StatefulWidget {
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
  State<TimelineRowBasic> createState() => _TimelineRowBasicState();
}

class _TimelineRowBasicState extends State<TimelineRowBasic>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true; // 👈 giữ widget này sống khi cuộn ra khỏi viewport

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final controller = Get.find<TimeController>();

    return Obx(() {
      final children = <Widget>[];
      for (int i = 0; i < 24; i++) {
        final utcBase = widget.hcmStart.toUtc();
        final localBase = tz.TZDateTime.from(utcBase, widget.location);
        final localStart = localBase.add(Duration(hours: i));
        final utcStart = localStart.toUtc();
        final utcEnd = utcStart.add(const Duration(hours: 1));

        children.add(TimeCellBasic(
          utcStart: utcStart,
          utcEnd: utcEnd,
          location: widget.location,
          utcNow: controller.utcNow.value, // 👈 luôn cập nhật
          selStart: widget.selStart,
          selEnd: widget.selEnd,
          selectedDateUtc: widget.selectedDateUtc,
          onDoubleTap: () {
            // Lưu instants (UTC)
            controller.selectedStartUtc.value = utcStart.toUtc();
            controller.selectedEndUtc.value   = utcEnd.toUtc();

            // Lưu selectedDate dưới dạng UTC midnight của ngày localStart
            final localStart = tz.TZDateTime.from(utcStart.toUtc(), widget.location);
            controller.selectedDate.value = DateTime.utc(localStart.year, localStart.month, localStart.day);
          },
        ));
      }

      return SingleChildScrollView(
        controller: widget.scrollController,
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          height: 52,
          child: Row(children: children),
        ),
      );
    });
  }
}