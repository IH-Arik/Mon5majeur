import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:camera/camera.dart';
import 'package:mon5majeur_app/core/dependency_injection/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/constants/app_colors.dart';
import 'core/constants/app_strings.dart';
import 'core/routes/routes.dart';
import 'core/language/language_controller.dart';
import 'core/dependency_injection/getx_injection.dart';

/// =======================================
/// Main Entry Point of the Application
/// =======================================

late final List<CameraDescription> cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize SharedPreferences
  await SharedPreferences.getInstance();

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  await initDependencies();
  // Initialize GetX dependencies
  initGetx();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      // designSize: const Size(390, 844),
      designSize: const Size(402, 874),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (_, _) {
        return GetMaterialApp.router(
          debugShowCheckedModeBanner: false,
          title: AppString.appTitle,

          /// ================= TRANSLATIONS =================
          translations: Language(),
          locale: const Locale('en', 'US'), // Default locale
          fallbackLocale: const Locale('en', 'US'),

          /// ================= THEME =================
          theme: ThemeData(
            scaffoldBackgroundColor: AppColors.backgroundColor,
            useMaterial3: true,
          ),

          /// ================= Routing =================
          routeInformationParser: AppRouter.route.routeInformationParser,
          routerDelegate: AppRouter.route.routerDelegate,
          routeInformationProvider: AppRouter.route.routeInformationProvider,
        );
      },
    );
  }
}
