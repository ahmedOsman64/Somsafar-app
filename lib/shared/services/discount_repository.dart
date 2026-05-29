import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/discount_model.dart';
import '../models/user_model.dart';
import 'auth_service.dart';
import '../../core/services/supabase_service.dart';
import 'package:flutter/foundation.dart';

class DiscountRepository extends StateNotifier<List<Discount>> {
  DiscountRepository() : super([]) {
    _initStream();
  }

  void _initStream() {
    SupabaseConfig.client
        .from('discounts')
        .stream(primaryKey: ['id'])
        .listen((data) {
          if (!mounted) return;
          try {
            state = data.map((json) => Discount.fromJson(json)).toList();
            checkExpirations(); // Check expirations on every data update
          } catch (e) {
            debugPrint('Error parsing discounts from Supabase: $e');
          }
        });
  }

  Future<void> checkExpirations() async {
    final now = DateTime.now();
    
    // We update local state first for immediate UI response, 
    // but the actual auto-expiration should ideally be handled by a DB cron job or Function.
    // For now, we'll keep the logic to trigger updates if we detect expired ones.
    
    for (final d in state) {
      if (d.status == DiscountStatus.pending || d.status == DiscountStatus.ended) continue;
      
      final endOfDay = DateTime(d.endDate.year, d.endDate.month, d.endDate.day, 23, 59, 59);
      final startOfDay = DateTime(d.startDate.year, d.startDate.month, d.startDate.day);

      if (d.status == DiscountStatus.active && now.isAfter(endOfDay)) {
        await updateDiscount(d.copyWith(status: DiscountStatus.ended));
      } else if (d.status == DiscountStatus.scheduled && (now.isAfter(startOfDay) || now.isAtSameMomentAs(startOfDay))) {
        if (now.isAfter(endOfDay)) {
           await updateDiscount(d.copyWith(status: DiscountStatus.ended));
        } else {
           await updateDiscount(d.copyWith(status: DiscountStatus.active));
        }
      }
    }
  }

  Future<void> addDiscount(Discount discount) async {
    try {
      await SupabaseConfig.client.from('discounts').insert(discount.toJson());
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
    } catch (e) {
      debugPrint('Error updating discount in Supabase: $e');
      rethrow;
    }
  }

  Future<void> deleteDiscount(String id) async {
    try {
      await SupabaseConfig.client.from('discounts').delete().eq('id', id);
    } catch (e) {
      debugPrint('Error deleting discount from Supabase: $e');
      rethrow;
    }
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
      final isProviderMatch = d.providerId == providerId;
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

  if (user.role == UserRole.provider || user.role == UserRole.providerHelper) {
    final providerKey = user.providerId ?? user.id;
    // For demo purposes, if it's the sample provider or matches the key
    return discounts
        .where(
          (d) =>
              d.providerId == providerKey || d.providerId == 'sample-provider',
        )
        .toList();
  }

  if (user.role == UserRole.admin) return discounts;

  return [];
});
