import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../controllers/global_league_controller.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/routes/route_path.dart';
import '../../../../core/routes/routes.dart';
import '../../tutorial/tutorial_controller.dart';

class HomeDrawer extends StatelessWidget {
  const HomeDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFFD97441),
      child: SafeArea(
        child: Column(
          children: [
            /// Close Button
            Padding(
              padding: EdgeInsets.all(16.w),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: EdgeInsets.all(8.r),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Icon(
                        Icons.menu_open,
                        color: Colors.white,
                        size: 28.r,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 40.h),

            /// FAQs Menu Item
            _buildMenuItem(
              label: AppString.faqs.tr,
              icon: Icons.help_outline,
              onTap: () => context.go(RoutePath.faqScreen.addBasePath),
            ),

            /// About Us Menu Item
            _buildMenuItem(
              label: AppString.aboutUs.tr,
              icon: Icons.info_outline,
              onTap: () => context.go(RoutePath.aboutUsScreen.addBasePath),
            ),

            /// Legal Notices Menu Item
            _buildMenuItem(
              label: AppString.legalNotices.tr,
              icon: Icons.gavel_outlined,
              onTap: () => context.go(RoutePath.legalNoticesScreen.addBasePath),
            ),

            /// Privacy Policy Menu Item
            _buildMenuItem(
              label: AppString.privacyPolicy.tr,
              icon: Icons.privacy_tip_outlined,
              onTap: () => context.go(RoutePath.privacyPolicyScreen.addBasePath),
            ),
            _buildMenuItem(
              label: AppString.termsOfUse.tr,
              icon: Icons.article_outlined,
              onTap: () => context.go(RoutePath.termsOfUseScreen.addBasePath),
            ),

            /// Replay Tutorial — lets any account (new or existing) redo the
            /// onboarding coach-marks on demand, independent of the passive
            /// first-launch trigger and its "no games tonight" hold.
            _buildMenuItem(
              label: AppString.replayTutorial.tr,
              icon: Icons.school_outlined,
              onTap: () {
                Navigator.of(context).pop();
                final alreadyJoined =
                    Get.find<GlobalLeagueController>().hasJoined.value;
                Get.find<TutorialController>().restart();
                // Already-joined accounts skip step 0 (its target, the
                // Home "Join now" button, doesn't render for them) — jump
                // straight to the lineup screen so step 1 has something to
                // spotlight instead of landing back on Home with nothing
                // to show.
                if (alreadyJoined) {
                  context.go(RoutePath.globalLeagueScreen.addBasePath);
                }
              },
            ),

            const Spacer(),

            /// Decorative Element at Bottom (Optional)
            Padding(
              padding: EdgeInsets.all(32.w),
              child: Opacity(
                opacity: 0.1,
                child: Icon(
                  Icons.sports_basketball,
                  size: 100.r,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24.w),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 20.w),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.white, width: 1),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Icon(icon, color: Colors.white, size: 24.r),
            ],
          ),
        ),
      ),
    );
  }
}
