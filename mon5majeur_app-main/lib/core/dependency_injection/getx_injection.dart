import 'package:get/get.dart';
import '../../controllers/global_league_controller.dart';
import '../../controllers/my_leagues_controller.dart';
import '../../controllers/my_match_today_controller.dart';
import '../../controllers/notifications_controller.dart';
import '../../presentation/screens/home/controllers/home_controller.dart';
import '../../presentation/screens/home/controllers/create_league_controller.dart';
import '../language/language_controller.dart';

void initGetx() {
  // ================== Global Controller ==================

  // ================== Language Controller (Register first) ==================
  Get.lazyPut(() => LanguageController(), fenix: true);

  // ================== User Session Service ==================
  // Get.put(UserSessionService(), permanent: true);

  // ================== Auth Controller ==================
  // Get.lazyPut(() => AuthController(), fenix: true);
  // Get.lazyPut(() => BottomNavController(), fenix: true);
  // Get.lazyPut(() => TransactionHistoryController(), fenix: true);
  Get.lazyPut(() => HomeController(), fenix: true);
  Get.lazyPut(
    () => CreateLeagueController(isPublic: false),
    fenix: true,
    tag: 'private',
  );
  Get.lazyPut(
    () => CreateLeagueController(isPublic: true),
    fenix: true,
    tag: 'public',
  );
  Get.lazyPut(() => MyLeaguesController(), fenix: true);
  Get.lazyPut(() => MyMatchTodayController(), fenix: true);
  Get.lazyPut(() => GlobalLeagueController(), fenix: true);
  Get.lazyPut(() => NotificationsController(), fenix: true);

  // Get.lazyPut(() => ScannedItemsController(), fenix: true);

  // ================================= Worker ======================================

  // ================================= Client ======================================
}
