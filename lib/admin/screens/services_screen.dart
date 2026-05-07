import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../shared/services/service_repository.dart';
import '../../shared/models/service_model.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/confirmation_dialog.dart';
import '../../shared/widgets/app_network_image.dart';

class AdminServicesScreen extends ConsumerStatefulWidget {
  const AdminServicesScreen({super.key});

  @override
  ConsumerState<AdminServicesScreen> createState() =>
      _AdminServicesScreenState();
}

class _AdminServicesScreenState extends ConsumerState<AdminServicesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final services = ref.watch(serviceProvider);

    // Filter by search
    final filteredServices = services.where((s) {
      return s.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          s.category.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    // Split by status
    final pendingServices = filteredServices
        .where((s) => s.status == ServiceStatus.pendingApproval)
        .toList();
    final activeServices = filteredServices
        .where((s) => s.status == ServiceStatus.active)
        .toList();
    final inactiveServices = filteredServices
        .where(
          (s) =>
              s.status == ServiceStatus.inactive ||
              s.status == ServiceStatus.draft,
        )
        .toList();
    final blockedServices = filteredServices
        .where((s) => s.status == ServiceStatus.blocked)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Services'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/admin/dashboard'),
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: AppColors.accent,
          tabs: [
            Tab(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Moderation'),
                    if (pendingServices.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${pendingServices.length}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Tab(text: 'Active (${activeServices.length})'),
            Tab(text: 'Inactive (${inactiveServices.length})'),
            Tab(text: 'Blocked (${blockedServices.length})'),
          ],
        ),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          hintText: 'Search services...',
                          prefixIcon: Icon(Icons.search),
                        ),
                        onChanged: (val) => setState(() => _searchQuery = val),
                      ),
                    ),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: () async {
                          ref.invalidate(serviceProvider);
                        },
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _ServiceList(
                              services: pendingServices,
                              isModeration: true,
                              onUpdateStatus: _updateStatus,
                              onDelete: (id) => _deleteService(context, id),
                            ),
                            _ServiceList(
                              services: activeServices,
                              onUpdateStatus: _updateStatus,
                              onDelete: (id) => _deleteService(context, id),
                            ),
                            _ServiceList(
                              services: inactiveServices,
                              onUpdateStatus: _updateStatus,
                              onDelete: (id) => _deleteService(context, id),
                            ),
                            _ServiceList(
                              services: blockedServices,
                              onUpdateStatus: _updateStatus,
                              onDelete: (id) => _deleteService(context, id),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
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
      ),
    );
  }

  Future<void> _updateStatus(
      BuildContext context, Service service, ServiceStatus status) async {
    // Determine action name and style
    String actionVerb = '';
    ConfirmationDialogType type = ConfirmationDialogType.info;
    IconData icon = Icons.info_outline;

    switch (status) {
      case ServiceStatus.active:
        actionVerb = service.status == ServiceStatus.blocked ? 'Unblock' : 'Approve';
        icon = Icons.check_circle_outline;
        break;
      case ServiceStatus.inactive:
        actionVerb = 'Deactivate';
        icon = Icons.pause_circle_outline;
        type = ConfirmationDialogType.info;
        break;
      case ServiceStatus.blocked:
        actionVerb = 'Block';
        icon = Icons.block;
        type = ConfirmationDialogType.danger;
        break;
      case ServiceStatus.draft:
        actionVerb = 'Reject';
        icon = Icons.close;
        type = ConfirmationDialogType.danger;
        break;
      default:
        actionVerb = 'Update';
    }

    final confirmed = await ConfirmationDialog.show(
      context: context,
      title: '$actionVerb Service?',
      message: 'Confirm Action: Do you want to $actionVerb this ${service.category.toLowerCase()}?',
      confirmLabel: 'Yes, $actionVerb',
      type: type,
      icon: icon,
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      await ref
          .read(serviceProvider.notifier)
          .updateService(service.copyWith(status: status));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Service status updated to ${status.name}'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        // Handle Postgrest error by extracting message if possible
        String errMsg = e.toString();
        if (errMsg.contains('PostgrestException')) {
          final regex = RegExp(r"message:\s*(.+?),");
          final match = regex.firstMatch(errMsg);
          if (match != null) {
            errMsg = match.group(1) ?? errMsg;
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Update failed: $errMsg'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteService(BuildContext context, String id) async {
    // We need the service title for the dialog, but _deleteService currently only gets ID.
    // However, looking at the call site, we can pass the title or the whole service object.
    // Let's find the service title from the state.
    final service = ref.read(serviceProvider).firstWhere((s) => s.id == id);

    final confirmed = await ConfirmationDialog.show(
      context: context,
      title: 'Delete Service?',
      message: 'Are you sure you want to delete ${service.title}? This action cannot be undone.',
      confirmLabel: 'Yes, Delete',
      type: ConfirmationDialogType.danger,
      icon: Icons.delete_forever_outlined,
    );

    if (confirmed == true) {
      if (!mounted) return;
      setState(() => _isLoading = true);
      try {
        await ref.read(serviceProvider.notifier).deleteService(id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Service deleted successfully!'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Delete failed: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }
}

class _ServiceList extends StatelessWidget {
  final List<Service> services;
  final bool isModeration;
  final Future<void> Function(
    BuildContext context,
    Service service,
    ServiceStatus status,
  ) onUpdateStatus;
  final Function(String id) onDelete;

  const _ServiceList({
    required this.services,
    required this.onUpdateStatus,
    required this.onDelete,
    this.isModeration = false,
  });

  @override
  Widget build(BuildContext context) {
    if (services.isEmpty) {
      return const Center(child: Text('No services found in this category'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: services.length,
      itemBuilder: (context, index) {
        final service = services[index];
        return Card(
          elevation: isModeration ? 4 : 1,
          margin: const EdgeInsets.only(bottom: 16),
          shape: isModeration
              ? RoundedRectangleBorder(
                  side: const BorderSide(color: Colors.orange, width: 2),
                  borderRadius: BorderRadius.circular(12),
                )
              : null,
          child: ExpansionTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: AppNetworkImage(
                imageUrl: service.images.isNotEmpty ? service.images.first : 'https://via.placeholder.com/150',
                width: 50,
                height: 50,
                fit: BoxFit.cover,
                memCacheWidth: 100, // Small list thumbnail
                errorWidget: Container(width: 50, height: 50, color: Colors.grey),
              ),
            ),
            title: Text(
              service.title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('${service.category} • \$${service.price}'),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: service.statusColor.withAlpha(26),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                service.statusLabel,
                style: TextStyle(
                  color: service.statusColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Description:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(service.description),
                    const SizedBox(height: 16),
                    _buildActions(context, service),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActions(BuildContext context, Service service) {
    final viewButton = OutlinedButton.icon(
      icon: const Icon(Icons.visibility_outlined),
      onPressed: () {
        _showServiceDetails(context, service);
      },
      label: const Text('View Details'),
    );

    final deleteButton = OutlinedButton.icon(
      icon: const Icon(Icons.delete_outline),
      onPressed: () => onDelete(service.id),
      style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
      label: const Text('Delete'),
    );

    if (service.status == ServiceStatus.pendingApproval) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.close),
                  onPressed: () => onUpdateStatus(
                    context,
                    service,
                    ServiceStatus.draft,
                  ),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  label: const Text('Reject'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.check),
                  onPressed: () => onUpdateStatus(context, service, ServiceStatus.active),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                  ),
                  label: const Text('Approve'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: viewButton),
              const SizedBox(width: 8),
              Expanded(child: deleteButton),
            ],
          ),
        ],
      );
    } else if (service.status == ServiceStatus.active) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => onUpdateStatus(context, service, ServiceStatus.inactive),
                  child: const Text('Deactivate'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => onUpdateStatus(context, service, ServiceStatus.blocked),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('Block'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: viewButton),
              const SizedBox(width: 8),
              Expanded(child: deleteButton),
            ],
          ),
        ],
      );
    } else {
      // Inactive, draft, or blocked
      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => onUpdateStatus(context, service, ServiceStatus.active),
              child: Text(service.status == ServiceStatus.blocked ? 'Unblock Service' : 'Activate Service'),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: viewButton),
              const SizedBox(width: 8),
              Expanded(child: deleteButton),
            ],
          ),
        ],
      );
    }
  }

  void _showServiceDetails(BuildContext context, Service service) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.info_outline, color: AppColors.primary),
            const SizedBox(width: 12),
            const Expanded(child: Text('Service Info')),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(dialogContext),
            ),
          ],
        ),
        content: SizedBox(
          width: MediaQuery.sizeOf(context).width * 0.9,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (service.images.isNotEmpty &&
                    service.images.first.isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: AppNetworkImage(
                      imageUrl: service.images.first,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      memCacheHeight: 360, // Optimize for modal height
                      errorWidget: Container(
                        height: 180,
                        width: double.infinity,
                        color: Colors.grey[200],
                        child:
                            const Icon(Icons.broken_image, color: Colors.grey),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                _buildSectionTitle('Basic Information'),
                _buildInfoRow(context, 'Title', service.title),
                _buildInfoRow(context, 'Category', service.category),
                _buildInfoRow(context, 'Status', service.statusLabel,
                    color: service.statusColor),
                _buildInfoRow(context, 'Price', '\$${service.price}'),
                _buildInfoRow(context, 'Location', service.location),
                const Divider(height: 32),
                _buildSectionTitle('Details'),
                _buildInfoRow(context, 'Description', service.description,
                    isLong: true),
                const Divider(height: 32),
                _buildSectionTitle('Metadata & Amenities'),
                if (service.category.toLowerCase().contains('hotel')) ...[
                  _buildInfoRow(
                      context,
                      'Hotel Name',
                      service.metadata['hotelName']?.toString() ??
                          service.metadata['hotel_name']?.toString() ??
                          'N/A'),
                  _buildInfoRow(
                      context,
                      'Star Rating',
                      '${service.metadata['starRating']?.toString() ?? service.metadata['star_rating']?.toString() ?? 'N/A'} Stars'),
                  _buildInfoRow(
                      context,
                      'Total Rooms',
                      service.metadata['rooms']?.toString() ??
                          service.metadata['total_rooms']?.toString() ??
                          'N/A'),
                ] else if (service.category
                    .toLowerCase()
                    .contains('apartment')) ...[
                  _buildInfoRow(
                      context,
                      'Apt Type',
                      service.metadata['apartmentType']?.toString() ??
                          service.metadata['apartment_type']?.toString() ??
                          'N/A'),
                  _buildInfoRow(
                      context,
                      'Bedrooms',
                      service.metadata['bedrooms']?.toString() ?? 'N/A'),
                  _buildInfoRow(
                      context,
                      'Bathrooms',
                      service.metadata['bathrooms']?.toString() ?? 'N/A'),
                ] else if (service.category.toLowerCase().contains('tour')) ...[
                  _buildInfoRow(
                      context,
                      'Package',
                      service.metadata['tourPackage']?.toString() ??
                          service.metadata['tour_package']?.toString() ??
                          'N/A'),
                ],
                if (service.amenities != null &&
                    service.amenities!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text('Amenities:',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                  Wrap(
                    spacing: 4,
                    children: service.amenities!
                        .map((a) => Chip(
                              label:
                                  Text(a, style: const TextStyle(fontSize: 10)),
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                            ))
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value,
      {Color? color, bool isLong = false}) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final labelWidth = screenWidth > 600 ? 120.0 : 80.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment:
            isLong ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: labelWidth,
            child: Text(
              '$label:',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
