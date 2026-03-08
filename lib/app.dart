import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:codeway_img_proc/app/routes/app_pages.dart';
import 'package:codeway_img_proc/app/routes/app_routes.dart';
import 'package:codeway_img_proc/app/bindings/initial_binding.dart';
import 'package:codeway_img_proc/app/theme/app_theme.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Codeway Image Processor',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      initialBinding: InitialBinding(),
      initialRoute: AppRoutes.home,
      getPages: AppPages.pages,
    );
  }
}
