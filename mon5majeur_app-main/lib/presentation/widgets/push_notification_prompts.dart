import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/constants/api_constants.dart';
import '../../core/constants/app_strings.dart';
import '../../core/local_db/local_db.dart';
import '../../core/services/notification_service.dart';
import '../screens/tutorial/tutorial_controller.dart';

/// The one screen that explains push notifications before the OS prompt.
/// Returns `true` if the player tapped "Enable".
Future<bool> showNotificationExplainer(BuildContext context) async {
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
              AppString.pushExplainerTitle.tr,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              AppString.pushExplainerBody.tr,
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
                        AppString.pushExplainerLater.tr,
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
                        AppString.pushExplainerEnable.tr,
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

/// Shows the explainer at most once per install, only when the OS permission
/// was never asked and the player did not switch notifications off in the app.
///  * [afterValidation] true: the first team validation (the moment of value).
///  * false: the safety net, from the 2nd app launch, for players who never
///    got there (also covers existing accounts that were never asked).
/// "Enable" runs the real OS prompt, registers the token and records the
/// outcome in `recived_notifications`; "Later" leaves everything untouched.
Future<void> maybeShowNotificationExplainer(
  BuildContext context, {
  required bool afterValidation,
}) async {
  final shown =
      await SharedPrefsHelper.getBool(AppConstants.notificationExplainerShown) ??
          false;
  if (shown) return;
  if (await isNotificationsOptOut()) return;
  if (await pushPermissionState() != PushPermission.notAsked) return;

  if (!afterValidation) {
    final opens = await SharedPrefsHelper.getInt(AppConstants.appOpenCount);
    if (opens < 2) return;
    // Never on top of the coach-mark tutorial.
    if (Get.isRegistered<TutorialController>() &&
        Get.find<TutorialController>().active.value) {
      return;
    }
  }
  if (!context.mounted) return;

  await SharedPrefsHelper.setBool(AppConstants.notificationExplainerShown, true);
  if (!context.mounted) return;
  final enable = await showNotificationExplainer(context);
  if (enable) await requestNotificationPermission();
}

/// Discreet home banner for players who refused the OS permission. Opens the
/// app's iOS settings; can be hidden; never shown to players who switched
/// notifications off in the app.
class PushPermissionBanner extends StatefulWidget {
  const PushPermissionBanner({super.key});

  @override
  State<PushPermissionBanner> createState() => _PushPermissionBannerState();
}

class _PushPermissionBannerState extends State<PushPermissionBanner>
    with WidgetsBindingObserver {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Back from the iOS settings: the permission may have changed.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final dismissed = await SharedPrefsHelper.getBool(
            AppConstants.notificationBannerDismissed) ??
        false;
    final show = !dismissed &&
        !await isNotificationsOptOut() &&
        await pushPermissionState() == PushPermission.denied;
    if (mounted && show != _visible) setState(() => _visible = show);
  }

  Future<void> _dismiss() async {
    await SharedPrefsHelper.setBool(
        AppConstants.notificationBannerDismissed, true);
    if (mounted) setState(() => _visible = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Container(
        padding: EdgeInsets.only(left: 12.w, top: 4.h, bottom: 4.h, right: 2.w),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: const Color(0xFFE8632C)),
        ),
        child: Row(
          children: [
            Icon(Icons.notifications_off_outlined,
                color: const Color(0xFFE8632C), size: 18.r),
            SizedBox(width: 8.w),
            Expanded(
              child: Text(
                AppString.pushBannerText.tr,
                style: TextStyle(color: Colors.white, fontSize: 12.sp),
              ),
            ),
            TextButton(
              onPressed: openAppSettings,
              child: Text(
                AppString.pushBannerAction.tr,
                style: TextStyle(
                  color: const Color(0xFFE8632C),
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            IconButton(
              onPressed: _dismiss,
              icon: Icon(Icons.close, color: Colors.white54, size: 18.r),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}
