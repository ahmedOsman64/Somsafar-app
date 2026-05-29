import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/responsive.dart';
import '../../shared/models/user_model.dart';
import '../../shared/services/system_activity_repository.dart';
import '../../shared/services/auth_service.dart';
import '../../shared/widgets/confirmation_dialog.dart';

class AdminShell extends ConsumerWidget {
  final Widget child;

  const AdminShell({required this.child, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);
    final adminRole = user?.adminRole ?? AdminRole.supportAdmin;

    // Listen for new security alerts
    ref.listen(activityProvider, (previous, next) {
      if (next.isNotEmpty &&
          (previous == null || next.length > previous.length)) {
        final latest = next.first;
        if (latest.type == ActivityType.securityAlert) {
          _showSecurityOverlay(context, latest);
        }
      }
    });

    final navItems = _getNavItems(adminRole);

    return Responsive(
      mobile: Scaffold(
        appBar: AppBar(
          title: const Text('Admin Portal'),
          backgroundColor: AppColors.dark,
          actions: [
            const SizedBox(width: 8),
            InkWell(
              onTap: () => context.go('/admin/profile'),
              child: const CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.primary,
                child: Icon(Icons.person, size: 20, color: Colors.white),
              ),
            ),
            const SizedBox(width: 16),
          ],
        ),
        drawer: Drawer(
          backgroundColor: AppColors.dark,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    DrawerHeader(
                      decoration: const BoxDecoration(color: Colors.black26),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset(
                            'assets/images/logo.png',
                            height: 60,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            "Admin Portal",
                            style: TextStyle(color: Colors.white, fontSize: 18),
                          ),
                        ],
                      ),
                    ),
                    ...navItems.asMap().entries.map((entry) {
                      final index = entry.key;
                      final item = entry.value;
                      return ListTile(
                        leading: Icon(item.icon, color: Colors.white70),
                        title: Text(
                          item.label,
                          style: const TextStyle(color: Colors.white),
                        ),
                        selected:
                            _calculateSelectedIndex(context, navItems) == index,
                        onTap: () {
                          _onItemTapped(index, context, navItems);
                          Navigator.pop(context);
                        },
                      );
                    }),
                  ],
                ),
              ),
              const Divider(color: Colors.white24),
              SafeArea(
                top: false,
                child: ListTile(
                  leading: const Icon(Icons.logout, color: AppColors.error),
                  title: const Text(
                    'Logout',
                    style: TextStyle(
                      color: AppColors.error,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onTap: () async {
                    final confirmed = await ConfirmationDialog.show(
                      context: context,
                      title: 'Logout?',
                      message:
                          'Are you sure you want to log out of the Admin Portal?',
                      confirmLabel: 'Yes, Logout',
                      type: ConfirmationDialogType.info,
                      icon: Icons.logout,
                    );
                    if (confirmed == true) {
                      ref.read(authServiceProvider).logout();
                      if (context.mounted) context.go('/login');
                    }
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
        body: child,
      ),
      desktop: Scaffold(
        body: Row(
          children: [
            LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: NavigationRail(
                      extended: true,
                      backgroundColor: AppColors.dark,
                      unselectedLabelTextStyle: const TextStyle(
                        color: Colors.white70,
                      ),
                      unselectedIconTheme: const IconThemeData(
                        color: Colors.white70,
                      ),
                      selectedIconTheme: const IconThemeData(
                        color: Color.fromARGB(255, 250, 154, 69),
                      ),
                      selectedLabelTextStyle: const TextStyle(
                        color: AppColors.accent,
                        fontWeight: FontWeight.bold,
                      ),
                      leading: Padding(
                        padding: const EdgeInsets.only(top: 24, bottom: 24),
                        child: Column(
                          children: [
                            Image.asset(
                              'assets/images/logo.png',
                              height: 50,
                              fit: BoxFit.contain,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              adminRole.name.toUpperCase().replaceAll(
                                    'ADMIN',
                                    '',
                                  ),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                            Container(
                              margin: const EdgeInsets.only(top: 4),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.accent.withAlpha(50),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.accent),
                              ),
                              child: const Text(
                                'ADMIN',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppColors.accent,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      destinations: navItems
                          .map(
                            (item) => NavigationRailDestination(
                              icon: Icon(item.icon),
                              selectedIcon: Icon(item.selectedIcon),
                              label: Text(item.label),
                            ),
                          )
                          .toList(),
                      trailing: Expanded(
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 20),
                            child: IconButton(
                              icon: const Icon(
                                Icons.logout,
                                color: AppColors.error,
                              ),
                              onPressed: () async {
                                final confirmed = await ConfirmationDialog.show(
                                  context: context,
                                  title: 'Logout?',
                                  message:
                                      'Are you sure you want to log out of the Admin Portal?',
                                  confirmLabel: 'Yes, Logout',
                                  type: ConfirmationDialogType.info,
                                  icon: Icons.logout,
                                );
                                if (confirmed == true) {
                                  ref.read(authServiceProvider).logout();
                                  if (context.mounted) context.go('/login');
                                }
                              },
                              tooltip: 'Logout',
                            ),
                          ),
                        ),
                      ),
                      selectedIndex: _calculateSelectedIndex(context, navItems),
                      onDestinationSelected: (index) =>
                          _onItemTapped(index, context, navItems),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  // Desktop Top Bar
                  Container(
                    height: 64,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(13),
                          blurRadius: 5,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Text(
                          _getPageTitle(context),
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () => context.go('/admin/profile'),
                          borderRadius: BorderRadius.circular(30),
                          child: Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: AppColors.primary,
                                  backgroundImage: user?.profileImage != null
                                      ? NetworkImage(user!.profileImage!)
                                      : null,
                                  child: user?.profileImage == null
                                      ? const Icon(
                                          Icons.person,
                                          size: 20,
                                          color: Colors.white,
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      user?.name ?? 'Admin',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      adminRole.name,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
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
                  ),
                  Expanded(child: child),
                ],
              ),
            ),
          ],
        ),
      ),
    );

  }

  void _showSecurityOverlay(BuildContext context, SystemActivity alert) {
    final isHigh = alert.metadata?['priority'] == 'high';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isHigh ? Icons.gpp_maybe : Icons.security,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    alert.title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    alert.subtitle,
                    style: const TextStyle(fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: isHigh ? Colors.red : Colors.orange,
        duration: const Duration(seconds: 8),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        action: SnackBarAction(
          label: 'VIEW',
          textColor: Colors.white,
          onPressed: () => context.go('/admin/security'),
        ),
      ),
    );
  }

  void _onItemTapped(int index, BuildContext context, List<_NavItem> navItems) {
    context.go(navItems[index].route);
  }

  int _calculateSelectedIndex(BuildContext context, List<_NavItem> navItems) {
    final String location = GoRouterState.of(context).uri.path;
    for (int i = 0; i < navItems.length; i++) {
      if (location.startsWith(navItems[i].route)) return i;
    }
    return 0;
  }

  List<_NavItem> _getNavItems(AdminRole role) {
    final allItems = [
      _NavItem(
        label: 'Overview',
        icon: Icons.analytics_outlined,
        selectedIcon: Icons.analytics,
        route: '/admin/dashboard',
        roles: [
          AdminRole.superAdmin,
          AdminRole.opsAdmin,
          AdminRole.financeAdmin,
          AdminRole.supportAdmin,
        ],
      ),
      _NavItem(
        label: 'Users',
        icon: Icons.people_outline,
        selectedIcon: Icons.people,
        route: '/admin/users',
        roles: [AdminRole.superAdmin, AdminRole.opsAdmin],
      ),
      _NavItem(
        label: 'Helpers',
        icon: Icons.support_agent_outlined,
        selectedIcon: Icons.support_agent,
        route: '/admin/helpers',
        roles: [AdminRole.superAdmin, AdminRole.opsAdmin, AdminRole.supportAdmin],
      ),
      _NavItem(
        label: 'Services',
        icon: Icons.verified_outlined,
        selectedIcon: Icons.verified,
        route: '/admin/services',
        roles: [
          AdminRole.superAdmin,
          AdminRole.supportAdmin,
          AdminRole.opsAdmin,
        ],
      ),
      _NavItem(
        label: 'Financials',
        icon: Icons.attach_money,
        selectedIcon: Icons.attach_money,
        route: '/admin/financials',
        roles: [AdminRole.superAdmin, AdminRole.financeAdmin],
      ),
      _NavItem(
        label: 'Bookings',
        icon: Icons.book_online_outlined,
        selectedIcon: Icons.book_online,
        route: '/admin/bookings',
        roles: [AdminRole.superAdmin, AdminRole.opsAdmin],
      ),
      _NavItem(
        label: 'Reviews',
        icon: Icons.rate_review_outlined,
        selectedIcon: Icons.rate_review,
        route: '/admin/reviews',
        roles: [AdminRole.superAdmin, AdminRole.supportAdmin],
      ),
      _NavItem(
        label: 'Logs',
        icon: Icons.list_alt_outlined,
        selectedIcon: Icons.list_alt,
        route: '/admin/logs',
        roles: [AdminRole.superAdmin],
      ),
      _NavItem(
        label: 'Support',
        icon: Icons.support_agent,
        selectedIcon: Icons.support_agent,
        route: '/admin/support',
        roles: [
          AdminRole.superAdmin,
          AdminRole.supportAdmin,
          AdminRole.opsAdmin,
        ],
      ),
      _NavItem(
        label: 'Settings',
        icon: Icons.settings_outlined,
        selectedIcon: Icons.settings,
        route: '/admin/settings',
        roles: [AdminRole.superAdmin],
      ),
      _NavItem(
        label: 'Taxes',
        icon: Icons.account_balance_outlined,
        selectedIcon: Icons.account_balance,
        route: '/admin/taxes',
        roles: [AdminRole.superAdmin, AdminRole.financeAdmin],
      ),
      _NavItem(
        label: 'Security',
        icon: Icons.security_outlined,
        selectedIcon: Icons.security,
        route: '/admin/security',
        roles: [AdminRole.superAdmin, AdminRole.opsAdmin],
      ),
      _NavItem(
        label: 'Banners',
        icon: Icons.image_outlined,
        selectedIcon: Icons.image,
        route: '/admin/banners',
        roles: [AdminRole.superAdmin, AdminRole.opsAdmin],
      ),
      _NavItem(
        label: 'Regions',
        icon: Icons.map_outlined,
        selectedIcon: Icons.map,
        route: '/admin/regions',
        roles: [AdminRole.superAdmin, AdminRole.opsAdmin],
      ),
      _NavItem(
        label: 'Highlights',
        icon: Icons.landscape_outlined,
        selectedIcon: Icons.landscape,
        route: '/admin/highlights',
        roles: [AdminRole.superAdmin, AdminRole.opsAdmin],
      ),
    ];

    return allItems.where((item) => item.roles.contains(role)).toList();
  }
}

class _NavItem {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String route;
  final List<AdminRole> roles;

  _NavItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.route,
    required this.roles,
  });
}

String _getPageTitle(BuildContext context) {
  final location = GoRouterState.of(context).uri.path;
  if (location.contains('dashboard')) return 'Dashboard';
  if (location.contains('users')) return 'User Management';
  if (location.contains('services')) return 'Service Listings';
  if (location.contains('financials')) return 'Financial Reports';
  if (location.contains('bookings')) return 'Platform Bookings';
  if (location.contains('reviews')) return 'Review Moderation';
  if (location.contains('logs')) return 'System Audit Logs';
  if (location.contains('support')) return 'Support Center';
  if (location.contains('settings')) return 'System Settings';
  if (location.contains('banners')) return 'Banner Management';
  if (location.contains('taxes')) return 'Taxes Management';
  if (location.contains('security')) return 'Security Command';
  if (location.contains('helpers')) return 'Provider Helpers';
  if (location.contains('regions')) return 'Destination Manager';
  if (location.contains('highlights')) return 'Explore Highlights';
  return 'Admin Portal';
}
