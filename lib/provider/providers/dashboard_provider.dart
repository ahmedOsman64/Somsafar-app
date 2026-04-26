import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../shared/models/booking_model.dart';
import '../../shared/models/service_model.dart';
import '../../shared/services/booking_repository.dart';
import '../../shared/services/service_repository.dart';
import '../../shared/services/auth_service.dart';

class DashboardStats {
  final int totalServices;
  final int activeServices;
  final int inactiveServices;
  final int draftServices;
  final int pendingBookings;
  final double totalEarnings;
  final double monthlyTarget;
  final List<Booking> recentBookings;
  final List<double> weeklyEarnings;
  final int daysLeft;

  const DashboardStats({
    this.totalServices = 0,
    this.activeServices = 0,
    this.inactiveServices = 0,
    this.draftServices = 0,
    this.pendingBookings = 0,
    this.totalEarnings = 0.0,
    this.monthlyTarget = 15000.00,
    this.recentBookings = const [],
    this.weeklyEarnings = const [],
    this.daysLeft = 0,
  });
}

// ---------------------------------------------------------------------------
// Editable monthly target
// ---------------------------------------------------------------------------
class MonthlyTargetNotifier extends StateNotifier<double> {
  static const _key = 'monthly_target';
  static const double _defaultTarget = 15000.0;

  MonthlyTargetNotifier() : super(_defaultTarget) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getDouble(_key) ?? _defaultTarget;
  }

  Future<void> setTarget(double value) async {
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_key, value);
  }
}

final monthlyTargetProvider =
    StateNotifierProvider<MonthlyTargetNotifier, double>(
  (_) => MonthlyTargetNotifier(),
);

final dashboardStatsProvider = Provider<DashboardStats>((ref) {
  final services = ref.watch(filteredServicesProvider);
  final bookings = ref.watch(filteredBookingsProvider);
  final user = ref.watch(authProvider);
  final monthlyTarget = ref.watch(monthlyTargetProvider);

  final providerKey = user?.providerId ?? user?.id ?? '';

  // Service stats — already isolated to this provider via filteredServicesProvider
  final totalServices = services.length;
  final activeServices = services
      .where((s) => s.status == ServiceStatus.active)
      .length;
  final inactiveServices = services
      .where(
        (s) =>
            s.status == ServiceStatus.inactive ||
            s.status == ServiceStatus.blocked,
      )
      .length;
  final draftServices = services
      .where((s) => s.status == ServiceStatus.draft)
      .length;

  // Only count bookings where THIS provider is the service owner (not personal trips)
  final providerBookings = bookings
      .where((b) => b.providerId == providerKey)
      .toList();

  final pendingBookings = providerBookings
      .where((b) => b.status == BookingStatus.pending)
      .length;

  // Earnings: only from provider-side completed/confirmed bookings
  final confirmedAndCompleted = providerBookings
      .where(
        (b) =>
            b.status == BookingStatus.completed ||
            b.status == BookingStatus.confirmed,
      )
      .toList();

  final totalEarnings = confirmedAndCompleted.fold<double>(0.0, (sum, b) => sum + b.totalPrice);

  // Dynamic Weekly Earnings calculation
  final now = DateTime.now();
  final last7Days = List.generate(7, (i) => now.subtract(Duration(days: 6 - i)));
  final weeklyEarnings = last7Days.map((day) {
    return confirmedAndCompleted.where((b) {
      return b.date.year == day.year &&
          b.date.month == day.month &&
          b.date.day == day.day;
    }).fold<double>(0.0, (sum, b) => sum + b.totalPrice);
  }).toList();

  // Days left in current month
  final lastDayOfMonth = DateTime(now.year, now.month + 1, 0);
  final daysLeft = lastDayOfMonth.difference(DateTime(now.year, now.month, now.day)).inDays;

  // Recent bookings: provider-side only, sorted newest first, top 5
  final sortedBookings = List<Booking>.from(providerBookings)
    ..sort((a, b) => b.date.compareTo(a.date));
  final recentBookings = sortedBookings.take(5).toList();

  return DashboardStats(
    totalServices: totalServices,
    activeServices: activeServices,
    inactiveServices: inactiveServices,
    draftServices: draftServices,
    pendingBookings: pendingBookings,
    totalEarnings: totalEarnings,
    monthlyTarget: monthlyTarget,
    recentBookings: recentBookings,
    weeklyEarnings: weeklyEarnings,
    daysLeft: daysLeft,
  );
});
