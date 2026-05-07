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
          actions: const [],
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
                        icon: Icons.analytics_outlined,
                        label: 'Reports',
                        index: 4,
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
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Logout'),
                onTap: () async {
                  final confirmed = await ConfirmationDialog.show(
                    context: context,
                    title: 'Logout?',
                    message: 'Are you sure you want to log out of your account?',
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
              const SizedBox(height: 16),
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
                      backgroundColor: Colors.white,
                      selectedIconTheme: const IconThemeData(
                        color: AppColors.secondary,
                      ),
                      selectedLabelTextStyle: const TextStyle(
                        color: AppColors.secondary,
                        fontWeight: FontWeight.bold,
                      ),
                      leading: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Image.asset(
                          'assets/images/logo.png',
                          height: 40,
                          fit: BoxFit.contain,
                        ),
                      ),
                      destinations: [
                        const NavigationRailDestination(
                          icon: Icon(Icons.dashboard_outlined),
                          selectedIcon: Icon(Icons.dashboard),
                          label: Text('Dashboard'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(servicesIcon),
                          selectedIcon: Icon(servicesIcon),
                          label: Text(servicesLabel),
                        ),
                        NavigationRailDestination(
                          icon: Icon(bookingsIcon),
                          selectedIcon: Icon(bookingsIcon),
                          label: Text(bookingsLabel),
                        ),
                        if (!isHelper)
                          const NavigationRailDestination(
                            icon: Icon(Icons.percent_outlined),
                            selectedIcon: Icon(Icons.percent),
                            label: Text('Discounts'),
                          ),
                        if (!isHelper)
                          const NavigationRailDestination(
                            icon: Icon(Icons.analytics_outlined),
                            selectedIcon: Icon(Icons.analytics),
                            label: Text('Reports'),
                          ),
                        const NavigationRailDestination(
                          icon: Icon(Icons.reviews_outlined),
                          selectedIcon: Icon(Icons.reviews),
                          label: Text('Reviews'),
                        ),
                        const NavigationRailDestination(
                          icon: Icon(Icons.person_outline),
                          selectedIcon: Icon(Icons.person),
                          label: Text('Profile'),
                        ),
                        if (!isHelper)
                          const NavigationRailDestination(
                            icon: Icon(Icons.settings_outlined),
                            selectedIcon: Icon(Icons.settings),
                            label: Text('Settings'),
                          ),
                      ],
                      trailing: Expanded(
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 20),
                            child: IconButton(
                              icon: const Icon(Icons.logout),
                              onPressed: () async {
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
                                  ref.read(authServiceProvider).logout();
                                  if (context.mounted) context.go('/login');
                                }
                              },
                              tooltip: 'Logout',
                            ),
                          ),
                        ),
                      ),
                      selectedIndex: _calculateSelectedIndex(context),
                      onDestinationSelected: (index) =>
                          _onItemTapped(index, context),
                    ),
                  ),
                ),
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
    return 0;
  }
}
