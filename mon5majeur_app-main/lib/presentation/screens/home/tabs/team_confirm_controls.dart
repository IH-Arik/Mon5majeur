import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/local_db/local_db.dart';
import '../../../../core/services/notification_service.dart';

/// The states of the team-builder confirm flow.
///
/// [locked] = the night's first tip-off has passed (`lockInSeconds <= 0`)
/// and the team was never confirmed in time — edits are no longer possible.
/// A team that *was* confirmed before lock stays in [confirmed] even after
/// lock passes (nothing more to represent — it's the final, locked-in team).
enum LineupState { incomplete, ready, confirmed, locked }

/// True once `lockInSeconds` says the night's first tip-off has passed.
/// `null` means no game is scheduled for this day (never locks).
bool isLineupLocked(int? lockInSeconds) =>
    lockInSeconds != null && lockInSeconds <= 0;

LineupState lineupStateFor({
  required int selectedCount,
  required bool isConfirmed,
  int? lockInSeconds,
}) {
  if (isConfirmed) return LineupState.confirmed;
  if (isLineupLocked(lockInSeconds)) return LineupState.locked;
  if (selectedCount < 5) return LineupState.incomplete;
  return LineupState.ready;
}

/// "3h 42m Left" from real backend seconds-until-lock. Falls back to
/// [AppString.fourHoursLeft] while lock data hasn't loaded yet, since there's
/// nothing truthful to show in that brief window.
String formatTimeLeft(int? lockInSeconds) {
  if (lockInSeconds == null) return AppString.fourHoursLeft.tr;
  if (lockInSeconds <= 0) return AppString.lineupLocked;
  final duration = Duration(seconds: lockInSeconds);
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  return '${hours}h ${minutes}m Left';
}

/// Green ("Team complete") / red ("You need X more players") status banner.
class TeamStatusBanner extends StatelessWidget {
  final LineupState state;
  final int remainingPlayers;

  const TeamStatusBanner({
    super.key,
    required this.state,
    required this.remainingPlayers,
  });

  @override
  Widget build(BuildContext context) {
    final bool complete =
        state == LineupState.ready || state == LineupState.confirmed;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: SizedBox(
        height: 27.h,
        child: Stack(
          children: [
            Positioned(
              left: complete ? 4.w : 0,
              top: 0,
              right: complete ? 7.w : 11.w,
              child: Container(
                height: 27.h,
                decoration: ShapeDecoration(
                  color: complete
                      ? const Color(0xFF5DD344)
                      : const Color(0xFFFF4C4C),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                ),
              ),
            ),
            Positioned(
              left: complete ? 6.w : 2.w,
              top: 0,
              right: complete ? 5.w : 9.w,
              child: Container(
                height: 27.h,
                decoration: ShapeDecoration(
                  color: complete
                      ? const Color(0xFF536150)
                      : const Color(0xFF311F1F),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              top: 3.h,
              child: Align(
                alignment: Alignment.center,
                child: Text(
                  state == LineupState.locked
                      ? AppString.lineupLocked
                      : complete
                          ? AppString.teamComplete
                          : AppString.youNeedMorePlayers(remainingPlayers),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: complete
                        ? const Color(0xFF5DD243)
                        : const Color(0xFFF84A4A),
                    fontSize: 10.sp,
                    fontFamily: 'Roboto',
                    fontWeight: FontWeight.w400,
                    height: 2.20,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The confirm CTA. Grey/disabled when incomplete, orange/enabled when ready,
/// green/disabled once confirmed. Shows a spinner while [isSubmitting].
class TeamConfirmButton extends StatelessWidget {
  final LineupState state;
  final bool isSubmitting;
  final VoidCallback onConfirm;

  const TeamConfirmButton({
    super.key,
    required this.state,
    required this.isSubmitting,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final bool confirmed = state == LineupState.confirmed;
    final bool enabled = state == LineupState.ready && !isSubmitting;

    List<Color> gradientColors;
    if (isSubmitting) {
      gradientColors = const [Color(0xFF666666), Color(0xFF888888)];
    } else if (state == LineupState.incomplete ||
        state == LineupState.locked) {
      gradientColors = const [Color(0xFF666666), Color(0xFF888888)];
    } else if (confirmed) {
      gradientColors = const [Color(0xFF2E9E2E), Color(0xFF43D043)];
    } else {
      gradientColors = const [Color(0xFFE8632C), Color(0xFFFF8A50)];
    }

    return GestureDetector(
      onTap: enabled ? onConfirm : null,
      child: Container(
        width: 235.w,
        padding: EdgeInsets.all(10.w),
        decoration: ShapeDecoration(
          gradient: LinearGradient(
            begin: const Alignment(0.00, 0.50),
            end: const Alignment(1.00, 0.50),
            colors: gradientColors,
          ),
          shape: RoundedRectangleBorder(
            side: BorderSide(width: 1.r, color: const Color(0xFF2C2C2C)),
            borderRadius: BorderRadius.circular(10.r),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (isSubmitting)
              SizedBox(
                width: 16.w,
                height: 16.h,
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            else
              Text(
                confirmed ? AppString.teamConfirmed : AppString.confirmMyTeam,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14.sp,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                  height: 1.57,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Centered "Team validated!" success popup shown after a successful confirm.
Future<void> showTeamValidatedDialog(BuildContext context) {
  return showDialog(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.r),
        side: const BorderSide(color: Color(0xFF2C2C2C)),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 24.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48.w,
              height: 48.h,
              decoration: const BoxDecoration(
                color: Color(0xFF43D043),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check, color: Colors.white, size: 30.r),
            ),
            SizedBox(height: 16.h),
            Text(
              AppString.teamValidated,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 20.h),
            GestureDetector(
              onTap: () => Navigator.of(ctx).pop(),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 12.h),
                decoration: ShapeDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2E9E2E), Color(0xFF43D043)],
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                ),
                child: Text(
                  'OK',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// "Enable notifications?" opt-in pop-up. Returns `true` if the user tapped
/// "Enable", `false` if they tapped "Not now" or dismissed.
Future<bool> showEnableNotificationsDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.r),
        side: const BorderSide(color: Color(0xFF2C2C2C)),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 24.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48.w,
              height: 48.h,
              decoration: const BoxDecoration(
                color: Color(0xFFE8632C),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.notifications_active,
                color: Colors.white,
                size: 28.r,
              ),
            ),
            SizedBox(height: 16.h),
            Text(
              AppString.enableNotificationsTitle.tr,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              AppString.enableNotificationsBody.tr,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: const Color(0xFFB0B0B0),
                fontSize: 12.sp,
                fontWeight: FontWeight.w400,
              ),
            ),
            SizedBox(height: 20.h),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.of(ctx).pop(false),
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      decoration: ShapeDecoration(
                        color: const Color(0xFF2C2C2C),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                      ),
                      child: Text(
                        AppString.notNow.tr,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.of(ctx).pop(true),
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      decoration: ShapeDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFE8632C), Color(0xFFFF8A50)],
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                      ),
                      child: Text(
                        AppString.enableAction.tr,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  return result ?? false;
}

/// Shows the notification opt-in pop-up once — after the user's first team
/// validation. Records that it has been handled so it never shows again,
/// regardless of the user's choice. If the user taps "Enable", triggers the
/// OS notification-permission prompt.
Future<void> maybeShowNotificationPromptAfterFirstValidation(
  BuildContext context,
) async {
  final handled =
      await SharedPrefsHelper.getBool(AppConstants.notificationPromptHandled) ??
          false;
  if (handled) return;
  await SharedPrefsHelper.setBool(AppConstants.notificationPromptHandled, true);
  if (!context.mounted) return;
  final enable = await showEnableNotificationsDialog(context);
  if (enable) {
    await requestNotificationPermission();
  }
}
