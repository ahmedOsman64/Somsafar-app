import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/services/user_repository.dart';
import '../../shared/models/user_model.dart';
import '../../shared/services/auth_service.dart';
import '../../shared/services/service_repository.dart';
import '../../shared/models/service_model.dart';
import '../../shared/services/booking_repository.dart';
import '../../shared/models/booking_model.dart';
import '../../shared/services/lookup_service.dart';

class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> {
  UserRole? _filterRole;
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final startUsers = ref.watch(userProvider);
    final currentUser = ref.watch(authProvider);
    final adminRole = currentUser?.adminRole ?? AdminRole.supportAdmin;

    // Filter Logic
    final filteredUsers = startUsers.where((u) {
      if (_filterRole != null && u.role != _filterRole) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        return u.name.toLowerCase().contains(q) ||
            u.email.toLowerCase().contains(q);
      }
      return true;
    }).toList();

    return Scaffold(
      floatingActionButton: (adminRole == AdminRole.superAdmin)
          ? FloatingActionButton.extended(
              onPressed: () => context.go('/admin/users/create'),
              label: const Text('Add User'),
              icon: const Icon(Icons.add),
              backgroundColor: AppColors.primary,
            )
          : null,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Toolbar
            Card(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: 'Search users...',
                          border: InputBorder.none,
                        ),
                        onChanged: (v) => setState(() => _searchQuery = v),
                      ),
                    ),
                    const VerticalDivider(),
                    DropdownButton<UserRole?>(
                      value: _filterRole,
                      hint: const Text('All Roles'),
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(value: null, child: Text('All Roles')),
                        DropdownMenuItem(
                          value: UserRole.provider,
                          child: Text('Providers'),
                        ),
                        DropdownMenuItem(
                          value: UserRole.admin,
                          child: Text('Admins'),
                        ),
                      ],
                      onChanged: (v) => setState(() => _filterRole = v),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // User List
            Expanded(
              child: Card(
                child: ListView.separated(
                  itemCount: filteredUsers.length,
                  separatorBuilder: (c, i) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final user = filteredUsers[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: user.profileImage != null
                            ? NetworkImage(user.profileImage!)
                            : null,
                        child: user.profileImage == null
                            ? Text(user.name[0].toUpperCase())
                            : null,
                      ),
                      title: Text(
                        user.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text('${user.email} • ${user.role.name}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (user.status == UserStatus.suspended)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red[100],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Suspended',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          if (adminRole == AdminRole.superAdmin ||
                              (adminRole == AdminRole.opsAdmin &&
                                  user.role == UserRole.provider))
                            PopupMenuButton(
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit, size: 16),
                                      SizedBox(width: 8),
                                      Text('Edit'),
                                    ],
                                  ),
                                ),
                                if (user.status == UserStatus.active)
                                  const PopupMenuItem(
                                    value: 'suspend',
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.block,
                                          size: 16,
                                          color: Colors.orange,
                                        ),
                                        SizedBox(width: 8),
                                        Text('Suspend'),
                                      ],
                                    ),
                                  ),
                                if (user.status == UserStatus.suspended)
                                  const PopupMenuItem(
                                    value: 'activate',
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.check_circle,
                                          size: 16,
                                          color: Colors.green,
                                        ),
                                        SizedBox(width: 8),
                                        Text('Activate'),
                                      ],
                                    ),
                                  ),
                                if (adminRole == AdminRole.superAdmin)
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.delete,
                                          size: 16,
                                          color: Colors.red,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'Delete',
                                          style: TextStyle(color: Colors.red),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                              onSelected: (value) {
                                // Handle Actions
                                if (value == 'suspend') {
                                  _updateUserStatus(
                                    ref,
                                    user,
                                    UserStatus.suspended,
                                  );
                                } else if (value == 'activate') {
                                  _updateUserStatus(
                                    ref,
                                    user,
                                    UserStatus.active,
                                  );
                                } else if (value == 'delete') {
                                  _deleteUser(ref, user);
                                }
                              },
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _updateUserStatus(WidgetRef ref, User user, UserStatus status) {
    final updatedUser = user.copyWith(status: status);
    ref.read(userProvider.notifier).updateUser(updatedUser);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('User ${user.name} is now ${status.name}')),
    );
  }

  void _deleteUser(WidgetRef ref, User user) {
    // Implement delete logic in repository first if not present
    // ref.read(userProvider.notifier).deleteUser(user.id);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Delete feature coming soon')));
  }
}

class AdminServicesScreen extends ConsumerStatefulWidget {
  const AdminServicesScreen({super.key});
  @override
  ConsumerState<AdminServicesScreen> createState() =>
      _AdminServicesScreenState();
}

class _AdminServicesScreenState extends ConsumerState<AdminServicesScreen> {
  ServiceStatus? _filterStatus;

  @override
  Widget build(BuildContext context) {
    final services = ref.watch(serviceProvider);
    final currentUser = ref.watch(authProvider);
    final adminRole = currentUser?.adminRole ?? AdminRole.supportAdmin;

    final filteredServices = services.where((s) {
      if (_filterStatus != null && s.status != _filterStatus) return false;
      return true;
    }).toList();

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    const Text(
                      'Filter by Status: ',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 16),
                    DropdownButton<ServiceStatus?>(
                      value: _filterStatus,
                      hint: const Text('All Statuses'),
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(value: null, child: Text('All')),
                        DropdownMenuItem(
                          value: ServiceStatus.active,
                          child: Text('Active'),
                        ),
                        DropdownMenuItem(
                          value: ServiceStatus.pendingApproval,
                          child: Text('Pending'),
                        ),
                        DropdownMenuItem(
                          value: ServiceStatus.draft,
                          child: Text('Draft'),
                        ),
                      ],
                      onChanged: (v) => setState(() => _filterStatus = v),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Card(
                child: ListView.separated(
                  itemCount: filteredServices.length,
                  separatorBuilder: (c, i) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final service = filteredServices[index];
                    return ListTile(
                      leading: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          image: service.images.isNotEmpty
                              ? DecorationImage(
                                  image: NetworkImage(service.images.first),
                                  fit: BoxFit.cover,
                                )
                              : null,
                          color: Colors.grey[300],
                        ),
                        child: service.images.isEmpty
                            ? const Icon(Icons.image, color: Colors.grey)
                            : null,
                      ),
                      title: Text(
                        service.title,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '${service.category} • \$${service.price}/night\nProvider: ${service.providerId}',
                      ),
                      isThreeLine: true,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildStatusChip(service.status),
                          if (adminRole == AdminRole.superAdmin ||
                              adminRole == AdminRole.opsAdmin)
                            PopupMenuButton(
                              itemBuilder: (context) => [
                                if (service.status ==
                                    ServiceStatus.pendingApproval)
                                  const PopupMenuItem(
                                    value: 'approve',
                                    child: Row(
                                      children: [
                                        Icon(Icons.check, color: Colors.green),
                                        SizedBox(width: 8),
                                        Text('Approve'),
                                      ],
                                    ),
                                  ),
                                if (service.status ==
                                        ServiceStatus.pendingApproval ||
                                    service.status == ServiceStatus.active)
                                  const PopupMenuItem(
                                    value: 'reject',
                                    child: Row(
                                      children: [
                                        Icon(Icons.close, color: Colors.red),
                                        SizedBox(width: 8),
                                        Text('Reject/Suspend'),
                                      ],
                                    ),
                                  ),
                              ],
                              onSelected: (value) {
                                if (value == 'approve') {
                                  _updateServiceStatus(
                                    ref,
                                    service,
                                    ServiceStatus.active,
                                  );
                                } else if (value == 'reject') {
                                  _updateServiceStatus(
                                    ref,
                                    service,
                                    ServiceStatus.draft,
                                  ); // Or suspended if enum exists
                                }
                              },
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(ServiceStatus status) {
    Color color;
    switch (status) {
      case ServiceStatus.active:
        color = Colors.green;
        break;
      case ServiceStatus.pendingApproval:
        color = Colors.orange;
        break;
      case ServiceStatus.draft:
        color = Colors.grey;
        break;
      default:
        color = Colors.grey;
    }
    return Chip(
      label: Text(
        status.name,
        style: const TextStyle(color: Colors.white, fontSize: 10),
      ),
      backgroundColor: color,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }

  void _updateServiceStatus(
    WidgetRef ref,
    Service service,
    ServiceStatus status,
  ) {
    final updatedService = service.copyWith(status: status);
    ref.read(serviceProvider.notifier).updateService(updatedService);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Service ${status.name}')));
  }
}

class AdminFinancialsScreen extends ConsumerWidget {
  const AdminFinancialsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookings = ref.watch(bookingProvider);
    // Simple revenue calculation
    final totalRevenue = bookings
        .where((b) => b.paymentStatus == BookingPaymentStatus.paid)
        .fold(0.0, (sum, b) => sum + b.totalPrice);

    // Recent Transactions (Mock from bookings)
    final paidBookings = bookings
        .where((b) => b.paymentStatus == BookingPaymentStatus.paid)
        .toList();

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Key Financial Cards
            Row(
              children: [
                Expanded(
                  child: _FinancialCard(
                    title: 'Total Revenue',
                    value: '\$${totalRevenue.toStringAsFixed(2)}',
                    icon: Icons.attach_money,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _FinancialCard(
                    title: 'Pending Payouts',
                    value:
                        '\$${(totalRevenue * 0.8).toStringAsFixed(2)}', // Mock 80% pending
                    icon: Icons.pending_actions,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Transactions',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.download),
                  label: const Text('Export Report'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Card(
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: paidBookings.length,
                separatorBuilder: (c, i) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final booking = paidBookings[index];
                  return ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.green,
                      child: Icon(Icons.check, color: Colors.white, size: 16),
                    ),
                    title: Text('Payment for ${booking.serviceTitle}'),
                    subtitle: Text(
                      'Booking #${booking.id} • ${booking.travelerName}',
                    ),
                    trailing: Text(
                      '+\$${booking.totalPrice}',
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FinancialCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _FinancialCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 16),
            Text(
              value,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text(title, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

class AdminSupportScreen extends StatelessWidget {
  const AdminSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Mock Support Tickets
    final tickets = [
      {
        'id': '#T101',
        'user': 'John Traveler',
        'issue': 'Booking Cancellation Request',
        'status': 'Open',
      },
      {
        'id': '#T102',
        'user': 'Sarah Host',
        'issue': 'Payment not received',
        'status': 'In Progress',
      },
      {
        'id': '#T103',
        'user': 'Ahmed Mohamed',
        'issue': 'Login issues',
        'status': 'Closed',
      },
    ];

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView.builder(
          itemCount: tickets.length,
          itemBuilder: (context, index) {
            final t = tickets[index];
            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: _getStatusColor(t['status']!),
                  child: const Icon(Icons.support_agent, color: Colors.white),
                ),
                title: Text(t['issue']!),
                subtitle: Text('${t['id']} • ${t['user']}'),
                trailing: Chip(
                  label: Text(t['status']!),
                  backgroundColor: _getStatusColor(t['status']!).withAlpha(50),
                ),
                onTap: () {},
              ),
            );
          },
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Open':
        return Colors.red;
      case 'In Progress':
        return Colors.orange;
      case 'Closed':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}

class AdminSettingsScreen extends ConsumerWidget {
  const AdminSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'System Settings',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
            ),
            const SizedBox(height: 32),
            _buildSection(
              context,
              title: 'System Maintenance',
              icon: Icons.build_circle_outlined,
              children: [
                ListTile(
                  leading: const Icon(Icons.storage_outlined, color: Colors.orange),
                  title: const Text('Fix Missing Database Lookups'),
                  subtitle: const Text(
                    'Restore essential categories, regions, and amenities if they are missing from the database.',
                  ),
                  trailing: ElevatedButton(
                    onPressed: () => _handleSeedLookups(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Run Fix'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildSection(
              context,
              title: 'Platform Configuration',
              icon: Icons.settings_applications_outlined,
              children: [
                const ListTile(
                  leading: Icon(Icons.email_outlined),
                  title: Text('System Notifications'),
                  subtitle: Text('Enable/Disable automated platform emails'),
                  trailing: Switch(value: true, onChanged: null),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.payments_outlined),
                  title: const Text('Platform Fee (%)'),
                  subtitle: const Text('Default service fee for all bookings'),
                  trailing: Text(
                    '10%',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...children,
        ],
      ),
    );
  }

  Future<void> _handleSeedLookups(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore Lookups?'),
        content: const Text(
          'This will ensure all essential categories, regions, and amenities exist in the database. Existing entries will not be overwritten (only labels/icons might be updated).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Proceed'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await LookupService.seedMissingLookups();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Database lookups restored successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error restoring lookups: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}
