import 'dart:io';

import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/services/google_calendar_service_v5.dart';
import '../../../app/util/calender_utils.dart';
import '../../controllers/time_controller.dart';
import '../city_search/city_search_page.dart';

class AppBarActions extends StatelessWidget {
  final TimeController controller;
  final VoidCallback onAfterAddOrDateChange;

  const AppBarActions({
    super.key,
    required this.controller,
    required this.onAfterAddOrDateChange,
  });

  Future<T?> _showProgressDialog<T>(BuildContext context) {
    return showDialog<T>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final GoogleCalendarServiceV5 calendarService = GoogleCalendarServiceV5();

    return Obx(() {
      final hasSelection = controller.selectedStartUtc.value != null ||
          controller.selectedEndUtc.value != null;
      final hasDate = controller.selectedDate.value != null;

      return Row(
        children: [
          if (hasSelection)
            IconButton(
              icon: const Icon(Icons.clear),
              tooltip: 'Hủy chọn thời gian',
              onPressed: () {
                controller.selectedStartUtc.value = null;
                controller.selectedEndUtc.value = null;
              },
            ),

          if (hasSelection)
            IconButton(
              icon: const Icon(Icons.event_available),
              tooltip: 'Tạo sự kiện Google Calendar',
              onPressed: () async {
                final start = controller.selectedStartUtc.value;
                final end = controller.selectedEndUtc.value;

                if (start == null || end == null) {
                  controller.showSafeSnackbar('Thiếu thời gian', 'Vui lòng chọn khoảng thời gian trước');
                  return;
                }

                final cities = controller.cityTimes;
                final description = buildDescription(
                  startUtc: start,
                  endUtc: end,
                  cities: cities,
                );

                _showProgressDialog(context);
                try {
                  final token = await calendarService.signInAndGetAccessToken();
                  if (token == null) {
                    Navigator.of(context, rootNavigator: true).pop();
                    controller.showSafeSnackbar('Lỗi đăng nhập', 'Người dùng đã hủy hoặc đăng nhập thất bại');
                    return;
                  }

                  final result = await calendarService.createEvent(
                    accessToken: token,
                    startUtc: start,
                    endUtc: end,
                    title: "Let's Meet",
                    description: description,
                  );

                  Navigator.of(context, rootNavigator: true).pop();

                  if (result != null) {
                    controller.showSafeSnackbar('Thành công', 'Sự kiện đã được tạo trong Calendar');
                    onAfterAddOrDateChange();

                    final htmlLink = result['htmlLink'];
                    final uri = Uri.parse(htmlLink!); // đảm bảo không null
                    final eid = uri.queryParameters['eid'];

                    if (eid != null) {
                      final calendarLink = 'https://calendar.google.com/calendar/u/2/r/eventedit/$eid';
                      final eventUri = Uri.parse(calendarLink);

                      try {
                        final launched = await launchUrl(eventUri, mode: LaunchMode.externalApplication);
                        if (!launched && Platform.isAndroid) {
                          // fallback mở app Calendar tại thời điểm sự kiện
                          final intent = AndroidIntent(
                            action: 'android.intent.action.VIEW',
                            data: 'content://com.android.calendar/time/${start.millisecondsSinceEpoch}',
                            package: 'com.google.android.calendar',
                          );
                          await intent.launch();
                        }
                      } catch (e) {
                        controller.showSafeSnackbar('Lỗi', 'Không thể mở sự kiện. Vui lòng mở ứng dụng Google Calendar thủ công.');
                      }
                    } else {
                      controller.showSafeSnackbar('Lỗi', 'Không thể xác định liên kết sự kiện.');
                    }
                  } else {
                    controller.showSafeSnackbar('Thất bại', 'Không thể tạo sự kiện');
                  }
                } catch (e) {
                  try {
                    Navigator.of(context, rootNavigator: true).pop();
                  } catch (_) {}
                  final msg = e is SocketException ? 'Không thể kết nối mạng' : 'Đã xảy ra lỗi';
                  controller.showSafeSnackbar('Lỗi', msg);
                }
              },
            ),

          IconButton(
            icon: const Icon(Icons.calendar_today),
            tooltip: 'Chọn ngày',
            onPressed: () async {
              final now = DateTime.now();
              final initial = controller.selectedDate.value != null
                  ? DateTime.fromMillisecondsSinceEpoch(
                controller.selectedDate.value!.millisecondsSinceEpoch,
                isUtc: true,
              ).toLocal()
                  : now;
              final picked = await showDatePicker(
                context: context,
                initialDate: initial,
                firstDate: DateTime(1900),
                lastDate: DateTime(2100),
              );
              if (picked != null) {
                controller.setSelectedDate(picked);
                onAfterAddOrDateChange();
              }
            },
          ),

          if (hasDate)
            IconButton(
              icon: const Icon(Icons.delete_forever),
              tooltip: 'Xóa ngày đã chọn',
              onPressed: () {
                controller.clearSelectedDate();
                onAfterAddOrDateChange();
              },
            ),

          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              await Get.to(() => CitySearchPage());
              onAfterAddOrDateChange();
            },
          ),
        ],
      );
    });
  }
}