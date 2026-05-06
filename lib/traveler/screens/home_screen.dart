import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/services/auth_service.dart';
import '../../shared/services/service_repository.dart';
import '../../shared/models/service_model.dart';

import '../../shared/services/special_offer_repository.dart';
import '../../shared/models/special_offer_model.dart';
import '../../shared/services/recently_viewed_provider.dart';
import '../../shared/services/favorites_provider.dart';
import '../../shared/services/notification_repository.dart';
import '../../shared/services/banner_repository.dart';
import '../../shared/services/review_repository.dart';
import '../../shared/services/lookup_service.dart';
import '../../shared/services/highlight_repository.dart';
import '../../core/widgets/responsive.dart';

class TravelerHomeScreen extends ConsumerStatefulWidget {
  const TravelerHomeScreen({super.key});

  @override
  ConsumerState<TravelerHomeScreen> createState() => _TravelerHomeScreenState();
}

class _TravelerHomeScreenState extends ConsumerState<TravelerHomeScreen> {
  String _selectedCategory = 'hotel';
  String? _selectedDestination; // null means no destination selected
  final ScrollController _scrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    final services = ref.watch(filteredServicesProvider);
    final specialOffers = ref.watch(activeSpecialOffersProvider);

    final regionsAsync = ref.watch(regionsProvider);

    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1024;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;

    final logoSize = isDesktop ? 42.0 : (isTablet ? 38.0 : 34.0);

    // Filter active services based on selection

    // Calculate aggregated destinations from all active services
    final destinationCounts = <String, int>{};
    for (final service in services) {
      if (service.status == ServiceStatus.active) {
        final userRegion = (service.metadata['region'] as String?)
            ?.toLowerCase();
        String dest = (userRegion != null && userRegion.isNotEmpty)
            ? userRegion
            : service.location.split(',').first.trim().toLowerCase();

        // 🌍 Normalize Region Names & Spelling
        if (dest == 'banadir') dest = 'banaadir';
        if (dest == 'hiran') dest = 'hiiraan';
        if (dest == 'bakol') dest = 'bakool';
        // Map common city names/spellings to the Banaadir region
        if (dest == 'mogadishu' ||
            dest == 'muqdisho' ||
            dest == 'xamar' ||
            dest == 'hamar') {
          dest = 'banaadir';
        }

        destinationCounts[dest] = (destinationCounts[dest] ?? 0) + 1;
      }
    }

    final List<Map<String, dynamic>> dynamicDestinations = regionsAsync.when(
      data: (regions) {
        final uniqueDestinations = <String, Map<String, dynamic>>{};

        // 🌍 Create a map for quick lookup from regions list
        final regionMap = {for (final r in regions) r.key.toLowerCase(): r};

        // 🌍 Iterate over ALL destinations found in services
        destinationCounts.forEach((slug, count) {
          if (count > 0) {
            final lookup = regionMap[slug];

            uniqueDestinations[slug] = {
              'city':
                  lookup?.label ??
                  slug
                      .split('_')
                      .map(
                        (word) => word.isNotEmpty
                            ? '${word[0].toUpperCase()}${word.substring(1)}'
                            : '',
                      )
                      .join(' '),
              'hotels': count,
              'image':
                  (lookup?.icon != null &&
                      (lookup!.icon!.startsWith('http') ||
                          lookup.icon!.startsWith('assets/')))
                  ? lookup.icon!
                  : 'https://picsum.photos/seed/${slug.replaceAll(' ', '')}/400/300',
              'key': slug,
            };
          }
        });

        return uniqueDestinations.values.toList()
          ..sort((a, b) => (b['hotels'] as int).compareTo(a['hotels'] as int));
      },
      loading: () => [],
      error: (_, __) => [],
    );

    // Use favorites instead of recently viewed
    final favorites = ref.watch(favoritesProvider);
    final displayServices = favorites.take(10).toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // 🔝 Top Navigation Bar
          SliverAppBar(
            pinned: true,
            backgroundColor: Theme.of(context).cardColor,
            elevation: 1,
            shadowColor: Colors.black.withAlpha(10),
            title: Row(
              children: [
                // Logo & Brand
                Image.asset(
                  'assets/images/logo.png',
                  width: logoSize,
                  height: logoSize,
                  fit: BoxFit.contain,
                ),

                // Space to push remaining icons to the right
                const Spacer(),

                // Notifications
                IconButton(
                  onPressed: () => context.push('/traveler/notifications'),
                  icon: Consumer(
                    builder: (context, ref, child) {
                      final unreadCount = ref.watch(
                        unreadNotificationsCountProvider,
                      );
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Icon(
                            unreadCount > 0
                                ? Icons.notifications
                                : Icons.notifications_none,
                            color: AppColors.primary,
                          ),
                          if (unreadCount > 0)
                            Positioned(
                              right: -4,
                              top: -4,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: AppColors.error,
                                  shape: BoxShape.circle,
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 16,
                                  minHeight: 16,
                                ),
                                child: Text(
                                  unreadCount > 9
                                      ? '9+'
                                      : unreadCount.toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),

                // Profile Avatar
                GestureDetector(
                  onTap: () => _showProfileMenu(context),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primary, width: 2),
                    ),
                    child: CircleAvatar(
                      backgroundImage:
                          user?.profileImage != null &&
                              user!.profileImage!.isNotEmpty
                          ? NetworkImage(user.profileImage!)
                          : null,
                      backgroundColor: Colors.grey[300],
                      child:
                          user?.profileImage == null ||
                              user!.profileImage!.isEmpty
                          ? const Icon(
                              Icons.person,
                              size: 20,
                              color: Colors.grey,
                            )
                          : null,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 🖼 Hero Section (Includes Search Bar overlapping at bottom)
          SliverToBoxAdapter(
            child: _HeroSection(
              selectedCategory: _selectedCategory,
              onCategorySelected: (categoryKey) {
                setState(() => _selectedCategory = categoryKey);
                // Navigate to search screen with category filter
                context.push('/traveler/search?category=$categoryKey');
              },
            ),
          ),

          // ⭐ Featured Destinations (Circular Somalia Regions)
          if (dynamicDestinations.isNotEmpty && _selectedDestination == null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 16),
                child: _FeaturedDestinationsSection(
                  destinations: dynamicDestinations,
                  onExplore: (city) {
                    setState(() => _selectedDestination = city);
                    Future.delayed(const Duration(milliseconds: 100), () {
                      _scrollController.animateTo(
                        _scrollController.position.pixels + 100,
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeOut,
                      );
                    });
                  },
                ),
              ),
            ),

          // 🗺 Destination Services (shown when a destination is explored)
          if (_selectedDestination != null)
            SliverToBoxAdapter(
              child: _DestinationServicesSection(
                city: _selectedDestination!,
                services: services
                    .where(
                      (s) =>
                          s.status == ServiceStatus.active &&
                          ((s.metadata['region'] as String?) ==
                                  _selectedDestination ||
                              s.location.split(',').first.trim() ==
                                  _selectedDestination),
                    )
                    .toList(),
                onCancel: () => setState(() => _selectedDestination = null),
              ),
            ),

          // 🏨 Recommended Services (Favorites / Top)
          if (_selectedDestination == null)
            SliverToBoxAdapter(
              child: _RecommendedServicesSection(services: displayServices),
            ),

          // 🏖️ Somalia Travel Highlights
          if (_selectedDestination == null)
            const SliverToBoxAdapter(child: _TravelHighlightsSection()),

          // 🔥 Special Offers
          if (specialOffers.isNotEmpty)
            SliverToBoxAdapter(
              child: _SpecialOffersSection(offers: specialOffers),
            ),

          // 💬 Reviews Section
          if (!context.isMobile)
            SliverToBoxAdapter(
              child: Consumer(
                builder: (context, ref, child) {
                  final reviews = ref.watch(reviewProvider);
                  if (reviews.isEmpty) return const SizedBox.shrink();

                  // Map to the format UI expects
                  final mappedReviews = reviews.take(5).map((r) {
                    return {
                      'name': r.travelerName,
                      'rating': r.rating.toDouble(),
                      'comment': r.comment,
                      'image':
                          'https://picsum.photos/seed/${r.travelerId}/100/100',
                    };
                  }).toList();

                  return _ReviewsSection(reviews: mappedReviews);
                },
              ),
            ),

          // 📱 Mobile App Promotion
          if (!context.isMobile)
            SliverToBoxAdapter(child: _MobileAppPromotion()),

          // 📞 Footer Section (Web Only)
          if (context.isDesktop) SliverToBoxAdapter(child: _FooterSection()),

          // Bottom spacing
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  void _showProfileMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor:
          Theme.of(context).bottomSheetTheme.backgroundColor ??
          Theme.of(context).cardColor,
      builder: (context) => SafeArea(
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Pull Bar
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: const Icon(
                  Icons.person_outline,
                  color: Colors.black87,
                ),
                title: const Text(
                  'Profile',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                contentPadding: EdgeInsets.zero,
                onTap: () {
                  Navigator.pop(context);
                  context.go('/traveler/profile');
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.collections_bookmark_outlined,
                  color: Colors.black87,
                ),
                title: const Text(
                  'Bookings',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                contentPadding: EdgeInsets.zero,
                onTap: () {
                  Navigator.pop(context);
                  context.go('/traveler/bookings');
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.logout_rounded,
                  color: Colors.black87,
                ),
                title: const Text(
                  'Logout',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                contentPadding: EdgeInsets.zero,
                onTap: () async {
                  Navigator.pop(context);
                  await ref.read(authServiceProvider).logout();
                  if (context.mounted) {
                    context.go('/login');
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 🖼 Hero Section Widget
class _HeroSection extends ConsumerStatefulWidget {
  final String? selectedCategory;
  final Function(String) onCategorySelected;

  const _HeroSection({
    required this.selectedCategory,
    required this.onCategorySelected,
  });

  @override
  ConsumerState<_HeroSection> createState() => _HeroSectionState();
}

class _HeroSectionState extends ConsumerState<_HeroSection> {
  final PageController _pageController = PageController(initialPage: 0);
  Timer? _timer;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    // Start auto-scroll after a short delay to ensure banners are loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startTimer();
    });
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_pageController.hasClients) {
        final banners = ref.read(activeBannersProvider);
        if (banners.length <= 1) return;

        _currentPage++;
        if (_currentPage >= banners.length) {
          _currentPage = 0;
        }

        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final banners = ref.watch(activeBannersProvider);
    final userName = ref.watch(authProvider)?.name ?? 'Traveler';
    final categoriesAsync = ref.watch(categoriesProvider);
    final firstName = userName.split(' ').first;

    final heroHeight = context.isMobile
        ? MediaQuery.of(context).size.height * 0.45
        : MediaQuery.of(context).size.height * 0.5;

    return SizedBox(
      height: heroHeight + 28, // heroHeight + half of search bar height to accommodate overlap
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          // Background images (rotating) - Positioned to stay within heroHeight
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: heroHeight,
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                _currentPage = index;
              },
              itemCount: banners.length,
              itemBuilder: (context, index) {
                final banner = banners[index];
                return Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
                    ),
                  ),
                  child: Image.network(
                    banner.imageUrl,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.blue[900]!, Colors.blue[600]!],
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.location_city,
                            size: 80,
                            color: Colors.white.withAlpha(100),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),

          // Gradient overlay - Positioned to stay within heroHeight
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: heroHeight,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withAlpha(50),
                    Colors.black.withAlpha(120),
                  ],
                ),
              ),
            ),
          ),

          // Content - Positioned to stay within heroHeight
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: heroHeight,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    Text(
                      'Hello! $firstName',
                      style: GoogleFonts.poppins(
                        fontSize: !context.isMobile ? 32 : 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                        shadows: [
                          Shadow(
                            color: Colors.black.withAlpha(100),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Where would you like to go?',
                      style: GoogleFonts.poppins(
                        fontSize: !context.isMobile ? 18 : 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withAlpha(230),
                        shadows: [
                          Shadow(
                            color: Colors.black.withAlpha(100),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    
                    // Categories
                    categoriesAsync.when(
                      data: (categoriesList) {
                        final displayCats = categoriesList.where((c) => 
                          ['hotel', 'apartment', 'tour'].contains(c.key.toLowerCase())
                        ).toList();
                        final cats = displayCats.isNotEmpty ? displayCats : categoriesList.take(3).toList();
                        
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(bottom: 24),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: cats.map((category) {
                                  final isSelected =
                                      category.key == widget.selectedCategory;
                                  return GestureDetector(
                                    onTap: () =>
                                        widget.onCategorySelected(category.key),
                                    child: _CategoryIconCard(
                                      icon: getLookupIcon(category.icon),
                                      label: category.label,
                                      isSelected: isSelected,
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                        );
                      },
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 🌙 Curved white background at the bottom of the hero image
          Positioned(
            bottom: 28, // Adjusted to sit at the bottom of heroHeight
            left: 0,
            right: 0,
            height: 40,
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF3F4F6), // Matches typical scaffold background
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
            ),
          ),

          // 🔍 Search Bar (Overlapping) - Now at the absolute bottom of the taller Stack
          Positioned(
            bottom: 0,
            left: 24,
            right: 24,
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(20),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  debugPrint('DEBUG: Search bar tapped');
                  context.push('/traveler/search');
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.search,
                        color: AppColors.primary,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Where to go',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: Colors.grey[400],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
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
}

// ⭐ Featured Destinations Section
class _FeaturedDestinationsSection extends StatelessWidget {
  final List<Map<String, dynamic>> destinations;
  final void Function(String city) onExplore;

  const _FeaturedDestinationsSection({
    required this.destinations,
    required this.onExplore,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 100,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              scrollDirection: Axis.horizontal,
              itemCount: destinations.length,
              separatorBuilder: (context, index) => const SizedBox(width: 24),
              itemBuilder: (context, index) {
                final destination = destinations[index];
                return _DestinationCircularCard(
                  city: destination['city'],
                  image: destination['image'],
                  onExplore: onExplore,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DestinationCircularCard extends StatefulWidget {
  final String city;
  final String image;
  final void Function(String city) onExplore;

  const _DestinationCircularCard({
    required this.city,
    required this.image,
    required this.onExplore,
  });

  @override
  State<_DestinationCircularCard> createState() => _DestinationCircularCardState();
}

class _DestinationCircularCardState extends State<_DestinationCircularCard> {
  bool _isHovered = false;

  Widget _buildErrorState() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.blue[100],
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Icon(
          Icons.location_city,
          size: 24,
          color: Colors.blue[400],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () => widget.onExplore(widget.city),
        child: Column(
          children: [
            AnimatedScale(
              scale: _isHovered ? 1.1 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.blue[100]!, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(_isHovered ? 20 : 10),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: widget.image.startsWith('assets/')
                      ? Image.asset(
                          widget.image,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildErrorState(),
                        )
                      : Image.network(
                          widget.image,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildErrorState(),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.city,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.dark,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _DestinationCard extends StatefulWidget {
  final String city;
  final int hotels;
  final String image;
  final void Function(String city) onExplore;

  const _DestinationCard({
    required this.city,
    required this.hotels,
    required this.image,
    required this.onExplore,
  });

  @override
  State<_DestinationCard> createState() => _DestinationCardState();
}

class _DestinationCardState extends State<_DestinationCard> {
  bool _isHovered = false;

  Widget _buildErrorState() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.blue[300]!, Colors.blue[500]!],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.location_city,
          size: 40,
          color: Colors.white.withAlpha(150),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () => widget.onExplore(widget.city),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 200,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Image Container
              AnimatedScale(
                scale: _isHovered ? 1.05 : 1.0,
                duration: const Duration(milliseconds: 300),
                child: Container(
                  height: 200,
                  width: 200,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: _isHovered ? 0.2 : 0.1,
                        ),
                        blurRadius: _isHovered ? 15 : 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        widget.image.startsWith('assets/')
                            ? Image.asset(
                                widget.image,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    _buildErrorState(),
                              )
                            : Image.network(
                                // Ensure valid URL and bust cache with timestamp
                                '${widget.image}${widget.image.contains('?') ? '&' : '?'}t=${DateTime.now().millisecondsSinceEpoch}',
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    _buildErrorState(),
                                loadingBuilder:
                                    (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return Center(
                                        child: CircularProgressIndicator(
                                          value:
                                              loadingProgress
                                                      .expectedTotalBytes !=
                                                  null
                                              ? loadingProgress
                                                        .cumulativeBytesLoaded /
                                                    loadingProgress
                                                        .expectedTotalBytes!
                                              : null,
                                          strokeWidth: 2,
                                        ),
                                      );
                                    },
                              ),
                        // Overlay for better text readability if we put text on it,
                        // but here we put text below.
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Name and Stats
              Text(
                widget.city,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.dark,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                '${widget.hotels} Services',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 🗺 Destination Services Section (shown when user explores a city)
class _DestinationServicesSection extends ConsumerWidget {
  final String city;
  final List<Service> services;
  final VoidCallback onCancel;

  const _DestinationServicesSection({
    required this.city,
    required this.services,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: title + cancel button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withAlpha(20),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Image.asset(
                            'assets/images/logo.png',
                            height: 60,
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            city,
                            style: GoogleFonts.poppins(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppColors.dark,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.only(left: 34),
                      child: Text(
                        '${services.length} service${services.length == 1 ? '' : 's'} available',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Cancel button
              OutlinedButton.icon(
                onPressed: onCancel,
                icon: const Icon(Icons.close, size: 16),
                label: Text(
                  'Cancel',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Services list or empty state
          if (services.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  children: [
                    Icon(Icons.search_off, size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 12),
                    Text(
                      'No services found in $city',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: services.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final service = services[index];
                return _DestinationServiceCard(service: service);
              },
            ),
        ],
      ),
    );
  }
}

// Card used inside _DestinationServicesSection
class _DestinationServiceCard extends ConsumerStatefulWidget {
  final Service service;
  const _DestinationServiceCard({required this.service});

  @override
  ConsumerState<_DestinationServiceCard> createState() =>
      _DestinationServiceCardState();
}

class _DestinationServiceCardState
    extends ConsumerState<_DestinationServiceCard> {
  bool _isHovered = false;

  String _getImage() {
    if (widget.service.images.isNotEmpty) return widget.service.images.first;
    final seed = widget.service.id.hashCode.abs();
    return 'https://picsum.photos/seed/${widget.service.category.toLowerCase()}$seed/600/400';
  }

  @override
  Widget build(BuildContext context) {
    final service = widget.service;
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () {
          ref.read(recentlyViewedProvider.notifier).addService(service);
          context.push('/traveler/booking/${service.id}', extra: service);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(_isHovered ? 25 : 8),
                blurRadius: _isHovered ? 20 : 10,
                offset: Offset(0, _isHovered ? 8 : 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 500;
              return SizedBox(
                height: isNarrow ? 130 : 160,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Image
                    SizedBox(
                      width: isNarrow ? 120 : 180,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          AnimatedScale(
                            scale: _isHovered ? 1.05 : 1.0,
                            duration: const Duration(milliseconds: 300),
                            child: Image.network(
                              _getImage(),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: Colors.grey[200],
                                child: Icon(
                                  Icons.hotel,
                                  color: Colors.grey[400],
                                  size: 36,
                                ),
                              ),
                            ),
                          ),
                          // Category tag
                          Positioned(
                            top: 8,
                            left: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withAlpha(220),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                service.category,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Details
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.all(isNarrow ? 10 : 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Title + rating
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    service.title,
                                    style: TextStyle(
                                      fontSize: isNarrow ? 14 : 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (service.rating != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withAlpha(20),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.star,
                                          size: 12,
                                          color: AppColors.primary,
                                        ),
                                        const SizedBox(width: 3),
                                        Text(
                                          service.rating!.toStringAsFixed(1),
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),

                            // Location
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on,
                                  size: 12,
                                  color: Colors.grey[500],
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    service.location,
                                    style: TextStyle(
                                      fontSize: isNarrow ? 11 : 12,
                                      color: Colors.grey[600],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),

                            const Spacer(),

                            // Price + View button
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Price/night',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                    Text(
                                      '\$${service.price}',
                                      style: TextStyle(
                                        fontSize: isNarrow ? 15 : 18,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    // Quick Preview Button
                                    IconButton(
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      icon: Icon(
                                        Icons.visibility_outlined,
                                        color: AppColors.primary.withAlpha(180),
                                        size: 20,
                                      ),
                                      onPressed: () =>
                                          _openQuickPreview(context, service),
                                      tooltip: 'Quick Preview',
                                    ),
                                    const SizedBox(width: 10),
                                    AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 200,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _isHovered
                                            ? AppColors.secondary
                                            : AppColors.primary,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'View',
                                        style: GoogleFonts.poppins(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// 🏨 Recommended Services Section
class _RecommendedServicesSection extends StatefulWidget {
  final List<Service> services;

  const _RecommendedServicesSection({required this.services});

  @override
  State<_RecommendedServicesSection> createState() => _RecommendedServicesSectionState();
}

class _RecommendedServicesSectionState extends State<_RecommendedServicesSection> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.65, initialPage: widget.services.length > 1 ? 1 : 0);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    'Recommended',
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.dark,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {},
                  child: Text(
                    'View All',
                    style: GoogleFonts.poppins(
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (widget.services.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                height: 150,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.recommend,
                      color: Colors.grey[300],
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No recommendations yet',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[400],
                      ),
                    ),
                    Text(
                      'Tap the heart icon to save services here.',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[400],
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SizedBox(
              height: 380,
              child: AnimatedBuilder(
                animation: _pageController,
                builder: (context, child) {
                  return PageView.builder(
                    controller: _pageController,
                    itemCount: widget.services.length,
                    itemBuilder: (context, index) {
                      double value = 1.0;
                      if (_pageController.position.haveDimensions) {
                        value = _pageController.page! - index;
                        value = (1 - (value.abs() * 0.15)).clamp(0.0, 1.0);
                      } else {
                        final initialPage = widget.services.length > 1 ? 1 : 0;
                        value = initialPage == index ? 1.0 : 0.85;
                      }

                      return Center(
                        child: SizedBox(
                          height: Curves.easeOut.transform(value) * 380,
                          width: double.infinity,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: _ServiceHorizontalCard(service: widget.services[index]),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _ServiceHorizontalCard extends ConsumerStatefulWidget {
  final Service service;

  const _ServiceHorizontalCard({required this.service});

  @override
  ConsumerState<_ServiceHorizontalCard> createState() =>
      _ServiceHorizontalCardState();
}

class _ServiceHorizontalCardState extends ConsumerState<_ServiceHorizontalCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final service = widget.service;
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () {
          ref.read(recentlyViewedProvider.notifier).addService(service);
          context.push('/traveler/booking/${service.id}', extra: service);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(_isHovered ? 40 : 15),
                blurRadius: _isHovered ? 20 : 10,
                offset: Offset(0, _isHovered ? 10 : 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background Image
              AnimatedScale(
                scale: _isHovered ? 1.05 : 1.0,
                duration: const Duration(milliseconds: 300),
                child: Image.network(
                  service.images.isNotEmpty
                      ? service.images.first
                      : 'https://picsum.photos/seed/${service.id}/400/600',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.blue[300]!, Colors.blue[500]!],
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          service.category.toLowerCase() == 'apartment'
                              ? Icons.apartment
                              : service.category.toLowerCase() == 'tour'
                              ? Icons.explore
                              : Icons.hotel,
                          size: 60,
                          color: Colors.white.withAlpha(150),
                        ),
                      ),
                    );
                  },
                ),
              ),
              
              // Gradient Overlay
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: 120,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withAlpha(150),
                        Colors.black.withAlpha(200),
                      ],
                    ),
                  ),
                ),
              ),

              // Heart Icon
              Positioned(
                top: 16,
                right: 16,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(100),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: Icon(
                      ref.watch(favoritesProvider).any((s) => s.id == service.id)
                          ? Icons.favorite
                          : Icons.favorite_border,
                      color: Colors.white,
                      size: 24,
                    ),
                    onPressed: () {
                      ref.read(favoritesProvider.notifier).toggleFavorite(service);
                    },
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(10),
                  ),
                ),
              ),

              // Location & Rating
              Positioned(
                bottom: 20,
                left: 20,
                right: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      service.title,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(
                                Icons.location_on,
                                color: Colors.white70,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  service.location,
                                  style: GoogleFonts.poppins(
                                    color: Colors.white70,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (service.rating != null)
                          Row(
                            children: [
                              const Icon(
                                Icons.star,
                                color: Colors.amber,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                service.rating!.toStringAsFixed(1),
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
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
    );
  }
}


class _CategoryIconCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;

  const _CategoryIconCard({
    required this.icon,
    required this.label,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = context.isMobile;
    final cardWidth = isMobile ? 100.0 : 110.0;
    final cardHeight = isMobile ? 105.0 : 120.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: cardWidth,
          height: cardHeight,
          padding: EdgeInsets.all(isMobile ? 8 : 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white.withAlpha(60) : Colors.white.withAlpha(20),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isSelected ? Colors.white : Colors.white.withAlpha(60),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(isSelected ? 40 : 20),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
              if (isSelected)
                BoxShadow(
                  color: Colors.white.withAlpha(30),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: Colors.white,
                size: isMobile ? 28 : 32,
              ),
              SizedBox(height: isMobile ? 8 : 12),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: isMobile ? 12 : 14,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 🔥 Special Offers Section
class _SpecialOffersSection extends StatefulWidget {
  final List<SpecialOffer> offers;

  const _SpecialOffersSection({required this.offers});

  @override
  State<_SpecialOffersSection> createState() => _SpecialOffersSectionState();
}

class _SpecialOffersSectionState extends State<_SpecialOffersSection> {
  final PageController _pageController = PageController();
  Timer? _timer;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    if (widget.offers.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
        if (_currentPage < widget.offers.length - 1) {
          _currentPage++;
        } else {
          _currentPage = 0;
        }

        if (_pageController.hasClients) {
          _pageController.animateToPage(
            _currentPage,
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              'Special Offers & Deals',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.dark,
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 220,
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() => _currentPage = index);
              },
              itemCount: widget.offers.length,
              itemBuilder: (context, index) {
                final offer = widget.offers[index];
                return _OfferCard(offer: offer);
              },
            ),
          ),
          if (widget.offers.length > 1)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  widget.offers.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _currentPage == index ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _currentPage == index
                          ? AppColors.primary
                          : AppColors.primary.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _OfferCard extends ConsumerWidget {
  final SpecialOffer offer;

  const _OfferCard({required this.offer});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background image
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Colors.grey[200],
            ),
            child: Stack(
              children: [
                Image.network(
                  offer.imageUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.orange[300]!, Colors.orange[500]!],
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.local_offer,
                          size: 50,
                          color: Colors.white.withAlpha(150),
                        ),
                      ),
                    );
                  },
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: Colors.grey[200],
                      ),
                      child: Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                              : null,
                          strokeWidth: 2,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // Gradient overlay
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withAlpha(200)],
              ),
            ),
          ),

          // Content
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Discount badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${offer.discount} OFF',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  offer.title,
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  offer.description,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.white.withAlpha(200),
                  ),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () {
                    if (offer.linkedServiceId != null) {
                      final services = ref.read(serviceProvider);
                      final service = services.firstWhere(
                        (s) => s.id == offer.linkedServiceId,
                        orElse: () => throw Exception('Service not found'),
                      );
                      context.push(
                        '/traveler/booking/${service.id}',
                        extra: service,
                      );
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Book Now',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// 💬 Reviews Section
class _ReviewsSection extends StatefulWidget {
  final List<Map<String, dynamic>> reviews;

  const _ReviewsSection({required this.reviews});

  @override
  State<_ReviewsSection> createState() => _ReviewsSectionState();
}

class _ReviewsSectionState extends State<_ReviewsSection> {
  final PageController _pageController = PageController(initialPage: 0);
  Timer? _timer;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    if (widget.reviews.isNotEmpty) {
      _timer = Timer.periodic(const Duration(seconds: 4), (Timer timer) {
        if (_currentPage < widget.reviews.length - 1) {
          _currentPage++;
        } else {
          _currentPage = 0;
        }

        if (_pageController.hasClients) {
          _pageController.animateToPage(
            _currentPage,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeIn,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center, // Center the title
        children: [
          Text(
            'What Travelers Say',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.dark,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200, // Increased height for centered column layout
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                _currentPage = index;
              },
              itemCount: widget.reviews.length,
              itemBuilder: (context, index) {
                final review = widget.reviews[index];
                return _ReviewCard(review: review);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final Map<String, dynamic> review;

  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // User photo
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.grey[300],
            backgroundImage:
                review['image'] != null && review['image'].isNotEmpty
                ? NetworkImage(review['image'])
                : null,
            child: review['image'] == null || review['image'].isEmpty
                ? const Icon(Icons.person, size: 30, color: Colors.grey)
                : null,
          ),
          const SizedBox(height: 12),
          // Review content
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                review['name'],
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : AppColors.dark,
                ),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    return Icon(
                      index < review['rating'].floor()
                          ? Icons.star
                          : Icons.star_border,
                      size: 16,
                      color: Colors.amber,
                    );
                  }),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                review['comment'],
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic, // Extra premium touch
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// 📱 Mobile App Promotion
class _MobileAppPromotion extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primary, AppColors.primaryDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bool isSmall = constraints.maxWidth < 600;
            return Row(
              children: [
                // App preview
                if (!isSmall)
                  Expanded(
                    flex: 2,
                    child: Column(
                      children: [
                        Container(
                          width: 120,
                          height: 240,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(50),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.phone_iphone,
                              size: 60,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Content
                Expanded(
                  flex: isSmall ? 1 : 3,
                  child: Padding(
                    padding: EdgeInsets.only(left: isSmall ? 0 : 32),
                    child: Column(
                      crossAxisAlignment: isSmall
                          ? CrossAxisAlignment.center
                          : CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Book faster with our app',
                          style: GoogleFonts.poppins(
                            fontSize: isSmall ? 20 : 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          textAlign: isSmall
                              ? TextAlign.center
                              : TextAlign.start,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Get exclusive deals and seamless booking experience on the go',
                          style: GoogleFonts.poppins(
                            fontSize: isSmall ? 14 : 16,
                            color: Colors.white.withAlpha(200),
                          ),
                          textAlign: isSmall
                              ? TextAlign.center
                              : TextAlign.start,
                        ),
                        const SizedBox(height: 20),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          alignment: isSmall
                              ? WrapAlignment.center
                              : WrapAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'App Store',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Play Store',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// 🏖️ Travel Highlights Section
class _TravelHighlightsSection extends ConsumerWidget {
  const _TravelHighlightsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final highlightsData = ref.watch(activeHighlightsProvider);

    // Fallback static data if database is empty
    final List<Map<String, String>> fallbackHighlights = [
      {
        'title': 'Liido Beach',
        'location': 'Mogadishu',
        'image': 'https://images.unsplash.com/photo-1544102807-640a23277732?auto=format&fit=crop&w=600&q=80',
        'tag': 'Beach',
      },
      {
        'title': 'Laas Geel',
        'location': 'Hargeisa',
        'image': 'https://images.unsplash.com/photo-1610473264667-27f99990543e?auto=format&fit=crop&w=600&q=80',
        'tag': 'History',
      },
      {
        'title': 'Daallo Mountains',
        'location': 'Erigavo',
        'image': 'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?auto=format&fit=crop&w=600&q=80',
        'tag': 'Nature',
      },
    ];

    final displayItems = highlightsData.isNotEmpty
        ? highlightsData.map((h) => {
            'title': h.title,
            'location': h.location,
            'image': h.imageUrl,
            'tag': h.tag,
          }).toList()
        : fallbackHighlights;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Explore Somalia',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.dark,
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 240,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: displayItems.length,
              itemBuilder: (context, index) {
                final item = displayItems[index];
                return Container(
                  width: 200,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(20),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        item['image']!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.grey[200],
                          child: const Icon(Icons.image_not_supported),
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withAlpha(150),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            item['tag']!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 12,
                        left: 12,
                        right: 12,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['title']!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              item['location']!,
                              style: TextStyle(
                                color: Colors.white.withAlpha(200),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// 📞 Footer Section
class _FooterSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1024;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;

    final logoSize = isDesktop ? 42.0 : (isTablet ? 38.0 : 34.0);
    final brandFontSize = isDesktop ? 24.0 : (isTablet ? 22.0 : 20.0);

    return Container(
      padding: const EdgeInsets.all(48),
      color: const Color(0xFF1E1E1E),
      child: Column(
        children: [
          // Logo and description
          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: logoSize * 1.3,
                    height: logoSize * 1.3,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Image.asset(
                      'assets/images/logo.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'SomSafar',
                    style: GoogleFonts.poppins(
                      fontSize: brandFontSize * 1.1,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Your trusted travel companion in Somalia',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.white.withAlpha(200),
                ),
              ),
            ],
          ),

          const SizedBox(height: 40),

          // Footer links
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Wrap(
              spacing: 40,
              runSpacing: 40,
              alignment: WrapAlignment.center,
              children: [
                _FooterColumn(
                  title: 'Company',
                  links: ['About', 'Contact', 'Careers'],
                ),
                _FooterColumn(
                  title: 'Support',
                  links: ['Help Center', 'FAQs', 'Terms'],
                ),
                _FooterColumn(
                  title: 'Explore',
                  links: ['Cities', 'Deals', 'Providers'],
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),

          // Social icons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _SocialIcon(icon: Icons.facebook),
              const SizedBox(width: 16),
              _SocialIcon(icon: Icons.camera_alt),
              const SizedBox(width: 16),
              _SocialIcon(icon: Icons.alternate_email),
              const SizedBox(width: 16),
              _SocialIcon(icon: Icons.message),
            ],
          ),

          const SizedBox(height: 20),

          Text(
            '© ${DateTime.now().year} SomSafar. All rights reserved.',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.white.withAlpha(150),
            ),
          ),
        ],
      ),
    );
  }
}

class _FooterColumn extends StatelessWidget {
  final String title;
  final List<String> links;

  const _FooterColumn({required this.title, required this.links});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        ...links.map(
          (link) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              link,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.white.withAlpha(200),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SocialIcon extends StatelessWidget {
  final IconData icon;

  const _SocialIcon({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(20),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Icon(icon, color: Colors.white, size: 20),
    );
  }
}

// 🖼 Quick Service Preview Dialog
void _openQuickPreview(BuildContext context, Service service) {
  showDialog(
    context: context,
    builder: (context) {
      final List<String> images = service.images.isNotEmpty
          ? service.images
          : [
              'https://picsum.photos/seed/${service.id}1/600/400',
              'https://picsum.photos/seed/${service.id}2/600/400',
              'https://picsum.photos/seed/${service.id}3/600/400',
            ];

      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Container(
          width: 500,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(50),
                blurRadius: 30,
                offset: const Offset(0, 15),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Image Gallery
              Stack(
                children: [
                  SizedBox(
                    height: 320,
                    child: PageView.builder(
                      itemCount: images.length,
                      itemBuilder: (context, index) {
                        return Image.network(
                          images[index],
                          fit: BoxFit.cover,
                          width: double.infinity,
                          errorBuilder: (_, __, ___) => Container(
                            color: Colors.grey[200],
                            child: const Icon(Icons.broken_image, size: 48),
                          ),
                        );
                      },
                    ),
                  ),
                  // Close button
                  Positioned(
                    top: 16,
                    right: 16,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                  // Image indicator
                  Positioned(
                    bottom: 16,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Swipe to see more pictures',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // Service Info
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                service.title,
                                style: GoogleFonts.poppins(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.dark,
                                ),
                              ),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.location_on,
                                    size: 14,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    service.location,
                                    style: GoogleFonts.poppins(
                                      color: Colors.grey[600],
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withAlpha(20),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '\$${service.price}',
                            style: GoogleFonts.poppins(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      service.description,
                      style: GoogleFonts.poppins(
                        color: Colors.black87,
                        fontSize: 14,
                        height: 1.5,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          context.push(
                            '/traveler/booking/${service.id}',
                            extra: service,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'View Full Details',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

IconData getLookupIcon(String? iconName) {
  if (iconName == null) return Icons.help_outline;
  switch (iconName.toLowerCase()) {
    case 'hotel':
      return Icons.hotel;
    case 'apartment':
      return Icons.apartment;
    case 'explore':
    case 'tour':
      return Icons.explore;
    case 'directions_car':
    case 'transport':
      return Icons.directions_car;
    default:
      return Icons.category;
  }
}
