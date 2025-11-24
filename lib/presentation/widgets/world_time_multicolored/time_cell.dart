import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

/// Single hour cell in timeline.
class TimeCell extends StatelessWidget {
  final DateTime utcStart;
  final DateTime utcEnd;
  final tz.Location location;
  final DateTime utcNow;
  final DateTime? selStart;
  final DateTime? selEnd;
  final DateTime? selectedDateUtc;
  final VoidCallback onDoubleTap;

  const TimeCell({
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

    // Normalize selection
    int? msSelStart = selStart?.toUtc().millisecondsSinceEpoch;
    int? msSelEnd = selEnd?.toUtc().millisecondsSinceEpoch;
    final msUtcStart = utcStart.toUtc().millisecondsSinceEpoch;
    final msUtcEnd = utcEnd.toUtc().millisecondsSinceEpoch;

    int? msS = msSelStart;
    int? msE = msSelEnd;
    if (msS != null && msE != null && msE < msS) {
      final tmp = msS;
      msS = msE;
      msE = tmp;
    }

    final isCurrent = localNow.isAfter(localStart) && localNow.isBefore(localEnd);
    final isStart = msSelStart != null && msSelStart == msUtcStart;
    final isEnd = msSelEnd != null && msSelEnd == msUtcEnd;
    // ✅ sửa điều kiện: highlight toàn bộ range
    final isTagged = msS != null && msE != null && msUtcStart >= msS && msUtcStart < msE;
    final isMidnight = localStart.hour == 0;

    // default colors/emojis
    Color? bgColor;
    Gradient? gradient;
    Color textColor = Colors.black;
    String emoji = '❓';

    if (isMidnight) {
      bgColor = Colors.black87;
      textColor = Colors.white;
      emoji = '🌙';
    } else if (localStart.hour >= 1 && localStart.hour <= 5) {
      bgColor = Colors.grey.shade700;
      textColor = Colors.white;
      emoji = '🌙';
    } else if (localStart.hour >= 6 && localStart.hour <= 11) {
      bgColor = Colors.yellow.shade200;
      emoji = '🌅';
    } else if (localStart.hour >= 12 && localStart.hour <= 17) {
      bgColor = Colors.orange.shade200;
      emoji = '🌇';
    } else {
      bgColor = Colors.purple.shade200;
      emoji = '🌃';
    }

    if (isCurrent && (isStart || isEnd || isTagged)) {
      gradient = LinearGradient(
        colors: [Colors.blueAccent, Colors.green.shade700],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
      textColor = Colors.white;
      emoji = '🕒';
    } else if (isCurrent) {
      bgColor = Colors.blueAccent;
      textColor = Colors.white;
      emoji = '🕒';
    } else if (isStart || isEnd) {
      bgColor = Colors.green.shade700;
      textColor = Colors.white;
    } else if (isTagged) {
      bgColor = Colors.green.shade300;
    }

    Widget content;
    if (isMidnight) {
      final tz.TZDateTime displayDateTz = (selectedDateUtc != null)
          ? tz.TZDateTime.from(selectedDateUtc!, location)
          : localStart;
      content = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(DateFormat.E().format(displayDateTz).toUpperCase(),
              style: const TextStyle(color: Colors.white, fontSize: 10)),
          Text(DateFormat('dd MMM').format(displayDateTz),
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
          if (selectedDateUtc == null && isCurrent) const SizedBox(height: 2),
          if (selectedDateUtc == null && isCurrent)
            const Text('00:00  🕒', style: TextStyle(color: Colors.white, fontSize: 12)),
        ],
      );
    } else {
      content = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(DateFormat('HH:mm').format(localStart),
              style: TextStyle(fontSize: 12, color: textColor)),
          Text(emoji, style: TextStyle(fontSize: 14, color: textColor)),
        ],
      );
    }

    return GestureDetector(
      onDoubleTap: onDoubleTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        width: 60,
        height: 50,
        alignment: Alignment.center,
        margin: const EdgeInsets.symmetric(horizontal: 1),
        decoration: BoxDecoration(
          color: gradient == null ? bgColor : null,
          gradient: gradient,
          borderRadius: BorderRadius.circular(4),
          boxShadow: isCurrent
              ? [BoxShadow(color: Colors.black26, blurRadius: 4, offset: const Offset(0, 1))]
              : null,
        ),
        child: content,
      ),
    );
  }
}