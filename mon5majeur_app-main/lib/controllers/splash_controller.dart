// Create a new file: lib/presentation/screens/splash/splash_controller.dart
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/local_db/local_db.dart';
import '../../../core/routes/route_path.dart';
import '../../../core/routes/routes.dart';
import '../presentation/screens/home/controllers/home_controller.dart';

class SplashController extends GetxController {
  @override
  void onInit() {
    super.onInit();
    checkAuthStatus();
  }

  Future<void> checkAuthStatus() async {
    await Future.delayed(const Duration(seconds: 2)); // Splash delay

    // Check if user is logged in
    final token = await SharedPrefsHelper.getString(AppConstants.token);

    if (token.isNotEmpty) {
      // User is logged in, check profile status
      final homeController = Get.find<HomeController>();
      await homeController.fetchUserProfile();

      final hasProfile = await homeController.hasCompletedProfile();

      if (hasProfile && homeController.userProfile.value != null) {
        // Profile exists, go to home
        Get.context?.go(RoutePath.home.addBasePath);
      } else {
        // No profile, go to profile setup
        Get.context?.go(RoutePath.profileSetup.addBasePath);
      }
    } else {
      // User not logged in, go to language selection
      Get.context?.go(RoutePath.languageScreen.addBasePath);
    }
  }
}
