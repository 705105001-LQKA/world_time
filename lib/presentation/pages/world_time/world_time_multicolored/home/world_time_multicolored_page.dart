import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter/services.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../../widgets/world_time_multicolored/city_time_row.dart';
import '../../../../controllers/time_controller.dart';
import 'world_time_multicolored_appbar_action.dart';
import '../city_search/world_time_multicolored_row_scroll_sync.dart';

class WorldTimeMulticoloredPage extends StatefulWidget {
  const WorldTimeMulticoloredPage({super.key});

  @override
  State<WorldTimeMulticoloredPage> createState() => _WorldTimeMulticoloredPageState();
}

class _WorldTimeMulticoloredPageState extends State<WorldTimeMulticoloredPage> {
  final TimeController controller = Get.put(TimeController());
  final RxString searchQuery = ''.obs;

  final ScrollController listScrollController = ScrollController();
  final RowScrollSync _scrollSync = RowScrollSync();

  static const int _kMaxCities = 15;

  Timer? _minuteTimer;

  @override
  void initState() {
    super.initState();

    // ✅ ép orientation sang ngang khi vào trang này
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
    ]);

    controller.updateTimes();
  }

  @override
  void dispose() {
    _minuteTimer?.cancel();
    Get.delete<TimeController>(); // ✅ hủy controller luôn

    for (final k in _scrollSync.keys()) {
      try {
        _scrollSync.detach(k);
      } catch (_) {}
    }
    listScrollController.dispose();
    debugPrint('🔴 AppleActions dispose called');

    // ✅ khi thoát trang ngang, đặt lại orientation về dọc
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);

    super.dispose();
  }

  ScrollController _ensureControllerFor(String cityId) {
    return _scrollSync.attach(cityId, (id) => _onRowScroll(id));
  }

  void _trimControllersForDisplayed(List<String> displayedIds) {
    final toRemove =
    _scrollSync.keys().where((k) => !displayedIds.contains(k)).toList();
    for (final k in toRemove) {
      _scrollSync.detach(k);
    }
  }

  void _onRowScroll(String sourceId) {
    _scrollSync.onRowScroll(sourceId);
  }

  void _syncControllerIfNeeded(String cityId) {
    _scrollSync.syncIfNeeded(cityId);
  }

  @override
  Widget build(BuildContext context) {
    final nowSystem = DateTime.now();

    final controller = Get.find<TimeController>();

    // ✅ Lấy thành phố mặc định và timezone
    final defaultCity = controller.cityTimes.firstWhereOrNull(
          (c) => c.cityName == controller.defaultCityId.value,
    );
    final defaultLocation = defaultCity != null
        ? tz.getLocation(defaultCity.timezone)
        : tz.getLocation('Asia/Ho_Chi_Minh');

    // ✅ Lấy thời gian hiện tại theo timezone của thành phố mặc định
    final nowInDefault = tz.TZDateTime.now(defaultLocation);

    // ✅ Tính ngày cơ sở theo timezone của home
    final selectedDateUtc = controller.selectedDate.value;
    final baseDate = selectedDateUtc ??
        DateTime.utc(nowInDefault.year, nowInDefault.month, nowInDefault.day);

    final utcNow = nowInDefault.toUtc();

    debugPrint('🔍 System time: $nowSystem');
    debugPrint('🌐 UTC time used in UI: $utcNow');

    // ✅ Mốc bắt đầu của ngày theo timezone của home
    final hcmStart =
    tz.TZDateTime(defaultLocation, baseDate.year, baseDate.month, baseDate.day, 0);

    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('World Time Multicolored'),
          actions: [
            AppBarActions(
              controller: controller,
              onAfterAddOrDateChange: () => setState(() {}),
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: Obx(() {
                final filtered = controller.cityTimes
                    .where((ct) => ct.cityName.toLowerCase().contains(searchQuery.value))
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

                return Stack(
                  children: [
                    ReorderableListView.builder(
                      key: const PageStorageKey('cityList'),
                      buildDefaultDragHandles: true,
                      scrollController: listScrollController,
                      itemCount: displayed.length,
                      onReorder: (oldIndex, newIndex) {
                        controller.reorderCity(oldIndex, newIndex);
                        setState(() {});
                      },
                      itemBuilder: (context, index) {
                        final city = displayed[index];
                        final cityId = city.cityName;
                        final rowController = _ensureControllerFor(cityId);

                        _syncControllerIfNeeded(cityId);

                        return Dismissible(
                          key: ValueKey(cityId),
                          direction: DismissDirection.none,
                          child: CityTimeRow(
                            cityTime: city,
                            utcNow: utcNow,
                            hcmStart: hcmStart,
                            scrollController: rowController,
                            onHomeChanged: () => setState(() {}),
                          ),
                        );
                      },
                      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 10),
                    ),
                    if (filtered.length > _kMaxCities)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 8,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black87,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'Chỉ hiển thị 15 thành phố. Xóa bớt để hiển thị thêm.',
                              style: TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ),
                        ),
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