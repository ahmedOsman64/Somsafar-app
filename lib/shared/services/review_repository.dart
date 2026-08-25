import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/review_model.dart';
import '../models/user_model.dart';
import '../../core/services/supabase_service.dart';
import 'auth_service.dart';
import 'service_repository.dart';

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
        _initStream();
        fetchReviews();
      }
    }, fireImmediately: true);
  }

  void _initStream() {
    _subscription?.cancel();

    _subscription = SupabaseConfig.client
        .from('reviews')
        .stream(primaryKey: ['id'])
        .listen((data) {
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

  Future<void> replyToReview(String reviewId, String replyText) async {
    final now = DateTime.now();
    final oldState = [...state];

    // Optimistic update
    state = state.map((r) {
      if (r.id == reviewId) {
        return r.copyWith(
          providerReply: replyText,
          providerRepliedAt: now,
        );
      }
      return r;
    }).toList();

    try {
      await SupabaseConfig.client.from('reviews').update({
        'provider_reply': replyText,
        'provider_replied_at': now.toIso8601String(),
      }).eq('id', reviewId);
    } catch (e) {
      debugPrint('Reply to review error: $e');
      if (mounted) state = oldState;
    }
  }

  Future<void> generateSampleReview({
    required String providerId,
    required String serviceId,
    required String serviceTitle,
  }) async {
    final newId = const Uuid().v4();
    final sampleReview = Review(
      id: newId,
      serviceId: serviceId,
      providerId: providerId,
      serviceTitle: serviceTitle,
      travelerId: 'guest-user-101',
      travelerName: 'Mohamed Ali',
      rating: 5,
      comment: 'Excellent service and friendly hospitality! Everything went smoothly during our stay.',
      createdAt: DateTime.now(),
    );

    await addReview(sampleReview);
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

final reviewProvider =
    StateNotifierProvider<ReviewRepository, List<Review>>((ref) {
  return ReviewRepository(ref);
});

// Selector for filtered reviews (specific to provider or all for admin)
final filteredReviewsProvider = Provider<List<Review>>((ref) {
  final user = ref.watch(authProvider);
  final reviews = ref.watch(reviewProvider);
  final services = ref.watch(serviceProvider);

  if (user == null) return [];

  if (user.role == UserRole.admin) {
    return reviews;
  }

  if (user.role == UserRole.provider || user.role == UserRole.providerHelper) {
    final providerKey = (user.providerId != null && user.providerId!.isNotEmpty)
        ? user.providerId!
        : user.id;

    final myServiceIds = services
        .where((s) => s.providerId == providerKey)
        .map((s) => s.id)
        .toSet();

    return reviews.where((r) {
      final matchesProviderId = r.providerId == providerKey;
      final matchesServiceId = myServiceIds.contains(r.serviceId);
      return matchesProviderId || matchesServiceId;
    }).toList();
  }

  return reviews.where((r) => r.travelerId == user.id).toList();
});
