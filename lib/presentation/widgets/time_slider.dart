// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
//
// class TimeSlider extends StatelessWidget {
//   final RxInt selectedHour;
//
//   const TimeSlider({super.key, required this.selectedHour});
//
//   @override
//   Widget build(BuildContext context) {
//     return Obx(() {
//       return Column(
//         children: [
//           Slider(
//             value: selectedHour.value.toDouble(),
//             min: 0,
//             max: 23,
//             divisions: 23,
//             label: '${selectedHour.value}:00',
//             onChanged: (value) => selectedHour.value = value.toInt(),
//           ),
//           Text('Selected Hour: ${selectedHour.value}:00'),
//         ],
//       );
//     });
//   }
// }