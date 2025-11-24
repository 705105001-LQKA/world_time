import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../controllers/time_controller.dart';
import '../../../domain/entities/city_time.dart';

class HeaderRow extends StatelessWidget {
  final CityTime cityTime;
  final DateTime utcNow;
  final tz.Location location;
  final VoidCallback onHomeChanged;

  const HeaderRow({
    super.key,
    required this.cityTime,
    required this.utcNow,
    required this.location,
    required this.onHomeChanged,
  });

  String _formatUtcOffset(Duration offset) {
    final totalMinutes = offset.inMinutes;
    final sign = totalMinutes >= 0 ? '+' : '-';
    final absMinutes = totalMinutes.abs();
    final hours = (absMinutes ~/ 60).toString().padLeft(2, '0');
    final minutes = (absMinutes % 60).toString().padLeft(2, '0');
    return 'UTC$sign$hours:$minutes';
  }

  String _formatDuration(Duration d) {
    final totalMinutes = d.inMinutes.abs();
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    if (hours > 0 && minutes > 0) {
      return '${hours}h ${minutes}m';
    } else if (hours > 0) {
      return '${hours}h';
    } else {
      return '${minutes}m';
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<TimeController>();
    final localNow = tz.TZDateTime.from(utcNow, location);

    return Row(
      mainAxisSize: MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 140,
                child: Text(
                  cityTime.cityName,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Obx(() {
                  final start = controller.selectedStartUtc.value;
                  final end = controller.selectedEndUtc.value;
                  final selectedDateUtc = controller.selectedDate.value;

                  // If there is a start/end selection, show the range in city's local tz
                  if (start != null && end != null) {
                    final localStart = tz.TZDateTime.from(start, location);
                    final localEnd = tz.TZDateTime.from(end, location);

                    // ensure we compute positive duration between normalized boundaries
                    DateTime s = start;
                    DateTime e = end;
                    if (e.isBefore(s)) {
                      final tmp = s;
                      s = e;
                      e = tmp;
                    }
                    final duration = e.difference(s);

                    final rangeLabel =
                        '${DateFormat('HH:mm E dd/MM').format(localStart)} → ${DateFormat('HH:mm E dd/MM').format(localEnd)}';
                    final durationLabel = ' (${_formatDuration(duration)})';

                    return Text(
                      '$rangeLabel$durationLabel',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    );
                  }

                  // If user selected a calendar date, show weekday + date (based on that date in city's tz)
                  if (selectedDateUtc != null) {
                    final tzDate = tz.TZDateTime.from(selectedDateUtc, location);
                    final label = '${DateFormat.E().format(tzDate)}, ${DateFormat('dd MMM yyyy').format(tzDate)}';
                    return Text(
                      label,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    );
                  }

                  // Default: show timezone · HH:mm · weekday, date · UTC offset
                  final weekday = DateFormat.E().format(localNow);
                  final date = DateFormat('dd MMM').format(localNow);
                  return Row(
                    children: [
                      Flexible(
                        child: Text(
                          cityTime.timezone,
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${localNow.hour.toString().padLeft(2, '0')}:${localNow.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          '$weekday, $date',
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _formatUtcOffset(localNow.timeZoneOffset),
                        style: const TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ],
                  );
                }),
              ),
            ],
          ),
        ),

        IconButton(
          icon: Obx(() {
            final isDefault = controller.defaultCityId.value == cityTime.cityName;
            return Icon(
              Icons.home,
              color: isDefault ? Colors.green : Colors.grey,
            );
          }),
          tooltip: 'Đặt làm mặc định',
          padding: EdgeInsets.zero,
          onPressed: () {
            controller.setDefaultCity(cityTime.cityName);
            onHomeChanged(); // Gọi lại setState từ HomePage
          },
          iconSize: 24.0,
          constraints: const BoxConstraints(minWidth: 0, minHeight: 0, maxWidth: 24, maxHeight: 24),
          visualDensity: VisualDensity.compact,
        ),

        IconButton(
          icon: const Icon(Icons.close, color: Colors.red),
          tooltip: 'Xóa thành phố',
          padding: EdgeInsets.zero,
          onPressed: () {
            final controller = Get.find<TimeController>();
            Get.defaultDialog(
              title: 'Xác nhận xóa',
              middleText: 'Bạn có chắc muốn xóa ${cityTime.cityName} khỏi danh sách?',
              textCancel: 'Hủy',
              textConfirm: 'Xóa',
              confirmTextColor: Colors.white,
              onConfirm: () {
                controller.removeCity(cityTime.cityName);
                Navigator.of(Get.context!).pop();
              },
            );
          },
          iconSize: 24.0,
          constraints: const BoxConstraints(minWidth: 0, minHeight: 0, maxWidth: 24, maxHeight: 24),
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }
}