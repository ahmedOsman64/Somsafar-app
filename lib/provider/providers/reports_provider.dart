import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/models/booking_model.dart';
import '../../shared/services/booking_repository.dart';
import '../../shared/services/auth_service.dart';

class ReportsStats {
  final double totalRevenue;
  final double pendingPayout;
  final int completedBookings;
  final List<Booking> transactions;

  const ReportsStats({
    this.totalRevenue = 0.0,
    this.pendingPayout = 0.0,
    this.completedBookings = 0,
    this.transactions = const [],
  });
}

final reportsStatsProvider = Provider<ReportsStats>((ref) {
  final bookings = ref.watch(filteredBookingsProvider);
  final user = ref.watch(authProvider);

  final providerKey = user?.providerId ?? user?.id ?? '';

  // Only count bookings where THIS provider is the service owner
  final providerBookings = bookings
      .where((b) => b.providerId == providerKey)
      .toList();

  final totalRevenue = providerBookings
      .where(
        (b) =>
            b.status == BookingStatus.completed ||
            b.status == BookingStatus.confirmed,
      )
      .fold<double>(0.0, (sum, b) => sum + b.totalPrice);

  final pendingPayout = providerBookings
      .where((b) => b.status == BookingStatus.pending)
      .fold<double>(0.0, (sum, b) => sum + b.totalPrice);

  final completedBookingsCount = providerBookings
      .where((b) => b.status == BookingStatus.completed)
      .length;

  final sortedTransactions = List<Booking>.from(providerBookings)
    ..sort((a, b) => b.date.compareTo(a.date));

  return ReportsStats(
    totalRevenue: totalRevenue,
    pendingPayout: pendingPayout,
    completedBookings: completedBookingsCount,
    transactions: sortedTransactions,
  );
});
