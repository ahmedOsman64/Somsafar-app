import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/services/service_repository.dart';

// Import new modular components
import 'widgets/search_header_bar.dart';
import 'widgets/filters_sidebar.dart';
import 'widgets/results_area.dart';
import 'widgets/map_view_widget.dart';

class TravelerSearchScreen extends ConsumerStatefulWidget {
  final String? category;
  const TravelerSearchScreen({super.key, this.category});

  @override
  ConsumerState<TravelerSearchScreen> createState() =>
      _TravelerSearchScreenState();
}

class _TravelerSearchScreenState extends ConsumerState<TravelerSearchScreen> {
  // Search Controllers
  final TextEditingController _destinationController = TextEditingController();
  final TextEditingController _checkInController = TextEditingController();
  final TextEditingController _checkOutController = TextEditingController();
  final TextEditingController _guestsController = TextEditingController();

  // State variables
  DateTime? _checkInDate;
  DateTime? _checkOutDate;
  int _guestsCount = 1;
  bool _showFilters = false;
  bool _isGridView = true;
  bool _showMapView = false;
  bool _isLoading = false;
  String _searchQuery = '';
  String _sortBy = 'Recommended';

  // Filter states
  RangeValues _priceRange = const RangeValues(0, 5000);
  final List<String> _selectedPropertyTypes = [];
  final List<String> _selectedAmenities = [];
  bool _verifiedOnly = false;

  @override
  void initState() {
    super.initState();
    _guestsController.text = _guestsCount.toString();

    // Auto-filter by category if provided from HomeScreen
    if (widget.category != null && widget.category!.isNotEmpty) {
      // Normalize to match what FiltersSidebar sends (e.g. 'hotel' -> 'Hotel')
      final normalized =
          widget.category![0].toUpperCase() +
          widget.category!.substring(1).toLowerCase();
      _selectedPropertyTypes.add(normalized);
    }
  }

  @override
  void didUpdateWidget(TravelerSearchScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.category != oldWidget.category &&
        widget.category != null &&
        widget.category!.isNotEmpty) {
      final normalized =
          widget.category![0].toUpperCase() +
          widget.category!.substring(1).toLowerCase();
      _selectedPropertyTypes.clear();
      _selectedPropertyTypes.add(normalized);
    }
  }

  @override
  void dispose() {
    _destinationController.dispose();
    _checkInController.dispose();
    _checkOutController.dispose();
    _guestsController.dispose();
    super.dispose();
  }

  void _resetFilters() {
    setState(() {
      _priceRange = const RangeValues(0, 5000);
      _selectedPropertyTypes.clear();
      _selectedAmenities.clear();
      _verifiedOnly = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Get all services
    final activeServices = ref.watch(filteredServicesProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    // Default to true grid view on non-mobile unless changed
    if (!isMobile && !_isGridView && !mounted) {
      _isGridView = true;
    }

    // 1. Filter services based on all criteria
    final filteredServices = activeServices.where((service) {
      bool matchesSearch =
          _searchQuery.isEmpty ||
          service.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          service.location.toLowerCase().contains(_searchQuery.toLowerCase());

      bool matchesPrice =
          service.price >= _priceRange.start &&
          service.price <= _priceRange.end;

      bool matchesPropertyType =
          _selectedPropertyTypes.isEmpty ||
          _selectedPropertyTypes.any(
            (type) =>
                type.trim().toLowerCase() ==
                service.category.trim().toLowerCase(),
          );

      bool matchesVerified = !_verifiedOnly || (service.isVerified == true);

      // Amenities check
      bool matchesAmenities =
          _selectedAmenities.isEmpty ||
          (_selectedAmenities.every(
            (a) =>
                service.amenities?.any(
                  (sa) => sa.toLowerCase().contains(a.toLowerCase()),
                ) ??
                false,
          ));

      return matchesSearch &&
          matchesPrice &&
          matchesPropertyType &&
          matchesVerified &&
          matchesAmenities;
    }).toList();

    // 2. Sort services
    switch (_sortBy) {
      case 'Price Low → High':
        filteredServices.sort((a, b) => a.price.compareTo(b.price));
        break;
      case 'Price High → Low':
        filteredServices.sort((a, b) => b.price.compareTo(a.price));
        break;
      case 'Rating':
        filteredServices.sort((a, b) {
          if (a.rating == null && b.rating == null) return 0;
          if (a.rating == null) return 1;
          if (b.rating == null) return -1;
          return b.rating!.compareTo(a.rating!);
        });
        break;
      default: // Recommended
        filteredServices.sort((a, b) {
          if (a.rating == null && b.rating == null) return 0;
          if (a.rating == null) return 1;
          if (b.rating == null) return -1;
          return b.rating!.compareTo(a.rating!);
        });
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: CustomScrollView(
        slivers: [
          // 3. Sticky Search Header Bar
          SliverPersistentHeader(
            pinned: true,
            delegate: SearchHeaderDelegate(
              minHeight: isMobile ? 245 : 160,
              maxHeight: isMobile ? 245 : 160,
              child: _buildHeaderBar(isMobile),
            ),
          ),

          // 4. Main Body (Filters side, Results Grid, Map split)
          SliverFillRemaining(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Desktop Filters Sidebar
                if (!isMobile && _showFilters)
                  SizedBox(
                    width: 320,
                    child: FiltersSidebar(
                      priceRange: _priceRange,
                      onPriceRangeChanged: (val) =>
                          setState(() => _priceRange = val),
                      selectedPropertyTypes: _selectedPropertyTypes,
                      onPropertyTypeToggled: (val) => setState(() {
                        if (_selectedPropertyTypes.contains(val)) {
                          _selectedPropertyTypes.remove(val);
                        } else {
                          _selectedPropertyTypes.add(val);
                        }
                      }),
                      selectedAmenities: _selectedAmenities,
                      onAmenityToggled: (val) => setState(() {
                        if (_selectedAmenities.contains(val)) {
                          _selectedAmenities.remove(val);
                        } else {
                          _selectedAmenities.add(val);
                        }
                      }),
                      verifiedOnly: _verifiedOnly,
                      onVerifiedOnlyChanged: (val) =>
                          setState(() => _verifiedOnly = val),
                      onReset: _resetFilters,
                      onApply: () => setState(() {
                        _showFilters = false; // Close filters on apply
                        _isLoading = true;
                        Future.delayed(const Duration(milliseconds: 600), () {
                          if (mounted) setState(() => _isLoading = false);
                        });
                      }),
                      onClose: () => setState(() => _showFilters = false),
                    ),
                  ),

                // Results Area (Left or Center)
                Expanded(
                  flex: isMobile || !_showMapView ? 1 : 1,
                  child: ResultsArea(
                    filteredServices: filteredServices,
                    isLoading: _isLoading,
                    isMobile: isMobile,
                    isGridView: _isGridView,
                    searchQuery: _searchQuery,
                    sortBy: _sortBy,
                    onSortChanged: (val) => setState(() => _sortBy = val),
                    onViewToggled: (val) => setState(() => _isGridView = val),
                    showMapView: _showMapView,
                    onMapToggled: () => setState(() {
                      _showMapView = !_showMapView;
                      if (_showMapView) {
                        _isGridView =
                            false; // Usually map view pairs with list or stacked grid
                      }
                    }),
                    onClearFilters: _resetFilters,
                    onExploreNearby: () => setState(() {
                      _searchQuery = '';
                      _destinationController.clear();
                    }),
                  ),
                ),

                // Map split right side
                if (!isMobile && _showMapView)
                  Expanded(
                    flex: 1,
                    child: MapViewWidget(
                      services: filteredServices,
                      onClose: () => setState(() => _showMapView = false),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),

      // Floating Filter Button for Mobile
      floatingActionButton: isMobile
          ? FloatingActionButton.extended(
              onPressed: () => _showMobileFilterSheet(context),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.filter_list),
              label: const Text(
                'Filters',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildHeaderBar(bool isMobile) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: SafeArea(
        top: isMobile,
        bottom: false,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 16 : 24,
            vertical: isMobile ? 12 : 16,
          ),
          child: isMobile ? _buildMobileHeader() : _buildDesktopHeader(),
        ),
      ),
    );
  }

  Widget _buildDesktopHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          children: [
            Expanded(
              flex: 3,
              child: SearchField(
                controller: _destinationController,
                hintText: 'Destination / City',
                icon: Icons.location_on,
                onChanged: (val) => setState(() => _searchQuery = val),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: DateField(
                controller: _checkInController,
                hintText: 'Check-in',
                onTap: () => _selectDate(context, true),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: DateField(
                controller: _checkOutController,
                hintText: 'Check-out',
                onTap: () => _selectDate(context, false),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 160,
              child: GuestsField(
                controller: _guestsController,
                guestsCount: _guestsCount,
                onIncrement: () => setState(() {
                  _guestsCount++;
                  _guestsController.text = _guestsCount.toString();
                }),
                onDecrement: () => setState(() {
                  if (_guestsCount > 1) {
                    _guestsCount--;
                    _guestsController.text = _guestsCount.toString();
                  }
                }),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Added Spacer to maintain button alignment on the right
            const Spacer(),

            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () => setState(() => _showFilters = !_showFilters),
                  icon: Icon(
                    _showFilters
                        ? Icons.filter_list
                        : Icons.filter_list_outlined,
                    color: _showFilters ? AppColors.primary : Colors.black87,
                  ),
                  label: Text(
                    _showFilters ? 'Hide Filters' : 'Filters',
                    style: TextStyle(
                      color: _showFilters ? AppColors.primary : Colors.black87,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: _showFilters
                          ? AppColors.primary
                          : Colors.grey.shade300,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () => setState(() {
                    _isLoading = true;
                    Future.delayed(const Duration(milliseconds: 800), () {
                      if (mounted) setState(() => _isLoading = false);
                    });
                  }),
                  icon: const Icon(Icons.search),
                  label: const Text(
                    'Search',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMobileHeader() {
    return Column(
      children: [
        SearchField(
          controller: _destinationController,
          hintText: 'Destination / City',
          icon: Icons.location_on,
          onChanged: (val) => setState(() => _searchQuery = val),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: DateField(
                controller: _checkInController,
                hintText: 'Check-in',
                onTap: () => _selectDate(context, true),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DateField(
                controller: _checkOutController,
                hintText: 'Check-out',
                onTap: () => _selectDate(context, false),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              flex: 1,
              child: GuestsField(
                controller: _guestsController,
                guestsCount: _guestsCount,
                onIncrement: () => setState(() {
                  _guestsCount++;
                  _guestsController.text = _guestsCount.toString();
                }),
                onDecrement: () => setState(() {
                  if (_guestsCount > 1) {
                    _guestsCount--;
                    _guestsController.text = _guestsCount.toString();
                  }
                }),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 1,
              child: ElevatedButton.icon(
                onPressed: () => setState(() {
                  _isLoading = true;
                  Future.delayed(const Duration(milliseconds: 600), () {
                    if (mounted) setState(() => _isLoading = false);
                  });
                }),
                icon: const Icon(Icons.search),
                label: const Text(
                  'Search',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _selectDate(BuildContext context, bool isCheckIn) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isCheckIn
          ? (_checkInDate ?? DateTime.now())
          : (_checkOutDate ??
                _checkInDate?.add(const Duration(days: 1)) ??
                DateTime.now().add(const Duration(days: 1))),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: AppColors.primary),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isCheckIn) {
          _checkInDate = picked;
          _checkInController.text = DateFormat('MMM dd, yyyy').format(picked);
        } else {
          _checkOutDate = picked;
          _checkOutController.text = DateFormat('MMM dd, yyyy').format(picked);
        }
      });
    }
  }

  void _showMobileFilterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: DraggableScrollableSheet(
          initialChildSize: 0.85,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          builder: (context, scrollController) => Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: StatefulBuilder(
                  builder: (context, setModalState) {
                    return FiltersSidebar(
                      priceRange: _priceRange,
                      onPriceRangeChanged: (val) {
                        setModalState(() => _priceRange = val);
                        setState(() => _priceRange = val);
                      },
                      selectedPropertyTypes: _selectedPropertyTypes,
                      onPropertyTypeToggled: (val) {
                        setModalState(() {
                          if (_selectedPropertyTypes.contains(val)) {
                            _selectedPropertyTypes.remove(val);
                          } else {
                            _selectedPropertyTypes.add(val);
                          }
                        });
                        setState(() {}); // Parent rebuild
                      },
                      selectedAmenities: _selectedAmenities,
                      onAmenityToggled: (val) {
                        setModalState(() {
                          if (_selectedAmenities.contains(val)) {
                            _selectedAmenities.remove(val);
                          } else {
                            _selectedAmenities.add(val);
                          }
                        });
                        setState(() {}); // Parent rebuild
                      },
                      verifiedOnly: _verifiedOnly,
                      onVerifiedOnlyChanged: (val) {
                        setModalState(() => _verifiedOnly = val);
                        setState(() => _verifiedOnly = val);
                      },
                      onReset: () {
                        setModalState(() => _resetFilters());
                      },
                      onApply: () {
                        Navigator.pop(context);
                        setState(() {
                          _isLoading = true;
                          Future.delayed(const Duration(milliseconds: 600), () {
                            if (mounted) setState(() => _isLoading = false);
                          });
                        });
                      },
                      onClose: () => Navigator.pop(context),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
