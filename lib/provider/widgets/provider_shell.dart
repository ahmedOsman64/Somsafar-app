import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/responsive.dart';
import '../../shared/services/auth_service.dart';
import '../../shared/models/user_model.dart';
import '../../core/services/storage_service.dart';
import '../../shared/widgets/confirmation_dialog.dart';
import '../../shared/widgets/app_network_image.dart';
import '../providers/dashboard_provider.dart';
import '../../shared/services/notification_repository.dart';

class ProviderShell extends ConsumerWidget {
  final Widget child;

  const ProviderShell({required this.child, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);
    final providerType = user?.providerType ?? ProviderType.hotel;
    final isHelper = user?.isProviderHelper ?? false;

    String servicesLabel = 'Services';
    String bookingsLabel = 'Bookings';
    IconData servicesIcon = Icons.list_alt;
    IconData bookingsIcon = Icons.book_online;

    switch (providerType) {
      case ProviderType.hotel:
        servicesLabel = 'Hotels';
        bookingsLabel = 'Room Bookings';
        servicesIcon = Icons.hotel;
        break;
      case ProviderType.home:
        servicesLabel = 'Apartments';
        bookingsLabel = 'Apartment Bookings';
        servicesIcon = Icons.apartment;
        break;
      case ProviderType.apartment:
        servicesLabel = 'Apartments';
        bookingsLabel = 'Apartment Bookings';
        servicesIcon = Icons.apartment;
        break;
      case ProviderType.all:
        servicesLabel = 'Services';
        bookingsLabel = 'Bookings';
        servicesIcon = Icons.miscellaneous_services;
        break;
      case ProviderType.tour:
        servicesLabel = 'Tours';
        bookingsLabel = 'Tour Bookings';
        servicesIcon = Icons.explore;
        break;
    }

    return Responsive(
      mobile: Scaffold(
        appBar: AppBar(
          title: Text(servicesLabel),
          backgroundColor: AppColors.primary,
          actions: [
            IconButton(
              icon: Stack(
                children: [
                  const Icon(Icons.notifications_outlined, color: Colors.white),
                  if (ref.watch(unreadNotificationsCountProvider) > 0)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 14,
                          minHeight: 14,
                        ),
                        child: Text(
                          '${ref.watch(unreadNotificationsCountProvider)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              onPressed: () => context.push('/provider/notifications'),
            ),
            const SizedBox(width: 8),
          ],
        ),
        drawer: Drawer(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    UserAccountsDrawerHeader(
                      decoration: const BoxDecoration(color: AppColors.primary),
                      accountName: Text(user?.name ?? "Provider"),
                      accountEmail:
                          Text(user?.email ?? "somsafarbooking@gmail.com"),
                      currentAccountPicture: CircleAvatar(
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        child: user?.profileImage != null &&
                                user!.profileImage!.isNotEmpty
                            ? ClipOval(
                                child: AppNetworkImage(
                                  imageUrl: StorageService.ensurePublicUrl(
                                      user.profileImage!),
                                  width: 72,
                                  height: 72,
                                  fit: BoxFit.cover,
                                  memCacheWidth: 144, // Optimize for 72 logical pixels
                                  errorWidget: const Icon(
                                      Icons.person,
                                      color: Colors.white),
                                ),
                              )
                            : const Icon(Icons.person, color: Colors.white),
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.dashboard_outlined),
                      title: const Text('Dashboard'),
                      selected: _calculateSelectedIndex(context) == 0,
                      onTap: () {
                        _onItemTapped(0, context);
                        Navigator.pop(context);
                      },
                    ),
                    ListTile(
                      leading: Icon(servicesIcon),
                      title: Text(servicesLabel),
                      selected: _calculateSelectedIndex(context) == 1,
                      onTap: () {
                        _onItemTapped(1, context);
                        Navigator.pop(context);
                      },
                    ),
                    ListTile(
                      leading: Icon(bookingsIcon),
                      title: Text(bookingsLabel),
                      selected: _calculateSelectedIndex(context) == 2,
                      trailing: ref.watch(dashboardStatsProvider).pendingBookings > 0
                          ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.error.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${ref.watch(dashboardStatsProvider).pendingBookings} New',
                                style: const TextStyle(
                                  color: AppColors.error,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            )
                          : null,
                      onTap: () {
                        _onItemTapped(2, context);
                        Navigator.pop(context);
                      },
                    ),
                    if (!isHelper)
                      _buildDrawerItem(
                        context,
                        icon: Icons.percent_outlined,
                        label: 'Discounts',
                        index: 3,
                      ),
                    if (!isHelper)
                      _buildDrawerItem(
                        context,
                        icon: Icons.receipt_long_outlined,
                        label: 'Reports',
                        index: 4,
                      ),
                    if (!isHelper)
                      _buildDrawerItem(
                        context,
                        icon: Icons.analytics_outlined,
                        label: 'Analysis',
                        index: 8,
                      ),
                    _buildDrawerItem(
                      context,
                      icon: Icons.reviews_outlined,
                      label: 'Reviews',
                      index: 5,
                    ),
                    _buildDrawerItem(
                      context,
                      icon: Icons.person_outline,
                      label: 'Profile',
                      index: 6,
                    ),
                    if (!isHelper)
                      _buildDrawerItem(
                        context,
                        icon: Icons.settings_outlined,
                        label: 'Settings',
                        index: 7,
                      ),
                  ],
                ),
              ),
              const Divider(),
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
                          'Are you sure you want to log out of your account?',
                      confirmLabel: 'Yes, Logout',
                      type: ConfirmationDialogType.info,
                      icon: Icons.logout,
                    );
                    if (confirmed == true) {
                      await ref.read(authServiceProvider).logout();
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 250,
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(10),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        children: [
                          // Leading / Logo Section
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Image.asset(
                              'assets/images/logo.png',
                              height: 40,
                              fit: BoxFit.contain,
                            ),
                          ),
                          // Nav Items
                          _buildSidebarItem(
                            context,
                            icon: Icons.dashboard_outlined,
                            selectedIcon: Icons.dashboard,
                            label: 'Dashboard',
                            isSelected: _calculateSelectedIndex(context) == 0,
                            onTap: () => _onItemTapped(0, context),
                          ),
                          _buildSidebarItem(
                            context,
                            icon: servicesIcon,
                            selectedIcon: servicesIcon,
                            label: servicesLabel,
                            isSelected: _calculateSelectedIndex(context) == 1,
                            onTap: () => _onItemTapped(1, context),
                          ),
                          _buildSidebarItem(
                            context,
                            icon: bookingsIcon,
                            selectedIcon: bookingsIcon,
                            label: bookingsLabel,
                            isSelected: _calculateSelectedIndex(context) == 2,
                            showDot: ref.watch(dashboardStatsProvider).pendingBookings > 0,
                            onTap: () => _onItemTapped(2, context),
                          ),
                           if (!isHelper) ...[
                            _buildSidebarItem(
                              context,
                              icon: Icons.percent_outlined,
                              selectedIcon: Icons.percent,
                              label: 'Discounts',
                              isSelected: _calculateSelectedIndex(context) == 3,
                              onTap: () => _onItemTapped(3, context),
                            ),
                          ],
                          if (!isHelper) ...[
                            _buildSidebarItem(
                              context,
                              icon: Icons.receipt_long_outlined,
                              selectedIcon: Icons.receipt_long,
                              label: 'Reports',
                              isSelected: _calculateSelectedIndex(context) == 4,
                              onTap: () => _onItemTapped(4, context),
                            ),
                            _buildSidebarItem(
                              context,
                              icon: Icons.analytics_outlined,
                              selectedIcon: Icons.analytics,
                              label: 'Analysis',
                              isSelected: _calculateSelectedIndex(context) == 8,
                              onTap: () => _onItemTapped(8, context),
                            ),
                          ],
                          _buildSidebarItem(
                            context,
                            icon: Icons.reviews_outlined,
                            selectedIcon: Icons.reviews,
                            label: 'Reviews',
                            isSelected: _calculateSelectedIndex(context) == (isHelper ? 3 : 5),
                            onTap: () => _onItemTapped(isHelper ? 3 : 5, context),
                          ),
                          _buildSidebarItem(
                            context,
                            icon: Icons.person_outline,
                            selectedIcon: Icons.person,
                            label: 'Profile',
                            isSelected: _calculateSelectedIndex(context) == (isHelper ? 4 : 6),
                            onTap: () => _onItemTapped(isHelper ? 4 : 6, context),
                          ),
                          if (!isHelper)
                            _buildSidebarItem(
                              context,
                              icon: Icons.settings_outlined,
                              selectedIcon: Icons.settings,
                              label: 'Settings',
                              isSelected: _calculateSelectedIndex(context) == 7,
                              onTap: () => _onItemTapped(7, context),
                          ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                    child: InkWell(
                      onTap: () async {
                        final confirmed = await ConfirmationDialog.show(
                          context: context,
                          title: 'Logout?',
                          message:
                              'Are you sure you want to log out of your account?',
                          confirmLabel: 'Yes, Logout',
                          type: ConfirmationDialogType.info,
                          icon: Icons.logout,
                        );
                        if (confirmed == true) {
                          await ref.read(authServiceProvider).logout();
                          if (context.mounted) context.go('/login');
                        }
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 16,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.error.withAlpha(20),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.logout_rounded,
                              color: AppColors.error,
                              size: 22,
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Logout',
                              style: TextStyle(
                                color: AppColors.error,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required int index,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      selected: _calculateSelectedIndex(context) == index,
      onTap: () {
        _onItemTapped(index, context);
        Navigator.pop(context);
      },
    );
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/provider/dashboard');
        break;
      case 1:
        context.go('/provider/services');
        break;
      case 2:
        context.go('/provider/bookings');
        break;
      case 3:
        context.go('/provider/discounts');
        break;
      case 4:
        context.go('/provider/reports');
        break;
      case 5:
        context.go('/provider/reviews');
        break;
      case 6:
        context.go('/provider/profile');
        break;
      case 7:
        context.go('/provider/settings');
        break;
      case 8:
        context.go('/provider/analysis');
        break;
    }
  }

  int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.path;
    if (location.startsWith('/provider/dashboard')) return 0;
    if (location.startsWith('/provider/services')) return 1;
    if (location.startsWith('/provider/bookings')) return 2;
    if (location.startsWith('/provider/discounts')) return 3;
    if (location.startsWith('/provider/reports')) return 4;
    if (location.startsWith('/provider/reviews')) return 5;
    if (location.startsWith('/provider/profile')) return 6;
    if (location.startsWith('/provider/settings')) return 7;
    if (location.startsWith('/provider/analysis')) return 8;
    return 0;
  }

  Widget _buildSidebarItem(
    BuildContext context, {
    required IconData icon,
    required IconData selectedIcon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    bool showDot = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.secondary.withAlpha(40)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Stack(
                children: [
                  Icon(
                    isSelected ? selectedIcon : icon,
                    color: isSelected ? AppColors.secondary : Colors.grey[700],
                    size: 24,
                  ),
                  if (showDot)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(1),
                        decoration: BoxDecoration(
                          color: AppColors.secondary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 8,
                          minHeight: 8,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? AppColors.secondary : Colors.black87,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
