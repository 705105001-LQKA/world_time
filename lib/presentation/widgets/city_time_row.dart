import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:url_launcher/url_launcher.dart';

import '../../app/util/calender_utils.dart';
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
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.calendar_today),
              label: const Text('Google Calendar'),
              onPressed: () async {
                final start = controller.selectedStartUtc.value;
                final end = controller.selectedEndUtc.value;

                if (start == null || end == null) {
                  controller.showSafeSnackbar('Missing time', 'Please select a time range first');
                  return;
                }

                final cities = controller.cityTimes;
                final description = buildDescription(
                  startUtc: start,
                  endUtc: end,
                  cities: cities,
                );

                final url = buildGoogleCalendarUrl(
                  title: 'Let\'s Meet',
                  startUtc: start,
                  endUtc: end,
                  description: description,
                );

                final uri = Uri.parse(url);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } else {
                  controller.showSafeSnackbar('Error', 'Could not launch Google Calendar');
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}