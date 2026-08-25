import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../providers/dashboard_provider.dart';
import '../../shared/services/auth_service.dart';
import '../../shared/models/user_model.dart';
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
      color: const Color(0xFFF4F6F9),
      child: RefreshIndicator(
        onRefresh: () async {
          await ref.read(bookingProvider.notifier).fetchBookings();
          await ref.read(serviceProvider.notifier).fetchServices();
          await ref.read(bookingProvider.notifier).syncAllServicesAvailability();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!context.isMobile) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                  child: const _DashboardHeader(),
                ),
                const SizedBox(height: 16),
              ],
              const _WelcomeBanner(),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                color: Color(0xFF0F172A),
              ),
            ),
            Text(
              'Welcome back to your provider panel',
              style: TextStyle(color: Colors.grey, fontSize: 13),
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
                    color: Colors.black.withAlpha(10),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Consumer(
                builder: (context, ref, child) {
                  final unreadCount =
                      ref.watch(unreadNotificationsCountProvider);
                  return Stack(
                    children: [
                      IconButton(
                        icon: Icon(
                          unreadCount > 0
                              ? Icons.notifications_rounded
                              : Icons.notifications_none_rounded,
                          color: AppColors.primary,
                        ),
                        onPressed: () =>
                            context.push('/provider/notifications'),
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
            const SizedBox(width: 14),
            CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.primary.withAlpha(20),
              child: user?.profileImage != null && user!.profileImage!.isNotEmpty
                  ? ClipOval(
                      child: AppNetworkImage(
                        imageUrl: StorageService.ensurePublicUrl(user.profileImage!),
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover,
                        memCacheWidth: 88,
                        errorWidget: const Icon(
                          Icons.person,
                          size: 22,
                          color: AppColors.primary,
                        ),
                      ),
                    )
                  : const Icon(Icons.person, color: AppColors.primary),
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
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E3A8A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(context.isMobile ? 0 : 28),
          bottomRight: Radius.circular(context.isMobile ? 0 : 28),
          topLeft: Radius.circular(context.isMobile ? 0 : 20),
          topRight: Radius.circular(context.isMobile ? 0 : 20),
        ),
      ),
      child: SafeArea(
        bottom: false,
        top: context.isMobile,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            20,
            24,
            context.isMobile ? 24 : 28,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withAlpha(35),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF10B981).withAlpha(90),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.sensors_rounded,
                          color: Color(0xFF10B981),
                          size: 13,
                        ),
                        SizedBox(width: 5),
                        Text(
                          'REALTIME SYNC ACTIVE',
                          style: TextStyle(
                            color: Color(0xFF10B981),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (context.isMobile)
                    IconButton(
                      icon: const Icon(
                        Icons.notifications_none_rounded,
                        color: Colors.white,
                      ),
                      onPressed: () => context.push('/provider/notifications'),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome back, $userName! 👋',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: context.isMobile ? 22 : 26,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Here is the live real-time overview of your business listings and bookings.',
                          style: TextStyle(
                            color: Colors.white.withAlpha(200),
                            fontSize: context.isMobile ? 12 : 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!context.isMobile) ...[
                    const SizedBox(width: 20),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => context.push('/provider/services/add'),
                          icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
                          label: const Text('Add Service'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.secondary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          onPressed: () => context.go('/provider/reports'),
                          icon: const Icon(Icons.bar_chart_rounded, size: 16),
                          label: const Text('Reports'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white.withAlpha(30),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: BorderSide(color: Colors.white.withAlpha(50)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OverviewSection extends ConsumerWidget {
  const _OverviewSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(dashboardStatsProvider);
    final user = ref.watch(authProvider);
    final providerType = user?.providerType ?? ProviderType.hotel;

    String servicesLabel = 'Properties';
    IconData servicesIcon = Icons.apartment_rounded;

    switch (providerType) {
      case ProviderType.hotel:
      case ProviderType.home:
      case ProviderType.apartment:
        servicesLabel = 'Properties';
        servicesIcon = Icons.apartment_rounded;
        break;
      case ProviderType.all:
      case ProviderType.tour:
        servicesLabel = 'Services';
        servicesIcon = Icons.grid_view_rounded;
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Business Performance Overview',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 600;
            final cardWidth = isMobile
                ? (constraints.maxWidth - 12) / 2
                : (constraints.maxWidth - 48) / 5;

            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _StatCard(
                  width: cardWidth,
                  icon: servicesIcon,
                  count: dashboard.totalServices,
                  label: servicesLabel,
                  subtitle: 'Total listed items',
                  color: AppColors.primary,
                ),
                _StatCard(
                  width: cardWidth,
                  icon: Icons.check_circle_rounded,
                  count: dashboard.activeServices,
                  label: 'Active',
                  subtitle: 'Live on platform',
                  color: const Color(0xFF10B981),
                ),
                _StatCard(
                  width: cardWidth,
                  icon: Icons.pause_circle_rounded,
                  count: dashboard.inactiveServices,
                  label: 'Inactive',
                  subtitle: 'Temporarily paused',
                  color: const Color(0xFFF59E0B),
                ),
                _StatCard(
                  width: cardWidth,
                  icon: Icons.edit_note_rounded,
                  count: dashboard.draftServices,
                  label: 'Drafts',
                  subtitle: 'Unpublished drafts',
                  color: const Color(0xFF64748B),
                ),
                _StatCard(
                  width: cardWidth,
                  icon: Icons.pending_actions_rounded,
                  count: dashboard.pendingBookings,
                  label: 'Pending',
                  subtitle: 'Needs action',
                  color: const Color(0xFF8B5CF6),
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
  final double width;
  final IconData icon;
  final int count;
  final String label;
  final String subtitle;
  final Color color;

  const _StatCard({
    required this.width,
    required this.icon,
    required this.count,
    required this.label,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 12,
            offset: const Offset(0, 4),
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
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                ),
                overflow: TextOverflow.ellipsis,
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '$count',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            overflow: TextOverflow.ellipsis,
          ),
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
        labels = [
          'Jan',
          'Feb',
          'Mar',
          'Apr',
          'May',
          'Jun',
          'Jul',
          'Aug',
          'Sep',
          'Oct',
          'Nov',
          'Dec'
        ];
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
      height: 380,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const Text(
                    'Booking count trends over time',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              SegmentedButton<ChartFilter>(
                segments: const [
                  ButtonSegment(
                    value: ChartFilter.weekly,
                    label: Text('Weekly', style: TextStyle(fontSize: 11)),
                  ),
                  ButtonSegment(
                    value: ChartFilter.monthly,
                    label: Text('Monthly', style: TextStyle(fontSize: 11)),
                  ),
                  ButtonSegment(
                    value: ChartFilter.yearly,
                    label: Text('Yearly', style: TextStyle(fontSize: 11)),
                  ),
                ],
                selected: {filter},
                onSelectionChanged: (val) =>
                    ref.read(chartFilterProvider.notifier).state = val.first,
                showSelectedIcon: false,
                style: SegmentedButton.styleFrom(
                  backgroundColor: const Color(0xFFF1F5F9),
                  selectedBackgroundColor: AppColors.primary,
                  selectedForegroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Expanded(
            child: BarChart(
              BarChartData(
                gridData: const FlGridData(show: false),
                titlesData: FlTitlesData(
                  show: true,
                  topTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx >= 0 && idx < labels.length) {
                          if (filter == ChartFilter.monthly && idx % 2 != 0) {
                            return const SizedBox();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              labels[idx],
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
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
                  final isHighlight = (filter == ChartFilter.monthly &&
                          e.key == now.month - 1) ||
                      (filter != ChartFilter.monthly &&
                          e.key == data.length - 1);
                  return BarChartGroupData(
                    x: e.key,
                    barRods: [
                      BarChartRodData(
                        toY: e.value.toDouble(),
                        color: isHighlight
                            ? AppColors.primary
                            : AppColors.primary.withAlpha(90),
                        width: filter == ChartFilter.monthly ? 12 : 22,
                        borderRadius:
                            const BorderRadius.vertical(top: Radius.circular(6)),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: (maxVal == 0 ? 5 : maxVal * 1.2).toDouble(),
                          color: const Color(0xFFF1F5F9),
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

class _LiveCalendarCard extends ConsumerWidget {
  const _LiveCalendarCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(dashboardStatsProvider);
    final selectedDay = ref.watch(selectedCalendarDayProvider);

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
            color: Colors.black.withAlpha(8),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Live Booking Calendar',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                  color: Color(0xFF0F172A),
                ),
              ),
              Icon(Icons.calendar_month_rounded, color: AppColors.primary),
            ],
          ),
          const SizedBox(height: 16),
          TableCalendar(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: selectedDay,
            selectedDayPredicate: (day) => isSameDay(selectedDay, day),
            onDaySelected: (selected, focused) {
              ref.read(selectedCalendarDayProvider.notifier).state = selected;
            },
            eventLoader: (day) {
              return dashboard.recentBookings
                  .where((b) => isSameDay(b.date, day))
                  .toList();
            },
            calendarStyle: CalendarStyle(
              todayDecoration: BoxDecoration(
                color: AppColors.primary.withAlpha(40),
                shape: BoxShape.circle,
              ),
              selectedDecoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              markerDecoration: const BoxDecoration(
                color: AppColors.secondary,
                shape: BoxShape.circle,
              ),
            ),
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextStyle:
                  TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          if (dayBookings.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'Bookings for ${DateFormat('MMMM d, yyyy').format(selectedDay)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 12),
            ...dayBookings.map((b) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: b.statusColor.withAlpha(20),
                    radius: 18,
                    child: Icon(Icons.person, size: 18, color: b.statusColor),
                  ),
                  title: Text(
                    b.travelerName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    b.serviceTitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                  trailing: Text(
                    '\$${b.totalPrice.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                )),
          ] else ...[
            const SizedBox(height: 16),
            Center(
              child: Text(
                'No bookings scheduled for ${DateFormat('MMM d').format(selectedDay)}.',
                style: TextStyle(color: Colors.grey[500], fontSize: 13),
              ),
            ),
          ],
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
            color: Colors.black.withAlpha(8),
            blurRadius: 12,
            offset: const Offset(0, 4),
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
                  fontSize: 17,
                  color: Color(0xFF0F172A),
                ),
              ),
              TextButton(
                onPressed: () => context.go('/provider/bookings'),
                child: const Text(
                  'View All',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (dashboard.recentBookings.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.bookmark_border_rounded,
                        size: 48, color: Colors.grey[300]),
                    const SizedBox(height: 8),
                    Text(
                      'No recent bookings found',
                      style: TextStyle(color: Colors.grey[500], fontSize: 13),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: dashboard.recentBookings.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
              itemBuilder: (context, index) {
                final booking = dashboard.recentBookings[index];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(vertical: 4),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: booking.statusColor.withAlpha(20),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.person_outline_rounded,
                      color: booking.statusColor,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    booking.travelerName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  subtitle: Text(
                    booking.serviceTitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '\$${booking.totalPrice.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: booking.statusColor.withAlpha(20),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          booking.statusLabel,
                          style: TextStyle(
                            color: booking.statusColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
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

class _QuickActionsSection extends StatelessWidget {
  const _QuickActionsSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Action Shortcuts',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 600;
            if (isMobile) {
              return Column(
                children: [
                  _buildActionButton(
                    context,
                    label: 'Add New Service',
                    icon: Icons.add_circle_outline_rounded,
                    color: AppColors.primary,
                    isPrimary: true,
                    onTap: () => context.push('/provider/services/add'),
                  ),
                  const SizedBox(height: 10),
                  _buildActionButton(
                    context,
                    label: 'Manage Listings',
                    icon: Icons.grid_view_rounded,
                    color: AppColors.primary,
                    isPrimary: false,
                    onTap: () => context.go('/provider/services'),
                  ),
                ],
              );
            }
            return Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    context,
                    label: 'Add New Service',
                    icon: Icons.add_circle_outline_rounded,
                    color: AppColors.primary,
                    isPrimary: true,
                    onTap: () => context.push('/provider/services/add'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionButton(
                    context,
                    label: 'Manage Listings',
                    icon: Icons.grid_view_rounded,
                    color: AppColors.primary,
                    isPrimary: false,
                    onTap: () => context.go('/provider/services'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionButton(
                    context,
                    label: 'Customer Reviews',
                    icon: Icons.rate_review_rounded,
                    color: const Color(0xFF6366F1),
                    isPrimary: false,
                    onTap: () => context.go('/provider/reviews'),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required Color color,
    required bool isPrimary,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: 50,
      child: isPrimary
          ? ElevatedButton.icon(
              onPressed: onTap,
              icon: Icon(icon, color: Colors.white, size: 18),
              label: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            )
          : OutlinedButton.icon(
              onPressed: onTap,
              icon: Icon(icon, color: color, size: 18),
              label: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: color, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
    );
  }
}
