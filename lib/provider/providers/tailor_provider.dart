import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../shared/models/tailor_models.dart';
import '../../shared/models/user_model.dart';
import '../../shared/services/auth_service.dart';
import '../../shared/services/user_repository.dart';

class TailorState {
  final List<TailorCustomer> customers;
  final List<TailorOrder> orders;
  final bool isLoading;

  TailorState({
    this.customers = const [],
    this.orders = const [],
    this.isLoading = false,
  });

  TailorState copyWith({
    List<TailorCustomer>? customers,
    List<TailorOrder>? orders,
    bool? isLoading,
  }) =>
      TailorState(
        customers: customers ?? this.customers,
        orders: orders ?? this.orders,
        isLoading: isLoading ?? this.isLoading,
      );
}

class TailorNotifier extends StateNotifier<TailorState> {
  final Ref _ref;
  String? _currentUserId;

  TailorNotifier(this._ref) : super(TailorState()) {
    _listenToAuth();
  }

  void _listenToAuth() {
    _ref.listen<User?>(authProvider, (previous, next) {
      if (next == null) {
        _currentUserId = null;
        state = TailorState();
      } else if (next.id != _currentUserId) {
        _currentUserId = next.id;
        _loadData(next);
      }
    }, fireImmediately: true);
  }

  Future<void> _loadData(User user) async {
    state = state.copyWith(isLoading: true);
    try {
      final prefs = await SharedPreferences.getInstance();

      // 1. Try loading from SharedPreferences
      final localCustomersJson = prefs.getString('tailor_customers_${user.id}');
      final localOrdersJson = prefs.getString('tailor_orders_${user.id}');

      List<TailorCustomer> loadedCustomers = [];
      List<TailorOrder> loadedOrders = [];

      if (localCustomersJson != null) {
        try {
          final List<dynamic> decoded = jsonDecode(localCustomersJson);
          loadedCustomers = decoded.map((item) => TailorCustomer.fromJson(item)).toList();
        } catch (e) {
          debugPrint('Error decoding local customers: $e');
        }
      }
      if (localOrdersJson != null) {
        try {
          final List<dynamic> decoded = jsonDecode(localOrdersJson);
          loadedOrders = decoded.map((item) => TailorOrder.fromJson(item)).toList();
        } catch (e) {
          debugPrint('Error decoding local orders: $e');
        }
      }

      // 2. Try loading from User Metadata (Supabase Cloud backup)
      final metaCustomers = user.metadata['tailor_customers'] as List<dynamic>?;
      final metaOrders = user.metadata['tailor_orders'] as List<dynamic>?;

      if (metaCustomers != null && loadedCustomers.isEmpty) {
        try {
          loadedCustomers = metaCustomers
              .map((item) => TailorCustomer.fromJson(Map<String, dynamic>.from(item)))
              .toList();
        } catch (e) {
          debugPrint('Error decoding cloud metadata customers: $e');
        }
      }
      if (metaOrders != null && loadedOrders.isEmpty) {
        try {
          loadedOrders = metaOrders
              .map((item) => TailorOrder.fromJson(Map<String, dynamic>.from(item)))
              .toList();
        } catch (e) {
          debugPrint('Error decoding cloud metadata orders: $e');
        }
      }

      // 3. Fallback or merge
      state = TailorState(
        customers: loadedCustomers,
        orders: loadedOrders,
        isLoading: false,
      );

      // If cloud is missing but we have local data, perform background sync to cloud
      if ((metaCustomers == null && loadedCustomers.isNotEmpty) ||
          (metaOrders == null && loadedOrders.isNotEmpty)) {
        _syncToCloud();
      }
    } catch (e) {
      debugPrint('Error loading tailor data: $e');
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> _saveLocal() async {
    if (_currentUserId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final customersJson = jsonEncode(state.customers.map((c) => c.toJson()).toList());
      final ordersJson = jsonEncode(state.orders.map((o) => o.toJson()).toList());

      await prefs.setString('tailor_customers_$_currentUserId', customersJson);
      await prefs.setString('tailor_orders_$_currentUserId', ordersJson);
    } catch (e) {
      debugPrint('Error saving tailor data locally: $e');
    }
  }

  Future<void> _syncToCloud() async {
    final user = _ref.read(authProvider);
    if (user == null || _currentUserId == null) return;

    try {
      final updatedMetadata = Map<String, dynamic>.from(user.metadata);
      updatedMetadata['tailor_customers'] = state.customers.map((c) => c.toJson()).toList();
      updatedMetadata['tailor_orders'] = state.orders.map((o) => o.toJson()).toList();

      final updatedUser = user.copyWith(metadata: updatedMetadata);

      // Update local auth state
      _ref.read(authServiceProvider).updateUserData(updatedUser);
      // Push to Supabase Cloud
      await _ref.read(userProvider.notifier).updateUser(updatedUser);
      debugPrint('Tailor data synced to Supabase Cloud.');
    } catch (e) {
      debugPrint('Error syncing tailor data to cloud: $e');
    }
  }

  // --- Customer Operations ---
  Future<void> addCustomer(TailorCustomer customer) async {
    state = state.copyWith(
      customers: [...state.customers, customer],
    );
    await _saveLocal();
    await _syncToCloud();
  }

  Future<void> updateCustomer(TailorCustomer updated) async {
    state = state.copyWith(
      customers: [
        for (final c in state.customers)
          if (c.id == updated.id) updated else c
      ],
    );
    await _saveLocal();
    await _syncToCloud();
  }

  Future<void> deleteCustomer(String id) async {
    state = state.copyWith(
      customers: state.customers.where((c) => c.id != id).toList(),
      // Also delete orders related to this customer
      orders: state.orders.where((o) => o.customerId != id).toList(),
    );
    await _saveLocal();
    await _syncToCloud();
  }

  // --- Order Operations ---
  Future<void> addOrder(TailorOrder order) async {
    state = state.copyWith(
      orders: [...state.orders, order],
    );
    await _saveLocal();
    await _syncToCloud();
  }

  Future<void> updateOrder(TailorOrder updated) async {
    state = state.copyWith(
      orders: [
        for (final o in state.orders)
          if (o.id == updated.id) updated else o
      ],
    );
    await _saveLocal();
    await _syncToCloud();
  }

  Future<void> deleteOrder(String id) async {
    state = state.copyWith(
      orders: state.orders.where((o) => o.id != id).toList(),
    );
    await _saveLocal();
    await _syncToCloud();
  }
}

final tailorProvider = StateNotifierProvider<TailorNotifier, TailorState>((ref) {
  return TailorNotifier(ref);
});
