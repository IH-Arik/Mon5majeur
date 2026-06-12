import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/routes/route_path.dart';
import '../../core/routes/routes.dart';

class NavigationWidget extends StatelessWidget {
  final int currentIndex;

  const NavigationWidget({super.key, required this.currentIndex});

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
        selectedItemColor: const Color(0xFFFF6B35),
        unselectedItemColor: Colors.grey,
        currentIndex: currentIndex,
        elevation: 0,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        onTap: (index) => _onItemTapped(context, index),
        items: [
          BottomNavigationBarItem(
            icon: Image.asset(
              currentIndex == 0
                  ? 'assets/icons/home_active.png'
                  : 'assets/icons/home_inactive.png',
              width: 24.w,
              height: 24.h,
            ),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: Image.asset(
              currentIndex == 1
                  ? 'assets/icons/basket_ball_active.png'
                  : 'assets/icons/basket_ball_inactive.png',
              width: 24.w,
              height: 24.h,
            ),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: Image.asset(
              currentIndex == 2
                  ? 'assets/icons/basket_ball_player_active.png'
                  : 'assets/icons/basket_ball_player_inactive.png',
              width: 24.w,
              height: 24.h,
            ),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: Image.asset(
              currentIndex == 3
                  ? 'assets/icons/shopping_card_active.png'
                  : 'assets/icons/shopping_card_inactive.png',
              width: 24.w,
              height: 24.h,
            ),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: Image.asset(
              currentIndex == 4
                  ? 'assets/icons/profile_active.png'
                  : 'assets/icons/profile_inactive.png',
              width: 24.w,
              height: 24.h,
            ),
            label: '',
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
