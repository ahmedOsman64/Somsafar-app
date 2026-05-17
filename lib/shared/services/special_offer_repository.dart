import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';
import '../models/special_offer_model.dart';
import '../../core/services/supabase_service.dart';

class SpecialOfferRepository extends StateNotifier<List<SpecialOffer>> {
  SpecialOfferRepository() : super([]) {
    _initStream();
  }

  void _initStream() {
    SupabaseConfig.client
        .from('special_offers')
        .stream(primaryKey: ['id'])
        .listen((data) {
      if (!mounted) return;
      state = data.map((res) {
        return SpecialOffer(
          id: res['id'] as String,
          title: res['title'] ?? '',
          discount: res['discount'] ?? '',
          description: res['description'] ?? '',
          imageUrl: res['image_url'] ?? '',
          order: res['display_order'] ?? 0,
          isActive: res['active'] ?? true,
          linkedServiceId: res['linked_service_id'] as String?,
          discountPercent: (res['discount_percent'] as num?)?.toDouble(),
        );
      }).toList();
    });
  }

  Future<String?> addOffer({
    required String title,
    required String discount,
    required String description,
    required String imageUrl,
    String? linkedServiceId,
    double? discountPercent,
  }) async {
    if (state.length >= 10) {
      return 'Maximum 10 offers allowed.';
    }

    final id = const Uuid().v4();
    final newOffer = SpecialOffer(
      id: id,
      title: title,
      discount: discount,
      description: description,
      imageUrl: imageUrl,
      order: state.length,
      isActive: true,
      linkedServiceId: linkedServiceId,
      discountPercent: discountPercent,
    );
    
    final oldState = [...state];
    if (mounted) state = [...state, newOffer];

    try {
      await SupabaseConfig.client.from('special_offers').insert({
        'id': id,
        'title': title,
        'discount': discount,
        'description': description,
        'image_url': imageUrl,
        'display_order': state.length - 1,
        'active': true,
        'linked_service_id': linkedServiceId,
        'discount_percent': discountPercent,
      });
      return null;
    } catch (e) {
      debugPrint('Add special offer error: $e');
      if (mounted) state = oldState;
      return 'Failed to add offer in database.';
    }
  }

  Future<void> removeOffer(String id) async {
    final oldState = [...state];
    if (mounted) state = state.where((o) => o.id != id).toList();
    try {
      await SupabaseConfig.client.from('special_offers').delete().eq('id', id);
    } catch (e) {
      debugPrint('Remove special offer error: $e');
      if (mounted) state = oldState;
    }
  }

  Future<void> updateOrder(List<SpecialOffer> newOrder) async {
    final oldState = [...state];
    if (mounted) state = newOrder;
    for (int i = 0; i < newOrder.length; i++) {
      try {
        await SupabaseConfig.client
            .from('special_offers')
            .update({'display_order': i})
            .eq('id', newOrder[i].id);
      } catch (e) {
          debugPrint('Update special offer order error: $e');
          if (mounted) state = oldState;
      }
    }
  }

  Future<String?> toggleStatus(String id) async {
    final oldState = [...state];
    final offer = state.firstWhere((o) => o.id == id);
    if (mounted) {
      state = [
        for (final o in state)
          if (o.id == id) o.copyWith(isActive: !o.isActive) else o
      ];
    }
    try {
      await SupabaseConfig.client
          .from('special_offers')
          .update({'active': !offer.isActive})
          .eq('id', id);
      return null;
    } catch (e) {
      debugPrint('Toggle special offer status error: $e');
      if (mounted) state = oldState;
      return e.toString();
    }
  }
}

final specialOfferProvider =
    StateNotifierProvider<SpecialOfferRepository, List<SpecialOffer>>((ref) {
  return SpecialOfferRepository();
});

final activeSpecialOffersProvider = Provider<List<SpecialOffer>>((ref) {
  final offers = ref.watch(specialOfferProvider);
  final active = offers.where((o) => o.isActive).toList()
    ..sort((a, b) => a.order.compareTo(b.order));
  return active;
});

