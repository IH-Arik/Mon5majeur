// lib/controllers/notifications_controller.dart
import 'package:get/get.dart';
import 'package:logger/logger.dart';

import '../data/models/notification_model.dart';
import '../data/services/api_service.dart';
import '../data/services/api_url.dart';

final _logger = Logger();

class NotificationsController extends GetxController {
  var isLoading = false.obs;
  var notifications = <NotificationModel>[].obs;

  bool get hasUnread => notifications.any((n) => !n.isRead);

  @override
  void onInit() {
    super.onInit();
    fetchNotifications();
  }

  Future<void> fetchNotifications() async {
    if (isLoading.value) return;
    isLoading.value = true;

    try {
      final apiClient = ApiClient();
      final response = await apiClient.get(
        url: ApiUrl.baseUrl + ApiUrl.notifications,
        isBasic: false,
        showResult: true,
      );

      if (response.statusCode == 200 && response.body != null) {
        final data = response.body['data'] as List? ?? [];
        // Newest first. The server sorts too; sorting here keeps the order
        // right even against a backend that does not yet.
        notifications.value = data
            .map((json) => NotificationModel.fromJson(json))
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      } else {
        _logger.e('Failed to load notifications: ${response.statusCode}');
      }
    } catch (e) {
      _logger.e('Error fetching notifications: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> markAllRead() async {
    try {
      final apiClient = ApiClient();
      final response = await apiClient.patch(
        url: ApiUrl.baseUrl + ApiUrl.markAllNotificationsRead,
        isBasic: false,
      );
      if (response.statusCode == 200 || response.statusCode == 204) {
        notifications.value = notifications
            .map((n) => NotificationModel(
                  id: n.id,
                  title: n.title,
                  body: n.body,
                  isRead: true,
                  notificationType: n.notificationType,
                  createdAt: n.createdAt,
                ))
            .toList();
      }
    } catch (e) {
      _logger.e('Error marking all notifications read: $e');
    }
  }

  Future<void> markRead(String id) async {
    final index = notifications.indexWhere((n) => n.id == id);
    if (index == -1 || notifications[index].isRead) return;

    try {
      final apiClient = ApiClient();
      final response = await apiClient.patch(
        url: ApiUrl.baseUrl + ApiUrl.markNotificationRead(id),
        isBasic: false,
      );
      if (response.statusCode == 200 || response.statusCode == 204) {
        final n = notifications[index];
        notifications[index] = NotificationModel(
          id: n.id,
          title: n.title,
          body: n.body,
          isRead: true,
          notificationType: n.notificationType,
          createdAt: n.createdAt,
        );
        notifications.refresh();
      }
    } catch (e) {
      _logger.e('Error marking notification read: $e');
    }
  }

  /// Deletes one notification. Removed from the list at once; put back if the
  /// server refuses (QA 30/09 #8 #2).
  Future<bool> deleteNotification(String id) async {
    final index = notifications.indexWhere((n) => n.id == id);
    if (index == -1) return false;
    final removed = notifications[index];
    notifications.removeAt(index);
    try {
      final ok = await ApiClient().delete(
        url: ApiUrl.baseUrl + ApiUrl.deleteNotification(id),
        code: 204,
      );
      if (ok) return true;
    } catch (e) {
      _logger.e('Error deleting notification: $e');
    }
    notifications.insert(index.clamp(0, notifications.length), removed);
    return false;
  }

  /// Deletes every notification of the user.
  Future<bool> clearAll() async {
    final backup = List<NotificationModel>.from(notifications);
    notifications.clear();
    try {
      final ok = await ApiClient().delete(
        url: ApiUrl.baseUrl + ApiUrl.clearNotifications,
        code: 204,
      );
      if (ok) return true;
    } catch (e) {
      _logger.e('Error clearing notifications: $e');
    }
    notifications.assignAll(backup);
    return false;
  }

  @override
  Future<void> refresh() async {
    await fetchNotifications();
  }
}
