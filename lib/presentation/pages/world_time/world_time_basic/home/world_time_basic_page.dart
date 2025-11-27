import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter/services.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../../widgets/world_time_basic/city_time_row_basic.dart';
import '../../../../widgets/world_time_basic/time_range_handles.dart';
import '../../../../widgets/world_time_basic/time_range_selector.dart';
import '../../../../controllers/time_controller.dart';
import '../../../../widgets/world_time_basic/time_range_selector_box.dart';
import '../../../../widgets/world_time_basic/time_range_overlay.dart';
import 'world_time_basic_appbar_action.dart';
import '../city_search/world_time_basic_row_scroll_sync.dart';

class WorldTimeBasicPage extends StatefulWidget {
  const WorldTimeBasicPage({super.key});

  @override
  State<WorldTimeBasicPage> createState() => _WorldTimeBasicPageState();
}

class _WorldTimeBasicPageState extends State<WorldTimeBasicPage> {
  final TimeController controller = Get.put(TimeController());
  final RxString searchQuery = ''.obs;

  final ScrollController listScrollController = ScrollController();
  final WorldTimeBasicRowScrollSync _scrollSync = WorldTimeBasicRowScrollSync();

  static const int _kMaxCities = 10;
  Timer? _minuteTimer;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeRight]);

    controller.updateTimes();
  }

  @override
  void dispose() {
    _minuteTimer?.cancel();
    Get.delete<TimeController>();
    for (final k in _scrollSync.keys()) {
      _scrollSync.detach(k);
    }
    listScrollController.dispose();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  ScrollController _ensureControllerFor(String cityId) {
    return _scrollSync.attach(cityId, (id) => _onRowScroll(id));
  }

  void _onRowScroll(String sourceId) {
    _scrollSync.onRowScroll(sourceId);
  }

  void _syncControllerIfNeeded(String cityId) {
    _scrollSync.syncIfNeeded(cityId);
  }

  void _trimControllersForDisplayed(List<String> displayedIds) {
    final toRemove =
    _scrollSync.keys().where((k) => !displayedIds.contains(k)).toList();
    for (final k in toRemove) {
      _scrollSync.detach(k);
    }
  }

  double _currentHorizontalOffsetPx() {
    return _scrollSync.currentOffsetPx();
  }

  @override
  Widget build(BuildContext context) {
    final tc = Get.find<TimeController>();

    final defaultCity = tc.cityTimes.firstWhereOrNull(
          (c) => c.cityName == tc.defaultCityId.value,
    );
    final defaultLocation = defaultCity != null
        ? tz.getLocation(defaultCity.timezone)
        : tz.getLocation('Asia/Ho_Chi_Minh');

    // Lấy thời điểm UTC từ controller (reactive). Nếu null thì fallback về DateTime.now()
    final utcNowDt = tc.utcNow.value ?? DateTime.now().toUtc();

// Chuyển UTC sang timezone của defaultLocation để có "now" theo location đó
    final nowInDefault = tz.TZDateTime.from(utcNowDt, defaultLocation);

// Tính baseDate dựa trên nowInDefault như trước
    final selectedDateUtc = tc.selectedDate.value;
    final baseDate = selectedDateUtc ??
        DateTime.utc(nowInDefault.year, nowInDefault.month, nowInDefault.day);

    final baseStartLocal = tz.TZDateTime(
        defaultLocation, baseDate.year, baseDate.month, baseDate.day, 0);

    final utcNow = nowInDefault.toUtc();

    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('World Time Basic'),
          actions: [
            WorldTimeBasicAppBarActions(
              controller: tc,
              onAfterAddOrDateChange: () => setState(() {}),
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: Obx(() {
                final filtered = tc.cityTimes
                    .where((ct) =>
                    ct.cityName.toLowerCase().contains(searchQuery.value))
                    .toList();

                if (filtered.isEmpty) {
                  _trimControllersForDisplayed([]);
                  return const Center(child: Text('No matching cities.'));
                }

                final displayCount =
                filtered.length > _kMaxCities ? _kMaxCities : filtered.length;
                final displayed = filtered.take(displayCount).toList();
                final displayedIds = displayed.map((c) => c.cityName).toList();

                _trimControllersForDisplayed(displayedIds);

                // Clamp offset sau khi danh sách thay đổi
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (listScrollController.hasClients) {
                    final pos = listScrollController.position;
                    final max = pos.maxScrollExtent;
                    final current = pos.pixels;
                    if (current > max) {
                      listScrollController.jumpTo(max);
                    }
                  }
                });

                // Lấy controller ngang của thành phố mặc định
                final homeCityId = tc.defaultCityId.value;
                final homeRowController = _ensureControllerFor(homeCityId);
                _syncControllerIfNeeded(homeCityId);

                // Tính overlay kích thước và vị trí tay nắm
                final count = displayed.length;
                final overlayHeight = count == 0 ? 0 : 50 + (count - 1) * 102;
                final double hourWidth = 50.0;
                final double horizontalPadding = 17.0;
                final double handleFixedHeight = 44.0;
                final double handleFixedTop = (count <= 3)
                    ? ((overlayHeight.toDouble() - handleFixedHeight) / 2.0)
                    .clamp(0.0, overlayHeight.toDouble())
                    : 54.0;

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Danh sách thành phố
                    ReorderableListView.builder(
                      key: const PageStorageKey('cityList'),
                      scrollController: listScrollController,
                      itemCount: displayed.length,
                      onReorder: (oldIndex, newIndex) {
                        tc.reorderCity(oldIndex, newIndex);
                        setState(() {});
                      },
                      padding:
                      const EdgeInsets.symmetric(horizontal: 0, vertical: 10),
                      itemBuilder: (context, index) {
                        final city = displayed[index];
                        final cityId = city.cityName;
                        final rowController = _ensureControllerFor(cityId);
                        _syncControllerIfNeeded(cityId);

                        return Dismissible(
                          key: ValueKey(cityId),
                          direction: DismissDirection.none,
                          child: CityTimeRowBasic(
                            cityTime: city,
                            utcNow: utcNow,
                            hcmStart: baseStartLocal,
                            scrollController: rowController,
                            onHomeChanged: () => setState(() {}),
                          ),
                        );
                      },
                    ),

                    // Overlay thanh chọn với chiều cao tùy theo số thành phố
                    if (overlayHeight > 0)
                      TimeRangeOverlay(
                        hourWidth: hourWidth,
                        horizontalPadding: horizontalPadding,
                        minWidthMinutes: 60.0,
                        readSelectedStartUtc: () => tc.selectedStartUtc.value,
                        readSelectedEndUtc: () => tc.selectedEndUtc.value,
                        onRangeChangedUtc: (startUtc, endUtc) {
                          tc.selectedStartUtc.value = startUtc;
                          tc.selectedEndUtc.value = endUtc;
                          setState(() {});
                        },
                        horizontalController: homeRowController,
                        listScrollController: listScrollController,
                        baseDateLocalDate: baseDate,
                        timelineLocation: defaultLocation,
                        overlayTop: 60.0,
                        overlayHeight: overlayHeight.toDouble(),
                        handleFixedTop: handleFixedTop,
                        handleFixedHeight: handleFixedHeight,
                      ),
                  ],
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}