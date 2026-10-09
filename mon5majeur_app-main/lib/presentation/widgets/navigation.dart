import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/routes/route_path.dart';
import '../../core/constants/app_strings.dart';
import '../../core/routes/routes.dart';

class NavigationWidget extends StatelessWidget {
  final int currentIndex;

  const NavigationWidget({super.key, required this.currentIndex});

  static const Color _activeColor = Color(0xFFFF6B35);

  // One tab: the icon (image) with its label underneath. The label lives in
  // the icon widget so it can shrink to a single line instead of overflowing,
  // and its text scale is capped so the bar never visibly grows with a large
  // system font.
  BottomNavigationBarItem _item(
    int index,
    String activeAsset,
    String inactiveAsset,
    String label, {
    Widget? icon,
  }) {
    final selected = currentIndex == index;
    // Same tile height as before the labels (the bar's own built-in label
    // slot is switched off with font size 0, so a label never makes the bar
    // taller): the 56 minimum, or the image height + the 34 of padding the
    // bar used to add around it.
    final tileHeight = math.max(kBottomNavigationBarHeight, 24.h + 34);
    return BottomNavigationBarItem(
      icon: SizedBox(
        height: tileHeight,
        child: Center(
          child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon ??
              Image.asset(
                selected ? activeAsset : inactiveAsset,
                width: 24.w,
                height: 24.h,
              ),
          SizedBox(height: 2.h),
          MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.1,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  color: selected ? _activeColor : Colors.grey,
                  fontSize: 10.5.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
          ),
        ),
      ),
      label: '',
    );
  }

  // The profile artwork has "MON PROFIL" baked into its bottom ~10%. Hide it
  // by clipping at display time (the label under the icon says it instead,
  // in the right language) and scale the figure up so it matches the others.
  Widget _profileIcon(String asset) {
    final height = 24.h;
    return SizedBox(
      width: 24.w,
      height: height,
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.topCenter,
          minHeight: height / 0.9,
          maxHeight: height / 0.9,
          child: Image.asset(asset, height: height / 0.9, fit: BoxFit.contain),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1a1a1a),
        border: Border(
          top: BorderSide(color: const Color(0xFF333333), width: 1.0.r),
        ),
      ),
      child: BottomNavigationBar(
        backgroundColor: Colors.transparent,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: _activeColor,
        unselectedItemColor: Colors.grey,
        currentIndex: currentIndex,
        elevation: 0,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        // The labels are drawn inside each icon widget (see _item), so the
        // bar's own label slot is given no height.
        selectedFontSize: 0,
        unselectedFontSize: 0,
        onTap: (index) => _onItemTapped(context, index),
        items: [
          _item(
            0,
            'assets/icons/home_active.png',
            'assets/icons/home_inactive.png',
            AppString.navHome.tr,
          ),
          _item(
            1,
            'assets/icons/basket_ball_active.png',
            'assets/icons/basket_ball_inactive.png',
            AppString.navResults.tr,
          ),
          _item(
            2,
            'assets/icons/basket_ball_player_active.png',
            'assets/icons/basket_ball_player_inactive.png',
            AppString.navData.tr,
          ),
          _item(
            3,
            'assets/icons/shopping_card_active.png',
            'assets/icons/shopping_card_inactive.png',
            AppString.navShop.tr,
          ),
          _item(
            4,
            '',
            '',
            AppString.navProfile.tr,
            icon: _profileIcon(
              currentIndex == 4
                  ? 'assets/icons/profile_active.png'
                  : 'assets/icons/profile_inactive.png',
            ),
          ),
        ],
      ),
    );
  }

  void _onItemTapped(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go(RoutePath.home.addBasePath);
        break;
      case 1:
        // Navigate to basketball/matches screen
        context.go(RoutePath.myMatch.addBasePath);
        break;
      case 2:
        // Navigate to players/leagues screen
        context.go(RoutePath.data.addBasePath);
        break;
      case 3:
        // Navigate to shop screen
        context.go(RoutePath.shopScreen.addBasePath);
        break;
      case 4:
        // Navigate to profile screen
        context.go(RoutePath.profileScreen.addBasePath);
        break;
    }
  }
}
