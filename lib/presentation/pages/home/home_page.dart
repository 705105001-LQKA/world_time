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

  // ScrollController cho ListView dọc
  final ScrollController listScrollController = ScrollController();

  // Row scroll sync service (quản lý tất cả ScrollController của từng hàng)
  final RowScrollSync _scrollSync = RowScrollSync();

  late tz.Location hcmLocation;

  // Giới hạn số thành phố hiển thị
  static const int _kMaxCities = 15;

  @override
  void initState() {
    super.initState();
    hcmLocation = tz.getLocation('Asia/Ho_Chi_Minh');

    // Gọi updateTimes ngay
    controller.updateTimes();

    // Căn chỉnh tới đầu phút kế tiếp, sau đó cập nhật định kỳ
    final now = DateTime.now();
    final nextTick = DateTime(now.year, now.month, now.day, now.hour, now.minute)
        .add(const Duration(minutes: 1));
    final initialDelay = nextTick.difference(now);

    Future.delayed(initialDelay, () {
      controller.updateTimes();
      setState(() {}); // cập nhật utcNow mỗi phút

      Timer.periodic(const Duration(minutes: 1), (_) {
        controller.updateTimes();
        setState(() {}); // buộc build lại để utcNow mới
      });
    });
  }

  @override
  void dispose() {
    // detach all controllers managed by RowScrollSync
    for (final k in _scrollSync.keys()) {
      try {
        _scrollSync.detach(k);
      } catch (_) {}
    }
    listScrollController.dispose();
    super.dispose();
  }

  // đảm bảo có controller cho cityId; trả về ScrollController từ RowScrollSync
  ScrollController _ensureControllerFor(String cityId) {
    return _scrollSync.attach(cityId, (id) => _onRowScroll(id));
  }

  // Trim controllers để chỉ giữ những key đang hiển thị (avoid leak)
  void _trimControllersForDisplayed(List<String> displayedIds) {
    final toRemove =
    _scrollSync.keys().where((k) => !displayedIds.contains(k)).toList();
    for (final k in toRemove) {
      _scrollSync.detach(k);
    }
  }

  // đồng bộ: khi một controller thay đổi, chuyển tiếp tới RowScrollSync
  void _onRowScroll(String sourceId) {
    _scrollSync.onRowScroll(sourceId);
  }

  // Khi một controller mới attach (sau build), đồng bộ nó tới lastRatio
  void _syncControllerIfNeeded(String cityId) {
    _scrollSync.syncIfNeeded(cityId);
  }

  @override
  Widget build(BuildContext context) {
    final nowSystem = DateTime.now();
    final nowUtcReal = DateTime.now().toUtc();

    // determine base date (UTC midnight) from controller or fallback to today's UTC date
    final selectedDateUtc = controller.selectedDate.value; // DateTime? (UTC midnight) or null
    final baseDate = selectedDateUtc ??
        DateTime.utc(nowSystem.year, nowSystem.month, nowSystem.day);

    // build utcNow: combine baseDate's YMD with current clock time (UTC)
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

    // hcmStart: midnight at selected day in HCM timezone
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
            // Danh sách thành phố
            Expanded(
              child: Obx(() {
                final filtered = controller.cityTimes
                    .where((ct) =>
                    ct.cityName.toLowerCase().contains(searchQuery.value))
                    .toList();

                if (filtered.isEmpty) {
                  // clean up controllers if none displayed
                  _trimControllersForDisplayed([]);
                  return const Center(child: Text('No matching cities.'));
                }

                // prepare display list (limited)
                final displayCount =
                filtered.length > _kMaxCities ? _kMaxCities : filtered.length;
                final displayed = filtered.take(displayCount).toList();
                final displayedIds = displayed.map((c) => c.cityName).toList();

                // trim controllers not used anymore
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
                        setState(() {}); // cập nhật lại UI
                      },
                      itemBuilder: (context, index) {
                        final city = displayed[index];
                        final cityId = city.cityName;
                        final rowController = _ensureControllerFor(cityId);

                        _syncControllerIfNeeded(cityId);

                        return Dismissible(
                          key: ValueKey(cityId),
                          direction: DismissDirection.none, // không cho swipe xoá
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

                    // banner nếu bị giới hạn
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
                            child: Text(
                              'Chỉ hiển thị $_kMaxCities thành phố. Xóa bớt để hiển thị thêm.',
                              style:
                              const TextStyle(color: Colors.white, fontSize: 12),
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