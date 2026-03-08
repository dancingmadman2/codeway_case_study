import 'package:get/get.dart';
import 'package:codeway_img_proc/modules/processing/processing_controller.dart';

class ProcessingBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => ProcessingController());
  }
}
