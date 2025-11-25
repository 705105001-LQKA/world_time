import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

/// Single hour cell in timeline.
class TimeCellBasic extends StatelessWidget {
  final DateTime utcStart;
  final DateTime utcEnd;
  final tz.Location location;
  final DateTime utcNow;
  final DateTime? selStart;
  final DateTime? selEnd;
  final DateTime? selectedDateUtc;
  final VoidCallback onDoubleTap;

  const TimeCellBasic({
    super.key,
    required this.utcStart,
    required this.utcEnd,
    required this.location,
    required this.utcNow,
    required this.selStart,
    required this.selEnd,
    required this.selectedDateUtc,
    required this.onDoubleTap,
  });

  @override
  Widget build(BuildContext context) {
    final localStart = tz.TZDateTime.from(utcStart, location);
    final localEnd = tz.TZDateTime.from(utcEnd, location);
    final localNow = tz.TZDateTime.from(utcNow, location);

    // --- Selection normalization ---
    final int? selStartMs = selStart?.toUtc().millisecondsSinceEpoch;
    final int? selEndMs   = selEnd?.toUtc().millisecondsSinceEpoch;

    // Cell boundaries
    final int cellStartMs = utcStart.toUtc().millisecondsSinceEpoch;
    final int cellEndMs   = utcEnd.toUtc().millisecondsSinceEpoch;

    // Ensure selStart <= selEnd
    int? sMs = selStartMs;
    int? eMs = selEndMs;
    if (sMs != null && eMs != null && eMs < sMs) {
      final tmp = sMs;
      sMs = eMs;
      eMs = tmp;
    }

    final bool hasSelection = sMs != null && eMs != null;

    // Flags
    final bool isCurrent = localNow.isAfter(localStart) && localNow.isBefore(localEnd);
    final bool isStart   = hasSelection && cellStartMs == sMs;
    final bool isEnd     = hasSelection && cellEndMs   == eMs;
    final bool isTagged  = hasSelection && (cellStartMs < eMs && cellEndMs > sMs);

    final bool isMidnight = localStart.hour == 0;

    // 🎨 Màu nền theo giờ
    Color baseColor;
    Color textColor = Colors.black;

    if (isMidnight) {
      baseColor = const Color(0xFF8BA3C9);
      textColor = Colors.white;
    } else if (localStart.hour >= 1 && localStart.hour <= 5 || localStart.hour >= 22) {
      baseColor = const Color(0xFF95B3D7);
      textColor = Colors.white;
    } else if (localStart.hour >= 6 && localStart.hour <= 7 || localStart.hour >= 18 && localStart.hour <= 21) {
      baseColor = const Color(0xFFEDFBFF);
      textColor = const Color(0xFF8BA3C9);
    } else if (localStart.hour >= 8 && localStart.hour <= 17) {
      baseColor = const Color(0xFFFFFFF3);
      textColor = const Color(0xFF8BA3C9);
    } else {
      baseColor = Colors.grey.shade300;
    }

    // 🔵 Highlight giờ hiện tại
    if (isCurrent) {
      baseColor = const Color(0xFF7289AA);
      textColor = Colors.white;
    }

    // ✅ Làm mờ nếu có selection và ô nằm ngoài khoảng
    final bool isOutsideSelection = hasSelection && !(isStart || isEnd || isTagged);

    final Color bgColor = isOutsideSelection
        ? baseColor.withValues(alpha: 0.5)
        : baseColor;

    final Color finalTextColor = isOutsideSelection
        ? textColor.withValues(alpha: 0.5)
        : textColor;

    final Color borderColor = isOutsideSelection
        ? const Color(0xFF8BA3C9).withValues(alpha: 0.5)
        : const Color(0xFF8BA3C9);

    // 🕒 Nội dung hiển thị
    Widget content;
    if (isMidnight) {
      final tz.TZDateTime displayDateTz = (selectedDateUtc != null)
          ? tz.TZDateTime.from(selectedDateUtc!, location)
          : localStart;
      content = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              DateFormat.E().format(displayDateTz).toUpperCase(),
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Flexible(
            child: Text(
              DateFormat('dd MMM').format(displayDateTz),
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    } else {
      final hour = localStart.hour;
      final hourNum = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
      final suffix = hour < 12 ? 'am' : 'pm';

      content = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text('$hourNum',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: finalTextColor)),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(suffix,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: finalTextColor)),
          ),
        ],
      );
    }

    // 👇 Bọc GestureDetector để lắng nghe double-tap
    return GestureDetector(
      onDoubleTap: onDoubleTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        width: 50,
        height: 48,
        alignment: Alignment.center,
        margin: EdgeInsets.only(left: isMidnight ? 1 : 0),
        decoration: BoxDecoration(
          color: bgColor,
          border: Border(
            top: BorderSide(color: borderColor, width: 1.5),
            bottom: BorderSide(color: borderColor, width: 1.5),
            left: isMidnight
                ? BorderSide(color: borderColor, width: 1.5)
                : BorderSide.none,
            right: localStart.hour == 23
                ? BorderSide(color: borderColor, width: 1.5)
                : BorderSide.none,
          ),
          borderRadius: isMidnight
              ? const BorderRadius.only(
            topLeft: Radius.circular(6),
            bottomLeft: Radius.circular(6),
          )
              : localStart.hour == 23
              ? const BorderRadius.only(
            topRight: Radius.circular(6),
            bottomRight: Radius.circular(6),
          )
              : BorderRadius.zero,
          boxShadow: isCurrent
              ? [BoxShadow(color: Colors.black26, blurRadius: 4, offset: const Offset(0, 1))]
              : null,
        ),
        child: content,
      ),
    );
  }
}