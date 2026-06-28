import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/services/auth_service.dart';
import '../../shared/models/user_model.dart';
import 'package:table_calendar/table_calendar.dart';
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
          // Auto-heal potential availability sync issues
          await ref.read(bookingProvider.notifier).syncAllServicesAvailability();
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
              const _IncomeComparisonChart(),
              const SizedBox(height: 24),
              const _LiveCalendarCard(),
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



class _LiveCalendarCard extends ConsumerWidget {
  const _LiveCalendarCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(dashboardStatsProvider);
    final selectedDay = ref.watch(selectedCalendarDayProvider);
    final focusedDay = selectedDay;

    // Filter bookings for the selected day
    final dayBookings = dashboard.recentBookings.where((b) {
      return isSameDay(b.date, selectedDay);
    }).toList();

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
          const Text(
            'Live Booking Calendar',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Color(0xFF0D3B66),
            ),
          ),
          const SizedBox(height: 16),
          TableCalendar(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: focusedDay,
            selectedDayPredicate: (day) => isSameDay(selectedDay, day),
            onDaySelected: (selected, focused) {
              ref.read(selectedCalendarDayProvider.notifier).state = selected;
            },
            eventLoader: (day) {
              // Show dots for any booking on this day
              // We'll search through ALL provider bookings here for the calendar
              // But for performance in this demo, let's use recentBookings/confirmed ones
              return dashboard.recentBookings.where((b) => isSameDay(b.date, day)).toList();
            },
            calendarStyle: CalendarStyle(
              todayDecoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              selectedDecoration: const BoxDecoration(
                color: AppColors.secondary,
                shape: BoxShape.circle,
              ),
              markerDecoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
            ),
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          if (dayBookings.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              'Bookings for ${DateFormat('MMMM d').format(selectedDay)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 12),
            ...dayBookings.map((b) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(
                backgroundColor: AppColors.secondary,
                radius: 15,
                child: Icon(Icons.person, size: 16, color: Colors.white),
              ),
              title: Text(b.travelerName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              subtitle: Text(b.serviceTitle, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              trailing: Text('\$${b.totalPrice.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold)),
            )),
          ] else ...[
            const SizedBox(height: 16),
            const Center(
              child: Text(
                'No bookings scheduled for this day.',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
class _IncomeComparisonChart extends ConsumerWidget {
  const _IncomeComparisonChart();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(dashboardStatsProvider);
    final filter = ref.watch(chartFilterProvider);
    
    List<double> data;
    List<String> labels;
    String title;

    final now = DateTime.now();

    switch (filter) {
      case ChartFilter.weekly:
        data = dashboard.weeklyBookingCounts.map((e) => e.toDouble()).toList();
        labels = List.generate(7, (i) {
          final date = now.subtract(Duration(days: 6 - i));
          return DateFormat('E').format(date);
        });
        title = 'Weekly Booking Trend';
        break;
      case ChartFilter.monthly:
        data = dashboard.monthlyBookingCounts.map((e) => e.toDouble()).toList();
        labels = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        title = 'Calendar Year Bookings';
        break;
      case ChartFilter.yearly:
        data = dashboard.yearlyBookingCounts.map((e) => e.toDouble()).toList();
        labels = List.generate(5, (i) => (now.year - (4 - i)).toString());
        title = 'Yearly Booking Growth';
        break;
    }

    final maxVal = data.isEmpty ? 1.0 : data.reduce((a, b) => a > b ? a : b);

    return Container(
      height: 380, // Slightly taller to fit the selector
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
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 400;
              return isNarrow 
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                          color: Color(0xFF0D3B66),
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SegmentedButton<ChartFilter>(
                        segments: const [
                          ButtonSegment(value: ChartFilter.weekly, label: Text('Weekly', style: TextStyle(fontSize: 10))),
                          ButtonSegment(value: ChartFilter.monthly, label: Text('Monthly', style: TextStyle(fontSize: 10))),
                          ButtonSegment(value: ChartFilter.yearly, label: Text('Yearly', style: TextStyle(fontSize: 10))),
                        ],
                        selected: {filter},
                        onSelectionChanged: (val) => ref.read(chartFilterProvider.notifier).state = val.first,
                        showSelectedIcon: false,
                        style: SegmentedButton.styleFrom(
                          backgroundColor: Colors.grey[100],
                          selectedBackgroundColor: AppColors.secondary,
                          selectedForegroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                          color: Color(0xFF0D3B66),
                          letterSpacing: -0.3,
                        ),
                      ),
                      SegmentedButton<ChartFilter>(
                        segments: const [
                          ButtonSegment(value: ChartFilter.weekly, label: Text('Weekly', style: TextStyle(fontSize: 11))),
                          ButtonSegment(value: ChartFilter.monthly, label: Text('Monthly', style: TextStyle(fontSize: 11))),
                          ButtonSegment(value: ChartFilter.yearly, label: Text('Yearly', style: TextStyle(fontSize: 11))),
                        ],
                        selected: {filter},
                        onSelectionChanged: (val) => ref.read(chartFilterProvider.notifier).state = val.first,
                        showSelectedIcon: false,
                        style: SegmentedButton.styleFrom(
                          backgroundColor: Colors.grey[100],
                          selectedBackgroundColor: AppColors.secondary,
                          selectedForegroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ],
                  );
            },
          ),
          const SizedBox(height: 32),
          Expanded(
            child: BarChart(
              BarChartData(
                gridData: const FlGridData(show: false),
                titlesData: FlTitlesData(
                  show: true,
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx >= 0 && idx < labels.length) {
                          // Show every label on weekly/yearly, every 2nd on monthly for space
                          if (filter == ChartFilter.monthly && idx % 2 != 0) return const SizedBox();
                          
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              labels[idx],
                              style: const TextStyle(color: Colors.grey, fontSize: 10),
                            ),
                          );
                        }
                        return const SizedBox();
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: data.asMap().entries.map((e) {
                  return BarChartGroupData(
                    x: e.key,
                    barRods: [
                      BarChartRodData(
                        toY: e.value.toDouble(),
                        color: (filter == ChartFilter.monthly && e.key == now.month - 1) || (filter != ChartFilter.monthly && e.key == data.length - 1) 
                            ? AppColors.secondary 
                            : AppColors.primary.withValues(alpha: 0.4),
                        width: filter == ChartFilter.monthly ? 10 : 20,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: (maxVal == 0 ? 5 : maxVal * 1.2).toDouble(),
                          color: Colors.grey[100],
                        ),
                      ),
                    ],
                  );
                }).toList(),
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
