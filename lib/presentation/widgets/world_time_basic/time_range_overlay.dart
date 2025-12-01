import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;
import 'time_range_handles.dart';
import 'time_range_selector_box.dart';

typedef DateTimeGetter = DateTime? Function();
typedef RangeUtcSetter = void Function(DateTime startUtc, DateTime endUtc);

class TimeRangeOverlay extends StatefulWidget {
  final double hourWidth;
  final double horizontalPadding;
  final double minWidthMinutes;

  final DateTimeGetter readSelectedStartUtc;
  final DateTimeGetter readSelectedEndUtc;
  final RangeUtcSetter onRangeChangedUtc;

  final ScrollController horizontalController;
  final ScrollController? listScrollController;

  /// baseDateLocalDate: local calendar date (year,month,day) used as base for timeline
  final DateTime baseDateLocalDate;
  final tz.Location timelineLocation;

  final double overlayTop;
  final double overlayHeight;
  final double handleFixedTop;
  final double handleFixedHeight;

  const TimeRangeOverlay({
    super.key,
    required this.hourWidth,
    required this.horizontalPadding,
    required this.minWidthMinutes,
    required this.readSelectedStartUtc,
    required this.readSelectedEndUtc,
    required this.onRangeChangedUtc,
    required this.horizontalController,
    required this.baseDateLocalDate,
    required this.timelineLocation,
    this.listScrollController,
    this.overlayTop = 60.0,
    required this.overlayHeight,
    required this.handleFixedTop,
    required this.handleFixedHeight,
  });

  @override
  State<TimeRangeOverlay> createState() => _TimeRangeOverlayState();
}

class _TimeRangeOverlayState extends State<TimeRangeOverlay> {
  late int _dragStartMin;
  late int _dragEndMin;

  late ValueNotifier<List<int>> _rangeNotifier;

  Timer? _pollTimer;
  static const Duration _pollInterval = Duration(milliseconds: 120);

  // Flag để tạm dừng sync từ nguồn ngoài khi user đang kéo
  bool _isUserDragging = false;

  // NEW: lưu giờ đã sync để chỉ update khi hour boundary thay đổi
  int _lastSyncedHour = -1;

  @override
  void initState() {
    super.initState();
    // Khởi tạo giá trị _dragStartMin/_dragEndMin từ controller hoặc mặc định
    _initFromController();
    // Khởi tạo notifier sau khi có giá trị
    _rangeNotifier = ValueNotifier<List<int>>([_dragStartMin, _dragEndMin]);

    // set initial _lastSyncedHour dựa trên trạng thái hiện tại
    final sUtc = widget.readSelectedStartUtc();
    final eUtc = widget.readSelectedEndUtc();
    if (sUtc == null && eUtc == null) {
      final nowLocal = tz.TZDateTime.now(widget.timelineLocation);
      _lastSyncedHour = nowLocal.hour;
    } else {
      // nếu có selection, disable auto-hour-sync
      _lastSyncedHour = -1;
    }

    // Bắt đầu polling để đồng bộ với controller khi user không kéo
    _startPolling();
  }

  void _initFromController() {
    final sUtc = widget.readSelectedStartUtc();
    final eUtc = widget.readSelectedEndUtc();

    if (sUtc != null && eUtc != null) {
      // Chuyển instants sang timezone của timeline để tính phút trong ngày
      final localStart = tz.TZDateTime.from(sUtc.toUtc(), widget.timelineLocation);
      final localEnd = tz.TZDateTime.from(eUtc.toUtc(), widget.timelineLocation);

      // Tính phút từ midnight local của ngày localStart
      final startMin = localStart.hour * 60 + localStart.minute;
      final endMin = localEnd.hour * 60 + localEnd.minute;

      // Nếu end vượt quá 24h (ví dụ selection qua nhiều ngày), clamp về 1440
      final diffFromBase = localEnd.difference(
        tz.TZDateTime(widget.timelineLocation, localStart.year, localStart.month, localStart.day, 0),
      ).inMinutes;
      final endClamped = diffFromBase >= 1440 ? 1440 : endMin;

      _dragStartMin = _clampMin(startMin);
      _dragEndMin = _clampMin(endClamped);
    } else {
      final nowLocal = tz.TZDateTime.now(widget.timelineLocation);

      // snap về đầu giờ (top of hour) thay vì theo phút hiện tại
      final start = nowLocal.hour * 60; // top of current hour
      _dragStartMin = _clampMin(start);
      _dragEndMin = _clampMin(_dragStartMin + widget.minWidthMinutes.toInt());

      // Đồng thời khởi tạo lastSyncedHour để polling không cập nhật liên tục
      _lastSyncedHour = nowLocal.hour;
    }
  }

  int _clampMin(int v) => math.max(0, math.min(1440, v));

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) {
      // Nếu user đang kéo thì skip sync từ nguồn ngoài
      if (_isUserDragging) return;

      final sUtc = widget.readSelectedStartUtc();
      final eUtc = widget.readSelectedEndUtc();

      // Nếu có selection từ controller thì đồng bộ ngay (giữ hành vi hiện tại)
      if (sUtc != null && eUtc != null) {
        final localStart = tz.TZDateTime.from(sUtc.toUtc(), widget.timelineLocation);
        final localEnd = tz.TZDateTime.from(eUtc.toUtc(), widget.timelineLocation);

        final startMin = _clampMin(localStart.hour * 60 + localStart.minute);
        final diffFromBase = localEnd.difference(
          tz.TZDateTime(widget.timelineLocation, localStart.year, localStart.month, localStart.day, 0),
        ).inMinutes;
        final endMin = diffFromBase >= 1440 ? 1440 : _clampMin(localEnd.hour * 60 + localEnd.minute);

        if (startMin != _dragStartMin || endMin != _dragEndMin) {
          setState(() {
            _dragStartMin = startMin;
            _dragEndMin = endMin;
          });
          _rangeNotifier.value = [_dragStartMin, _dragEndMin];
        }

        // reset lastSyncedHour so auto-hour-sync won't interfere
        _lastSyncedHour = -1;
        return;
      }

      // Nếu không có selection: chỉ update khi giờ thay đổi (snap hourly)
      final nowLocal = tz.TZDateTime.now(widget.timelineLocation);
      final currentHour = nowLocal.hour;

      if (currentHour != _lastSyncedHour) {
        // compute start at top of hour
        final selStartMin = _clampMin(currentHour * 60);
        final selEndMin = _clampMin(selStartMin + widget.minWidthMinutes.toInt());

        setState(() {
          _dragStartMin = selStartMin;
          _dragEndMin = selEndMin;
        });
        _rangeNotifier.value = [_dragStartMin, _dragEndMin];

        _lastSyncedHour = currentHour;
      }
      // else: giờ chưa thay đổi -> không làm gì (giữ vị trí hiện tại)
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _rangeNotifier.dispose();
    super.dispose();
  }

  double _currentHorizontalOffsetPx() {
    if (!widget.horizontalController.hasClients) return 0.0;
    return widget.horizontalController.offset;
  }

  // Gọi khi handles báo dragging (realtime)
  void _onDragging(int s, int e) {
    // Khi user đang kéo, đảm bảo cờ true (nếu chưa set)
    if (!_isUserDragging) {
      setState(() {
        _isUserDragging = true;
      });
    }

    setState(() {
      _dragStartMin = _clampMin(s);
      _dragEndMin = _clampMin(e);
    });
    _rangeNotifier.value = [_dragStartMin, _dragEndMin];
  }

  // Gọi khi user thả tay (handles báo onRangeChanged)
  void _onRangeChanged(int s, int e) {
    // base là midnight của baseDateLocalDate trong timelineLocation
    final base = tz.TZDateTime(
      widget.timelineLocation,
      widget.baseDateLocalDate.year,
      widget.baseDateLocalDate.month,
      widget.baseDateLocalDate.day,
      0,
    );
    final startLocal = base.add(Duration(minutes: s));
    final endLocal = base.add(Duration(minutes: e));
    widget.onRangeChangedUtc(startLocal.toUtc(), endLocal.toUtc());

    // Đồng bộ state tạm thời và notify
    setState(() {
      _dragStartMin = _clampMin(s);
      _dragEndMin = _clampMin(e);
      _isUserDragging = false; // bật lại sync từ nguồn ngoài
    });
    _rangeNotifier.value = [_dragStartMin, _dragEndMin];
  }

  // Gọi khi bắt đầu kéo (handles)
  void _onDragStart() {
    if (!_isUserDragging) {
      setState(() {
        _isUserDragging = true;
      });
    }
  }

  // Gọi khi kết thúc kéo (handles) — nếu onRangeChanged đã xử lý thì cờ đã false,
  // nhưng vẫn đảm bảo reset nếu cần
  void _onDragEnd() {
    if (_isUserDragging) {
      setState(() {
        _isUserDragging = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.overlayHeight <= 0) return const SizedBox.shrink();

    final List<Listenable> listenables = [];
    listenables.add(widget.horizontalController); // rebuild khi timeline ngang cuộn
    if (widget.listScrollController != null) {
      listenables.add(widget.listScrollController!); // rebuild khi list dọc cuộn
    }
    listenables.add(_rangeNotifier);
    final merged = Listenable.merge(listenables);

    return Stack(
      children: [
        // Box hiển thị vùng chọn
        Positioned(
          left: 0,
          right: 0,
          top: widget.overlayTop,
          height: widget.overlayHeight,
          child: AnimatedBuilder(
            animation: merged,
            builder: (context, _) {
              final dy = (widget.listScrollController?.hasClients ?? false)
                  ? -widget.listScrollController!.offset
                  : 0.0;

              final current = _rangeNotifier.value;
              final currentStart = current[0];
              final currentEnd = current[1];

              return Transform.translate(
                offset: Offset(0, dy),
                child: SizedBox(
                  height: widget.overlayHeight,
                  width: double.infinity,
                  child: TimeRangeSelectorBox(
                    hourWidth: widget.hourWidth,
                    horizontalPadding: widget.horizontalPadding,
                    verticalPadding: 0.0,
                    currentHorizontalOffsetPx: _currentHorizontalOffsetPx, // đọc offset từ horizontalController
                    startMin: currentStart,
                    endMin: currentEnd,
                  ),
                ),
              );
            },
          ),
        ),

        // Handles để kéo
        Positioned(
          left: 0,
          right: 0,
          top: widget.overlayTop,
          height: widget.overlayHeight,
          child: AnimatedBuilder(
            animation: merged,
            builder: (context, _) {
              return TimeRangeHandles(
                hourWidth: widget.hourWidth,
                minWidthMinutes: widget.minWidthMinutes,
                horizontalPadding: widget.horizontalPadding,
                currentHorizontalOffsetPx: _currentHorizontalOffsetPx, // đọc offset từ horizontalController
                startMin: _dragStartMin,
                endMin: _dragEndMin,
                fixedTop: widget.handleFixedTop,
                fixedHeight: widget.handleFixedHeight,
                horizontalController: widget.horizontalController, // dùng để auto-scroll khi kéo
                onDragging: _onDragging,
                onDragStart: _onDragStart,
                onDragEnd: _onDragEnd,
                onRangeChanged: _onRangeChanged,
              );
            },
          ),
        ),
      ],
    );
  }
}