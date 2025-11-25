import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../domain/entities/city_time.dart';
import '../../controllers/time_controller.dart';
import 'header_row_basic.dart';
import 'timeline_row_basic.dart';

class CityTimeRowBasic extends StatelessWidget {
  final CityTime cityTime;
  final DateTime utcNow;
  final tz.TZDateTime hcmStart;
  final ScrollController scrollController;
  final VoidCallback onHomeChanged;

  const CityTimeRowBasic({
    super.key,
    required this.cityTime,
    required this.utcNow,
    required this.hcmStart,
    required this.scrollController,
    required this.onHomeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final location = tz.getLocation(cityTime.timezone);
    final controller = Get.find<TimeController>();

    // Mốc UTC của thành phố mặc định
    final utcBase = hcmStart.toUtc();

    // Dịch sang timezone của thành phố hiện tại
    final startOfDay = tz.TZDateTime.from(utcBase, location);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HeaderRowBasic(
            cityTime: cityTime,
            utcNow: utcNow,
            location: location,
            onHomeChanged: onHomeChanged,
          ),
          const SizedBox(height: 8),

          // Obx đọc observable và truyền giá trị xuống TimelineRowBasic
          Obx(() {
            final selStart = controller.selectedStartUtc.value;
            final selEnd = controller.selectedEndUtc.value;
            final selectedDateUtc = controller.selectedDate.value;

            return TimelineRowBasic(
              hcmStart: startOfDay,
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