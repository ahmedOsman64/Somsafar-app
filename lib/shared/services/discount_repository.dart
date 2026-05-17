import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/discount_model.dart';
import '../models/user_model.dart';
import 'auth_service.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class DiscountRepository extends StateNotifier<List<Discount>> {
  DiscountRepository() : super([]) {
    _loadFromPrefs();
  }

  static const String _storageKey = 'somsafar_discounts';

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final String? storedData = prefs.getString(_storageKey);
    if (storedData != null) {
      try {
        final List<dynamic> decoded = jsonDecode(storedData);
        state = decoded.map((json) => Discount.fromJson(json)).toList();
        await checkExpirations(); // Automatically check and update expired discounts
      } catch (e) {
        state = [];
      }
    } else {
      state = [];
      await _saveToPrefs();
    }
  }

  Future<void> checkExpirations() async {
    final now = DateTime.now();
    bool hasChanges = false;
    
    final updatedList = state.map((d) {
      final endOfDay = DateTime(d.endDate.year, d.endDate.month, d.endDate.day, 23, 59, 59);
      final startOfDay = DateTime(d.startDate.year, d.startDate.month, d.startDate.day);

      if (d.status == DiscountStatus.active && now.isAfter(endOfDay)) {
        hasChanges = true;
        return Discount(
          id: d.id,
          providerId: d.providerId,
          value: d.value,
          isPercentage: d.isPercentage,
          startDate: d.startDate,
          endDate: d.endDate,
          applicableServiceIds: d.applicableServiceIds,
          status: DiscountStatus.ended, // Automatically deactivate
          code: d.code,
          createdAt: d.createdAt,
        );
      } else if (d.status == DiscountStatus.scheduled && (now.isAfter(startOfDay) || now.isAtSameMomentAs(startOfDay))) {
        hasChanges = true;
        if (now.isAfter(endOfDay)) {
           return Discount(
             id: d.id,
             providerId: d.providerId,
             value: d.value,
             isPercentage: d.isPercentage,
             startDate: d.startDate,
             endDate: d.endDate,
             applicableServiceIds: d.applicableServiceIds,
             status: DiscountStatus.ended,
             code: d.code,
             createdAt: d.createdAt,
           );
        } else {
           return Discount(
             id: d.id,
             providerId: d.providerId,
             value: d.value,
             isPercentage: d.isPercentage,
             startDate: d.startDate,
             endDate: d.endDate,
             applicableServiceIds: d.applicableServiceIds,
             status: DiscountStatus.active, // Automatically activate scheduled
             code: d.code,
             createdAt: d.createdAt,
           );
        }
      }
      return d;
    }).toList();

    if (hasChanges) {
      state = updatedList;
      await _saveToPrefs();
    }
  }

  Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(state.map((s) => s.toJson()).toList());
    await prefs.setString(_storageKey, encoded);
  }

  Future<void> addDiscount(Discount discount) async {
    state = [...state, discount];
    await _saveToPrefs();
    await checkExpirations();
  }

  Future<void> updateDiscount(Discount updatedDiscount) async {
    state = [
      for (final d in state)
        if (d.id == updatedDiscount.id) updatedDiscount else d,
    ];
    await _saveToPrefs();
    await checkExpirations();
  }

  Future<void> deleteDiscount(String id) async {
    state = state.where((d) => d.id != id).toList();
    await _saveToPrefs();
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
