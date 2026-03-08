import 'package:get/get.dart';
import 'package:codeway_img_proc/modules/capture/capture_controller.dart';

class CaptureBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => CaptureController());
  }
}
