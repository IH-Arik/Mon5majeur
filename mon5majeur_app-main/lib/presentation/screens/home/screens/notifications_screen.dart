// lib/presentation/screens/home/screens/notifications_screen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../controllers/notifications_controller.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/routes/route_path.dart';
import '../../../../core/routes/routes.dart';
import '../../../../data/models/notification_model.dart';
import '../../../widgets/custom_heading.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<NotificationsController>();

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: SafeArea(
        child: Column(
          children: [
            CustomHeading(
              title: AppString.notifications.tr,
              routePath: RoutePath.home.addBasePath,
            ),
            SizedBox(height: 8.h),
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: Obx(
                  () => controller.hasUnread
                      ? TextButton(
                          onPressed: controller.markAllRead,
                          child: Text(
                            AppString.markAllRead.tr,
                            style: TextStyle(
                              color: const Color(0xFFFF6B35),
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ),
            SizedBox(height: 8.h),
            Expanded(
              child: Obx(() {
                if (controller.isLoading.value &&
                    controller.notifications.isEmpty) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFFFF6B35)),
                  );
                }

                if (controller.notifications.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.notifications_none,
                          color: Colors.grey,
                          size: 64.r,
                        ),
                        SizedBox(height: 16.h),
                        Text(
                          AppString.noNotifications.tr,
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: controller.refresh,
                  color: const Color(0xFFFF6B35),
                  backgroundColor: const Color(0xFF252838),
                  child: ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    itemCount: controller.notifications.length,
                    itemBuilder: (context, index) {
                      final n = controller.notifications[index];
                      return Padding(
                        padding: EdgeInsets.only(bottom: 12.h),
                        child: _NotificationCard(
                          notification: n,
                          onTap: () => controller.markRead(n.id),
                        ),
                      );
                    },
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback onTap;

  const _NotificationCard({required this.notification, required this.onTap});

  IconData get _icon {
    switch (notification.notificationType) {
      case 'team_reminder':
        return Icons.timer_outlined;
      case 'results':
        return Icons.emoji_events_outlined;
      case 'weekly_top8_reward':
      case 'monthly_winner_reward':
        return Icons.workspace_premium_outlined;
      case 'player_out':
        return Icons.warning_amber_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: notification.isRead
                ? const [Color(0xFF1A1A1A), Color(0xFF1A1A1A)]
                : const [Color(0xFF2A2D3E), Color(0xFF252838)],
          ),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: notification.isRead
                ? const Color(0xFF333333)
                : const Color(0xFFFF6B35).withValues(alpha: 0.4),
          ),
        ),
        padding: EdgeInsets.all(14.r),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(8.r),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF3A3D50),
              ),
              child: Icon(_icon, color: const Color(0xFFFF6B35), size: 18.r),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (!notification.isRead)
                        Container(
                          width: 8.w,
                          height: 8.w,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFFFF6B35),
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    notification.body,
                    style: TextStyle(
                      color: const Color(0xFFAAAAAA),
                      fontSize: 12.sp,
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    _timeAgo(notification.createdAt),
                    style: TextStyle(
                      color: const Color(0xFF777777),
                      fontSize: 10.sp,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _timeAgo(DateTime dt) {
  final diff = DateTime.now().toUtc().difference(dt.toUtc());
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${dt.day}/${dt.month}/${dt.year}';
}
