import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/review_model.dart';
import 'package:flutter/foundation.dart';
import '../../core/services/supabase_service.dart';
import '../models/user_model.dart';
import 'auth_service.dart';



class ReviewRepository extends StateNotifier<List<Review>> {
  final Ref _ref;
  StreamSubscription? _subscription;

  ReviewRepository(this._ref) : super([]) {
    _listenToAuth();
  }

  void _listenToAuth() {
    _ref.listen<User?>(authProvider, (previous, next) {
      if (next == null) {
        _subscription?.cancel();
        _subscription = null;
        state = [];
      } else if (previous?.id != next.id) {
        _initStream(next);
      }
    }, fireImmediately: true);
  }

  void _initStream(User user) {
    _subscription?.cancel();
    
    dynamic query = SupabaseConfig.client
        .from('reviews')
        .stream(primaryKey: ['id']);

    // DB-level filtering based on role to save bandwidth
    if (user.role == UserRole.provider || user.role == UserRole.providerHelper) {
      final providerKey = user.providerId ?? user.id;
      query = query.eq('provider_id', providerKey);
    } else if (user.role == UserRole.traveler) {
      query = query.eq('traveler_id', user.id);
    }
    // Admins see everything (no filter)

    _subscription = query.listen((data) {
      if (!mounted) return;
      state = data.map((res) => Review.fromMap(res)).toList();
    }, onError: (e) => debugPrint('Review stream error: $e'));
  }

  Future<void> fetchReviews() async {
    try {
      final data = await SupabaseConfig.client.from('reviews').select();
      if (!mounted) return;
      state = data.map((res) => Review.fromMap(res)).toList();
    } catch (e) {
      debugPrint('Fetch reviews error: $e');
    }
  }

  Future<void> addReview(Review review) async {
    final oldState = [...state];
    if (mounted) state = [...state, review];
    try {
      await SupabaseConfig.client.from('reviews').insert(review.toMap());
    } catch (e) {
      debugPrint('Add review error: $e');
      if (mounted) state = oldState;
    }
  }

  Future<void> deleteReview(String id) async {
    final oldState = [...state];
    if (mounted) state = state.where((r) => r.id != id).toList();
    try {
      await SupabaseConfig.client.from('reviews').delete().eq('id', id);
    } catch (e) {
      debugPrint('Delete review error: $e');
      if (mounted) state = oldState;
    }
  }
}

final reviewProvider = StateNotifierProvider<ReviewRepository, List<Review>>((ref) {
  return ReviewRepository(ref);
});

// Selector for filtered reviews (specific to provider or all for admin)
final filteredReviewsProvider = Provider<List<Review>>((ref) {
  final user = ref.watch(authProvider);
  final reviews = ref.watch(reviewProvider);

  if (user == null) return [];

  if (user.role == UserRole.admin) {
    return reviews;
  }

  if (user.role == UserRole.provider || user.role == UserRole.providerHelper) {
    final providerKey = user.providerId ?? user.id;
    return reviews.where((r) => r.providerId == providerKey).toList();
  }

  return reviews.where((r) => r.travelerId == user.id).toList();
});
