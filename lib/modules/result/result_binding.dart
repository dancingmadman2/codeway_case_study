import 'package:get/get.dart';
import 'package:codeway_img_proc/modules/result/result_controller.dart';

class ResultBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => ResultController());
  }
}
