import 'package:get/get.dart';
import '../controllers/time_controller.dart';

class TimeBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(TimeController(), permanent: true);
  }
}