import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/service_model.dart';
import '../models/user_model.dart';
import 'auth_service.dart';
import 'user_repository.dart';
import 'lookup_service.dart';
import 'system_activity_repository.dart';
import 'notification_repository.dart';
import '../models/notification_model.dart';
import '../../core/services/supabase_service.dart';

class ServiceRepository extends StateNotifier<List<Service>> {
  final Ref? _ref;
  ServiceRepository([this._ref]) : super([]) {
    _listenToAuth();
  }

  void _listenToAuth() {
    if (_ref == null) {
      _initStream();
      return;
    }

    _ref.listen<User?>(authProvider, (previous, next) {
      if (next == null) {
        _subscription?.cancel();
        _subscription = null;
        state = [];
      } else if (previous?.id != next.id) {
        _initStream();
        fetchServices(); // Initial fetch
      }
    }, fireImmediately: true);
  }

  StreamSubscription? _subscription;

  void _initStream() {
    _subscription?.cancel();
    _subscription = SupabaseConfig.client
        .from('services')
        .stream(primaryKey: ['id'])
        .listen((data) {
          if (!mounted) return;
          state = data
              .where((res) =>
                  res['id'] != null && (res['id'] as String).isNotEmpty)
              .map((res) => Service.fromJson(res))
              .toList();
        });
  }

  Future<void> fetchServices() async {
    try {
      final data = await SupabaseConfig.client.from('services').select();
      if (!mounted) return;
      state = data
          .where((res) =>
              res['id'] != null && (res['id'] as String).isNotEmpty)
          .map((res) => Service.fromJson(res))
          .toList();
    } catch (e) {
      debugPrint('Fetch services error: $e');
    }
  }

  Future<void> addService(Service service) async {
    // 🌍 Auto-seed region if it doesn't exist
    if (service.metadata['region'] != null) {
      await LookupService.ensureRegionExists(service.metadata['region'].toString());
    }

    // Generate a valid UUID for the optimistic update and database record
    final realId = const Uuid().v4();
    
    // Check if the provider is verified
    final users = _ref?.read(userProvider) ?? [];
    final provider = users.firstWhere(
      (u) => u.id == service.providerId || u.providerId == service.providerId,
      orElse: () => User(id: '', name: '', email: '', password: '', role: UserRole.traveler),
    );
    
    final bool providerIsVerified = provider.isVerified;
    
    // Fallback to provider default prices if not set on service
    final cleaningPrice = service.cleaningPrice ?? 
        double.tryParse(provider.metadata['cleaning_price']?.toString() ?? '') ?? 0.0;
    final earlyCheckInPrice = service.earlyCheckInPrice ?? 
        double.tryParse(provider.metadata['early_checkin_price']?.toString() ?? '') ?? 0.0;
    final lateCheckoutPrice = service.lateCheckoutPrice ?? 
        double.tryParse(provider.metadata['late_checkout_price']?.toString() ?? '') ?? 0.0;

    final optimisticService = service.copyWith(
      id: realId,
      isVerified: providerIsVerified ? true : service.isVerified,
      cleaningPrice: cleaningPrice,
      earlyCheckInPrice: earlyCheckInPrice,
      lateCheckoutPrice: lateCheckoutPrice,
    );
    
    try {
      // Optimistic Update
      state = [...state, optimisticService];

      await SupabaseConfig.client.from('services').insert(optimisticService.toJson());
      
      // Log Activity
      _ref?.read(activityProvider.notifier).logServiceAddition(
        optimisticService.title,
        provider.name,
        optimisticService.providerId,
      );
      
      // The stream will handle updating the state with the real record
    } catch (e) {
      debugPrint('Insert service error: $e');
      // Revert ONLY the optimistic service if error
      if (mounted) {
        state = state.where((s) => s.id != realId).toList();
      }
      rethrow;
    }
  }

  Future<void> updateService(Service service) async {
    // 🌍 Auto-seed region if it doesn't exist
    if (service.metadata['region'] != null) {
      await LookupService.ensureRegionExists(service.metadata['region'].toString());
    }

    final previousState = [...state];
    try {
      // Optimistic Update
      state = [
        for (final s in state)
          if (s.id == service.id) service else s
      ];

      // Security: Ensure the provider owns this service
      final user = _ref?.read(authProvider);
      if (user == null) throw Exception('Authentication required');
      
      if (user.role != UserRole.admin && service.providerId != (user.providerId ?? user.id)) {
        throw Exception('Security Alert: Unauthorized attempt to update service owned by another provider.');
      }

      await SupabaseConfig.client
          .from('services')
          .update(service.toJson())
          .eq('id', service.id);

      // Log Activity
      final oldService = previousState.firstWhere((s) => s.id == service.id);
      if (oldService.status != service.status) {
        _ref?.read(activityProvider.notifier).logServiceUpdate(
          service.title,
          'Status changed to ${service.status.name}',
          service.providerId,
        );

        // Notify Provider if updated by Admin
        if (user.role == UserRole.admin) {
          _ref?.read(notificationProvider.notifier).addNotification(
            userId: service.providerId,
            title: 'Service Update',
            message: 'Your service "${service.title}" status has been updated to ${service.status.name}.',
            type: NotificationType.verification, // Reusing verification type for status updates
            data: {'serviceId': service.id},
          );
        }
      } else {
        _ref?.read(activityProvider.notifier).logServiceUpdate(
          service.title,
          'Details updated',
          service.providerId,
        );
      }
    } catch (e) {
      debugPrint('Update service error: $e');
      if (mounted) {
        state = previousState;
      }
      rethrow;
    }
  }

  Future<void> deleteService(String id) async {
    final serviceToDelete = state.firstWhere((s) => s.id == id);
    
    // Security: Ensure owner or admin
    final user = _ref?.read(authProvider);
    if (user == null) throw Exception('Authentication required');
    if (user.role != UserRole.admin && serviceToDelete.providerId != (user.providerId ?? user.id)) {
      throw Exception('Security Alert: Unauthorized attempt to delete service owned by another provider.');
    }

    try {
      // Optimistic Update
      state = state.where((s) => s.id != id).toList();

      await SupabaseConfig.client.from('services').delete().eq('id', id);

      // Log Activity
      _ref?.read(activityProvider.notifier).logServiceDeletion(
        serviceToDelete.title,
        serviceToDelete.providerId,
      );
    } catch (e) {
      debugPrint('Delete service error: $e');
      rethrow;
    }
  }

  // Provider specific functions
  List<Service> get activeServices =>
      state.where((s) => s.status == ServiceStatus.active).toList();
  List<Service> get draftServices =>
      state.where((s) => s.status == ServiceStatus.draft).toList();
  List<Service> get pendingServices =>
      state.where((s) => s.status == ServiceStatus.pendingApproval).toList();
  List<Service> get inactiveServices => state
      .where(
        (s) =>
            s.status == ServiceStatus.inactive ||
            s.status == ServiceStatus.blocked,
      )
      .toList();

  bool isServiceUnique(String title, String providerId, [String? excludeId]) {
    return !state.any(
      (s) =>
          s.title.toLowerCase() == title.toLowerCase() &&
          s.providerId == providerId &&
          s.id != excludeId,
    );
  }

  Future<void> syncServicesVerificationForProvider(String userId, String? providerId, bool isVerified) async {
    try {
      if (!isVerified) return; // Only sync if becoming verified

      // Update services where provider_id matches either user id or shared provider id
      final query = SupabaseConfig.client.from('services').update({'is_verified': true});
      
      if (providerId != null && providerId.isNotEmpty) {
        await query.or('provider_id.eq.$userId,provider_id.eq.$providerId');
      } else {
        await query.eq('provider_id', userId);
      }
      
      // Update local state is handled by the stream
    } catch (e) {
      debugPrint('Sync services verification error: $e');
    }
  }

  Future<void> syncDefaultPricesToServices(User provider) async {
    final cleaningPrice = double.tryParse(provider.metadata['cleaning_price']?.toString() ?? '') ?? 0.0;
    final earlyCheckInPrice = double.tryParse(provider.metadata['early_checkin_price']?.toString() ?? '') ?? 0.0;
    final lateCheckOutPrice = double.tryParse(provider.metadata['late_checkout_price']?.toString() ?? '') ?? 0.0;

    final servicesToUpdate = state.where((s) => s.providerId == provider.id).toList();
    
    for (final service in servicesToUpdate) {
      final updated = service.copyWith(
        cleaningPrice: cleaningPrice,
        earlyCheckInPrice: earlyCheckInPrice,
        lateCheckoutPrice: lateCheckOutPrice,
      );
      await updateService(updated);
    }
  }
}

final serviceProvider = StateNotifierProvider<ServiceRepository, List<Service>>(
  (ref) {
    return ServiceRepository(ref);
  },
);

// Selector for role-based data isolation with verification enrichment
final filteredServicesProvider = Provider<List<Service>>((ref) {
  final user = ref.watch(authProvider);
  final services = ref.watch(serviceProvider);
  final users = ref.watch(userProvider);

  // Enrich services with provider verification status
  final enrichedServices = services.map((service) {
    if (service.isVerified == true) return service;

    // Check if the provider is verified
    final provider = users.firstWhere(
      (u) =>
          u.id == service.providerId ||
          (u.providerId != null && u.providerId == service.providerId),
      orElse: () => User(
        id: '',
        name: '',
        email: '',
        password: '',
        role: UserRole.traveler,
      ),
    );

    if (provider.isVerified) {
      return service.copyWith(isVerified: true);
    }
    return service;
  }).toList();

  if (user == null) {
    // If not logged in see only active
    return enrichedServices
        .where((s) => s.status == ServiceStatus.active)
        .toList();
  }

  switch (user.role) {
    case UserRole.traveler:
      return enrichedServices
          .where((s) => s.status == ServiceStatus.active)
          .toList();
    case UserRole.provider:
    case UserRole.providerHelper:
      final providerKey = user.providerId ?? user.id;
      return enrichedServices.where((s) => s.providerId == providerKey).toList();
    case UserRole.admin:
      return enrichedServices;
  }
});
