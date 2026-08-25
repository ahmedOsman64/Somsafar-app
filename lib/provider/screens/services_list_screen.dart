import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/responsive.dart';
import '../../shared/services/service_repository.dart';
import '../../shared/models/service_model.dart';
import '../../shared/services/auth_service.dart';
import '../../shared/models/user_model.dart';
import '../../shared/widgets/confirmation_dialog.dart';
import '../../shared/widgets/app_network_image.dart';

class ProviderServicesScreen extends ConsumerStatefulWidget {
  const ProviderServicesScreen({super.key});

  @override
  ConsumerState<ProviderServicesScreen> createState() =>
      _ProviderServicesScreenState();
}

class _ProviderServicesScreenState
    extends ConsumerState<ProviderServicesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isGridView = false;
  bool _isLoading = false;
  _StatusFilter _selectedFilter = _StatusFilter.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final services = ref.watch(filteredServicesProvider);
    final user = ref.watch(authProvider);
    final providerType = user?.providerType ?? ProviderType.hotel;

    String title = 'Manage Services';
    String addLabel = 'Add Service';

    switch (providerType) {
      case ProviderType.hotel:
        title = 'Manage Hotels';
        addLabel = 'Add Hotel';
        break;
      case ProviderType.home:
      case ProviderType.apartment:
        title = 'Manage Apartments';
        addLabel = 'Add Apartment';
        break;
      case ProviderType.all:
        title = 'Manage Services';
        addLabel = 'Add Service';
        break;
      case ProviderType.tour:
        title = 'Manage Tours';
        addLabel = 'Add Tour';
        break;
    }

    // Filter services
    final filteredServices = services.where((s) {
      final matchesSearch =
          s.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          s.location.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          s.category.toLowerCase().contains(_searchQuery.toLowerCase());

      bool matchesStatus = true;
      if (_selectedFilter == _StatusFilter.active) {
        matchesStatus = s.status == ServiceStatus.active;
      } else if (_selectedFilter == _StatusFilter.inactive) {
        matchesStatus = s.status == ServiceStatus.inactive;
      }

      return matchesSearch && matchesStatus;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              children: [
                // ── Full-Width Header Banner ────────────────────────
                _buildHeader(context, title, addLabel),

                const SizedBox(height: 20),

                // ── Filter Chips Bar ────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildFilterChip(_StatusFilter.all, 'All Services (${services.length})'),
                            const SizedBox(width: 8),
                            _buildFilterChip(
                              _StatusFilter.active,
                              'Active (${services.where((s) => s.status == ServiceStatus.active).length})',
                            ),
                            const SizedBox(width: 8),
                            _buildFilterChip(
                              _StatusFilter.inactive,
                              'Inactive (${services.where((s) => s.status == ServiceStatus.inactive).length})',
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${filteredServices.length} listing(s)',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ── Service List / Grid ─────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: filteredServices.isEmpty
                      ? _buildEmptyState(context, addLabel)
                      : RefreshIndicator(
                          onRefresh: () async {
                            ref.invalidate(serviceProvider);
                          },
                          child: _isGridView
                              ? GridView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: context.isMobile
                                        ? 2
                                        : (context.isTablet ? 3 : 4),
                                    crossAxisSpacing: 16,
                                    mainAxisSpacing: 16,
                                    childAspectRatio: 0.78,
                                  ),
                                  itemCount: filteredServices.length,
                                  itemBuilder: (context, index) => _ServiceGridCard(
                                    service: filteredServices[index],
                                    ref: ref,
                                    onLoading: (val) =>
                                        setState(() => _isLoading = val),
                                  ),
                                )
                              : ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: filteredServices.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 14),
                                  itemBuilder: (context, index) => _ServiceListCard(
                                    service: filteredServices[index],
                                    ref: ref,
                                    onLoading: (val) =>
                                        setState(() => _isLoading = val),
                                  ),
                                ),
                        ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),

          if (_isLoading)
            Container(
              color: Colors.black38,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String title, String addLabel) {
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
                          Icons.grid_view_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const Text(
                            'Manage listings, pricing & availability',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(25),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: IconButton(
                          icon: Icon(
                            _isGridView
                                ? Icons.view_list_rounded
                                : Icons.grid_view_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          onPressed: () =>
                              setState(() => _isGridView = !_isGridView),
                          tooltip: _isGridView ? 'Switch to List' : 'Switch to Grid',
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: () => context.push('/provider/services/add'),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: Text(addLabel),
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
                ],
              ),
              const SizedBox(height: 20),

              // Search Field
              TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val),
                style: const TextStyle(color: Color(0xFF0F172A)),
                decoration: InputDecoration(
                  hintText: 'Search by title, category, or location...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(_StatusFilter filter, String label) {
    final isSelected = _selectedFilter == filter;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) setState(() => _selectedFilter = filter);
      },
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : const Color(0xFF0F172A),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        fontSize: 12,
      ),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? AppColors.primary : Colors.grey[200]!,
        ),
      ),
      showCheckmark: false,
    );
  }

  Widget _buildEmptyState(BuildContext context, String addLabel) {
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
          Icon(Icons.search_off_rounded, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty ? 'No listings published' : 'No matches found',
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isEmpty
                ? 'Create your first service or property listing to start accepting bookings.'
                : 'Try refining your search query or status filter.',
            style: TextStyle(color: Colors.grey[500], fontSize: 13),
            textAlign: TextAlign.center,
          ),
          if (_searchQuery.isEmpty) ...[
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => context.push('/provider/services/add'),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(addLabel),
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
}

enum _StatusFilter { all, active, inactive }

class _ServiceListCard extends StatelessWidget {
  final Service service;
  final WidgetRef ref;
  final Function(bool) onLoading;

  const _ServiceListCard({
    required this.service,
    required this.ref,
    required this.onLoading,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Image Preview
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  AppNetworkImage(
                    imageUrl: service.images.isNotEmpty
                        ? service.images.first
                        : '',
                    width: 84,
                    height: 84,
                    fit: BoxFit.cover,
                    memCacheWidth: 168,
                    errorWidget: Container(
                      width: 84,
                      height: 84,
                      color: Colors.grey[200],
                      child: const Icon(Icons.image_not_supported_rounded,
                          color: Colors.grey),
                    ),
                  ),
                  if ((service.rating ?? 0) > 0)
                    Positioned(
                      top: 4,
                      left: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(160),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star_rounded,
                                color: Colors.amber, size: 12),
                            const SizedBox(width: 2),
                            Text(
                              (service.rating ?? 0.0).toStringAsFixed(1),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 14),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          service.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Color(0xFF0F172A),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      _StatusChip(
                        status: service.status,
                        label: service.statusLabel,
                        color: service.statusColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.location_on_rounded,
                          size: 13, color: Colors.grey[400]),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          '${service.category} · ${service.location}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_getFormattedPriceText(service)} ${_getPricingUnit(service)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: AppColors.primary,
                        ),
                      ),
                      _ServicePopupMenu(
                        service: service,
                        ref: ref,
                        onLoading: onLoading,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceGridCard extends StatelessWidget {
  final Service service;
  final WidgetRef ref;
  final Function(bool) onLoading;

  const _ServiceGridCard({
    required this.service,
    required this.ref,
    required this.onLoading,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
          // Image Banner
          Expanded(
            flex: 3,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                  child: AppNetworkImage(
                    imageUrl: service.images.isNotEmpty
                        ? service.images.first
                        : '',
                    fit: BoxFit.cover,
                    memCacheWidth: 300,
                    errorWidget: Container(
                      color: Colors.grey[200],
                      child: const Icon(Icons.image_rounded, color: Colors.grey),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: _StatusChip(
                    status: service.status,
                    label: service.statusLabel,
                    color: service.statusColor,
                    compact: true,
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(120),
                      shape: BoxShape.circle,
                    ),
                    child: _ServicePopupMenu(
                      service: service,
                      ref: ref,
                      onLoading: onLoading,
                      isIconWhite: true,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Details
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    service.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    '${service.category} · ${service.location}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
                  Text(
                    '${_getFormattedPriceText(service)} ${_getPricingUnit(service)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

double _getResolvedPrice(Service service) {
  if (service.price > 0) return service.price;

  final rooms = service.metadata['rooms'];
  if (rooms is List && rooms.isNotEmpty) {
    final prices = rooms
        .map((r) => double.tryParse(r['price']?.toString() ?? '0') ?? 0.0)
        .where((p) => p > 0);
    if (prices.isNotEmpty) {
      return prices.reduce((a, b) => a < b ? a : b);
    }
  }

  if ((service.adultPrice ?? 0) > 0) {
    return service.adultPrice!;
  }

  return 0.0;
}

String _getFormattedPriceText(Service service) {
  final price = _getResolvedPrice(service);
  if (price == 0) return '\$0.00';
  return price % 1 == 0 ? '\$${price.toInt()}' : '\$${price.toStringAsFixed(2)}';
}

String _getPricingUnit(Service service) {
  final cat = service.category.toLowerCase();
  final pricingType = service.pricingType.toLowerCase();

  if (pricingType == 'monthly' || cat.contains('monthly')) return '/ month';
  if (pricingType == 'daily' ||
      cat.contains('tour') ||
      cat.contains('vehicle') ||
      cat.contains('car') ||
      cat.contains('rent')) {
    return '/ day';
  }
  if (cat.contains('person') || cat.contains('guest')) return '/ person';
  return '/ night';
}

class _StatusChip extends StatelessWidget {
  final ServiceStatus status;
  final String label;
  final Color color;
  final bool compact;

  const _StatusChip({
    required this.status,
    required this.label,
    required this.color,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: compact ? 9.5 : 10.5,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _ServicePopupMenu extends StatelessWidget {
  final Service service;
  final WidgetRef ref;
  final Function(bool) onLoading;
  final bool isIconWhite;

  const _ServicePopupMenu({
    required this.service,
    required this.ref,
    required this.onLoading,
    this.isIconWhite = false,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.more_vert_rounded,
        color: isIconWhite ? Colors.white : Colors.grey[600],
        size: 20,
      ),
      onSelected: (value) async {
        if (value == 'edit') {
          if (service.status == ServiceStatus.blocked) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Cannot edit blocked service')),
            );
            return;
          }
          if (service.metadata['pending_deletion'] == true) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Cannot edit service marked for deletion'),
              ),
            );
            return;
          }
          context.push('/provider/services/edit/${service.id}');
        } else if (value == 'toggle') {
          if (service.metadata['pending_deletion'] == true) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Cannot activate/deactivate service marked for deletion',
                ),
              ),
            );
            return;
          }
          final isActivating = service.status != ServiceStatus.active;
          final actionVerb = isActivating ? 'Activate' : 'Deactivate';

          final confirmed = await ConfirmationDialog.show(
            context: context,
            title: '$actionVerb Service?',
            message:
                'Confirm Action: Do you want to $actionVerb this ${service.category.toLowerCase()}?',
            confirmLabel: 'Yes, $actionVerb',
            type: ConfirmationDialogType.info,
            icon: isActivating
                ? Icons.check_circle_outline
                : Icons.pause_circle_outline,
          );

          if (confirmed != true) return;

          final newStatus =
              isActivating ? ServiceStatus.active : ServiceStatus.inactive;
          onLoading(true);
          try {
            await ref
                .read(serviceProvider.notifier)
                .updateService(service.copyWith(status: newStatus));
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Service ${newStatus == ServiceStatus.active ? 'activated' : 'deactivated'} successfully!',
                  ),
                  backgroundColor: AppColors.primary,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to update service: $e'),
                  backgroundColor: Colors.red,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          } finally {
            onLoading(false);
          }
        } else if (value == 'delete') {
          _showDeleteConfirm(context, ref, service);
        }
      },
      itemBuilder: (context) {
        final isPendingDeletion = service.metadata['pending_deletion'] == true;

        return [
          PopupMenuItem(
            value: 'edit',
            enabled: !isPendingDeletion,
            child: Text(
              'Edit Listing',
              style: TextStyle(color: isPendingDeletion ? Colors.grey : null),
            ),
          ),
          PopupMenuItem(
            value: 'toggle',
            enabled: !isPendingDeletion,
            child: Text(
              service.status == ServiceStatus.active ? 'Deactivate' : 'Activate',
              style: TextStyle(color: isPendingDeletion ? Colors.grey : null),
            ),
          ),
          PopupMenuItem(
            value: 'delete',
            child: Text(
              isPendingDeletion ? 'Pending Deletion' : 'Delete Listing',
              style: TextStyle(
                color: isPendingDeletion ? Colors.orange : Colors.red,
              ),
            ),
          ),
        ];
      },
    );
  }

  void _showDeleteConfirm(
      BuildContext context, WidgetRef ref, Service service) async {
    final confirmed = await ConfirmationDialog.show(
      context: context,
      title: 'Delete Service?',
      message:
          'Are you sure you want to delete ${service.title}? This action cannot be undone.',
      confirmLabel: 'Yes, Delete',
      type: ConfirmationDialogType.danger,
      icon: Icons.delete_forever_outlined,
    );

    if (confirmed == true) {
      onLoading(true);
      try {
        await ref.read(serviceProvider.notifier).deleteService(service.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Service deleted successfully!'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          final isPendingDeletion = e.toString().contains('PENDING_DELETION');

          if (isPendingDeletion) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Service has active bookings. It will be hidden from new customers and deleted automatically once bookings are completed.',
                ),
                backgroundColor: AppColors.secondary,
                duration: Duration(seconds: 5),
                behavior: SnackBarBehavior.floating,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Delete failed: $e'),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      } finally {
        onLoading(false);
      }
    }
  }
}
