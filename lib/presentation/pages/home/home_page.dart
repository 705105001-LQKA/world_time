import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../widgets/city_time_row.dart';
import '../../controllers/time_controller.dart';
import 'appbar_action.dart';
import 'row_scroll_sync.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TimeController controller = Get.put(TimeController());
  final RxString searchQuery = ''.obs;

  final ScrollController listScrollController = ScrollController();
  final RowScrollSync _scrollSync = RowScrollSync();

  late tz.Location hcmLocation;
  static const int _kMaxCities = 15;

  Timer? _minuteTimer;

  @override
  void initState() {
    super.initState();
    hcmLocation = tz.getLocation('Asia/Ho_Chi_Minh');

    controller.updateTimes();

    final now = DateTime.now();
    final nextTick = DateTime(now.year, now.month, now.day, now.hour, now.minute)
        .add(const Duration(minutes: 1));
    final initialDelay = nextTick.difference(now);

    Future.delayed(initialDelay, () {
      controller.updateTimes();
      if (mounted) setState(() {});

      _minuteTimer = Timer.periodic(const Duration(minutes: 1), (_) {
        controller.updateTimes();
        if (mounted) setState(() {});
      });
    });
  }

  @override
  void dispose() {
    _minuteTimer?.cancel();

    for (final k in _scrollSync.keys()) {
      try {
        _scrollSync.detach(k);
      } catch (_) {}
    }
    listScrollController.dispose();
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
    final nowUtcReal = DateTime.now().toUtc();

    final selectedDateUtc = controller.selectedDate.value;
    final baseDate = selectedDateUtc ??
        DateTime.utc(nowSystem.year, nowSystem.month, nowSystem.day);

    final utcNow = DateTime.utc(
      baseDate.year,
      baseDate.month,
      baseDate.day,
      nowUtcReal.hour,
      nowUtcReal.minute,
      nowUtcReal.second,
    );

    debugPrint('🔍 System time: $nowSystem');
    debugPrint('🌐 UTC time used in UI: $utcNow');

    final hcmStart =
    tz.TZDateTime(hcmLocation, baseDate.year, baseDate.month, baseDate.day, 0);

    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('World Time'),
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
                          ),
                        );
                      },
                      padding:
                      const EdgeInsets.symmetric(horizontal: 0, vertical: 10),
                    ),
                    if (filtered.length > _kMaxCities)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 8,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black87,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'Chỉ hiển thị 15 thành phố. Xóa bớt để hiển thị thêm.',
                              style:
                              TextStyle(color: Colors.white, fontSize: 12),
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