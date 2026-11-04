import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
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
import 'core/services/analytics_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/revenuecat_service.dart';
import 'data/services/api_url.dart';
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

  // A release build that does not point at the production server stops here,
  // before anything else starts.
  ApiUrl.assertSafeForRelease();

  // Initialize SharedPreferences
  await SharedPreferences.getInstance();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // No usage statistics unless the app talks to the production server.
  await AnalyticsService.configureForEnvironment();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  // Counts launches (the notification explainer's safety net starts at the
  // 2nd). The token itself is synced once the session is confirmed (splash /
  // login / app resumed), never here: there may be no session yet.
  unawaited(registerAppOpen());
  // Tokens rotate: send the new one to the backend whenever it changes, and
  // show pushes that arrive while the app is open (iOS hides them otherwise).
  FirebaseMessaging.instance.onTokenRefresh
      .listen((_) => syncPushToken(reason: 'token refreshed'));
  unawaited(
    FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    ),
  );

  // ── RevenueCat ──
  // Initialise the SDK early so the paywall can fetch offerings immediately.
  // If the user already has a stored session, link them to RevenueCat.
  await RevenueCatService.instance.init();
  unawaited(RevenueCatService.instance.loginUser());

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
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en', 'US'), Locale('fr', 'FR')],

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
