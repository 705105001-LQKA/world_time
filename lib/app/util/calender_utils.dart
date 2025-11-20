import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
import '../../domain/entities/city_time.dart';

String buildDescription({
  required DateTime startUtc,
  required DateTime endUtc,
  required List<CityTime> cities,
}) {
  final buffer = StringBuffer();

  for (final city in cities) {
    final location = tz.getLocation(city.timezone);
    final localStart = tz.TZDateTime.from(startUtc, location);
    final localEnd = tz.TZDateTime.from(endUtc, location);

    final startStr = DateFormat('h:mma E, MMM d yyyy').format(localStart);
    final endStr = DateFormat('h:mma E, MMM d yyyy').format(localEnd);

    buffer.writeln('${city.cityName}');
    buffer.writeln('$startStr');
    buffer.writeln('$endStr\n');
  }

  buffer.writeln('\nScheduled with your app');
  return buffer.toString();
}

String buildGoogleCalendarUrl({
  required String title,
  required DateTime startUtc,
  required DateTime endUtc,
  required String description,
}) {
  final startStr = DateFormat("yyyyMMdd'T'HHmmss'Z'").format(startUtc.toUtc());
  final endStr = DateFormat("yyyyMMdd'T'HHmmss'Z'").format(endUtc.toUtc());

  final encodedTitle = Uri.encodeComponent(title);
  final encodedDetails = Uri.encodeComponent(description);

  return 'https://www.google.com/calendar/render?action=TEMPLATE'
      '&text=$encodedTitle'
      '&dates=$startStr/$endStr'
      '&details=$encodedDetails';
}