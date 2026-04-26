import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/notification_model.dart';
import '../../core/services/supabase_service.dart';
import 'auth_service.dart';

class NotificationRepository extends StateNotifier<List<AppNotification>> {
  final Ref _ref;
  StreamSubscription? _subscription;

  NotificationRepository(this._ref) : super([]) {
    _init();
  }

  void _init() {
    final user = _ref.watch(authProvider);
    if (user != null) {
      fetchNotifications();
      _subscribeToNotifications(user.id);
    } else {
      state = [];
      _subscription?.cancel();
    }
  }

  Future<void> fetchNotifications() async {
    final user = _ref.read(authProvider);
    if (user == null) return;

    try {
      final response = await SupabaseConfig.client
          .from('notifications')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      final notifications = (response as List)
          .map((json) => AppNotification.fromJson(json))
          .toList();
      if (mounted) {
        state = notifications;
      }
    } catch (e) {
      debugPrint('Error fetching notifications: $e');
    }
  }

  void _subscribeToNotifications(String userId) {
    _subscription?.cancel();
    _subscription = SupabaseConfig.client
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .listen((data) {
          final notifications = data.map((json) => AppNotification.fromJson(json)).toList();
          if (mounted) {
            state = notifications;
          }
        });
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await SupabaseConfig.client
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId);
      
      if (mounted) {
        state = [
          for (final n in state)
            if (n.id == notificationId) n.copyWith(isRead: true) else n
        ];
      }
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  Future<void> markAllAsRead() async {
    final user = _ref.read(authProvider);
    if (user == null) return;

    try {
      await SupabaseConfig.client
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', user.id);
      
      if (mounted) {
        state = state.map((n) => n.copyWith(isRead: true)).toList();
      }
    } catch (e) {
      debugPrint('Error marking all notifications as read: $e');
    }
  }

  Future<void> addNotification({
    required String userId,
    required String title,
    required String message,
    required NotificationType type,
    Map<String, dynamic>? data,
  }) async {
    try {
      await SupabaseConfig.client.from('notifications').insert({
        'user_id': userId,
        'title': title,
        'message': message,
        'type': type.name,
        'is_read': false,
        'created_at': DateTime.now().toIso8601String(),
        'data': data,
      });
    } catch (e) {
      debugPrint('Error adding notification: $e');
    }
  }

  Future<void> deleteNotification(String id) async {
    try {
      if (mounted) {
        state = state.where((n) => n.id != id).toList();
      }
    } catch (e) {
      debugPrint('Error deleting notification: $e');
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

final notificationProvider =
    StateNotifierProvider<NotificationRepository, List<AppNotification>>((ref) {
  return NotificationRepository(ref);
});

final unreadNotificationsCountProvider = Provider<int>((ref) {
  return ref.watch(notificationProvider).where((n) => !n.isRead).length;
});
