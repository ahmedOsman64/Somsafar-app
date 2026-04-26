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
      } catch (e) {
        state = [];
      }
    } else {
      state = [];
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
  }

  Future<void> updateDiscount(Discount updatedDiscount) async {
    state = [
      for (final d in state)
        if (d.id == updatedDiscount.id) updatedDiscount else d,
    ];
    await _saveToPrefs();
  }

  Future<void> deleteDiscount(String id) async {
    state = state.where((d) => d.id != id).toList();
    await _saveToPrefs();
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
