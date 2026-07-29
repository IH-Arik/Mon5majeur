import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:camera/camera.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:mon5majeur_app/core/dependency_injection/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/constants/app_colors.dart';
import 'core/constants/app_strings.dart';
import 'core/routes/routes.dart';
import 'core/language/language_controller.dart';
import 'core/dependency_injection/getx_injection.dart';
import 'core/services/notification_service.dart';
import 'firebase_options.dart';

/// =======================================
/// Main Entry Point of the Application
/// =======================================

late final List<CameraDescription> cameras;

/// Must be a top-level function — FCM invokes this in a separate isolate
/// when a data/notification message arrives while the app is terminated
/// or backgrounded. Keep it side-effect-free beyond what Firebase itself needs.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize SharedPreferences
  await SharedPreferences.getInstance();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  // Best-effort: registers the device's FCM token with the backend if the
  // user already granted notification permission in a previous session.
  // The actual permission *request* still only happens from the post-team-
  // validation prompt (team_confirm_controls.dart) — this just keeps the
  // token in sync on every app start once permission already exists.
  unawaited(syncFcmTokenIfPermissionGranted());

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
