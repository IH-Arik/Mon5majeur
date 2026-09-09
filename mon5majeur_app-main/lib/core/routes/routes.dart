// lib/core/routes/routes.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_strings.dart';
import '../../data/services/api_url.dart';
import '../../presentation/screens/authentication/forget_password_screen.dart';
import '../../presentation/screens/authentication/language_selection.dart';
import '../../presentation/screens/authentication/otp_screen.dart';
import '../../presentation/screens/authentication/password_updated_success_screen.dart';
import '../../presentation/screens/authentication/sign_in_screen.dart';
import '../../presentation/screens/authentication/sign_up_screen.dart';
import '../../presentation/screens/authentication/verify_code.dart';
import '../../presentation/screens/authentication/welcome_screen.dart';
import '../../presentation/screens/data/data_screen.dart';
import '../../presentation/screens/home/home.dart';
import '../../presentation/screens/mymatch/my_match_screen.dart';
import '../../presentation/screens/profile setup/profile_setup_screen.dart';
import '../../presentation/screens/profile/password_reset.dart';
import '../../presentation/screens/profile/profile_screen.dart';
import '../../presentation/screens/profile/profile_settings.dart';
import '../../presentation/screens/profile/support_screen.dart';
import '../../presentation/screens/shop/buy_token.dart';
import '../../presentation/screens/shop/shop_screen.dart';
import '../../presentation/widgets/error_screen.dart';
import 'route_observer.dart';
import 'route_path.dart';

class AppRouter {
  static final GoRouter initRoute = GoRouter(
    initialLocation: RoutePath.languageScreen.addBasePath,
    debugLogDiagnostics: true,
    routes: [
      /// Authentication
      GoRoute(
        name: RoutePath.languageScreen,
        path: RoutePath.languageScreen.addBasePath,
        builder: (context, state) => const LanguageSelectionScreen(),
      ),
      GoRoute(
        name: RoutePath.welcomeScreen,
        path: RoutePath.welcomeScreen.addBasePath,
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        name: RoutePath.signInScreen,
        path: RoutePath.signInScreen.addBasePath,
        builder: (context, state) => const SignInScreen(),
      ),

      GoRoute(
        name: RoutePath.signUp,
        path: RoutePath.signUp.addBasePath,
        builder: (context, state) => const SignUpScreen(),
      ),
      GoRoute(
        name: RoutePath.verifyRegistration,
        path: RoutePath.verifyRegistration.addBasePath,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          final email = extra['email'] as String? ?? '';
          final from = extra['from'] as String? ?? '';
          return VerifyRegistration(email: email, from: from);
        },
      ),
      GoRoute(
        name: RoutePath.forgetPassword,
        path: RoutePath.forgetPassword.addBasePath,
        builder: (context, state) => const ForgetPassword(),
      ),
      GoRoute(
        name: RoutePath.otpScreen,
        path: RoutePath.otpScreen.addBasePath,
        builder: (context, state) {
          return const OtpScreen(email: '');
        },
      ),
      GoRoute(
        name: RoutePath.errorScreen,
        path: RoutePath.errorScreen.addBasePath,
        builder: (context, state) {
          return const ErrorPage();
        },
      ),

      // GoRoute(
      //   name: RoutePath.errorScreen,
      //   path: RoutePath.errorScreen.addBasePath,
      //   parentNavigatorKey: _rootNavigatorKey,
      //   pageBuilder: (ctx, state) => CustomTransitionPage(
      //     key: state.pageKey,
      //     child: const ErrorPage(),
      //     transitionsBuilder: _fadeTransition,
      //   ),
      // ),
      GoRoute(
        name: RoutePath.success,
        path: RoutePath.success.addBasePath,
        builder: (context, state) => const SuccessScreen(),
      ),

      /// Profile Setup
      GoRoute(
        name: RoutePath.profileSetup,
        path: RoutePath.profileSetup.addBasePath,
        builder: (context, state) => const ProfileSetupScreen(),
      ),

      /// Home
      GoRoute(
        name: RoutePath.home,
        path: RoutePath.home.addBasePath,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        name: RoutePath.myLeague,
        path: RoutePath.myLeague.addBasePath,
        builder: (context, state) => const MyLeaguesScreen(),
      ),
      GoRoute(
        name: RoutePath.myMatchToday,
        path: RoutePath.myMatchToday.addBasePath,
        builder: (context, state) => const MyMatchesTodayScreen(),
      ),
      GoRoute(
        name: RoutePath.notificationsScreen,
        path: RoutePath.notificationsScreen.addBasePath,
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        name: RoutePath.createLeagueScreen,
        path: RoutePath.createLeagueScreen.addBasePath,
        builder: (context, state) => const CreateLeagueScreen(),
      ),
      GoRoute(
        name: RoutePath.createPrivateLeagueScreen,
        path: RoutePath.createPrivateLeagueScreen.addBasePath,
        builder: (context, state) =>
            const CreateLeagueFormScreen(isPublic: false),
      ),
      // GoRoute(
      //   name: RoutePath.editPrivateLeagueScreen,
      //   path: RoutePath.editPrivateLeagueScreen.addBasePath,
      //   builder: (context, state) => const EditPrivateLeagueScreen(),
      // ),
      GoRoute(
        name: RoutePath.createPrivateLeagueWaitingRoomScreen,
        path: RoutePath.createPrivateLeagueWaitingRoomScreen.addBasePath,
        builder: (context, state) {
          final leagueIdParam = state.uri.queryParameters['leagueId'];
          final isPublicParam = state.uri.queryParameters['isPublic'];

          final leagueId = leagueIdParam != null
              ? int.tryParse(leagueIdParam)
              : null;

          final isPublic =
              isPublicParam == 'true'; // Parse the isPublic parameter

          return CreatePrivateLeagueWaitingRoomScreen(
            leagueId: leagueId,
            isPublicLeague: isPublic, // Pass it to the screen
          );
        },
      ),
      GoRoute(
        name: RoutePath.createPublicLeagueScreen,
        path: RoutePath.createPublicLeagueScreen.addBasePath,
        builder: (context, state) =>
            const CreateLeagueFormScreen(isPublic: true),
      ),
      GoRoute(
        name: RoutePath.editPrivateLeagueScreen,
        path: RoutePath.editPrivateLeagueScreen.addBasePath,
        builder: (context, state) {
          final leagueIdParam = state.uri.queryParameters['leagueId'];
          final leagueId = leagueIdParam != null
              ? int.tryParse(leagueIdParam)
              : null;
          return EditLeagueScreen(leagueId: leagueId, isPublic: false);
        },
      ),
      GoRoute(
        name: RoutePath.createPublicLeagueWaitingRoomScreen,
        path: RoutePath.createPublicLeagueWaitingRoomScreen.addBasePath,
        builder: (context, state) {
          final leagueIdParam = state.uri.queryParameters['leagueId'];
          final leagueId = leagueIdParam != null
              ? int.tryParse(leagueIdParam)
              : null;
          return CreatePrivateLeagueWaitingRoomScreen(
            leagueId: leagueId,
            isPublicLeague: true,
          );
        },
      ),
      GoRoute(
        name: RoutePath.editPublicLeagueScreen,
        path: RoutePath.editPublicLeagueScreen.addBasePath,
        builder: (context, state) {
          final leagueIdParam = state.uri.queryParameters['leagueId'];
          final leagueId = leagueIdParam != null
              ? int.tryParse(leagueIdParam)
              : null;
          return EditLeagueScreen(leagueId: leagueId, isPublic: true);
        },
      ),
      GoRoute(
        name: RoutePath.chooseALeagueScreen,
        path: RoutePath.chooseALeagueScreen.addBasePath,
        builder: (context, state) => const ChooseALeagueScreen(),
      ),
      GoRoute(
        name: RoutePath.privateLeagueScreen,
        path: RoutePath.privateLeagueScreen.addBasePath,
        builder: (context, state) => const PrivateLeagueScreen(),
      ),
      GoRoute(
        name: RoutePath.publicLeagueScreen,
        path: RoutePath.publicLeagueScreen.addBasePath,
        builder: (context, state) => const ExploreLeaguesScreen(),
      ),
      GoRoute(
        name: RoutePath.publicLeagueWaitingRoomScreen,
        path: RoutePath.publicLeagueWaitingRoomScreen.addBasePath,
        builder: (context, state) {
          final leagueId = int.tryParse(
            state.uri.queryParameters['leagueId'] ?? '',
          );
          return JoinLeagueWaitingRoomScreen(
            leagueId: leagueId,
            isPublic: true,
          );
        },
      ),
      GoRoute(
        name: RoutePath.privateLeagueWaitingRoomScreen,
        path: RoutePath.privateLeagueWaitingRoomScreen.addBasePath,
        builder: (context, state) {
          final leagueId = int.tryParse(
            state.uri.queryParameters['leagueId'] ?? '',
          );
          return JoinLeagueWaitingRoomScreen(leagueId: leagueId);
        },
      ),
      GoRoute(
        name: RoutePath.selectPlayerScreenPublic,
        path: RoutePath.selectPlayerScreenPublic.addBasePath,
        builder: (context, state) => LeagueFantasyScreen(
          backRoute: RoutePath.createPublicLeagueWaitingRoomScreen.addBasePath,
          leagueTypeLabel: AppString.publicLeague.tr,
          showBudgetBonus: true,
        ),
      ),
      GoRoute(
        name: RoutePath.globalLeagueScreen,
        path: RoutePath.globalLeagueScreen.addBasePath,
        builder: (context, state) => const GlobalLeagueScreen(),
      ),

      GoRoute(
        name: RoutePath.faqScreen,
        path: RoutePath.faqScreen.addBasePath,
        builder: (context, state) => const FaqScreen(),
      ),
      GoRoute(
        name: RoutePath.aboutUsScreen,
        path: RoutePath.aboutUsScreen.addBasePath,
        builder: (context, state) => StaticContentScreen(
          screenTitle: AppString.aboutUs.tr,
          endpoint: ApiUrl.aboutUs,
        ),
      ),
      GoRoute(
        name: RoutePath.legalNoticesScreen,
        path: RoutePath.legalNoticesScreen.addBasePath,
        builder: (context, state) => StaticContentScreen(
          screenTitle: AppString.legalNotices.tr,
          endpoint: ApiUrl.legalNotices,
        ),
      ),
      GoRoute(
        name: RoutePath.privacyPolicyScreen,
        path: RoutePath.privacyPolicyScreen.addBasePath,
        builder: (context, state) => StaticContentScreen(
          screenTitle: AppString.privacyPolicy.tr,
          endpoint: ApiUrl.privacyPolicy,
        ),
      ),
      GoRoute(
        name: RoutePath.termsOfUseScreen,
        path: RoutePath.termsOfUseScreen.addBasePath,
        builder: (context, state) => StaticContentScreen(
          screenTitle: AppString.termsOfUse.tr,
          endpoint: ApiUrl.termsOfUse,
        ),
      ),
      GoRoute(
        name: RoutePath.fantasyLeagueScreenPrivate,
        path: RoutePath.fantasyLeagueScreenPrivate.addBasePath,
        builder: (context, state) => LeagueFantasyScreen(
          backRoute: RoutePath.createPrivateLeagueWaitingRoomScreen.addBasePath,
          leagueTypeLabel: AppString.privateLeague.tr,
          isPrivate: true,
          showBudgetBonus: true,
        ),
      ),
      GoRoute(
        name: RoutePath.fantasyLeagueScreenForJoin,
        path: '${RoutePath.fantasyLeagueScreenForJoin.addBasePath}/:leagueId',
        builder: (BuildContext context, GoRouterState state) {
          final leagueId = int.tryParse(
            state.pathParameters['leagueId'] ?? '0',
          );
          final matchDay = int.tryParse(
            state.uri.queryParameters['matchDay'] ?? '1',
          );
          final isPrivate =
              state.uri.queryParameters['isPrivate'] == 'true'; // ADD THIS

          return LeagueFantasyScreen(
            leagueId: leagueId,
            matchDay: matchDay,
            isPrivate: isPrivate,
            backRoute: RoutePath.home.addBasePath,
            leagueTypeLabel: isPrivate
                ? AppString.privateLeague.tr
                : AppString.publicLeague.tr,
          );
        },
      ),

      GoRoute(
        name: RoutePath.liveScoreScreen,
        path: RoutePath.liveScoreScreen.addBasePath,
        builder: (BuildContext context, GoRouterState state) {
          final matchId = state.uri.queryParameters['matchId'];
          return LiveScoreScreen(
            mode: matchId != null ? LiveScoreMode.duel : LiveScoreMode.global,
            matchId: matchId,
          );
        },
      ),

      /// Shop screen
      GoRoute(
        name: RoutePath.shopScreen,
        path: RoutePath.shopScreen.addBasePath,
        builder: (context, state) => const ShopScreen(),
      ),
      GoRoute(
        name: RoutePath.buyToken,
        path: RoutePath.buyToken.addBasePath,
        builder: (context, state) => const BuyTokenScreen(),
      ),

      /// Profile Screen
      GoRoute(
        name: RoutePath.profileScreen,
        path: RoutePath.profileScreen.addBasePath,
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        name: RoutePath.profileSettingsScreen,
        path: RoutePath.profileSettingsScreen.addBasePath,
        builder: (context, state) => const ProfileSettingsScreen(),
      ),
      GoRoute(
        name: RoutePath.supportScreen,
        path: RoutePath.supportScreen.addBasePath,
        builder: (context, state) => const SupportScreen(),
      ),
      GoRoute(
        name: RoutePath.passwordReset,
        path: RoutePath.passwordReset.addBasePath,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          final email = extra['email'] as String? ?? '';
          final otp = extra['otp'] as String? ?? '';
          return PasswordReset(email: email, otp: otp);
        },
      ),

      /// My league Screen
      GoRoute(
        name: RoutePath.myMatch,
        path: RoutePath.myMatch.addBasePath,
        builder: (context, state) => const MyMatchScreen(),
      ),

      /// data
      GoRoute(
        name: RoutePath.data,
        path: RoutePath.data.addBasePath,
        builder: (context, state) => const DataScreen(),
      ),
    ],
    observers: [routeObserver],
  );

  static GoRouter get route => initRoute;
}

// Extension for base path
extension BasePathExtension on String {
  String get addBasePath => '/$this';
}
