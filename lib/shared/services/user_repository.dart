import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import '../models/notification_model.dart';
import 'notification_repository.dart';
import '../../core/services/supabase_service.dart';
import 'auth_service.dart';
import 'service_repository.dart';
import 'system_activity_repository.dart';

import '../models/payment_account_model.dart';

class UserRepository extends StateNotifier<List<User>> {
  final Ref _ref;
  StreamSubscription? _subscription;

  UserRepository(this._ref) : super([]) {
    _listenToAuth();
  }

  void _listenToAuth() {
    _ref.listen<User?>(authProvider, (previous, next) {
      if (next == null) {
        // Clear state and stop stream on logout
        _subscription?.cancel();
        _subscription = null;
        state = [];
      } else if (previous?.id != next.id) {
        // Restart stream for new user session
        _initStream(next);
      }
    }, fireImmediately: true);
  }

  void _initStream(User user) {
    _subscription?.cancel();
    
    debugPrint('UserRepository: Initializing stream for role ${user.role}...');
    
    dynamic query = SupabaseConfig.client
        .from('users')
        .stream(primaryKey: ['id']);

    // DB-level filtering to prevent data leaks and reduce bandwidth
    if (user.role == UserRole.admin) {
      // Admins see everyone
    } else {
      // Providers, Helpers, and Travelers only stream their own profile data
      // This ensures immediate updates for status changes or profile edits.
      query = query.eq('id', user.id);
    }

    _subscription = query.listen((data) {
      if (!mounted) return;
      debugPrint('UserRepository: Received ${data.length} records');
      
      final users = data.map((res) {
        try {
          final roleStr = res['role']?.toString() ?? 'traveler';
          final statusStr = res['status']?.toString() ?? 'active';
          final adminRoleStr = res['admin_role']?.toString();
          final providerTypeStr = res['provider_type']?.toString();
          final travelerTypeStr = res['traveler_type']?.toString();

          UserRole role = UserRole.traveler;
          if (roleStr == 'admin') {
            role = UserRole.admin;
          } else if (roleStr == 'provider') {
            role = UserRole.provider;
          } else if (roleStr == 'provider_helper') {
            role = UserRole.providerHelper;
          }

          UserStatus status = UserStatus.active;
          try {
            status = UserStatus.values.firstWhere(
              (e) => e.name == statusStr,
              orElse: () => UserStatus.active,
            );
          } catch (_) {}

          AdminRole? adminRole = adminRoleStr != null
              ? AdminRole.values.firstWhere(
                (e) => e.name == adminRoleStr,
                orElse: () => AdminRole.supportAdmin,
              )
              : null;

          ProviderType? providerType = providerTypeStr != null
              ? ProviderType.values.firstWhere(
                (e) => e.name == providerTypeStr,
                orElse: () => ProviderType.all,
              )
              : null;

          TravelerType? travelerType = travelerTypeStr != null
              ? TravelerType.values.firstWhere(
                (e) => e.name == travelerTypeStr,
                orElse: () => TravelerType.solo,
              )
              : null;

          final metadata = Map<String, dynamic>.from(res['metadata'] as Map? ?? {});
          final List<PaymentAccount> paymentAccounts = [];
          if (metadata.containsKey('payment_accounts')) {
            final accountsData = metadata['payment_accounts'];
            if (accountsData is List) {
              for (var item in accountsData) {
                if (item is Map) {
                  try {
                    paymentAccounts.add(PaymentAccount.fromJson(Map<String, dynamic>.from(item)));
                  } catch (e) {
                    debugPrint('UserRepository: Error parsing payment account: $e');
                  }
                }
              }
            }
          }

          return User(
            id: res['id']?.toString() ?? '',
            name: res['name']?.toString() ?? '',
            email: res['email']?.toString() ?? '',
            password: '',
            role: role,
            status: status,
            adminRole: adminRole,
            providerType: providerType,
            travelerType: travelerType,
            providerId: res['provider_id']?.toString(),
            phone: res['phone']?.toString(),
            location: res['location']?.toString(),
            metadata: metadata,
            paymentAccounts: paymentAccounts,
            lastSessionId: res['last_session_id']?.toString(),
            failedAttempts: (res['failed_attempts'] as num?)?.toInt() ?? 0,
            createdAt: res['created_at'] != null
                ? DateTime.tryParse(res['created_at'].toString())
                : null,
          );
        } catch (e) {
          debugPrint('UserRepository: Critical error mapping user record: $e');
          return null;
        }
      }).whereType<User>().toList();
      
      if (mounted) {
        try {
          state = users;
        } catch (e) {
          debugPrint('UserRepository: Error setting state: $e');
        }
      }
    }, onError: (error) {
      debugPrint('UserRepository Stream error: $error');
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> addUser(User user) async {
    try {
      // Optimistic Update
      state = [...state, user];

      await SupabaseConfig.client.from('users').insert({
        'id': user.id,
        'name': user.name,
        'email': user.email,
        'role': user.role.name,
        'status': user.status.name,
      });

      // Log activity
      _ref.read(activityProvider.notifier).logUserRegistration(user);
    } catch (e) {
      print('Insert user error: $e');
      // On error, remove it from the state (revert)
      if (mounted) {
        state = state.where((u) => u.id != user.id).toList();
      }
    }
  }

  Future<void> updateUser(User updatedUser) async {
    final oldUser = state.firstWhere((u) => u.id == updatedUser.id);
    try {
      // Optimistic Update: Update the local state immediately
      state = [
        for (final user in state)
          if (user.id == updatedUser.id) updatedUser else user,
      ];

      final updateData = {
        'name': updatedUser.name.replaceFirst('Verified ', ''),
        'email': updatedUser.email,
        'role': updatedUser.role.name,
        'status': updatedUser.status.name,
        'admin_role': updatedUser.adminRole?.name,
        'provider_type': updatedUser.providerType?.name,
        'traveler_type': updatedUser.travelerType?.name,
        'phone': updatedUser.phone,
        'location': updatedUser.location,
        'metadata': updatedUser.metadata,
      };

      // Reset failed attempts if status is changed to active
      if (oldUser.status != UserStatus.active && updatedUser.status == UserStatus.active) {
        updateData['failed_attempts'] = 0;
      }

      await SupabaseConfig.client
          .from('users')
          .update(updateData)
          .eq('id', updatedUser.id);

      // Trigger automatic service verification if provider just became verified
      if (!oldUser.isVerified && updatedUser.isVerified) {
        _ref.read(serviceProvider.notifier).syncServicesVerificationForProvider(
          updatedUser.id,
          updatedUser.providerId,
          true,
        );

        // --- SEND NOTIFICATION FOR VERIFICATION ---
        _ref.read(notificationProvider.notifier).addNotification(
          userId: updatedUser.id,
          title: 'Account Verified!',
          message: 'Congratulations! Your account has been verified. Your services are now prioritized in search.',
          type: NotificationType.verification,
        );
      }
      
      // Sync default prices to services if metadata changed
      final bool pricingChanged = 
          oldUser.metadata['cleaning_price'] != updatedUser.metadata['cleaning_price'] ||
          oldUser.metadata['early_checkin_price'] != updatedUser.metadata['early_checkin_price'] ||
          oldUser.metadata['late_checkout_price'] != updatedUser.metadata['late_checkout_price'];

      if (pricingChanged && updatedUser.role == UserRole.provider) {
        _ref.read(serviceProvider.notifier).syncDefaultPricesToServices(updatedUser);
      }

      // Log status change or role change
      if (oldUser.status != updatedUser.status) {
        final admin = _ref.read(authProvider);
        _ref.read(activityProvider.notifier).logStatusUpdate(
          admin?.name ?? 'Admin',
          updatedUser.name,
          updatedUser.status.name,
        );
      }
    } catch (e) {
      print('Update user error: $e');
    }
  }

  Future<void> deleteUser(String id) async {
    try {
      final userToDelete = state.firstWhere((u) => u.id == id, orElse: () => User(id: id, name: 'Unknown', email: '', password: '', role: UserRole.traveler));
      
      // Optimistic Update: Remove the user from the local state immediately
      state = state.where((user) => user.id != id).toList();

      await SupabaseConfig.client.rpc(
        'admin_delete_user',
        params: {'target_user_id': id},
      );

      // Log activity
      _ref.read(activityProvider.notifier).logUserDeletion(userToDelete.name);
    } catch (e) {
      print('Delete user error: $e');
    }
  }

  Future<void> systemRemoveAll(String currentUserId) async {
    try {
      final usersToDelete = state.where((u) => u.id != currentUserId).toList();
      for (final user in usersToDelete) {
        await deleteUser(user.id);
      }
    } catch (e) {
      print('System Remove All error: $e');
    }
  }

  Future<void> addPaymentAccount(String userId, PaymentAccount account) async {
    // Security: Ensure the ID matches the current user
    final currentUser = _ref.read(authProvider);
    if (currentUser == null || currentUser.id != userId) {
      print('Security Breach: Unauthorized attempt to add payment account.');
      return;
    }

    try {
      final user = state.firstWhere((u) => u.id == userId);
      final updatedAccounts = [...user.paymentAccounts, account];

      final updatedMetadata = Map<String, dynamic>.from(user.metadata);
      updatedMetadata['payment_accounts'] =
          updatedAccounts.map((a) => a.toJson()).toList();

      final updatedUser = user.copyWith(
        metadata: updatedMetadata,
        paymentAccounts: updatedAccounts,
      );

      // Optimistic Update
      state = [
        for (final u in state)
          if (u.id == userId) updatedUser else u,
      ];

      await SupabaseConfig.client
          .from('users')
          .update({'metadata': updatedMetadata}).eq('id', userId);
    } catch (e) {
      print('Add payment account error: $e');
    }
  }

  Future<void> removePaymentAccount(String userId, String accountId) async {
    // Security: Ensure the ID matches the current user
    final currentUser = _ref.read(authProvider);
    if (currentUser == null || currentUser.id != userId) {
      print('Security Breach: Unauthorized attempt to remove payment account.');
      return;
    }

    try {
      final user = state.firstWhere((u) => u.id == userId);
      final updatedAccounts =
          user.paymentAccounts.where((a) => a.id != accountId).toList();

      final updatedMetadata = Map<String, dynamic>.from(user.metadata);
      updatedMetadata['payment_accounts'] =
          updatedAccounts.map((a) => a.toJson()).toList();

      final updatedUser = user.copyWith(
        metadata: updatedMetadata,
        paymentAccounts: updatedAccounts,
      );

      // Optimistic Update
      state = [
        for (final u in state)
          if (u.id == userId) updatedUser else u,
      ];

      await SupabaseConfig.client
          .from('users')
          .update({'metadata': updatedMetadata}).eq('id', userId);
    } catch (e) {
      print('Remove payment account error: $e');
    }
  }

  int get totalUsers => state.length;
  int get providerCount =>
      state.where((u) => u.role == UserRole.provider).length;

  bool isEmailUnique(String email, [String? currentUserId]) {
    return !state.any(
      (u) =>
          u.email.toLowerCase() == email.toLowerCase() && u.id != currentUserId,
    );
  }

  Future<bool> isEmailRegistered(String email) async {
    try {
      final res = await SupabaseConfig.client
          .from('users')
          .select('id')
          .eq('email', email.toLowerCase())
          .maybeSingle();
      return res != null;
    } catch (e) {
      debugPrint('Error checking email registration: $e');
      return false;
    }
  }

  bool isPhoneUnique(String phone, [String? currentUserId]) {
    return !state.any((u) => u.phone == phone && u.id != currentUserId);
  }

  bool isUsernameUnique(String username, [String? currentUserId]) {
    return !state.any(
      (u) =>
          u.email.toLowerCase() == username.toLowerCase() &&
          u.id != currentUserId,
    );
  }
}

final userProvider =
    StateNotifierProvider<UserRepository, List<User>>((ref) {
  return UserRepository(ref);
});

// Selector for role-based data isolation
final filteredUsersProvider = Provider<List<User>>((ref) {
  final user = ref.watch(authProvider);
  final users = ref.watch(userProvider);

  if (user == null) return [];

  switch (user.role) {
    case UserRole.traveler:
      // Travelers can only see their own profile
      return users.where((u) => u.id == user.id).toList();
    case UserRole.provider:
    case UserRole.providerHelper:
      return users.where((u) => u.id == user.id).toList();
    case UserRole.admin:
      // Admins see everyone
      return users;
  }
});
