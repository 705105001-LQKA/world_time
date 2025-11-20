import 'package:flutter/material.dart';
import 'package:get/get.dart';

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

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final hasSelection = controller.selectedStartUtc.value != null || controller.selectedEndUtc.value != null;
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

          IconButton(
            icon: const Icon(Icons.calendar_today),
            tooltip: 'Chọn ngày',
            onPressed: () async {
              final now = DateTime.now();
              final initial = controller.selectedDate.value != null
                  ? DateTime.fromMillisecondsSinceEpoch(controller.selectedDate.value!.millisecondsSinceEpoch, isUtc: true).toLocal()
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