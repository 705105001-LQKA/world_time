import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../domain/entities/city_time.dart';
import '../controllers/time_controller.dart';
import 'header_row.dart';
import 'timeline_row.dart';

class CityTimeRow extends StatelessWidget {
  final CityTime cityTime;
  final DateTime utcNow;
  final tz.TZDateTime hcmStart;
  final ScrollController scrollController;

  const CityTimeRow({
    super.key,
    required this.cityTime,
    required this.utcNow,
    required this.hcmStart,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final location = tz.getLocation(cityTime.timezone);
    final controller = Get.find<TimeController>();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HeaderRow(cityTime: cityTime, utcNow: utcNow, location: location),
          const SizedBox(height: 8),

          // Obx đọc observable và truyền giá trị thuần xuống TimelineRow
          Obx(() {
            final selStart = controller.selectedStartUtc.value;
            final selEnd = controller.selectedEndUtc.value;
            final selectedDateUtc = controller.selectedDate.value;

            return TimelineRow(
              hcmStart: hcmStart,
              location: location,
              utcNow: utcNow,
              scrollController: scrollController,
              selStart: selStart,
              selEnd: selEnd,
              selectedDateUtc: selectedDateUtc,
            );
          }),
        ],
      ),
    );
  }
}