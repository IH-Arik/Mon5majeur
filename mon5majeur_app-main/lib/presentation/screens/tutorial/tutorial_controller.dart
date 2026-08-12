import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import '../../../controllers/global_league_controller.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/local_db/local_db.dart';
import '../../../core/services/analytics_service.dart';
import '../../../data/services/api_service.dart';
import '../../../data/services/api_url.dart';

/// Onboarding coach-mark tutorial state (spec Part 3).
///
/// Step numbering follows the spec's "Full sequence" table (0-5). `step`
/// is only meaningful while `active` is true; -1 means "never started".
/// Persisted so the tutorial resumes at the step reached if the app is
/// closed mid-flow, and never re-triggers once `done`.
class TutorialController extends GetxController {
  final RxBool done = false.obs;
  final RxBool active = false.obs;
  final RxInt step = (-1).obs;
  bool _loaded = false;

  // Shared GlobalKeys for the four spotlighted widgets (steps 0-3). Kept
  // here rather than local to each screen so the same key instance is
  // available both where the Showcase wraps the widget and where
  // startShowCase([key]) is triggered.
  final GlobalKey homeJoinKey = GlobalKey(debugLabel: 'tutorial_home_join');
  final GlobalKey jerseySlotKey = GlobalKey(debugLabel: 'tutorial_jersey_slot');
  final GlobalKey playerRowKey = GlobalKey(debugLabel: 'tutorial_player_row');
  final GlobalKey confirmKey = GlobalKey(debugLabel: 'tutorial_confirm');

  /// Whether the Home screen should currently trigger the step-0 spotlight.
  /// Recomputed by [checkHomeReadiness] once the "any NBA game tonight"
  /// check resolves — holds the tutorial at Home (spec edge case: "No NBA
  /// games tonight at first launch") until a match_day with a game exists.
  final RxBool showHomeSpotlight = false.obs;

  // Whether tonight's NBA slate is non-empty. Deliberately independent of
  // any specific user's own leagues/matches: a brand-new account has no
  // LeagueMatch yet (hasn't joined anything), so gating on the user's own
  // "my matches today" list would permanently block step 0 for exactly the
  // users this step targets. null = not checked yet.
  bool? _hasGamesTonight;
  bool _gamesCheckInFlight = false;

  @override
  void onInit() {
    super.onInit();
    _load();
  }

  Future<void> _load() async {
    final isDone = await SharedPrefsHelper.getBool(AppConstants.tutorialDone) ?? false;
    done.value = isDone;
    if (!isDone) {
      final savedStep = await SharedPrefsHelper.getInt(AppConstants.tutorialStep);
      step.value = savedStep;
      active.value = savedStep >= 0;
    }
    _loaded = true;
  }

  /// True once first-launch persisted state has loaded and the tutorial
  /// has neither been completed nor started yet — the only state from
  /// which `start()` is allowed to fire.
  bool get eligibleToStart => _loaded && !done.value && step.value < 0;

  Future<void> start() async {
    if (!eligibleToStart) return;
    await _persistStep(0);
  }

  Future<void> advanceTo(int nextStep) async {
    if (done.value) return;
    await _persistStep(nextStep);
  }

  /// Called once from Home. Kicks off the "any NBA game tonight" check
  /// (cached after the first call) and (re)applies its result. Starts the
  /// tutorial the first time a match_day with at least one game is seen;
  /// holds it, rather than starting, on a gameless night.
  void checkHomeReadiness() {
    if (done.value) {
      showHomeSpotlight.value = false;
      return;
    }
    if (_hasGamesTonight != null) {
      _applyHomeReadiness();
      return;
    }
    if (_gamesCheckInFlight) return;
    _gamesCheckInFlight = true;
    _fetchGamesTonight();
  }

  Future<void> _fetchGamesTonight() async {
    try {
      final response = await ApiClient().get(
        url: '${ApiUrl.baseUrl}${ApiUrl.gamesToday}',
      );
      _hasGamesTonight =
          response.statusCode == 200 && (response.body as List).isNotEmpty;
    } catch (_) {
      _hasGamesTonight = false;
    }
    _gamesCheckInFlight = false;
    _applyHomeReadiness();
  }

  void _applyHomeReadiness() {
    if (done.value || _hasGamesTonight != true) {
      showHomeSpotlight.value = false;
      return;
    }
    if (eligibleToStart) {
      start();
    }
    // Step 0 spotlights the Home "Join now" button, which the app simply
    // doesn't render once the user has already joined the Global League
    // (e.g. an existing account that joined before this tutorial existed,
    // or a resumed session). Spotlighting a non-existent target leaves the
    // barrier up with nothing tappable, so skip straight to step 1 instead
    // of getting stuck — the user still reaches the lineup screen normally
    // by tapping the card, and step 1 picks up from there.
    final alreadyJoined =
        Get.isRegistered<GlobalLeagueController>() &&
        Get.find<GlobalLeagueController>().hasJoined.value;
    if (alreadyJoined && step.value == 0) {
      advanceTo(1);
    }
    showHomeSpotlight.value = active.value && step.value == 0 && !alreadyJoined;
  }

  Future<void> _persistStep(int s) async {
    step.value = s;
    active.value = true;
    await SharedPrefsHelper.setInt(AppConstants.tutorialStep, s);
  }

  /// Skip is available on steps 0-4 only (step 5 exits via its own two
  /// buttons instead) — enforced by callers only rendering Skip there.
  Future<void> skip() async {
    if (done.value) return;
    await AnalyticsService.logEvent('tutorial_skipped_at_step', {
      'step': step.value,
    });
    await _finish();
  }

  /// Step 5's exit: either button finishes the tutorial. Logged
  /// separately from skip so drop-off and completion are distinguishable.
  Future<void> finishFromStep5(String buttonTapped) async {
    await AnalyticsService.logEvent('tutorial_step5_choice', {
      'button': buttonTapped,
    });
    await _finish();
  }

  /// Manual replay (e.g. a "Replay tutorial" drawer entry). Bypasses both
  /// the "already done" and "no games tonight" gates that guard the
  /// passive first-launch trigger — this is an explicit, deliberate
  /// request. Still skips step 0 if the account already joined the Global
  /// League (same reasoning as [_applyHomeReadiness]): that step's target
  /// doesn't exist for them, so forcing it would show a dead spotlight
  /// with nothing to tap.
  Future<void> restart() async {
    done.value = false;
    await SharedPrefsHelper.setBool(AppConstants.tutorialDone, false);
    await _persistStep(0);

    final alreadyJoined =
        Get.isRegistered<GlobalLeagueController>() &&
        Get.find<GlobalLeagueController>().hasJoined.value;
    if (alreadyJoined) {
      await advanceTo(1);
    }

    // Force a change even if showHomeSpotlight was already at this value,
    // so the Home listener that starts the actual ShowCaseWidget fires.
    showHomeSpotlight.value = false;
    showHomeSpotlight.value = !alreadyJoined;
  }

  Future<void> _finish() async {
    done.value = true;
    active.value = false;
    step.value = -1;
    await SharedPrefsHelper.setBool(AppConstants.tutorialDone, true);
    await SharedPrefsHelper.remove(AppConstants.tutorialStep);
  }
}
