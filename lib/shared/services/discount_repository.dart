import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/discount_model.dart';
import '../models/user_model.dart';
import 'auth_service.dart';
import '../../core/services/supabase_service.dart';
import 'package:flutter/foundation.dart';


class DiscountRepository extends StateNotifier<List<Discount>> {
  Timer? _expirationTimer;

  DiscountRepository() : super([]) {
    _initStream();
    _startAutoCheck();
  }

  @override
  void dispose() {
    _expirationTimer?.cancel();
    super.dispose();
  }

  void _startAutoCheck() {
    // Check every hour (or whenever app starts) to ensure accurate statuses
    _expirationTimer = Timer.periodic(const Duration(hours: 1), (timer) {
      if (mounted) checkExpirations();
    });
  }

  void _initStream() {
    SupabaseConfig.client
        .from('discounts')
        .stream(primaryKey: ['id'])
        .listen((data) {
          if (!mounted) return;
          try {
            final List<Discount> loadedDiscounts = [];
            for (final json in data) {
              try {
                loadedDiscounts.add(Discount.fromJson(json));
              } catch (e) {
                debugPrint('Error parsing individual discount (${json['id']}): $e');
              }
            }
            state = loadedDiscounts;
            // Run expiration check to ensure statuses match current date
            checkExpirations();
          } catch (e) {
            debugPrint('Error in discount stream listener: $e');
          }
        });
  }

  Future<void> checkExpirations() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
      // Process local state to find what needs updating on the server
    for (final d in state) {
      // If manually deactivated, don't change status automatically
      if (d.status == DiscountStatus.inactive) continue;

      final endOfDay = DateTime(d.endDate.year, d.endDate.month, d.endDate.day, 23, 59, 59);
      final startOfDay = DateTime(d.startDate.year, d.startDate.month, d.startDate.day);

      DiscountStatus? newStatus;

      if (d.status != DiscountStatus.ended && now.isAfter(endOfDay)) {
        newStatus = DiscountStatus.ended;
      } else if (d.status == DiscountStatus.scheduled && (now.isAfter(startOfDay) || now.isAtSameMomentAs(today))) {
        newStatus = DiscountStatus.active;
      } else if (d.status == DiscountStatus.pending && (now.isAfter(startOfDay) || now.isAtSameMomentAs(today))) {
        // Auto-activate pending if dates match (simplified for provider self-management)
        newStatus = now.isAfter(endOfDay) ? DiscountStatus.ended : DiscountStatus.active;
      }

      if (newStatus != null && newStatus != d.status) {
        // Fire and forget update to server; stream will update local state
        updateDiscount(d.copyWith(status: newStatus));
      }
    }
  }

  Future<void> addDiscount(Discount discount) async {
    try {
      await SupabaseConfig.client.from('discounts').insert(discount.toJson());
      // Explicitly update state for immediate UI refresh
      state = [...state, discount];
    } catch (e) {
      debugPrint('Error adding discount to Supabase: $e');
      rethrow;
    }
  }

  Future<void> updateDiscount(Discount updatedDiscount) async {
    try {
      await SupabaseConfig.client
          .from('discounts')
          .update(updatedDiscount.toJson())
          .eq('id', updatedDiscount.id);
      
      // Explicitly update state for immediate UI refresh
      state = state.map((d) => d.id == updatedDiscount.id ? updatedDiscount : d).toList();
    } catch (e) {
      debugPrint('Error updating discount in Supabase: $e');
      rethrow;
    }
  }

  Future<void> deleteDiscount(String id) async {
    try {
      await SupabaseConfig.client.from('discounts').delete().eq('id', id);
      // Explicitly update state for immediate UI refresh
      state = state.where((d) => d.id != id).toList();
    } catch (e) {
      debugPrint('Error deleting discount from Supabase: $e');
      rethrow;
    }
  }

  Future<void> toggleDiscountStatus(Discount discount) async {
    DiscountStatus newStatus;
    if (discount.status == DiscountStatus.inactive) {
      // Recalculate status based on dates when re-activating
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final start = DateTime(discount.startDate.year, discount.startDate.month, discount.startDate.day);
      final end = DateTime(discount.endDate.year, discount.endDate.month, discount.endDate.day, 23, 59, 59);

      if (now.isAfter(end)) {
        newStatus = DiscountStatus.ended;
      } else if (now.isAfter(start) || now.isAtSameMomentAs(today)) {
        newStatus = DiscountStatus.active;
      } else {
        newStatus = DiscountStatus.scheduled;
      }
    } else {
      newStatus = DiscountStatus.inactive;
    }

    await updateDiscount(discount.copyWith(status: newStatus));
  }

  static Discount? getBestDiscount(
    List<Discount> discounts,
    String serviceId,
    String providerId,
  ) {
    final now = DateTime.now();
    final activeDiscounts = discounts.where((d) {
      final startOfDay = DateTime(d.startDate.year, d.startDate.month, d.startDate.day);
      final endOfDay = DateTime(d.endDate.year, d.endDate.month, d.endDate.day, 23, 59, 59);

      final isDateValid =
          (startOfDay.isBefore(now) ||
              startOfDay.isAtSameMomentAs(now)) &&
          (endOfDay.isAfter(now) || endOfDay.isAtSameMomentAs(now));
      
      // Robust matching: A discount matches if it has the same providerId 
      // as the service, or if it's a platform-wide 'sample-provider' discount.
      final isProviderMatch = d.providerId == providerId || d.providerId == 'sample-provider';
      
      final isServiceMatch =
          d.applicableServiceIds.isEmpty ||
          d.applicableServiceIds.contains(serviceId);
          
      return d.status == DiscountStatus.active &&
          isDateValid &&
          isProviderMatch &&
          isServiceMatch;
    }).toList();

    if (activeDiscounts.isEmpty) return null;

    // Pick the best discount: highest percentage first, then highest fixed amount
    activeDiscounts.sort((a, b) {
      // Percentages are generally better, prioritize them
      if (a.isPercentage && !b.isPercentage) return -1;
      if (!a.isPercentage && b.isPercentage) return 1;
      // Both same type: pick higher value
      return b.value.compareTo(a.value);
    });
    return activeDiscounts.first;
  }
}

final discountRepositoryProvider =
    StateNotifierProvider<DiscountRepository, List<Discount>>(
      (ref) => DiscountRepository(),
    );

final filteredDiscountsProvider = Provider<List<Discount>>((ref) {
  final user = ref.watch(authProvider);
  final discounts = ref.watch(discountRepositoryProvider);

  if (user == null) return [];

  // Admins see all discounts across the platform
  if (user.role == UserRole.admin) return discounts;

  // Providers see their own business discounts or sample data
  if (user.role == UserRole.provider || user.role == UserRole.providerHelper) {
    final businessId = user.providerId;
    final personalId = user.id;
    
    return discounts.where((d) {
      final isOwner = d.providerId == personalId;
      final isBusinessMatch = businessId != null && d.providerId == businessId;
      final isSample = d.providerId == 'sample-provider';
      
      return isOwner || isBusinessMatch || isSample;
    }).toList();
  }

  return [];
});
