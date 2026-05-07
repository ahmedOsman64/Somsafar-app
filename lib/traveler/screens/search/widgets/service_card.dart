import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/widgets/app_network_image.dart';
import '../../../../core/theme/app_colors.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/services/recently_viewed_provider.dart';
import '../../../../shared/services/favorites_provider.dart';
import '../../../../shared/models/service_model.dart';
import '../../../../shared/services/discount_repository.dart';
import '../../../../core/services/storage_service.dart';

class ServiceCard extends ConsumerStatefulWidget {
  final dynamic service;
  final bool isGrid;

  const ServiceCard({super.key, required this.service, required this.isGrid});

  @override
  ConsumerState<ServiceCard> createState() => _ServiceCardState();
}

class _ServiceCardState extends ConsumerState<ServiceCard> {
  bool _isHovered = false;
  int _currentImageIndex = 0;
  void _toggleFavorite() {
    ref
        .read(favoritesProvider.notifier)
        .toggleFavorite(widget.service as Service);
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () {
          if (widget.service.id.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Invalid service ID.')),
            );
            return;
          }
          // Add to recently viewed
          ref.read(recentlyViewedProvider.notifier).addService(widget.service);
          // Navigate to details
          context.push(
            '/traveler/service/${widget.service.id}',
            extra: widget.service,
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: _isHovered ? 0.1 : 0.04),
                blurRadius: _isHovered ? 24 : 12,
                offset: Offset(0, _isHovered ? 12 : 6),
                spreadRadius: _isHovered ? 1 : -2,
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: widget.isGrid ? _buildGridCard() : _buildListCard(),
        ),
      ),
    );
  }

  Widget _buildGridCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Image Section with Slider and Actions
        Expanded(
          flex: 4,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Image Slider
              _buildImageSlider(),

              // Discount Badge
              _buildDiscountBadge(),

              // Category Badge
              _buildCategoryBadge(),

              // Top Actions
              _buildTopActions(),
            ],
          ),
        ),

        // Content Section
        Expanded(
          flex: 6,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title and Rating
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        widget.service.title,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    _buildRatingBadge(),
                  ],
                ),
                const SizedBox(height: 4),

                Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 12,
                      color: AppColors.primary.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        widget.service.location,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // Highlights
                _buildHighlights(),

                const Spacer(),

                // Booking Box
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade100),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              (widget.service.category
                                      .toString()
                                      .toLowerCase()
                                      .contains('apartment'))
                                  ? 'Price per month'
                                  : (widget.service.category
                                        .toString()
                                        .toLowerCase()
                                        .contains('tour'))
                                  ? 'Price per person'
                                  : 'Price per night',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade500,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Builder(
                                    builder: (context) {
                                      final discounts = ref.watch(
                                        discountRepositoryProvider,
                                      );
                                      final activeDiscount =
                                          DiscountRepository.getBestDiscount(
                                            discounts,
                                            widget.service.id,
                                            widget.service.providerId,
                                          );

                                      if (activeDiscount == null) {
                                        return Text(
                                          '\$${widget.service.price}',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primary,
                                          ),
                                        );
                                      }

                                      double finalPrice = widget.service.price;
                                      if (activeDiscount.isPercentage) {
                                        finalPrice -=
                                            widget.service.price *
                                            (activeDiscount.value / 100);
                                      } else {
                                        finalPrice -= activeDiscount.value;
                                      }

                                      return Row(
                                        children: [
                                          Text(
                                            '\$${widget.service.price}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade400,
                                              decoration:
                                                  TextDecoration.lineThrough,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '\$${finalPrice.toStringAsFixed(0)}',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    (widget.service.category
                                            .toString()
                                            .toLowerCase()
                                            .contains('apartment'))
                                        ? '/mo'
                                        : (widget.service.category
                                              .toString()
                                              .toLowerCase()
                                              .contains('tour'))
                                        ? '/person'
                                        : '/nt',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      // Actions
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: () {
                              if (widget.service.id.isEmpty) return;
                              context.push(
                                '/traveler/booking/${widget.service.id}',
                                extra: widget.service,
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.2,
                                    ),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Text(
                                'Book',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildListCard() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 650;
        final isSmall = constraints.maxWidth < 500;

        return SizedBox(
          height: isSmall ? 155 : (isNarrow ? 180 : 200),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left: Image Slider
              SizedBox(
                width: isSmall ? 120 : (isNarrow ? 160 : 220),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildImageSlider(),
                    if (!isSmall) _buildTopActions(),
                    _buildDiscountBadge(),
                    _buildCategoryBadge(),
                  ],
                ),
              ),

              // Center: Details
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(isSmall ? 8 : 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.service.title,
                                  style: TextStyle(
                                    fontSize: isSmall
                                        ? 14
                                        : (isNarrow ? 15 : 18),
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.location_on,
                                      size: isSmall ? 11 : 13,
                                      color: AppColors.primary,
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        widget.service.location,
                                        style: TextStyle(
                                          fontSize: isSmall
                                              ? 11
                                              : (isNarrow ? 12 : 14),
                                          color: Colors.grey.shade600,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          _buildRatingBadge(),
                        ],
                      ),
                      if (!isSmall) ...[
                        const SizedBox(height: 8),
                        Text(
                          widget.service.description,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                          maxLines: isNarrow ? 1 : 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const Spacer(),
                      if (isSmall)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  (widget.service.category
                                          .toString()
                                          .toLowerCase()
                                          .contains('apartment'))
                                      ? 'Price/month'
                                      : (widget.service.category
                                            .toString()
                                            .toLowerCase()
                                            .contains('tour'))
                                      ? 'Price/person'
                                      : 'Price/night',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey,
                                  ),
                                ),
                                Builder(
                                  builder: (context) {
                                    final discounts = ref.watch(
                                      discountRepositoryProvider,
                                    );
                                    final activeDiscount =
                                        DiscountRepository.getBestDiscount(
                                          discounts,
                                          widget.service.id,
                                          widget.service.providerId,
                                        );

                                    if (activeDiscount == null) {
                                      return Text(
                                        '\$${widget.service.price}',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primary,
                                        ),
                                      );
                                    }

                                    double finalPrice = widget.service.price;
                                    if (activeDiscount.isPercentage) {
                                      finalPrice -=
                                          widget.service.price *
                                          (activeDiscount.value / 100);
                                    } else {
                                      finalPrice -= activeDiscount.value;
                                    }

                                    return Row(
                                      children: [
                                        Text(
                                          '\$${widget.service.price}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade400,
                                            decoration:
                                                TextDecoration.lineThrough,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '\$${finalPrice.toStringAsFixed(0)}',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                OutlinedButton(
                                  onPressed: () {
                                    if (widget.service.id.isEmpty) return;
                                    context.push(
                                      '/traveler/service/${widget.service.id}',
                                      extra: widget.service,
                                    );
                                  },
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.primary,
                                    side: BorderSide(
                                      color: AppColors.primary.withValues(
                                        alpha: 0.3,
                                      ),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    minimumSize: const Size(50, 32),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: const Text(
                                    'View',
                                    style: TextStyle(fontSize: 11),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: () {
                                    if (widget.service.id.isEmpty) return;
                                    context.push(
                                      '/traveler/booking/${widget.service.id}',
                                      extra: widget.service,
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    minimumSize: const Size(50, 32),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: const Text(
                                    'Book',
                                    style: TextStyle(fontSize: 11),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        )
                      else
                        _buildAmenitiesRow(maxItems: isNarrow ? 3 : 5),
                    ],
                  ),
                ),
              ),

              if (!isSmall) ...[
                // Vertical Divider
                Container(
                  width: 1,
                  color: Colors.grey.shade100,
                  margin: const EdgeInsets.symmetric(vertical: 16),
                ),

                // Right: Booking Box
                Container(
                  width: isNarrow ? 140 : 170,
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Spacer(),
                      Text(
                        (widget.service.category
                                .toString()
                                .toLowerCase()
                                .contains('apartment'))
                            ? 'Price/month'
                            : (widget.service.category
                                  .toString()
                                  .toLowerCase()
                                  .contains('tour'))
                            ? 'Price/person'
                            : 'Price/night',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                      Builder(
                        builder: (context) {
                          final discounts = ref.watch(
                            discountRepositoryProvider,
                          );
                          final activeDiscount =
                              DiscountRepository.getBestDiscount(
                                discounts,
                                widget.service.id,
                                widget.service.providerId,
                              );

                          if (activeDiscount == null) {
                            return Text(
                              '\$${widget.service.price}',
                              style: TextStyle(
                                fontSize: isNarrow ? 18 : 22,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            );
                          }

                          double finalPrice = widget.service.price;
                          if (activeDiscount.isPercentage) {
                            finalPrice -=
                                widget.service.price *
                                (activeDiscount.value / 100);
                          } else {
                            finalPrice -= activeDiscount.value;
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '\$${widget.service.price}',
                                style: TextStyle(
                                  fontSize: isNarrow ? 12 : 14,
                                  color: Colors.grey.shade400,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                              Text(
                                '\$${finalPrice.toStringAsFixed(0)}',
                                style: TextStyle(
                                  fontSize: isNarrow ? 18 : 22,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 4),
                      const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle,
                            size: 10,
                            color: Colors.green,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Available',
                            style: TextStyle(fontSize: 10, color: Colors.green),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                if (widget.service.id.isEmpty) return;
                                context.push(
                                  '/traveler/service/${widget.service.id}',
                                  extra: widget.service,
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                side: BorderSide(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.3,
                                  ),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Text(
                                'View',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: isNarrow ? 11 : 13,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                if (widget.service.id.isEmpty) return;
                                context.push(
                                  '/traveler/booking/${widget.service.id}',
                                  extra: widget.service,
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                elevation: 0,
                              ),
                              child: Text(
                                'Book',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: isNarrow ? 11 : 13,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  /// Returns fallback image URLs based on category when the service has none.
  List<String> _getEffectiveImages() {
    final stored = widget.service.images as List<dynamic>;
    if (stored.isNotEmpty) {
      return stored
          .map((e) => StorageService.ensurePublicUrl(e.toString()))
          .toList();
    }

    // Generate 3 beautiful fallback images per category
    final category = (widget.service.category as String? ?? '').toLowerCase();
    final seed = widget.service.id.hashCode.abs();

    const categorySeeds = {
      'hotel': ['hotel', 'luxury', 'resort'],
      'apartment': ['apartment', 'interior', 'room'],
      'tour': ['travel', 'landscape', 'adventure'],
      'transport': ['car', 'road', 'vehicle'],
    };

    final seeds = categorySeeds[category] ?? ['somalia', 'beach', 'nature'];

    return List.generate(
      3,
      (i) =>
          'https://picsum.photos/seed/${seeds[i % seeds.length]}${seed + i}/600/400',
    );
  }

  Widget _buildImageSlider() {
    final images = _getEffectiveImages();

    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            itemCount: images.length,
            onPageChanged: (index) =>
                setState(() => _currentImageIndex = index),
            itemBuilder: (context, index) {
              return AnimatedScale(
                scale: _isHovered ? 1.05 : 1.0,
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutCubic,
                child: AppNetworkImage(
                  imageUrl: images[index],
                  fit: BoxFit.cover,
                ),
              );
            },
          ),

          // Dots Indicator
          if (images.length > 1)
            Positioned(
              bottom: 8,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  images.length > 5 ? 5 : images.length,
                  (index) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    width: _currentImageIndex == index ? 8 : 6,
                    height: _currentImageIndex == index ? 8 : 6,
                    decoration: BoxDecoration(
                      color: _currentImageIndex == index
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 2,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTopActions() {
    final isFavorite = ref
        .watch(favoritesProvider)
        .any((s) => s.id == widget.service.id);
    return Positioned(
      top: 8,
      right: 8,
      child: Column(
        children: [
          _QuickActionButton(
            icon: isFavorite ? Icons.favorite : Icons.favorite_border,
            color: isFavorite ? Colors.red : Colors.black87,
            onTap: _toggleFavorite,
            tooltip: 'Save to favorites',
          ),
          if (_isHovered) ...[
            const SizedBox(height: 8),
            _QuickActionButton(
              icon: Icons.compare_arrows_rounded,
              color: Colors.black87,
              onTap: () {},
              tooltip: 'Compare',
            ),
            const SizedBox(height: 8),
            _QuickActionButton(
              icon: Icons.remove_red_eye_outlined,
              color: Colors.black87,
              onTap: () {},
              tooltip: 'Quick Preview',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDiscountBadge() {
    final discounts = ref.watch(discountRepositoryProvider);
    final activeDiscount = DiscountRepository.getBestDiscount(
      discounts,
      widget.service.id,
      widget.service.providerId,
    );

    if (activeDiscount != null) {
      return Positioned(
        bottom: 12,
        left: 8,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.secondary,
            borderRadius: BorderRadius.circular(4),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.local_offer_rounded,
                size: 12,
                color: Colors.white,
              ),
              const SizedBox(width: 4),
              Text(
                activeDiscount.badgeText,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Only showing stub discount badge for styling demonstration
    if (widget.service.rating != null &&
        widget.service.rating! >= 4.5 &&
        !widget.isGrid) {
      return Positioned(
        top: 8,
        left: 8,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.orange.shade600,
            borderRadius: BorderRadius.circular(4),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.local_fire_department, size: 12, color: Colors.white),
              SizedBox(width: 4),
              Text(
                'Top Rated',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildCategoryBadge() {
    final String category = widget.service.category;
    IconData icon = Icons.help_outline;
    if (category.toLowerCase().contains('hotel')) {
      icon = Icons.hotel_outlined;
    }
    if (category.toLowerCase().contains('apartment') ||
        category.toLowerCase().contains('home')) {
      icon = Icons.apartment_outlined;
    }
    if (category.toLowerCase().contains('tour')) {
      icon = Icons.explore_outlined;
    }
    if (category.toLowerCase().contains('transport')) {
      icon = Icons.airport_shuttle;
    }

    return Positioned(
      top: 12,
      left: 12,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppColors.primary),
            const SizedBox(width: 6),
            Text(
              category,
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHighlights() {
    final category = widget.service.category.toLowerCase();
    final metadata = widget.service.metadata;

    List<Widget> highlights = [];

    if (category.contains('hotel')) {
      // final rooms = metadata['rooms']?.toString() ?? '1+';
      // final stars = metadata['starRating']?.toString() ?? '4';
      highlights = [
        // _buildHighlightItem(Icons.hotel_outlined, '$rooms Rooms'),
        // _buildHighlightItem(Icons.star_outline_rounded, '$stars Stars'),
        if (widget.service.maxGuests != null)
          _buildHighlightItem(
            Icons.people_outline_rounded,
            '${widget.service.maxGuests} Guests',
          ),
        if (metadata['breakfastIncluded'] == true)
          _buildHighlightItem(Icons.restaurant_outlined, 'Breakfast'),
      ];
    } else if (category.contains('apartment') || category.contains('home')) {
      // final rooms = metadata['rooms']?.toString() ?? '1';
      final beds = metadata['bedrooms']?.toString() ?? '1';
      final guests = metadata['maxGuests']?.toString() ?? '2';
      highlights = [
        // _buildHighlightItem(Icons.door_front_door_outlined, '$rooms Rooms'),
        _buildHighlightItem(Icons.bed_outlined, '$beds Beds'),
        _buildHighlightItem(Icons.people_outline_rounded, '$guests Guests'),
      ];
    } else if (category.contains('tour')) {
      final duration = metadata['duration']?.toString() ?? 'Full Day';
      final maxTravelers = metadata['maxTravelers']?.toString() ?? 'Any';
      highlights = [
        _buildHighlightItem(Icons.timer_outlined, duration),
        _buildHighlightItem(Icons.group_outlined, 'Max $maxTravelers'),
        _buildHighlightItem(Icons.language_outlined, 'Guides'),
      ];
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(spacing: 12, runSpacing: 8, children: highlights),
        const SizedBox(height: 8),
        // Availability Status
        _buildAvailabilityBadge(),
      ],
    );
  }

  Widget _buildHighlightItem(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade700),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildAvailabilityBadge() {
    final bool isHotel = widget.service.category.toLowerCase().contains(
      'hotel',
    );
    final metadata = widget.service.metadata;
    final int availableRooms =
        (metadata['availableRooms'] as num?)?.toInt() ?? 1;
    final bool isInactive = widget.service.status == ServiceStatus.inactive;

    if (isInactive) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.block, size: 12, color: Colors.red),
            SizedBox(width: 4),
            Text(
              'Fully Booked',
              style: TextStyle(
                color: Colors.red,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    if (isHotel && availableRooms > 0 && availableRooms <= 3) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.flash_on, size: 12, color: Colors.orange),
            const SizedBox(width: 4),
            Text(
              'Only $availableRooms left!',
              style: const TextStyle(
                color: Colors.orange,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    String availabilityText = 'Available Now';
    final String category = widget.service.category.toLowerCase();
    final String? package = metadata['package'] as String?;

    if (category.contains('tour') && package != null) {
      // Capitalize first letter
      final formattedPackage = package[0].toUpperCase() + package.substring(1);
      availabilityText = 'Available Now - $formattedPackage';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_outline, size: 12, color: Colors.green),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              availabilityText,
              style: const TextStyle(
                color: Colors.green,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingBadge() {
    final bool isVerified = widget.service.isVerified ?? false;
    final double? rating = widget.service.rating;
    // final int? hotelStars = widget.service.metadata['starRating'] as int?;
    // final bool isHotel =
    //     widget.service.category.toLowerCase().contains('hotel');

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        /*
        if (isHotel && hotelStars != null && hotelStars > 0) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Text(
                  hotelStars.toString(),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
                const Icon(Icons.star, size: 14, color: Colors.orange),
              ],
            ),
          ),
          const SizedBox(width: 4),
        ],
        */
        if (isVerified) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
            ),
            child: const Icon(Icons.verified, size: 14, color: Colors.blue),
          ),
          const SizedBox(width: 4),
        ],
        if (rating != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: rating >= 4.5
                  ? Colors.green.withValues(alpha: 0.1)
                  : AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: rating >= 4.5 ? Colors.green : AppColors.primary,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.star_rounded,
                  size: 16,
                  color: rating >= 4.5 ? Colors.green : AppColors.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  rating.toStringAsFixed(1),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: rating >= 4.5 ? Colors.green : AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildAmenitiesRow({required int maxItems}) {
    final List<String> serviceAmenities = widget.service.amenities ?? [];

    if (serviceAmenities.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: serviceAmenities.take(maxItems).map((amenity) {
        return _buildAmenityIcon(_getIconForAmenity(amenity), amenity);
      }).toList(),
    );
  }

  Widget _buildAmenityIcon(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        icon,
        size: 14,
        color: AppColors.primary.withValues(alpha: 0.7),
      ),
    );
  }

  IconData _getIconForAmenity(String amenity) {
    final a = amenity.toLowerCase();
    if (a.contains('wifi')) return Icons.wifi;
    if (a.contains('ac') || a.contains('air condition')) return Icons.ac_unit;
    if (a.contains('pool')) return Icons.pool;
    if (a.contains('parking')) return Icons.local_parking;
    if (a.contains('breakfast')) return Icons.free_breakfast;
    if (a.contains('gym') || a.contains('fitness')) return Icons.fitness_center;
    if (a.contains('tv')) return Icons.tv;
    if (a.contains('restaurant') || a.contains('food')) return Icons.restaurant;
    if (a.contains('spa')) return Icons.spa;
    if (a.contains('security') || a.contains('safe')) return Icons.lock_outline;
    if (a.contains('coffee')) return Icons.coffee_maker_outlined;
    if (a.contains('transport') || a.contains('pickup')) {
      return Icons.airport_shuttle;
    }
    return Icons.done;
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String tooltip;

  const _QuickActionButton({
    required this.icon,
    required this.color,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      preferBelow: false,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, size: 18, color: color),
          ),
        ),
      ),
    );
  }
}
