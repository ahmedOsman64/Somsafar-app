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
        title = 'Manage Apartments';
        addLabel = 'Add Apartment';
        break;
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
          s.location.toLowerCase().contains(_searchQuery.toLowerCase());

      bool matchesStatus = true;
      if (_selectedFilter == _StatusFilter.active) {
        matchesStatus = s.status == ServiceStatus.active;
      } else if (_selectedFilter == _StatusFilter.inactive) {
        matchesStatus = s.status == ServiceStatus.inactive;
      }

      return matchesSearch && matchesStatus;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view),
            onPressed: () => setState(() => _isGridView = !_isGridView),
            tooltip: 'Toggle View',
          ),
          IconButton(
            onPressed: () => context.push('/provider/services/add'),
            icon: const Icon(Icons.add),
            tooltip: addLabel,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(110),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: Row(
                  children: [
                    _buildFilterChip(_StatusFilter.all, 'All Services'),
                    const SizedBox(width: 8),
                    _buildFilterChip(_StatusFilter.active, 'Active'),
                    const SizedBox(width: 8),
                    _buildFilterChip(_StatusFilter.inactive, 'Inactive'),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      body: Stack(
        children: [
          filteredServices.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.search_off, size: 64, color: AppColors.grey),
                      const SizedBox(height: 16),
                      Text(
                        _searchQuery.isEmpty
                            ? 'No services found'
                            : 'No matches found',
                      ),
                      if (_searchQuery.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 16.0),
                          child: ElevatedButton(
                            onPressed: () => context.go('/provider/services/add'),
                            child: const Text('Add Service'),
                          ),
                        ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(serviceProvider);
                  },
                  child: _isGridView
                      ? GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: context.isMobile 
                                ? 2 
                                : (context.isTablet ? 3 : 4),
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: 0.8,
                          ),
                          itemCount: filteredServices.length,
                          itemBuilder: (context, index) => _ServiceGridCard(
                            service: filteredServices[index],
                            ref: ref,
                            onLoading: (val) => setState(() => _isLoading = val),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredServices.length,
                          itemBuilder: (context, index) => _ServiceListCard(
                            service: filteredServices[index],
                            ref: ref,
                            onLoading: (val) => setState(() => _isLoading = val),
                          ),
                        ),
                ),
          if (_isLoading)
            Container(
              color: Colors.black26,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
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
      selectedColor: AppColors.secondary.withValues(alpha: 0.2),
      labelStyle: TextStyle(
        color: isSelected ? AppColors.secondary : Colors.grey[700],
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? AppColors.secondary : Colors.grey[300]!,
          width: 1,
        ),
      ),
      showCheckmark: false,
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
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            service.images.first,
            width: 60,
            height: 60,
            fit: BoxFit.cover,
            errorBuilder: (c, o, s) => Container(
              width: 60,
              height: 60,
              color: Colors.grey,
              child: const Icon(Icons.image_not_supported),
            ),
          ),
        ),
        title: Text(
          service.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${service.category} • ${service.location}'),
            const SizedBox(height: 4),
            Row(
              children: [
                _StatusChip(
                  status: service.status,
                  label: service.statusLabel,
                  color: service.statusColor,
                ),
                const Spacer(),
                Text(
                  '\$${service.price.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: _ServicePopupMenu(
          service: service,
          ref: ref,
          onLoading: onLoading,
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
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  service.images.first,
                  fit: BoxFit.cover,
                  errorBuilder: (c, o, s) => Container(
                    color: Colors.grey,
                    child: const Icon(Icons.image),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: _ServicePopupMenu(
                    service: service,
                    ref: ref,
                    onLoading: onLoading,
                    isIconWhite: true,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    service.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    service.location,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _StatusChip(
                        status: service.status,
                        label: service.statusLabel,
                        color: service.statusColor,
                        compact: true,
                      ),
                      Text(
                        '\$${service.price.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
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
  }
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
      padding: EdgeInsets.symmetric(horizontal: compact ? 4 : 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(26),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
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
        Icons.more_vert,
        color: isIconWhite ? Colors.white : Colors.grey,
      ),
      onSelected: (value) async {
        if (value == 'edit') {
          if (service.status == ServiceStatus.blocked) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Cannot edit blocked service')),
            );
            return;
          }
          context.push('/provider/services/edit/${service.id}');
        } else if (value == 'toggle') {
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
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'edit', child: Text('Edit')),
        PopupMenuItem(
          value: 'toggle',
          child: Text(
            service.status == ServiceStatus.active ? 'Deactivate' : 'Activate',
          ),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: Text('Delete', style: TextStyle(color: Colors.red)),
        ),
      ],
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Delete failed: $e'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } finally {
        onLoading(false);
      }
    }
  }
}
