import 'package:get/get.dart';
import 'package:codeway_img_proc/modules/history_detail/history_detail_controller.dart';

class HistoryDetailBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => HistoryDetailController());
  }
}
