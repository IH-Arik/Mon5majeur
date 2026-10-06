import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/custom_assets/assets.gen.dart';
import '../../../core/language/language_controller.dart';
import '../../../core/routes/route_path.dart';
import '../../../core/routes/routes.dart';
import '../../../core/services/revenuecat_service.dart';
import '../../../data/services/session_service.dart';
import '../home/controllers/home_controller.dart';

/// First screen of every launch. A stored session goes straight to Home (or
/// Profile Setup) so the user never signs in again (QA 30/09 #8 #1); anyone
/// else continues with the usual language -> welcome -> sign-in flow.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    // The saved language must be applied here: signed-in users skip the
    // language screen that used to load it.
    if (Get.isRegistered<LanguageController>()) {
      await Get.find<LanguageController>().getLanguageType();
    }

    // Capped, so a dead connection never keeps the user on the splash: the
    // stored session is kept either way and the screens retry by themselves.
    final destination = await SessionService.resolve().timeout(
      const Duration(seconds: 12),
      onTimeout: () => SessionDestination.home,
    );
    if (!mounted) return;

    switch (destination) {
      case SessionDestination.home:
        RevenueCatService.instance.loginUser();
        if (Get.isRegistered<HomeController>()) {
          Get.find<HomeController>().fetchUserProfile();
        }
        context.go(RoutePath.home.addBasePath);
      case SessionDestination.profileSetup:
        context.go(RoutePath.profileSetup.addBasePath);
      case SessionDestination.signedOut:
        context.go(RoutePath.languageScreen.addBasePath);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Assets.images.mainLogo.image(width: 200.w, height: 200.w),
            SizedBox(height: 24.h),
            SizedBox(
              width: 24.r,
              height: 24.r,
              child: const CircularProgressIndicator(
                color: Color(0xFFFF8C42),
                strokeWidth: 2.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
