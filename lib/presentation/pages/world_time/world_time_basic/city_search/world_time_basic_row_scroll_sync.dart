import 'package:flutter/widgets.dart';

/// Quản lý ScrollController cho từng hàng timeline và đồng bộ offset giữa chúng.
/// - attach: tạo/hoặc trả về controller cho id và đăng listener onScrollCallback.
/// - detach: huỷ controller khi không dùng nữa.
/// - onRowScroll: gọi khi một controller có sự thay đổi offset (thường từ callback listener).
/// - syncIfNeeded: khi controller mới attach, đồng bộ vị trí theo lastRatio.
class WorldTimeBasicRowScrollSync {
  final Map<String, ScrollController> _controllers = {};
  double lastRatio = 0.0;
  bool _isSyncing = false;

  /// Trả về ScrollController đã attach cho id. Nếu chưa có thì tạo mới và add listener.
  ScrollController attach(String id, void Function(String) onScrollCallback) {
    if (_controllers.containsKey(id)) return _controllers[id]!;
    final c = ScrollController();
    c.addListener(() => onScrollCallback(id));
    _controllers[id] = c;
    return c;
  }

  /// Xoá và dispose controller cho id nếu có.
  void detach(String id) {
    final c = _controllers.remove(id);
    if (c != null) {
      try {
        c.dispose();
      } catch (_) {}
    }
  }

  /// Trả về list các id đang attach (dùng để trim nếu cần).
  List<String> keys() => _controllers.keys.toList();

  /// Gọi khi một hàng đang scroll; sẽ tính tỉ lệ và jumpTo cho các controller khác.
  void onRowScroll(String sourceId) {
    final source = _controllers[sourceId];
    if (_isSyncing) return;
    if (source == null || !source.hasClients) return;

    _isSyncing = true;
    final offset = source.offset;
    final sourceMax = source.position.maxScrollExtent;
    final ratio = sourceMax > 0 ? (offset / sourceMax) : 0.0;
    lastRatio = ratio;

    for (final entry in _controllers.entries) {
      final id = entry.key;
      final c = entry.value;
      if (id == sourceId) continue;
      if (!c.hasClients) continue;
      try {
        final targetMax = c.position.maxScrollExtent;
        final target = (targetMax * ratio).clamp(0.0, targetMax);
        c.jumpTo(target);
      } catch (_) {
        // ignore possible exceptions from positions not ready
      }
    }
    _isSyncing = false;
  }

  /// Khi một controller mới attach, gọi syncIfNeeded để set vị trí ban đầu theo lastRatio.
  void syncIfNeeded(String id) {
    final c = _controllers[id];
    if (c == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!c.hasClients) return;
      try {
        final targetMax = c.position.maxScrollExtent;
        final target = (targetMax * lastRatio).clamp(0.0, targetMax);
        c.jumpTo(target);
      } catch (_) {}
    });
  }

  /// Lấy offset ngang hiện tại (px) từ một controller bất kỳ.
  /// Nếu chưa có controller nào attach thì trả về 0.
  double currentOffsetPx() {
    if (_controllers.isEmpty) return 0.0;
    // lấy controller đầu tiên làm chuẩn
    final first = _controllers.values.first;
    if (!first.hasClients) return 0.0;
    return first.offset;
  }
}