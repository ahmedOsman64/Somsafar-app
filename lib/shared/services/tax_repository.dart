import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/tax_model.dart';
import 'package:flutter/foundation.dart';
import '../../core/services/supabase_service.dart';

class TaxRepository extends StateNotifier<List<TaxModel>> {
  TaxRepository() : super([]) {
    _initStream();
  }

  void _initStream() {
    SupabaseConfig.client.from('taxes').stream(primaryKey: ['id']).listen((
      data,
    ) {
      if (!mounted) return;
      state = data.map((json) => TaxModel.fromJson(json)).toList();
    });
  }

  Future<void> addTax(TaxModel tax) async {
    try {
      // Optimistic update
      state = [...state, tax];

      await SupabaseConfig.client.from('taxes').insert({
        if (tax.id.isNotEmpty && !tax.id.startsWith('t_')) 'id': tax.id,
        'name': tax.name,
        'provider_type': tax.providerType.name,
        'tax_type': tax.taxType.name,
        'rate': tax.rate,
        'is_active': tax.isActive,
      });
    } catch (e) {
      debugPrint('Add tax error: $e');
      state = state.where((t) => t.id != tax.id).toList();
    }
  }

  Future<void> updateTax(TaxModel tax) async {
    try {
      await SupabaseConfig.client
          .from('taxes')
          .update(tax.toJson())
          .eq('id', tax.id);
    } catch (e) {
      debugPrint('Update tax error: $e');
    }
  }

  Future<void> deleteTax(String id) async {
    try {
      await SupabaseConfig.client.from('taxes').delete().eq('id', id);
    } catch (e) {
      debugPrint('Delete tax error: $e');
    }
  }

  Future<void> toggleStatus(String id, bool currentStatus) async {
    try {
      await SupabaseConfig.client
          .from('taxes')
          .update({'is_active': !currentStatus})
          .eq('id', id);
    } catch (e) {
      debugPrint('Toggle tax error: $e');
    }
  }
}

final taxProvider = StateNotifierProvider<TaxRepository, List<TaxModel>>((ref) {
  return TaxRepository();
});

final activeTaxesProvider = Provider<List<TaxModel>>((ref) {
  final taxes = ref.watch(taxProvider);
  return taxes.where((t) => t.isActive).toList();
});
