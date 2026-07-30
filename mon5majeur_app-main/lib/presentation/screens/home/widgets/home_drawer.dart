import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/routes/route_path.dart';
import '../../../../core/routes/routes.dart';

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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Icon(icon, color: Colors.white, size: 24.r),
            ],
          ),
        ),
      ),
    );
  }
}
