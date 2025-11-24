import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:world_time/presentation/pages/landing_page/landing_page.dart';

// import 'binding/time_binding.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'World Time',
      // initialBinding: TimeBinding(),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
      ),
      home: const LandingPage(),
    );
  }
}