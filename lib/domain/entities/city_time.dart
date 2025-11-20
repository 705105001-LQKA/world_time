import 'package:equatable/equatable.dart';

class CityTime extends Equatable {
  final String cityName;
  final String timezone; // e.g. "Asia/Ho_Chi_Minh"
  final DateTime time;

  const CityTime({
    required this.cityName,
    required this.timezone,
    required this.time,
  });

  @override
  List<Object?> get props => [cityName, timezone, time];
}