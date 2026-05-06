import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import 'auth_service.dart';
import '../../core/services/supabase_service.dart';

enum ActivityType {
  userRegistration,
  userDeletion,
  serviceListing,
  payment,
  booking,
  passwordChange,
  statusUpdate,
  bookingCancellation,
  automaticBackup,
  audit,
  security,
  securityAlert,
  finance,
  system,
}

class SystemActivity {
  final String id;
  final String title;
  final String subtitle;
  final ActivityType type;
  final DateTime timestamp;
  final IconData icon;
  final Color iconColor;
  final String? userId; // The user who performed the action
  final String? providerId; // Related provider (if applicable)
  final UserRole? role; // Role of the performer
  final Map<String, dynamic>? metadata; // Extra info (price, serviceId, etc)

  SystemActivity({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.type,
    required this.timestamp,
    required this.icon,
    required this.iconColor,
    this.userId,
    this.providerId,
    this.role,
    this.metadata,
  });

  factory SystemActivity.fromMap(Map<String, dynamic> map) {
    final typeStr = map['type'] as String? ?? 'system';
    final type = ActivityType.values.firstWhere(
      (e) => e.name == typeStr,
      orElse: () => ActivityType.system,
    );

    IconData icon;
    Color color;

    switch (type) {
      case ActivityType.audit:
        icon = Icons.assignment_turned_in_outlined;
        color = Colors.blue;
        break;
      case ActivityType.security:
      case ActivityType.securityAlert:
      case ActivityType.userDeletion:
        icon = Icons.security;
        color = Colors.red;
        break;
      case ActivityType.finance:
      case ActivityType.payment:
        icon = Icons.account_balance_wallet_outlined;
        color = Colors.green;
        break;
      case ActivityType.system:
      case ActivityType.automaticBackup:
        icon = Icons.settings_input_component;
        color = Colors.purple;
        break;
      case ActivityType.booking:
        icon = Icons.book_online;
        color = Colors.teal;
        break;
      case ActivityType.userRegistration:
        icon = Icons.person_add;
        color = Colors.blue;
        break;
      case ActivityType.statusUpdate:
        icon = Icons.security_update_good;
        color = Colors.teal;
        break;
      default:
        icon = Icons.info_outline;
        color = Colors.grey;
    }

    return SystemActivity(
      id: map['id']?.toString() ?? '',
      title: map['title'] ?? '',
      subtitle: map['subtitle'] ?? '',
      type: type,
      timestamp: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : DateTime.now(),
      icon: icon,
      iconColor: color,
      userId: map['user_id'],
      metadata: map['metadata'],
    );
  }
}

class SystemActivityRepository extends StateNotifier<List<SystemActivity>> {
  final Ref _ref;
  StreamSubscription? _subscription;

  SystemActivityRepository(this._ref) : super([]) {
    _listenToAuth();
  }

  void _listenToAuth() {
    _ref.listen<User?>(authProvider, (previous, next) {
      if (next == null) {
        _subscription?.cancel();
        _subscription = null;
        state = [];
      } else if (previous?.id != next.id) {
        _initStream(next);
      }
    }, fireImmediately: true);
  }

  void _initStream(User user) {
    _subscription?.cancel();
    
    dynamic query = SupabaseConfig.client
        .from('system_activities')
        .stream(primaryKey: ['id']);

    // DB-level filtering based on role
    if (user.role == UserRole.provider || user.role == UserRole.providerHelper) {
      final providerKey = user.providerId ?? user.id;
      query = query.eq('provider_id', providerKey);
    } else if (user.role == UserRole.traveler) {
      query = query.eq('user_id', user.id);
    }
    // Admins get no filter (query remains the same)

    _subscription = query.order('created_at', ascending: false).listen((data) {
      if (!mounted) return;
      state = data.map((map) => SystemActivity.fromMap(map)).toList();
    }, onError: (e) => debugPrint('SystemActivity stream error: $e'));
  }

  Future<void> fetchActivities() async {
    // Stream handles this now
  }

  Future<void> addActivity(SystemActivity activity) async {
    // Optimistic UI update
    state = [activity, ...state];

    // Persist to Supabase
    try {
      await SupabaseConfig.client.from('system_activities').insert({
        'title': activity.title,
        'subtitle': activity.subtitle,
        'type': activity.type.name,
        'user_id': activity.userId,
        'metadata': activity.metadata,
      });
    } catch (e) {
      debugPrint('Error adding activity to DB: $e');
    }
  }

  void logSecurityAlert({
    required String title,
    required String message,
    required String? adminId,
    bool isHighPriority = false,
  }) {
    addActivity(
      SystemActivity(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        title: title,
        subtitle: message,
        type: ActivityType.securityAlert,
        timestamp: DateTime.now(),
        icon: Icons.warning_amber_rounded,
        iconColor: isHighPriority ? Colors.red : Colors.orange,
        userId: adminId,
        metadata: {'priority': isHighPriority ? 'high' : 'normal'},
      ),
    );
  }

  void logBooking({
    required String travelerName,
    required String serviceTitle,
    required double price,
    required String providerId,
    required String userId,
  }) {
    addActivity(
      SystemActivity(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        title: 'New Booking: $serviceTitle',
        subtitle: '$travelerName booked for \$${price.toStringAsFixed(0)}',
        type: ActivityType.booking,
        timestamp: DateTime.now(),
        icon: Icons.book_online,
        iconColor: Colors.green,
        userId: userId,
        providerId: providerId,
        role: UserRole.traveler,
        metadata: {'service': serviceTitle, 'price': price},
      ),
    );
  }

  void logUserRegistration(User user) {
    addActivity(
      SystemActivity(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        title: user.role == UserRole.provider
            ? 'New Provider: ${user.name}'
            : 'New Traveler: ${user.name}',
        subtitle: 'Joined our growing community',
        type: ActivityType.userRegistration,
        timestamp: DateTime.now(),
        icon: Icons.person_add,
        iconColor: user.role == UserRole.provider
            ? Colors.deepPurple
            : Colors.blue,
        userId: user.id,
        role: user.role,
      ),
    );
  }

  void logStatusUpdate(String actorName, String targetName, String status) {
    addActivity(
      SystemActivity(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        title: 'Status Updated: $targetName',
        subtitle: 'Admin $actorName set status to $status',
        type: ActivityType.statusUpdate,
        timestamp: DateTime.now(),
        icon: Icons.security_update_good,
        iconColor: Colors.teal,
        role: UserRole.admin,
      ),
    );
  }

  void logUserDeletion(String userName) {
    addActivity(
      SystemActivity(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        title: 'User Deleted: $userName',
        subtitle: '$userName has deleted their account',
        type: ActivityType.userDeletion,
        timestamp: DateTime.now(),
        icon: Icons.person_remove,
        iconColor: Colors.red,
      ),
    );
  }

  void logPasswordChange(String userName) {
    addActivity(
      SystemActivity(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        title: 'Password Changed: $userName',
        subtitle: '$userName changed their password',
        type: ActivityType.passwordChange,
        timestamp: DateTime.now(),
        icon: Icons.password,
        iconColor: Colors.orange,
      ),
    );
  }

  void logServiceAddition(String serviceTitle, String providerName, String providerId) {
    addActivity(
      SystemActivity(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        title: 'New Service: $serviceTitle',
        subtitle: 'Listed by $providerName',
        type: ActivityType.serviceListing,
        timestamp: DateTime.now(),
        icon: Icons.hotel,
        iconColor: Colors.orange,
        providerId: providerId,
      ),
    );
  }

  void logServiceUpdate(String serviceTitle, String action, String providerId) {
    addActivity(
      SystemActivity(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        title: 'Service Updated: $serviceTitle',
        subtitle: 'Action: $action',
        type: ActivityType.statusUpdate,
        timestamp: DateTime.now(),
        icon: Icons.edit_note,
        iconColor: Colors.blue,
        providerId: providerId,
      ),
    );
  }

  void logServiceDeletion(String serviceTitle, String providerId) {
    addActivity(
      SystemActivity(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        title: 'Service Deleted: $serviceTitle',
        subtitle: 'Removed from the platform',
        type: ActivityType.userDeletion,
        timestamp: DateTime.now(),
        icon: Icons.delete_sweep,
        iconColor: Colors.red,
        providerId: providerId,
      ),
    );
  }
}

// Global provider for all activities
final activityProvider =
    StateNotifierProvider<SystemActivityRepository, List<SystemActivity>>((
      ref,
    ) {
      return SystemActivityRepository(ref);
    });

// Selector for Admin role (sees everything)
final adminActivityProvider = Provider<List<SystemActivity>>((ref) {
  return ref.watch(activityProvider);
});

// Selector for Provider role (sees only their service activities)
final providerActivityProvider = Provider<List<SystemActivity>>((ref) {
  final user = ref.watch(authProvider);
  final allActivity = ref.watch(activityProvider);
  if (user == null || user.role != UserRole.provider) return [];

  return allActivity.where((a) => a.providerId == user.id).toList();
});

// Selector for Traveler role (sees only their own bookings/activities)
final travelerActivityProvider = Provider<List<SystemActivity>>((ref) {
  final user = ref.watch(authProvider);
  final allActivity = ref.watch(activityProvider);
  if (user == null || user.role != UserRole.traveler) return [];

  return allActivity.where((a) => a.userId == user.id).toList();
});
