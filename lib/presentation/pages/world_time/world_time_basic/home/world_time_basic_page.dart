import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter/services.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../../widgets/world_time_basic/city_time_row_basic.dart';
import '../../../../widgets/world_time_basic/time_range_selector.dart';
import '../../../../controllers/time_controller.dart';
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

    final nowInDefault = tz.TZDateTime.now(defaultLocation);

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

                // 👇 Clamp offset sau khi danh sách thay đổi
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
                _syncControllerIfNeeded(homeCityId);

                return Stack(
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
                      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 10),
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
                    Builder(
                      builder: (context) {
                        final count = displayed.length;
                        final overlayHeight = count == 0 ? 0 : 50 + (count - 1) * 102;

                        if (overlayHeight <= 0) {
                          return const SizedBox.shrink();
                        }

                        // Lấy controller ngang của thành phố mặc định
                        final homeCityId = tc.defaultCityId.value;
                        final homeRowController = _ensureControllerFor(homeCityId);
                        _syncControllerIfNeeded(homeCityId);

                        // 👇 Chỉ render selector khi controller đã attach
                        if (!homeRowController.hasClients) {
                          return const SizedBox.shrink();
                        }

                        return Positioned(
                          left: 0,
                          right: 0,
                          top: 60,
                          height: overlayHeight.toDouble(),
                          child: AnimatedBuilder(
                            animation: listScrollController,
                            builder: (context, _) {
                              final dy = -listScrollController.offset;
                              return Transform.translate(
                                offset: Offset(0, dy),
                                child: SizedBox(
                                  height: overlayHeight.toDouble(),
                                  width: double.infinity,
                                  child: Obx(() => TimeRangeSelector(
                                    key: ValueKey('trs_$homeCityId'),
                                    hourWidth: 50.0,
                                    horizontalPadding: 17.0,
                                    verticalPadding: 0.0,
                                    scrollController: homeRowController,
                                    currentHorizontalOffsetPx: _currentHorizontalOffsetPx,
                                    nowUtc: tc.utcNow.value,
                                    timelineLocation: defaultLocation,
                                    resetCounter: tc.resetCounter.value,
                                    selectedStartUtc: tc.selectedStartUtc.value,
                                    selectedEndUtc: tc.selectedEndUtc.value,
                                    onRangeChanged: (startMin, endMin) {
                                      final baseDateLocal = tz.TZDateTime(
                                        defaultLocation,
                                        baseDate.year, baseDate.month, baseDate.day, 0,
                                      );
                                      final startLocal = baseDateLocal.add(Duration(minutes: startMin));
                                      final endLocal   = baseDateLocal.add(Duration(minutes: endMin));
                                      tc.selectedStartUtc.value = startLocal.toUtc();
                                      tc.selectedEndUtc.value   = endLocal.toUtc();
                                      setState(() {});
                                    },
                                  )),
                                ),
                              );
                            },
                          ),
                        );
                      },
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