import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/services/auth_service.dart';
import '../../shared/models/user_model.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../providers/dashboard_provider.dart';
import '../../shared/services/notification_repository.dart';
import '../../core/services/storage_service.dart';
import '../../shared/services/booking_repository.dart';
import '../../shared/services/service_repository.dart';
import '../../core/widgets/responsive.dart';
import '../../shared/widgets/app_network_image.dart';

class ProviderDashboardScreen extends StatelessWidget {
  const ProviderDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _DashboardScreenContent();
  }
}

class _DashboardScreenContent extends ConsumerWidget {
  const _DashboardScreenContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      color: const Color(0xFFF8FAFC),
      child: RefreshIndicator(
        onRefresh: () async {
          await ref.read(bookingProvider.notifier).fetchBookings();
          await ref.read(serviceProvider.notifier).fetchServices();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(context.isMobile ? 16.0 : 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!context.isMobile) ...[
                const _DashboardHeader(),
                const SizedBox(height: 24),
              ],
              const _WelcomeBanner(),
              const SizedBox(height: 24),
              const _OverviewSection(),
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(flex: 2, child: _EarningsChartSection()),
                  if (context.isDesktop) const SizedBox(width: 24),
                  if (context.isDesktop)
                    const Expanded(flex: 1, child: _RevenueProgressCard()),
                ],
              ),
              if (!context.isDesktop) ...[
                const SizedBox(height: 24),
                const _RevenueProgressCard(),
              ],
              const SizedBox(height: 24),
              const _RecentBookingsSection(),
              const SizedBox(height: 24),
              const _QuickActionsSection(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardHeader extends ConsumerWidget {
  const _DashboardHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dashboard Overview',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0D3B66),
              ),
            ),
            Text(
              'Welcome back to your provider panel',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ],
        ),
        Row(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Consumer(
                builder: (context, ref, child) {
                  final unreadCount = ref.watch(unreadNotificationsCountProvider);
                  return Stack(
                    children: [
                      IconButton(
                        icon: Icon(
                            unreadCount > 0 ? Icons.notifications : Icons.notifications_none,
                            color: AppColors.primary,
                          ),
                        onPressed: () => context.push('/provider/notifications'),
                      ),
                      if (unreadCount > 0)
                        Positioned(
                          right: 8,
                          top: 8,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: AppColors.error,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 14,
                              minHeight: 14,
                            ),
                            child: Text(
                              unreadCount > 9 ? '9+' : unreadCount.toString(),
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
            const SizedBox(width: 16),
            CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.secondary.withValues(alpha: 0.1),
              child: user?.profileImage != null && user!.profileImage!.isNotEmpty
                  ? ClipOval(
                      child: AppNetworkImage(
                        imageUrl: StorageService.ensurePublicUrl(user.profileImage!),
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover,
                        memCacheWidth: 88, // Double for retina
                        errorWidget: const Icon(
                            Icons.person,
                            size: 22, // Adjusted size for radius 22
                            color: AppColors.secondary),
                      ),
                    )
                  : const Icon(Icons.person, color: Colors.white),
            ),
          ],
        ),
      ],
    );
  }
}

class _WelcomeBanner extends ConsumerWidget {
  const _WelcomeBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);
    final userName = user?.name.split(' ').first ?? 'Provider';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D3B66), Color(0xFF1B62A4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back, $userName!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: context.isMobile ? 18 : 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Here is the latest overview of your services and bookings.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: context.isMobile ? 12 : 14,
                  ),
                ),
              ],
            ),
          ),
          if (!context.isMobile)
            AppNetworkImage(
              imageUrl: 'https://cdn3d.iconscout.com/3d/premium/thumb/hotel-7151000-5807490.png',
              height: 100,
              fit: BoxFit.contain,
              errorWidget: const Icon(Icons.hotel, color: Colors.white, size: 60),
            ),
        ],
      ),
    );
  }
}

class _RevenueProgressCard extends ConsumerWidget {
  const _RevenueProgressCard();

  Future<void> _showEditTargetDialog(BuildContext context, WidgetRef ref, double currentTarget) async {
    final controller = TextEditingController(text: currentTarget.toStringAsFixed(0));
    final formKey = GlobalKey<FormState>();
    final notifier = ref.read(monthlyTargetProvider.notifier);

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.track_changes, color: AppColors.primary, size: 22),
            SizedBox(width: 10),
            Text('Set Monthly Target', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Target Amount (\$)',
              prefixText: '\$ ',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Please enter a value';
              final parsed = double.tryParse(v.replaceAll(',', ''));
              if (parsed == null || parsed <= 0) return 'Enter a valid positive number';
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              final value = double.parse(controller.text.replaceAll(',', ''));
              // Close the dialog FIRST, then update state to avoid
              // _dependents.isEmpty assertion when notifyListeners fires
              // while the dialog's BuildContext is being torn down.
              Navigator.pop(ctx);
              notifier.setTarget(value);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(dashboardStatsProvider);
    final progress = (dashboard.totalEarnings / dashboard.monthlyTarget).clamp(0.0, 1.0);
    final currencyFormat = NumberFormat.currency(symbol: '\$');

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Monthly Target',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[400],
                  fontSize: 13,
                  letterSpacing: 0.5,
                ),
              ),
              Tooltip(
                message: 'Edit target',
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => _showEditTargetDialog(context, ref, dashboard.monthlyTarget),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.more_horiz, color: Colors.grey[400], size: 20),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            currencyFormat.format(dashboard.totalEarnings),
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0D3B66),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Target: ${currencyFormat.format(dashboard.monthlyTarget)}',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 24),
          Stack(
            children: [
              Container(
                height: 8,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              FractionallySizedBox(
                widthFactor: progress,
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppColors.secondary,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.secondary.withValues(alpha: 0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(progress * 100).toStringAsFixed(1)}% Completed',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: AppColors.secondary,
                ),
              ),
              Text(
                '${dashboard.daysLeft} days left',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EarningsChartSection extends ConsumerWidget {
  const _EarningsChartSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(dashboardStatsProvider);

    return Container(
      height: 320,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Earnings Trend (Last 7 Days)',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 17,
              color: Color(0xFF0D3B66),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 32),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: dashboard.weeklyEarnings
                        .asMap()
                        .entries
                        .map((e) => FlSpot(e.key.toDouble(), e.value))
                        .toList(),
                    isCurved: true,
                    curveSmoothness: 0.35,
                    color: AppColors.secondary,
                    barWidth: 4,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          AppColors.secondary.withValues(alpha: 0.15),
                          AppColors.secondary.withValues(alpha: 0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
                minX: 0,
                maxX: 6,
                minY: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentBookingsSection extends ConsumerWidget {
  const _RecentBookingsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(dashboardStatsProvider);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Bookings',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Color(0xFF0D3B66),
                ),
              ),
              TextButton(
                onPressed: () => context.go('/provider/bookings'),
                child: const Text(
                  'View All',
                  style: TextStyle(color: AppColors.secondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: dashboard.recentBookings.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, index) {
              final booking = dashboard.recentBookings[index];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: booking.statusColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.person,
                    color: booking.statusColor,
                    size: 20,
                  ),
                ),
                title: Text(
                  booking.travelerName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                subtitle: Text(
                  booking.serviceTitle,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '\$${booking.totalPrice.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      booking.statusLabel,
                      style: TextStyle(
                        color: booking.statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// Side navigation is now handled by ProviderShell

class _OverviewSection extends ConsumerWidget {
  const _OverviewSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(dashboardStatsProvider);
    final user = ref.watch(authProvider);
    final providerType = user?.providerType ?? ProviderType.hotel;

    String servicesLabel = 'Hotels';
    IconData servicesIcon = Icons.bed_outlined;

    switch (providerType) {
      case ProviderType.hotel:
      case ProviderType.home:
      case ProviderType.apartment:
        servicesLabel = 'Properties';
        servicesIcon = Icons.apartment;
        break;
      case ProviderType.all:
      case ProviderType.tour:
        servicesLabel = 'Services';
        servicesIcon =
            Icons.miscellaneous_services; // Or another appropriate icon
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Overview',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0D3B66),
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            int crossAxisCount = 5;
            if (context.isMobile) {
              crossAxisCount = 2;
            } else if (context.isTablet) {
              crossAxisCount = 3;
            } else if (constraints.maxWidth < 1200) {
              crossAxisCount = 4;
            }

            return GridView.count(
              crossAxisCount: crossAxisCount,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: constraints.maxWidth < 600 ? 1.05 : 1.2,
              children: [
                _StatCard(
                  icon: servicesIcon,
                  count: dashboard.totalServices,
                  label: servicesLabel,
                  color: Colors.blue,
                ),
                _StatCard(
                  icon: Icons.fact_check_outlined,
                  count: dashboard.activeServices,
                  label: 'Active',
                  color: Colors.green,
                ),
                _StatCard(
                  icon: Icons.hotel_class_outlined,
                  count: dashboard.inactiveServices,
                  label: 'Inactive',
                  color: Colors.orange,
                ),
                _StatCard(
                  icon: Icons.edit_note,
                  count: dashboard.draftServices,
                  label: 'Drafts',
                  color: Colors.grey,
                ),
                _StatCard(
                  icon: Icons.assignment_outlined,
                  count: dashboard.pendingBookings,
                  label: 'Pending',
                  color: Colors.purple,
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final int count;
  final String label;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.count,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            '$count',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0D3B66),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: Colors.grey, fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _QuickActionsSection extends StatelessWidget {
  const _QuickActionsSection();

  @override
  Widget build(BuildContext context) {

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0D3B66),
          ),
        ),
        const SizedBox(height: 16),
        if (context.isMobile)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 55,
                child: ElevatedButton.icon(
                  onPressed: () => context.push('/provider/services/add'),
                  icon: const Icon(Icons.add_circle_outline, color: Colors.white),
                  label: const Text(
                    'Add New Service',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D3B66),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 55,
                child: OutlinedButton.icon(
                  onPressed: () => context.go('/provider/services'),
                  icon: const Icon(Icons.settings, color: Color(0xFF0D3B66)),
                  label: const Text(
                    'Manage Services',
                    style: TextStyle(color: Color(0xFF0D3B66), fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF0D3B66), width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          )
        else
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 55,
                  child: ElevatedButton.icon(
                    onPressed: () => context.push('/provider/services/add'),
                    icon: const Icon(Icons.add_circle_outline, color: Colors.white),
                    label: const Text(
                      'Add New Service',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D3B66),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: SizedBox(
                  height: 55,
                  child: OutlinedButton.icon(
                    onPressed: () => context.go('/provider/services'),
                    icon: const Icon(Icons.settings, color: Color(0xFF0D3B66)),
                    label: const Text(
                      'Manage Services',
                      style: TextStyle(color: Color(0xFF0D3B66), fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF0D3B66), width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}
