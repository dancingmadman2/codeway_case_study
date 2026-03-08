import 'package:get/get.dart';
import 'package:codeway_img_proc/app/routes/app_routes.dart';
import 'package:codeway_img_proc/modules/home/home_screen.dart';
import 'package:codeway_img_proc/modules/home/home_binding.dart';
import 'package:codeway_img_proc/modules/capture/capture_screen.dart';
import 'package:codeway_img_proc/modules/capture/capture_binding.dart';
import 'package:codeway_img_proc/modules/processing/processing_screen.dart';
import 'package:codeway_img_proc/modules/processing/processing_binding.dart';
import 'package:codeway_img_proc/modules/result/result_screen.dart';
import 'package:codeway_img_proc/modules/result/result_binding.dart';
import 'package:codeway_img_proc/modules/history_detail/history_detail_screen.dart';
import 'package:codeway_img_proc/modules/history_detail/history_detail_binding.dart';

abstract class AppPages {
  static final pages = <GetPage>[
    GetPage(
      name: AppRoutes.home,
      page: () => const HomeScreen(),
      binding: HomeBinding(),
    ),
    GetPage(
      name: AppRoutes.capture,
      page: () => const CaptureScreen(),
      binding: CaptureBinding(),
    ),
    GetPage(
      name: AppRoutes.processing,
      page: () => const ProcessingScreen(),
      binding: ProcessingBinding(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: AppRoutes.result,
      page: () => const ResultScreen(),
      binding: ResultBinding(),
    ),
    GetPage(
      name: AppRoutes.historyDetail,
      page: () => const HistoryDetailScreen(),
      binding: HistoryDetailBinding(),
    ),
  ];
}
