library;

import 'package:flutter/material.dart';

/// Ngưỡng coi là “sát cuối ngày”
const int kAlmostEndMinutes = 1430; // 23:50

/// Làm tròn phút về mốc giờ gần nhất (>=30 phút → sang giờ kế)
int snapToHour(int minutes) {
  final hr = (minutes / 60.0).round();
  return (hr * 60).clamp(0, 1440);
}

/// Chuẩn hóa end để không wrap 1440 → 0.
/// - Nếu end >= 1430 → ép 1440.
/// - Nếu end == 0 nhưng start > 0 → coi là 24:00 → 1440.
/// - Clamp về [0, 1440].
int normalizeEnd(int start, int end, {int? previousEnd}) {
  if (end >= kAlmostEndMinutes) return 1440;
  if (end == 0 && start > 0) return 1440;
  if (previousEnd != null && end == 0 && previousEnd >= kAlmostEndMinutes) return 1440;
  return end.clamp(0, 1440);
}

/// Ép cuối ngày khi emit để phía ngoài không nhận 0 lúc kết thúc.
int normalizeEndForEmit(int end) {
  return end >= kAlmostEndMinutes ? 1440 : end.clamp(0, 1440);
}

/// Tính tọa độ content theo phút + padding
double minutesToContentX({
  required int minutes,
  required double hourWidth,
  required double horizontalPadding,
}) {
  return (minutes / 60.0) * hourWidth + horizontalPadding;
}

/// Tính phần hiển thị trong viewport (left, width) từ rawLeft/rawRight.
/// Tránh width=0 ở mép phải bằng epsilon nhỏ.
@immutable
class VisibleBox {
  final double left;
  final double width;
  const VisibleBox(this.left, this.width);
}

VisibleBox visibleSlice({
  required double rawLeft,
  required double rawRight,
  required double viewportWidth,
  double epsilon = 0.5,
}) {
  // Nếu khoảng chọn không có chiều rộng thực → ẩn
  if (rawRight <= rawLeft) return const VisibleBox(0.0, 0.0);

  double left = rawLeft;
  double right = rawRight;

  // Cắt theo viewport
  if (left < 0.0) left = 0.0;
  if (right > viewportWidth) right = viewportWidth;

  // Nếu toàn bộ nằm ngoài bên phải → vẽ vệt mỏng ở mép phải
  if (rawLeft >= viewportWidth) {
    left = viewportWidth - epsilon;
    right = viewportWidth;
  }

  // Đảm bảo hợp lệ
  if (right < left) right = left;

  double width = right - left;

  // Nếu có khoảng thực nhưng phần hiển thị co về 0 do cắt → giữ epsilon
  if (width == 0.0 && rawRight > rawLeft) {
    width = epsilon;
  }

  return VisibleBox(left, width);
}