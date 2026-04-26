import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import '../admin_strings.dart';
import '../../shared/services/service_repository.dart';
import '../../shared/services/booking_repository.dart';
import '../../shared/services/user_repository.dart';
import '../../shared/services/auth_service.dart';
import '../../shared/models/user_model.dart';
import '../../shared/models/service_model.dart';
import '../../shared/models/booking_model.dart';
import '../../shared/services/banner_repository.dart';
import '../../shared/services/special_offer_repository.dart';
import '../../shared/services/system_activity_repository.dart';
import '../../core/theme/app_colors.dart';
import 'package:intl/intl.dart';
import '../../core/widgets/responsive.dart';
enum ChartInterval { daily, weekly, monthly }

final chartIntervalProvider = StateProvider<ChartInterval>((ref) => ChartInterval.weekly);

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final services = ref.watch(serviceProvider);
    final bookings = ref.watch(bookingProvider);
    final users = ref.watch(userProvider);
    final currentUser = ref.watch(authProvider);
    final activities = ref.watch(activityProvider);
    final adminRole = currentUser?.adminRole ?? AdminRole.supportAdmin;

    // Admin KPIs
    final activeUsers = users
        .where((u) => u.status == UserStatus.active)
        .length;
    final inactiveUsers = users
        .where((u) => u.status != UserStatus.active)
        .length;
    final activeServicesCount = services
        .where((s) => s.status == ServiceStatus.active)
        .length;
    final pendingServices = services
        .where((s) => s.status == ServiceStatus.pendingApproval)
        .length;
    final totalBookingsCount = bookings.length;
    final totalRevenue = bookings
        .where((b) => b.status == BookingStatus.completed)
        .fold(0.0, (sum, b) => sum + b.totalPrice);

    final totalBanners = ref.watch(bannerProvider).length;

    // Chart Data Preparation
    final interval = ref.watch(chartIntervalProvider);
    final now = DateTime.now();
    
    List<DateTime> intervalDays;
    if (interval == ChartInterval.daily) {
      intervalDays = List.generate(12, (i) => now.subtract(Duration(hours: (11 - i) * 2)));
    } else if (interval == ChartInterval.monthly) {
      intervalDays = List.generate(10, (i) => now.subtract(Duration(days: (9 - i) * 3)));
    } else {
      // Weekly: Find last Monday or just last 7 days starting from Monday fix
      final lastMonday = now.subtract(Duration(days: now.weekday - 1));
      intervalDays = List.generate(7, (i) => lastMonday.add(Duration(days: i)));
    }

    final bookingSpots = intervalDays.asMap().entries.map((entry) {
      final t = entry.value;
      final count = bookings.where((b) {
        if (interval == ChartInterval.daily) {
          return b.date.year == t.year && b.date.month == t.month && b.date.day == t.day && (b.date.hour ~/ 2) == (t.hour ~/ 2);
        }
        return b.date.year == t.year && b.date.month == t.month && b.date.day == t.day;
      }).length;
      return FlSpot(entry.key.toDouble(), count.toDouble());
    }).toList();

    final activitySpots = intervalDays.asMap().entries.map((entry) {
      final t = entry.value;
      final count = activities.where((a) {
        if (interval == ChartInterval.daily) {
          return a.timestamp.year == t.year && a.timestamp.month == t.month && a.timestamp.day == t.day && (a.timestamp.hour ~/ 2) == (t.hour ~/ 2);
        }
        return a.timestamp.year == t.year && a.timestamp.month == t.month && a.timestamp.day == t.day;
      }).length;
      return FlSpot(entry.key.toDouble(), count.toDouble());
    }).toList();

    return Container(
      color: const Color(0xFFF8FAFC),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _AdminDashboardHeader(),
            const SizedBox(height: 24),
            const _AdminWelcomeBanner(),
            const SizedBox(height: 32),
            Text(
              AdminStrings.platformOverview,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            Builder(
              builder: (context) {
                final crossAxisCount = context.isDesktop ? 6 : (context.isTablet ? 3 : 2);
                final childAspectRatio = context.isMobile ? 1.05 : 1.0;

                return GridView.count(
                  crossAxisCount: crossAxisCount,
                  childAspectRatio: childAspectRatio,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    if (adminRole == AdminRole.superAdmin ||
                        adminRole == AdminRole.opsAdmin)
                      _AdminKpiCard(
                        title: 'Active Users',
                        value: activeUsers.toString(),
                        icon: Icons.person_outline,
                        color: Colors.green,
                        onTap: () => context.go('/admin/users'),
                      ),
                    if (adminRole == AdminRole.superAdmin ||
                        adminRole == AdminRole.opsAdmin)
                      _AdminKpiCard(
                        title: 'Inactive Users',
                        value: inactiveUsers.toString(),
                        icon: Icons.person_off_outlined,
                        color: Colors.red,
                        onTap: () => context.go('/admin/users'),
                      ),
                    if (adminRole == AdminRole.superAdmin ||
                        adminRole == AdminRole.supportAdmin ||
                        adminRole == AdminRole.opsAdmin)
                      _AdminKpiCard(
                        title: AdminStrings.activeServices,
                        value: activeServicesCount.toString(),
                        icon: Icons.hotel,
                        color: Colors.orange,
                        onTap: () => context.go('/admin/services'),
                      ),
                    if (adminRole == AdminRole.superAdmin ||
                        adminRole == AdminRole.supportAdmin)
                      _AdminKpiCard(
                        title: AdminStrings.pendingApprovals,
                        value: pendingServices.toString(),
                        icon: Icons.verified,
                        color: pendingServices > 0 ? Colors.red : Colors.green,
                        onTap: () => context.go('/admin/services'),
                      ),
                    if (adminRole == AdminRole.superAdmin ||
                        adminRole == AdminRole.opsAdmin)
                      _AdminKpiCard(
                        title: AdminStrings.totalBookings,
                        value: totalBookingsCount.toString(),
                        icon: Icons.book_online,
                        color: Colors.purple,
                        onTap: () => context.go('/admin/bookings'),
                      ),
                    if (adminRole == AdminRole.superAdmin ||
                        adminRole == AdminRole.financeAdmin)
                      _AdminKpiCard(
                        title: AdminStrings.revenue,
                        value: '\$${totalRevenue.toStringAsFixed(0)}',
                        icon: Icons.attach_money,
                        color: Colors.green,
                        onTap: () => context.go('/admin/financials'),
                      ),
                    _AdminKpiCard(
                      title: 'Dynamic Banners',
                      value: totalBanners.toString(),
                      icon: Icons.image,
                      color: Colors.indigo,
                      onTap: () => context.go('/admin/banners'),
                    ),
                    if (adminRole == AdminRole.superAdmin ||
                        adminRole == AdminRole.opsAdmin)
                      _AdminKpiCard(
                        title: 'Special Offers',
                        value: ref
                            .watch(specialOfferProvider)
                            .length
                            .toString(),
                        icon: Icons.local_offer,
                        color: Colors.pink,
                        onTap: () => context.go('/admin/special-offers'),
                      ),
                  ],
                );
              },
            ),

            const SizedBox(height: 32),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: context.isDesktop ? 2 : 1,
                  child: _AdminServiceCategoryBreakdown(services: services),
                ),
                if (context.isDesktop) const SizedBox(width: 24),
                if (context.isDesktop)
                  const Expanded(
                    flex: 1,
                    child: _AdminQuickActions(),
                  ),
              ],
            ),

            if (!context.isDesktop) ...[
              const SizedBox(height: 32),
              const _AdminQuickActions(),
            ],

            const SizedBox(height: 32),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: _AdminPerformanceChart(
                    bookingSpots: bookingSpots,
                    activitySpots: activitySpots,
                    intervalDays: intervalDays,
                  ),
                ),
                if (context.isDesktop)
                  const SizedBox(width: 24),
                if (context.isDesktop)
                  const Expanded(flex: 1, child: _RecentActivitySection()),
              ],
            ),

            if (!context.isDesktop) ...[
              const SizedBox(height: 32),
              const _RecentActivitySection(),
            ],

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _AdminServiceCategoryBreakdown extends StatelessWidget {
  final List<Service> services;

  const _AdminServiceCategoryBreakdown({required this.services});

  @override
  Widget build(BuildContext context) {
    // Only count active services to match the KPI card above
    final activeServices = services.where((s) => s.status == ServiceStatus.active).toList();
    
    final hotelCount = activeServices.where((s) => s.category.toLowerCase().contains('hotel')).length;
    final aptCount = activeServices.where((s) => s.category.toLowerCase().contains('apartment') || s.category.toLowerCase().contains('apt')).length;
    final tourCount = activeServices.where((s) => s.category.toLowerCase().contains('tour')).length;
    
    // Catch-all for any other categories
    final otherCount = activeServices.length - (hotelCount + aptCount + tourCount);
    
    final total = activeServices.length;

    return Container(
      height: 350,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Active Service Breakdown',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: total == 0
                ? const Center(child: Text('No active services found'))
                : PieChart(
                    PieChartData(
                      sections: [
                        if (hotelCount > 0)
                          PieChartSectionData(
                            value: hotelCount.toDouble(),
                            title: 'Hotels',
                            color: AppColors.primary,
                            radius: 60,
                            titleStyle: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        if (aptCount > 0)
                          PieChartSectionData(
                            value: aptCount.toDouble(),
                            title: 'Apts',
                            color: AppColors.accent,
                            radius: 55,
                            titleStyle: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        if (tourCount > 0)
                          PieChartSectionData(
                            value: tourCount.toDouble(),
                            title: 'Tours',
                            color: Colors.green,
                            radius: 50,
                            titleStyle: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        if (otherCount > 0)
                          PieChartSectionData(
                            value: otherCount.toDouble(),
                            title: 'Other',
                            color: Colors.grey,
                            radius: 45,
                            titleStyle: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                      ],
                      centerSpaceRadius: 40,
                      sectionsSpace: 4,
                    ),
                  ),
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.spaceAround,
            spacing: 16,
            runSpacing: 8,
            children: [
              _StatIndicator(color: AppColors.primary, label: 'Hotels', count: hotelCount),
              _StatIndicator(color: AppColors.accent, label: 'Apartments', count: aptCount),
              _StatIndicator(color: Colors.green, label: 'Tours', count: tourCount),
              if (otherCount > 0)
                _StatIndicator(color: Colors.grey, label: 'Others', count: otherCount),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatIndicator extends StatelessWidget {
  final Color color;
  final String label;
  final int count;

  const _StatIndicator({
    required this.color,
    required this.label,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
        Text(count.toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }
}

class _AdminQuickActions extends StatelessWidget {
  const _AdminQuickActions();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 350,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              children: [
                _QuickActionTile(
                  icon: Icons.map_rounded,
                  label: 'Manage Destinations',
                  onTap: () => context.go('/admin/regions'),
                ),
                _QuickActionTile(
                  icon: Icons.image_rounded,
                  label: 'Launch New Banner',
                  onTap: () => context.go('/admin/banners'),
                ),
                _QuickActionTile(
                  icon: Icons.person_add_rounded,
                  label: 'Register Provider',
                  onTap: () => context.go('/admin/users/create?role=provider'),
                ),
                _QuickActionTile(
                  icon: Icons.security_rounded,
                  label: 'System Security',
                  onTap: () => context.go('/admin/security'),
                ),
                _QuickActionTile(
                  icon: Icons.settings_rounded,
                  label: 'Global Settings',
                  onTap: () => context.go('/admin/settings'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary, size: 20),
      title: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
    );
  }
}

class _AdminDashboardHeader extends StatelessWidget {
  const _AdminDashboardHeader();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Dashboard Overview',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        Text(
          'System management and platform metrics',
          style: TextStyle(color: Colors.grey, fontSize: 14),
        ),
      ],
    );
  }
}

class _AdminWelcomeBanner extends ConsumerWidget {
  const _AdminWelcomeBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);
    final userName = user?.name.split(' ').first ?? 'Admin';
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, Color(0xFF1B62A4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withAlpha(51),
            blurRadius: 15,
            offset: const Offset(0, 8),
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
                    fontSize: context.isMobile ? 20 : 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'You have full control over the SomSafar platform today. Check the pending approvals and recent activities below.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: context.isMobile ? 13 : 15,
                  ),
                ),
              ],
            ),
          ),
          if (!context.isMobile) ...[
            const SizedBox(width: 16),
            // Using a Hero-like illustration/icon
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(30),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.admin_panel_settings,
                color: Colors.white,
                size: 64,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AdminPerformanceChart extends ConsumerWidget {
  final List<FlSpot> bookingSpots;
  final List<FlSpot> activitySpots;
  final List<DateTime> intervalDays;
 
  const _AdminPerformanceChart({
    required this.bookingSpots,
    required this.activitySpots,
    required this.intervalDays,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    double maxY = bookingSpots.fold(0.0, (m, spot) => spot.y > m ? spot.y : m);
    double activityMaxY = activitySpots.fold(
      0.0,
      (m, spot) => spot.y > m ? spot.y : m,
    );
    maxY = (maxY > activityMaxY ? maxY : activityMaxY) + 5;
    if (maxY < 10) maxY = 10;

    final totalBookings = bookingSpots.fold(0.0, (sum, spot) => sum + spot.y).toInt();

    return Container(
      height: 400,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Platform Analytics',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                        color: AppColors.primary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      '$totalBookings total bookings in this period',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<ChartInterval>(
                offset: const Offset(0, 44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 8,
                onSelected: (val) => ref.read(chartIntervalProvider.notifier).state = val,
                itemBuilder: (ctx) => [
                  PopupMenuItem(value: ChartInterval.daily, child: _buildPopupItem(Icons.today, 'Daily')),
                  PopupMenuItem(value: ChartInterval.weekly, child: _buildPopupItem(Icons.calendar_view_week, 'Weekly')),
                  PopupMenuItem(value: ChartInterval.monthly, child: _buildPopupItem(Icons.calendar_month, 'Monthly')),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(8),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary.withAlpha(20)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        ref.watch(chartIntervalProvider).name[0].toUpperCase() + ref.watch(chartIntervalProvider).name.substring(1),
                        style: const TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.keyboard_arrow_down, size: 18, color: AppColors.primary),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) =>
                      FlLine(color: Colors.grey.withAlpha(15), strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= intervalDays.length) return const Text('');
                        final date = intervalDays[idx];
                        final interval = ref.watch(chartIntervalProvider);
                        String label = '';
                        if (interval == ChartInterval.daily) {
                          label = DateFormat('HH:mm').format(date);
                        } else if (interval == ChartInterval.monthly) {
                          label = DateFormat('MMM d').format(date);
                        } else {
                          label = DateFormat('EEE').format(date);
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(label, style: TextStyle(color: Colors.grey[400], fontSize: 10, fontWeight: FontWeight.w600)),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: (maxY / 4).ceilToDouble(),
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        return Text(value.toInt().toString(), style: TextStyle(color: Colors.grey[400], fontSize: 10, fontWeight: FontWeight.w600));
                      },
                    ),
                  ),
                ),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => AppColors.primary.withAlpha(230),
                    tooltipRoundedRadius: 12,
                    tooltipPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final isBooking = spot.barIndex == 1;
                        return LineTooltipItem(
                          '${isBooking ? "Bookings" : "System"}: ${spot.y.toInt()}',
                          const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                        );
                      }).toList();
                    },
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: activitySpots,
                    isCurved: true,
                    color: AppColors.secondary,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [AppColors.secondary.withAlpha(40), AppColors.secondary.withAlpha(0)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  LineChartBarData(
                    spots: bookingSpots,
                    isCurved: true,
                    color: AppColors.primary,
                    barWidth: 4,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                        radius: 3,
                        color: Colors.white,
                        strokeWidth: 2,
                        strokeColor: AppColors.primary,
                      ),
                      checkToShowDot: (spot, barData) => spot.y > 0,
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [AppColors.primary.withAlpha(40), AppColors.primary.withAlpha(0)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
                minX: 0,
                maxX: (intervalDays.length - 1).toDouble(),
                minY: 0,
                maxY: maxY,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ModernLegend(color: AppColors.secondary, label: 'System Action'),
              const SizedBox(width: 32),
              _ModernLegend(color: AppColors.primary, label: 'New Bookings'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPopupItem(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey[700]),
        const SizedBox(width: 12),
        Text(title, style: TextStyle(fontSize: 13, color: Colors.grey[800], fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class _ModernLegend extends StatelessWidget {
  final Color color;
  final String label;

  const _ModernLegend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _RecentActivitySection extends ConsumerWidget {
  const _RecentActivitySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activities = ref.watch(activityProvider);

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
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
                'Monitor Activity',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                  letterSpacing: -0.5,
                ),
              ),
              TextButton(
                onPressed: () => context.go('/admin/logs'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('View All', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (activities.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: Text('No recent activity recorded', style: TextStyle(color: Colors.grey))),
            )
          else
            ...activities.take(6).map((activity) {
              return _ActivityCard(
                icon: activity.icon,
                iconColor: activity.iconColor,
                title: activity.title,
                subtitle: DateFormat('MMM d, HH:mm').format(activity.timestamp),
                activityType: activity.type,
              );
            }),
        ],
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final ActivityType activityType;

  const _ActivityCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.activityType,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withAlpha(15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(5),
            offset: const Offset(0, 4),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: iconColor.withAlpha(20),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF1F2937),
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.grey[500], fontSize: 11, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
        ],
      ),
    );
  }
}

class _AdminKpiCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _AdminKpiCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withAlpha(26),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 24, color: color),
              ),
              const SizedBox(height: 12),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 26,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
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
