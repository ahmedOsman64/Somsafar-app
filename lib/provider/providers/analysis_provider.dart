import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/models/booking_model.dart';
import '../../shared/services/booking_repository.dart';
import '../../shared/services/auth_service.dart';
import '../../shared/services/service_repository.dart';

enum AnalysisTimeframe { weekly, monthly, yearly }

final analysisTimeframeProvider =
    StateProvider<AnalysisTimeframe>((ref) => AnalysisTimeframe.monthly);

class TopServiceStat {
  final String serviceId;
  final String title;
  final double revenue;
  final int bookingCount;
  final double percentage;

  const TopServiceStat({
    required this.serviceId,
    required this.title,
    required this.revenue,
    required this.bookingCount,
    required this.percentage,
  });
}

class AnalysisStats {
  final double totalRevenue;
  final double pendingPayout;
  final double averageBookingValue;
  final double completionRate;
  final int totalBookings;
  final int completedBookings;
  final int pendingBookings;
  final int confirmedBookings;
  final int cancelledBookings;
  final List<double> chartData;
  final List<String> chartLabels;
  final List<TopServiceStat> topServices;

  const AnalysisStats({
    this.totalRevenue = 0.0,
    this.pendingPayout = 0.0,
    this.averageBookingValue = 0.0,
    this.completionRate = 0.0,
    this.totalBookings = 0,
    this.completedBookings = 0,
    this.pendingBookings = 0,
    this.confirmedBookings = 0,
    this.cancelledBookings = 0,
    this.chartData = const [],
    this.chartLabels = const [],
    this.topServices = const [],
  });
}

final analysisStatsProvider = Provider<AnalysisStats>((ref) {
  final bookings = ref.watch(filteredBookingsProvider);
  final user = ref.watch(authProvider);
  final timeframe = ref.watch(analysisTimeframeProvider);
  final serviceList = ref.watch(serviceProvider);

  final providerKey = user?.providerId ?? user?.id ?? '';

  // Filter bookings belonging to this provider
  final providerBookings = bookings
      .where((b) => b.providerId == providerKey)
      .toList();

  if (providerBookings.isEmpty) {
    return const AnalysisStats();
  }

  final now = DateTime.now();

  // Helper function to check if booking date falls within the selected timeframe
  bool isInTimeframe(DateTime date) {
    if (timeframe == AnalysisTimeframe.weekly) {
      final diffInDays = now.difference(date).inDays;
      return diffInDays >= 0 && diffInDays < 7;
    } else if (timeframe == AnalysisTimeframe.monthly) {
      return date.month == now.month && date.year == now.year;
    } else {
      return date.year == now.year;
    }
  }

  // Filter bookings strictly for the selected timeframe
  final timeframeBookings =
      providerBookings.where((b) => isInTimeframe(b.date)).toList();

  // Revenue & counts for current timeframe
  double totalRevenue = 0.0;
  double pendingPayout = 0.0;
  int completedCount = 0;
  int pendingCount = 0;
  int confirmedCount = 0;
  int cancelledCount = 0;

  final Map<String, double> serviceRevenueMap = {};
  final Map<String, int> serviceCountMap = {};

  for (final b in timeframeBookings) {
    if (b.status == BookingStatus.completed ||
        b.status == BookingStatus.confirmed) {
      totalRevenue += b.totalPrice;
    }
    if (b.status == BookingStatus.pending) {
      pendingPayout += b.totalPrice;
      pendingCount++;
    } else if (b.status == BookingStatus.completed) {
      completedCount++;
    } else if (b.status == BookingStatus.confirmed) {
      confirmedCount++;
    } else if (b.status == BookingStatus.cancelled) {
      cancelledCount++;
    }

    if (b.status != BookingStatus.cancelled) {
      serviceRevenueMap[b.serviceId] =
          (serviceRevenueMap[b.serviceId] ?? 0.0) + b.totalPrice;
      serviceCountMap[b.serviceId] =
          (serviceCountMap[b.serviceId] ?? 0) + 1;
    }
  }

  final totalBookings = timeframeBookings.length;
  final validPaidCount = completedCount + confirmedCount;
  final averageBookingValue =
      validPaidCount > 0 ? totalRevenue / validPaidCount : 0.0;
  final completionRate =
      totalBookings > 0 ? (completedCount / totalBookings) * 100 : 0.0;

  // Compute Chart Data & Labels based on Timeframe
  List<double> chartData = [];
  List<String> chartLabels = [];

  if (timeframe == AnalysisTimeframe.weekly) {
    // Last 7 days
    chartLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    chartData = List.filled(7, 0.0);

    for (final b in timeframeBookings) {
      if (b.status == BookingStatus.completed ||
          b.status == BookingStatus.confirmed) {
        final dayIdx = (b.date.weekday - 1) % 7;
        chartData[dayIdx] += b.totalPrice;
      }
    }
  } else if (timeframe == AnalysisTimeframe.monthly) {
    // 4 Weeks of current month
    chartLabels = ['Week 1', 'Week 2', 'Week 3', 'Week 4'];
    chartData = List.filled(4, 0.0);

    for (final b in timeframeBookings) {
      if (b.status == BookingStatus.completed ||
          b.status == BookingStatus.confirmed) {
        int weekIdx = (b.date.day - 1) ~/ 7;
        if (weekIdx > 3) weekIdx = 3;
        chartData[weekIdx] += b.totalPrice;
      }
    }
  } else {
    // 12 Months of current year
    chartLabels = [
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
    chartData = List.filled(12, 0.0);

    for (final b in timeframeBookings) {
      if (b.status == BookingStatus.completed ||
          b.status == BookingStatus.confirmed) {
        final monthIdx = b.date.month - 1;
        chartData[monthIdx] += b.totalPrice;
      }
    }
  }

  // Compute Top Services
  final List<TopServiceStat> topServicesList = [];
  serviceRevenueMap.forEach((serviceId, rev) {
    final sMatch = serviceList.where((s) => s.id == serviceId);
    final title =
        sMatch.isNotEmpty ? sMatch.first.title : 'Service #$serviceId';
    final count = serviceCountMap[serviceId] ?? 0;
    final percentage = totalRevenue > 0 ? (rev / totalRevenue) * 100 : 0.0;

    topServicesList.add(TopServiceStat(
      serviceId: serviceId,
      title: title,
      revenue: rev,
      bookingCount: count,
      percentage: percentage,
    ));
  });

  topServicesList.sort((a, b) => b.revenue.compareTo(a.revenue));

  return AnalysisStats(
    totalRevenue: totalRevenue,
    pendingPayout: pendingPayout,
    averageBookingValue: averageBookingValue,
    completionRate: completionRate,
    totalBookings: totalBookings,
    completedBookings: completedCount,
    pendingBookings: pendingCount,
    confirmedBookings: confirmedCount,
    cancelledBookings: cancelledCount,
    chartData: chartData,
    chartLabels: chartLabels,
    topServices: topServicesList.take(5).toList(),
  );
});
