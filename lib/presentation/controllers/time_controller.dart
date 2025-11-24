import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

import '../../domain/entities/city_time.dart';

class TimeController extends GetxController {
  final cityTimes = <CityTime>[].obs;
  final selectedHour = DateTime.now().hour.obs;
  final storage = GetStorage();
  final utcNow = DateTime.now().toUtc().obs;
  final selectedStartUtc = Rx<DateTime?>(null);
  final selectedEndUtc = Rx<DateTime?>(null);
  final resetCounter = 0.obs;
  final RxString defaultCityId = ''.obs;

  // NEW: selected calendar date (nullable). Stored as UTC midnight.
  final Rxn<DateTime> selectedDate = Rxn<DateTime>();

  // Optional reload indicator if you need it later
  final RxBool isReloading = false.obs;

  Timer? _minuteTimer;

  @override
  void onInit() {
    super.onInit();
    tz_data.initializeTimeZones();
    loadCities();
    updateTimes();

    // ✅ chỉ tạo 1 timer duy nhất trong controller
    _minuteTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      updateTimes();
    });
  }

  @override
  void onClose() {
    _minuteTimer?.cancel();
    super.onClose();
  }

  // --- calendar date helpers ---
  void setSelectedDate(DateTime dateLocal) {
    final utcMidnight = DateTime.utc(dateLocal.year, dateLocal.month, dateLocal.day);
    selectedDate.value = utcMidnight;
  }

  void clearSelectedDate() {
    selectedDate.value = null;
  }

  // --- existing city/time methods ---
  void addCity(String cityName, String timezone) {
    const int maxCities = 15;

    if (cityTimes.length >= maxCities) {
      Get.snackbar(
        'Giới hạn thành phố',
        'Bạn chỉ có thể lưu tối đa $maxCities thành phố.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.black87,
        colorText: Colors.white,
      );
      return;
    }

    final exists = cityTimes.any((c) =>
    c.cityName.toLowerCase() == cityName.toLowerCase() || c.timezone == timezone);
    if (exists) {
      Get.snackbar(
        'Đã có trong danh sách',
        'Thành phố này đã có trong danh sách.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.black87,
        colorText: Colors.white,
      );
      return;
    }

    final location = tz.getLocation(timezone);
    final now = tz.TZDateTime.now(location);
    final cityTime = CityTime(cityName: cityName, timezone: timezone, time: now);

    cityTimes.add(cityTime);
    saveCities();

    if (cityTimes.length == 1) {
      setDefaultCity(cityTime.cityName);
    }
  }

  void removeCity(String cityName) {
    cityTimes.removeWhere((ct) => ct.cityName == cityName);
    saveCities();

    if (defaultCityId.value == cityName) {
      if (cityTimes.isNotEmpty) {
        setDefaultCity(cityTimes.first.cityName);
      } else {
        defaultCityId.value = '';
        storage.remove('defaultCityId');
      }
    }
  }

  void updateTimes() {
    final now = DateTime.now();
    utcNow.value = now.toUtc();

    debugPrint('⏱ updateTimes() called at: $now');

    final updated = cityTimes.map((ct) {
      final location = tz.getLocation(ct.timezone);
      final local = tz.TZDateTime.now(location);
      debugPrint('📍 ${ct.cityName} local time: $local');
      return CityTime(cityName: ct.cityName, timezone: ct.timezone, time: local);
    }).toList();

    cityTimes.assignAll(updated);
  }

  void saveCities() {
    final list = cityTimes.map((ct) => {
      'city': ct.cityName,
      'timezone': ct.timezone,
    }).toList();
    storage.write('cities', list);
  }

  void loadCities() {
    final list = storage.read<List>('cities') ?? [];
    final loaded = list.map((item) {
      return CityTime(
        cityName: item['city'],
        timezone: item['timezone'],
        time: tz.TZDateTime.now(tz.getLocation(item['timezone'])),
      );
    }).toList();

    final savedDefault = storage.read<String>('defaultCityId');

    if (savedDefault != null && loaded.any((c) => c.cityName == savedDefault)) {
      defaultCityId.value = savedDefault;
      final index = loaded.indexWhere((c) => c.cityName == savedDefault);
      if (index > 0) {
        final home = loaded.removeAt(index);
        loaded.insert(0, home);
      }
    } else if (loaded.isNotEmpty) {
      defaultCityId.value = loaded.first.cityName;
      storage.write('defaultCityId', defaultCityId.value);
    }

    cityTimes.assignAll(loaded);
  }

  void reorderCity(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    final item = cityTimes.removeAt(oldIndex);
    cityTimes.insert(newIndex, item);
    saveCities();
  }

  void moveCityUp(String cityName) {
    final index = cityTimes.indexWhere((c) => c.cityName == cityName);
    if (index > 0) {
      final temp = cityTimes[index];
      cityTimes[index] = cityTimes[index - 1];
      cityTimes[index - 1] = temp;
    }
  }

  void moveCityDown(String cityName) {
    final index = cityTimes.indexWhere((c) => c.cityName == cityName);
    if (index < cityTimes.length - 1 && index != -1) {
      final temp = cityTimes[index];
      cityTimes[index] = cityTimes[index + 1];
      cityTimes[index + 1] = temp;
    }
  }

  void setDefaultCity(String cityName) {
    defaultCityId.value = cityName;
    storage.write('defaultCityId', cityName);

    final index = cityTimes.indexWhere((c) => c.cityName == cityName);
    if (index > 0) {
      final city = cityTimes.removeAt(index);
      cityTimes.insert(0, city);
    }

    // cập nhật giờ hiện tại theo location mới
    final location = tz.getLocation(cityTimes.first.timezone);
    final nowLocal = tz.TZDateTime.now(location);
    utcNow.value = nowLocal.toUtc();

    // ép TimeRangeSelector reset về giờ hiện tại của home city mới
    resetCounter.value++;

    updateTimes();
  }

  void showSafeSnackbar(String title, String message) {
    final context = Get.context;
    if (context != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}