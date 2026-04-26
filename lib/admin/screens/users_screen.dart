import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/models/user_model.dart';
import '../../core/theme/app_colors.dart';
import 'package:go_router/go_router.dart';
import '../../shared/services/user_repository.dart';
import '../../shared/services/auth_service.dart';
import '../../shared/widgets/confirmation_dialog.dart';

class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _roleFilter = 'all'; // all, traveler, provider, admin

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
    final users = ref.watch(userProvider);

    // Apply Role and Search Filter first
    var filtered = users.where((u) {
      final matchesRole = _roleFilter == 'all' || u.role.name == _roleFilter;
      final matchesSearch =
          u.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          u.email.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesRole && matchesSearch;
    }).toList();

    // Split by status categories for tabs
    final moderationUsers = filtered
        .where(
          (u) => u.role == UserRole.provider && !u.isVerified,
        )
        .toList();
    final activeUsers = filtered
        .where((u) => u.status == UserStatus.active)
        .toList();
    final blockedUsers = filtered
        .where((u) => u.status == UserStatus.blocked)
        .toList();
    final suspendedUsers = filtered
        .where((u) => u.status == UserStatus.suspended)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Users'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/admin/dashboard'),
        ),
        actions: [
          IconButton(
            onPressed: () => context.go('/admin/users/create'),
            icon: const Icon(Icons.person_add),
            tooltip: 'Create New Account',
          ),
        ],
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
                    if (moderationUsers.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${moderationUsers.length}',
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
            Tab(text: 'Active (${activeUsers.length})'),
            Tab(text: 'Blocked (${blockedUsers.length})'),
            Tab(text: 'Suspended (${suspendedUsers.length})'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Search and Role Filters
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'Search by name or email...',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChip(
                        label: 'All Roles',
                        isSelected: _roleFilter == 'all',
                        onSelected: () => setState(() => _roleFilter = 'all'),
                      ),
                      const SizedBox(width: 8),

                      _FilterChip(
                        label: 'Travelers',
                        isSelected: _roleFilter == 'traveler',
                        onSelected: () =>
                            setState(() => _roleFilter = 'traveler'),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Providers',
                        isSelected: _roleFilter == 'provider',
                        onSelected: () =>
                            setState(() => _roleFilter = 'provider'),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Admins',
                        isSelected: _roleFilter == 'admin',
                        onSelected: () => setState(() => _roleFilter = 'admin'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _UserList(users: moderationUsers, isModeration: true),
                _UserList(users: activeUsers),
                _UserList(users: blockedUsers),
                _UserList(users: suspendedUsers),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UserList extends ConsumerWidget {
  final List<User> users;
  final bool isModeration;

  const _UserList({required this.users, this.isModeration = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(authProvider);

    if (users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No users found in this category',
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(userProvider);
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(), // Ensure it's scrollable to trigger refresh
        itemCount: users.length,
        itemBuilder: (context, index) {
        final user = users[index];
        final isProvider = user.role == UserRole.provider;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: isModeration && isProvider && !user.isVerified
              ? RoundedRectangleBorder(
                  side: const BorderSide(color: Colors.orange, width: 2),
                  borderRadius: BorderRadius.circular(12),
                )
              : null,
          child: ListTile(
            leading: Stack(
              children: [
                CircleAvatar(
                  backgroundColor: user.status == UserStatus.blocked
                      ? Colors.grey
                      : isProvider
                      ? Colors.teal
                      : Colors.blue,
                  child: Icon(
                    isProvider
                        ? Icons.store
                        : (user.role == UserRole.admin
                            ? Icons.admin_panel_settings
                            : Icons.person),
                    color: Colors.white,
                  ),
                ),
                if (user.isVerified)
                  const Positioned(
                    bottom: 0,
                    right: 0,
                    child: Icon(
                      Icons.check_circle,
                      size: 16,
                      color: Colors.blue,
                    ),
                  ),
              ],
            ),
            title: Text(
              user.displayName,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                decoration: user.status == UserStatus.blocked
                    ? TextDecoration.lineThrough
                    : null,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${user.email} • ${user.role.name.toUpperCase()}${isProvider && user.providerType != null ? " (${user.providerType!.name.toUpperCase()})" : ""}',
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _getStatusColor(user.status).withAlpha(26),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        user.status.name.toUpperCase(),
                        style: TextStyle(
                          color: _getStatusColor(user.status),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (isProvider && !user.isVerified) ...[
                      const SizedBox(width: 8),
                      const Text(
                        'Verification Pending',
                        style: TextStyle(
                          color: Colors.orange,
                          fontSize: 10,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (value) =>
                  _handleAction(context, ref, user, currentUser, value),
              itemBuilder: (context) => [
                if (user.role != UserRole.traveler &&
                    !(currentUser?.isOpsAdmin == true && (user.id == currentUser?.id || user.isSuperAdmin)))
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, color: Colors.blue, size: 20),
                        SizedBox(width: 8),
                        Text('Edit User'),
                      ],
                    ),
                  ),

                if (isProvider && !user.isVerified)
                  PopupMenuItem(
                    value: 'verify',
                    enabled: !(currentUser?.isOpsAdmin == true && user.isSuperAdmin),
                    child: const Row(
                      children: [
                        Icon(Icons.verified, color: Colors.blue, size: 20),
                        SizedBox(width: 8),
                        Text('Verify Identity'),
                      ],
                    ),
                  ),

                PopupMenuItem(
                  value: 'toggle_block',
                  enabled:
                      user.id != currentUser?.id &&
                      !(currentUser?.isOpsAdmin == true && user.isSuperAdmin),
                  child: Row(
                    children: [
                      Icon(
                        user.status == UserStatus.blocked
                            ? Icons.check_circle_outline
                            : Icons.block,
                        color: Colors.red,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        user.status == UserStatus.blocked
                            ? 'Unblock User'
                            : 'Block User',
                      ),
                    ],
                  ),
                ),
                if (user.status != UserStatus.suspended)
                  PopupMenuItem(
                    value: 'suspend',
                    enabled:
                        user.id != currentUser?.id &&
                        !(currentUser?.isOpsAdmin == true && user.isSuperAdmin),
                    child: Row(
                      children: [
                        Icon(
                          Icons.pause_circle_outline,
                          color: Colors.orange,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text('Suspend Account'),
                      ],
                    ),
                  ),
                PopupMenuItem(
                  value: 'delete',
                  enabled:
                      user.id != currentUser?.id &&
                      !(currentUser?.isOpsAdmin == true && user.isSuperAdmin),
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, color: Colors.red, size: 20),
                      SizedBox(width: 8),
                      Text('Delete User', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

  Future<void> _handleAction(
    BuildContext context,
    WidgetRef ref,
    User user,
    User? currentUser,
    String value,
  ) async {
    if (user.id == currentUser?.id &&
        (value == 'toggle_block' || value == 'suspend' || value == 'delete')) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cannot block or delete your own account.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // 🛑 CRITICAL VALDIATION: OpsAdmin cannot perform any management actions on SuperAdmin
    if (currentUser?.isOpsAdmin == true && user.isSuperAdmin) {
      if (context.mounted) {
        String actionName = 'manage';
        if (value == 'toggle_block') actionName = 'block/unblock';
        if (value == 'suspend') actionName = 'suspend';
        if (value == 'delete') actionName = 'delete';
        if (value == 'verify') actionName = 'verify';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('OpsAdmin cannot $actionName a SuperAdmin.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (value == 'edit') {
      // Security guard for OpsAdmins
      if (currentUser?.isOpsAdmin == true &&
          (user.id == currentUser?.id || user.isSuperAdmin)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Wait, OpsAdmin cannot edit this user.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      context.push('/admin/users/edit/${user.id}', extra: user);
      return;
    }

    if (value == 'verify') {
      final confirmed = await ConfirmationDialog.show(
        context: context,
        title: 'Verify User?',
        message: 'Confirm Action: Do you want to verify the identity of ${user.name}?',
        confirmLabel: 'Yes, Verify',
        type: ConfirmationDialogType.info,
        icon: Icons.verified_user_outlined,
      );

      if (confirmed != true) return;

      final updatedMeta = Map<String, dynamic>.from(user.metadata);
      updatedMeta['is_verified'] = true;
      await ref
          .read(userProvider.notifier)
          .updateUser(user.copyWith(metadata: updatedMeta));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User verified successfully.'),
            backgroundColor: Colors.green,
          ),
        );
      }
      return;
    }

    // Determine the action verb and colors for the confirmation dialog
    String actionVerb = '';
    String actionMessage = '';
    ConfirmationDialogType dialogType = ConfirmationDialogType.danger;
    IconData icon = Icons.info_outline;

    if (value == 'toggle_block') {
      actionVerb = user.status == UserStatus.blocked ? 'Unblock' : 'Block';
      actionMessage = user.status == UserStatus.blocked
          ? 'Are you sure you want to unblock ${user.name}? They will regain access.'
          : 'Are you sure you want to block ${user.name}? They will lose access to the system.';
      dialogType = user.status == UserStatus.blocked
          ? ConfirmationDialogType.info
          : ConfirmationDialogType.danger;
      icon = user.status == UserStatus.blocked
          ? Icons.check_circle_outline
          : Icons.block_flipped;
    } else if (value == 'suspend') {
      actionVerb = 'Suspend';
      actionMessage =
          'Are you sure you want to temporarily suspend ${user.name}?';
      dialogType = ConfirmationDialogType.info;
      icon = Icons.pause_circle_outline;
    } else if (value == 'delete') {
      actionVerb = 'Delete';
      actionMessage =
          'Are you sure you want to PERMANENTLY delete ${user.name}? This action cannot be undone and deletes all their data.';
      dialogType = ConfirmationDialogType.danger;
      icon = Icons.delete_forever_outlined;
    }

    // Show Confirmation Dialog
    if (!context.mounted) return;
    final confirmed = await ConfirmationDialog.show(
      context: context,
      title: '$actionVerb User?',
      message: actionMessage,
      confirmLabel: 'Yes, $actionVerb',
      type: dialogType,
      icon: icon,
    );

    if (confirmed != true) return;

    // Execute Action if confirmed
    try {
      if (value == 'toggle_block') {
        final newStatus = user.status == UserStatus.blocked
            ? UserStatus.active
            : UserStatus.blocked;
        await ref
            .read(userProvider.notifier)
            .updateUser(user.copyWith(status: newStatus));
      } else if (value == 'suspend') {
        await ref
            .read(userProvider.notifier)
            .updateUser(user.copyWith(status: UserStatus.suspended));
      } else if (value == 'delete') {
        await ref.read(userProvider.notifier).deleteUser(user.id);
      }

      // Show success message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('User ${actionVerb.toLowerCase()}ed successfully.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to $actionVerb user. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Color _getStatusColor(UserStatus status) {
    switch (status) {
      case UserStatus.active:
        return Colors.green;
      case UserStatus.blocked:
        return Colors.red;
      case UserStatus.suspended:
        return Colors.orange;
    }
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onSelected;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelected(),
      selectedColor: AppColors.primary.withAlpha(51),
      checkmarkColor: AppColors.primary,
    );
  }
}
