import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/highlight_model.dart';
import '../../core/services/supabase_service.dart';

class HighlightRepository extends StateNotifier<List<TravelHighlight>> {
  StreamSubscription? _subscription;

  HighlightRepository() : super([]) {
    _initStream();
    refresh(); // Fetch initial data
  }

  void _initStream() {
    _subscription?.cancel();
    _subscription = SupabaseConfig.client
        .from('travel_highlights')
        .stream(primaryKey: ['id'])
        .order('display_order', ascending: true)
        .listen(
      (data) {
        if (!mounted) return;
        state = data.map((res) => TravelHighlight.fromMap(res)).toList();
      },
      onError: (e) {
        debugPrint('Highlight stream error: $e');
      },
    );
  }

  Future<void> refresh() async {
    try {
      final data = await SupabaseConfig.client
          .from('travel_highlights')
          .select()
          .order('display_order', ascending: true);

      if (!mounted) return;
      final highlights = (data as List).map((res) => TravelHighlight.fromMap(res)).toList();
      debugPrint('DEBUG: Fetched ${highlights.length} highlights from DB');
      state = highlights;
    } catch (e) {
      debugPrint('Highlight refresh error: $e');
    }
  }

  Future<String?> addHighlight({
    required String title,
    required String location,
    required String imageUrl,
    required String tag,
  }) async {
    final id = const Uuid().v4();
    final nextOrder = state.isEmpty ? 0 : state.length;

    try {
      await SupabaseConfig.client.from('travel_highlights').insert({
        'id': id,
        'title': title,
        'location': location,
        'image_url': imageUrl,
        'tag': tag,
        'display_order': nextOrder,
        'active': true,
      });
      return null;
    } catch (e) {
      debugPrint('Add highlight error: $e');
      return 'Failed to add highlight: $e';
    }
  }

  Future<String?> updateHighlight(
    String id, {
    String? title,
    String? location,
    String? imageUrl,
    String? tag,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (title != null) updates['title'] = title;
      if (location != null) updates['location'] = location;
      if (imageUrl != null) updates['image_url'] = imageUrl;
      if (tag != null) updates['tag'] = tag;

      await SupabaseConfig.client
          .from('travel_highlights')
          .update(updates)
          .eq('id', id);

      return null;
    } catch (e) {
      debugPrint('Update highlight error: $e');
      return 'Failed to update highlight: $e';
    }
  }

  Future<void> removeHighlight(String id) async {
    final oldState = [...state];
    try {
      state = state.where((h) => h.id != id).toList();
      await SupabaseConfig.client.from('travel_highlights').delete().eq('id', id);
    } catch (e) {
      debugPrint('Remove highlight error: $e');
      state = oldState;
    }
  }

  Future<void> toggleStatus(String id) async {
    final oldState = [...state];
    final highlightIndex = state.indexWhere((h) => h.id == id);
    if (highlightIndex == -1) return;

    final highlight = state[highlightIndex];
    final newStatus = !highlight.isActive;

    state = [
      for (final h in state)
        if (h.id == id) h.copyWith(isActive: newStatus) else h,
    ];

    try {
      await SupabaseConfig.client
          .from('travel_highlights')
          .update({'active': newStatus}).eq('id', id);
    } catch (e) {
      debugPrint('Toggle highlight status error: $e');
      state = oldState;
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

final highlightProvider =
    StateNotifierProvider<HighlightRepository, List<TravelHighlight>>((ref) {
  return HighlightRepository();
});

final activeHighlightsProvider = Provider<List<TravelHighlight>>((ref) {
  final highlights = ref.watch(highlightProvider);
  return highlights.where((h) => h.isActive).toList()
    ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
});
