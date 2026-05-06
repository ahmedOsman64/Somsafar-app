import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/banner_model.dart';
import '../../core/services/supabase_service.dart';

class BannerRepository extends StateNotifier<List<BannerImage>> {
  StreamSubscription? _subscription;

  BannerRepository() : super([]) {
    _initStream();
  }

  void _initStream() {
    _subscription?.cancel();
    _subscription = SupabaseConfig.client
        .from('banners')
        .stream(primaryKey: ['id'])
        .order('display_order', ascending: true)
        .listen(
      (data) {
        if (!mounted) return;
        state = data.map((res) {
          return BannerImage(
            id: res['id'],
            imageUrl: res['image_url'],
            caption: res['caption'],
            order: res['display_order'] ?? 0,
            isActive: res['active'] ?? true,
          );
        }).toList();
      },
      onError: (e) {
        debugPrint('Banner stream error: $e');
      },
    );
  }

  /// Force reload from Supabase (manual refresh)
  Future<void> refresh() async {
    try {
      final data = await SupabaseConfig.client
          .from('banners')
          .select()
          .order('display_order', ascending: true);

      if (!mounted) return;
      state = (data as List).map((res) {
        return BannerImage(
          id: res['id'],
          imageUrl: res['image_url'],
          caption: res['caption'],
          order: res['display_order'] ?? 0,
          isActive: res['active'] ?? true,
        );
      }).toList();
    } catch (e) {
      debugPrint('Banner refresh error: $e');
    }
  }

  Future<String?> addBanner(String imageUrl, String? caption) async {
    if (state.length >= 10) {
      return 'Maximum 10 images allowed.';
    }

    final id = const Uuid().v4();
    final nextOrder = state.isEmpty ? 0 : state.length;

    try {
      await SupabaseConfig.client.from('banners').insert({
        'id': id,
        'image_url': imageUrl,
        'caption': caption?.isEmpty == true ? null : caption,
        'display_order': nextOrder,
        'active': true,
      });
      return null;
    } catch (e) {
      debugPrint('Add banner error: $e');
      return 'Failed to add banner: $e';
    }
  }

  Future<String?> updateBanner(
    String id, {
    String? imageUrl,
    String? caption,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (imageUrl != null) updates['image_url'] = imageUrl;
      updates['caption'] = caption?.isEmpty == true ? null : caption;

      await SupabaseConfig.client
          .from('banners')
          .update(updates)
          .eq('id', id);

      return null;
    } catch (e) {
      debugPrint('Update banner error: $e');
      return 'Failed to update banner: $e';
    }
  }

  Future<void> removeBanner(String id) async {
    final oldState = [...state];
    try {
      // Optimistic Update
      state = state.where((b) => b.id != id).toList();
      await SupabaseConfig.client.from('banners').delete().eq('id', id);
    } catch (e) {
      debugPrint('Remove banner error: $e');
      state = oldState;
    }
  }

  Future<void> updateOrder(List<BannerImage> newOrder) async {
    // Optimistic Update
    state = newOrder;

    for (int i = 0; i < newOrder.length; i++) {
      try {
        await SupabaseConfig.client
            .from('banners')
            .update({'display_order': i}).eq('id', newOrder[i].id);
      } catch (e) {
        debugPrint('Update banner order error: $e');
      }
    }
  }

  Future<void> toggleStatus(String id) async {
    final oldState = [...state];
    final bannerIndex = state.indexWhere((b) => b.id == id);
    if (bannerIndex == -1) return;

    final banner = state[bannerIndex];
    final newStatus = !banner.isActive;

    // Optimistic Update
    state = [
      for (final b in state)
        if (b.id == id) b.copyWith(isActive: newStatus) else b,
    ];

    try {
      await SupabaseConfig.client
          .from('banners')
          .update({'active': newStatus}).eq('id', id);
    } catch (e) {
      debugPrint('Toggle banner status error: $e');
      state = oldState;
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

final bannerProvider =
    StateNotifierProvider<BannerRepository, List<BannerImage>>((ref) {
      return BannerRepository();
    });

final activeBannersProvider = Provider<List<BannerImage>>((ref) {
  final banners = ref.watch(bannerProvider);
  final active = banners.where((b) => b.isActive).toList()
    ..sort((a, b) => a.order.compareTo(b.order));

  // If no active banners, return the default fallback image
  if (active.isEmpty) {
    return [
      const BannerImage(
        id: 'fallback',
        imageUrl:
            'https://images.unsplash.com/photo-1476514525535-07fb3b4ae5f1?q=80&w=1974&auto=format&fit=crop',
        caption: 'Welcome to SomSafar',
        order: 0,
      ),
    ];
  }
  return active;
});
