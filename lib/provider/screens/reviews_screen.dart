import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/services/review_repository.dart';
import '../../shared/services/service_repository.dart';
import '../../shared/services/auth_service.dart';
import '../../shared/models/review_model.dart';
import '../../core/widgets/responsive.dart';

final reviewSearchQueryProvider = StateProvider<String>((ref) => '');
final reviewRatingFilterProvider = StateProvider<int>((ref) => 0); // 0 = All

class ProviderReviewsScreen extends ConsumerStatefulWidget {
  const ProviderReviewsScreen({super.key});

  @override
  ConsumerState<ProviderReviewsScreen> createState() =>
      _ProviderReviewsScreenState();
}

class _ProviderReviewsScreenState extends ConsumerState<ProviderReviewsScreen> {
  final TextEditingController _replyController = TextEditingController();
  bool _isReplying = false;

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  void _showReplyDialog(Review review) {
    _replyController.text = review.providerReply ?? '';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(20),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.reply_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text('Reply to Review'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Review from ${review.travelerName}:',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '"${review.comment}"',
                    style: const TextStyle(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _replyController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Write a polite & professional response...',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.primary),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  onPressed: _isReplying
                      ? null
                      : () async {
                          final text = _replyController.text.trim();
                          if (text.isEmpty) return;

                          setModalState(() => _isReplying = true);
                          await ref
                              .read(reviewProvider.notifier)
                              .replyToReview(review.id, text);
                          if (mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Row(
                                  children: [
                                    Icon(Icons.check_circle,
                                        color: Colors.white, size: 18),
                                    SizedBox(width: 8),
                                    Text('Reply posted successfully!'),
                                  ],
                                ),
                                backgroundColor: const Color(0xFF10B981),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            );
                          }
                        },
                  icon: _isReplying
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_rounded, size: 16),
                  label: const Text('Post Reply'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _createSampleReview() async {
    final user = ref.read(authProvider);
    final services = ref.read(serviceProvider);
    if (user == null) return;

    final providerKey = user.providerId ?? user.id;
    final myServices = services
        .where((s) => s.providerId == providerKey)
        .toList();

    final serviceId = myServices.isNotEmpty ? myServices.first.id : 'demo-s1';
    final serviceTitle =
        myServices.isNotEmpty ? myServices.first.title : 'Hotel Room Service';

    await ref.read(reviewProvider.notifier).generateSampleReview(
          providerId: providerKey,
          serviceId: serviceId,
          serviceTitle: serviceTitle,
        );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.stars_rounded, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('Sample 5-Star Customer Review Generated!'),
            ],
          ),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final reviews = ref.watch(filteredReviewsProvider);
    final searchQuery = ref.watch(reviewSearchQueryProvider);
    final selectedRating = ref.watch(reviewRatingFilterProvider);

    // Calculate rating stats
    double avgRating = 0;
    if (reviews.isNotEmpty) {
      avgRating =
          reviews.map((r) => r.rating).reduce((a, b) => a + b) / reviews.length;
    }

    final positiveFeedback = reviews.isEmpty
        ? '0%'
        : '${((reviews.where((r) => r.rating >= 4).length / reviews.length) * 100).toStringAsFixed(0)}%';

    // Count rating breakdown (5★ to 1★)
    final Map<int, int> ratingCounts = {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
    for (final r in reviews) {
      final key = r.rating.clamp(1, 5);
      ratingCounts[key] = (ratingCounts[key] ?? 0) + 1;
    }

    // Filter reviews by search query and rating tab
    final filteredList = reviews.where((r) {
      final matchesQuery = searchQuery.isEmpty ||
          r.travelerName.toLowerCase().contains(searchQuery.toLowerCase()) ||
          r.comment.toLowerCase().contains(searchQuery.toLowerCase()) ||
          r.serviceTitle.toLowerCase().contains(searchQuery.toLowerCase());

      final matchesRating = selectedRating == 0 || r.rating == selectedRating;

      return matchesQuery && matchesRating;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ── Full-Width Header Banner ────────────────────────
            _buildHeader(
              context,
              avgRating.toStringAsFixed(1),
              reviews.length,
              positiveFeedback,
              ratingCounts,
            ),

            const SizedBox(height: 24),

            // ── Search & Rating Filter Controls ─────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildFilterBar(ref, searchQuery, selectedRating),
            ),

            const SizedBox(height: 20),

            // ── Reviews List / Empty State ──────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: filteredList.isEmpty
                  ? _buildEmptyState(reviews.isEmpty)
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filteredList.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 16),
                      itemBuilder: (context, index) =>
                          _buildReviewCard(filteredList[index]),
                    ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    String avg,
    int total,
    String positive,
    Map<int, int> ratingCounts,
  ) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E3A8A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(context.isMobile ? 0 : 32),
          bottomRight: Radius.circular(context.isMobile ? 0 : 32),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, 20, 24, context.isMobile ? 24 : 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(25),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.rate_review_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Customer Feedback',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'Reviews, ratings & customer responses',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: _createSampleReview,
                    icon: const Icon(Icons.add_comment_rounded, size: 16),
                    label: const Text('Add Demo Review'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Overall Stats Grid
              LayoutBuilder(
                builder: (context, constraints) {
                  final isDesktop = constraints.maxWidth > 700;
                  if (isDesktop) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          flex: 2,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildHeaderStat(avg, 'Average Rating', Icons.star_rounded),
                              _buildHeaderStat('$total', 'Total Reviews', Icons.forum_rounded),
                              _buildHeaderStat(positive, 'Positive Score', Icons.thumb_up_alt_rounded),
                            ],
                          ),
                        ),
                        Container(
                          height: 70,
                          width: 1,
                          color: Colors.white.withAlpha(40),
                          margin: const EdgeInsets.symmetric(horizontal: 20),
                        ),
                        Expanded(
                          flex: 3,
                          child: _buildRatingBars(total, ratingCounts),
                        ),
                      ],
                    );
                  }
                  return Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildHeaderStat(avg, 'Average Rating', Icons.star_rounded),
                          _buildHeaderStat('$total', 'Total Reviews', Icons.forum_rounded),
                          _buildHeaderStat(positive, 'Positive Score', Icons.thumb_up_alt_rounded),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _buildRatingBars(total, ratingCounts),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderStat(String value, String label, IconData icon) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppColors.secondary, size: 26),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.white70),
        ),
      ],
    );
  }

  Widget _buildRatingBars(int total, Map<int, int> counts) {
    return Column(
      children: [5, 4, 3, 2, 1].map((star) {
        final count = counts[star] ?? 0;
        final pct = total > 0 ? count / total : 0.0;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              SizedBox(
                width: 24,
                child: Text(
                  '$star★',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 6,
                    backgroundColor: Colors.white.withAlpha(20),
                    color: AppColors.secondary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 30,
                child: Text(
                  '$count',
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFilterBar(WidgetRef ref, String query, int selectedRating) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (val) {
                    ref.read(reviewSearchQueryProvider.notifier).state = val;
                  },
                  decoration: InputDecoration(
                    hintText: 'Search customer name, comment, or service...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey[200]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey[200]!),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildRatingChip(ref, 'All Ratings', 0, selectedRating),
                _buildRatingChip(ref, '5 Stars ⭐', 5, selectedRating),
                _buildRatingChip(ref, '4 Stars ⭐', 4, selectedRating),
                _buildRatingChip(ref, '3 Stars ⭐', 3, selectedRating),
                _buildRatingChip(ref, '2 Stars ⭐', 2, selectedRating),
                _buildRatingChip(ref, '1 Star ⭐', 1, selectedRating),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingChip(
    WidgetRef ref,
    String label,
    int rating,
    int selectedRating,
  ) {
    final isSelected = rating == selectedRating;
    return GestureDetector(
      onTap: () {
        ref.read(reviewRatingFilterProvider.notifier).state = rating;
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF0F172A),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool noReviewsAtAll) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(Icons.rate_review_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            noReviewsAtAll ? 'No customer reviews yet' : 'No matching reviews',
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            noReviewsAtAll
                ? 'Customer feedback will appear here once travelers complete & review your services.'
                : 'Try adjusting your search query or rating filter.',
            style: TextStyle(color: Colors.grey[500], fontSize: 13),
            textAlign: TextAlign.center,
          ),
          if (noReviewsAtAll) ...[
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _createSampleReview,
              icon: const Icon(Icons.add_comment_rounded, size: 18),
              label: const Text('Generate Demo Review To Test'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReviewCard(Review review) {
    final formattedDate = DateFormat.yMMMd().format(review.createdAt);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: User & Rating
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.primary.withAlpha(20),
                    child: Text(
                      review.travelerName.isNotEmpty
                          ? review.travelerName[0].toUpperCase()
                          : 'G',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        review.travelerName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        '${review.serviceTitle} · $formattedDate',
                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ],
              ),
              Row(
                children: List.generate(
                  5,
                  (index) => Icon(
                    index < review.rating
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    color: Colors.amber,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Comment
          Text(
            '"${review.comment}"',
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF334155),
              height: 1.4,
            ),
          ),

          const SizedBox(height: 14),

          // Provider Reply Bubble
          if (review.providerReply != null && review.providerReply!.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
                border: Border(
                  left: BorderSide(color: AppColors.primary, width: 3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.reply_rounded,
                              size: 14, color: AppColors.primary),
                          SizedBox(width: 6),
                          Text(
                            'Your Response (Provider)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      if (review.providerRepliedAt != null)
                        Text(
                          DateFormat.yMMMd().format(review.providerRepliedAt!),
                          style:
                              TextStyle(fontSize: 10, color: Colors.grey[500]),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    review.providerReply!,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF0F172A),
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 10),

          // Reply Action Button
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _showReplyDialog(review),
              icon: Icon(
                review.providerReply != null
                    ? Icons.edit_rounded
                    : Icons.reply_rounded,
                size: 14,
                color: AppColors.primary,
              ),
              label: Text(
                review.providerReply != null ? 'Edit Reply' : 'Reply to Customer',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
