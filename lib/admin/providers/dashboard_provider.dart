import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/services/user_repository.dart';
import '../../shared/services/service_repository.dart';
import '../../shared/services/booking_repository.dart';
import '../../shared/models/user_model.dart';
import '../../shared/models/service_model.dart';
import '../../shared/services/banner_repository.dart';

class AdminDashboardStats {
  final int totalUsers;
  final int providers;
  final int activeServices;
  final int pendingApprovals;
  final int totalBookings;
  final double totalRevenue;
  final int dynamicBanners;
  final bool isHealthy;

  const AdminDashboardStats({
    this.totalUsers = 0,
    this.providers = 0,
    this.activeServices = 0,
    this.pendingApprovals = 0,
    this.totalBookings = 0,
    this.totalRevenue = 0.0,
    this.dynamicBanners = 0,
    this.isHealthy = true,
  });
}

final adminDashboardStatsProvider = Provider<AdminDashboardStats>((ref) {
  final users = ref.watch(userProvider);
  final services = ref.watch(serviceProvider);
  final bookings = ref.watch(bookingProvider);
  final banners = ref.watch(bannerProvider);

  final totalUsers = users.length;
  final providers = users.where((u) => u.role == UserRole.provider).length;
  final activeServices = services
      .where((s) => s.status == ServiceStatus.active)
      .length;
  final pendingApprovals = services
      .where((s) => s.status == ServiceStatus.pendingApproval)
      .length;
  final totalBookings = bookings.length;

  // Calculate total revenue from all bookings (admin view)
  final totalRevenue = bookings.fold<double>(
    0.0,
    (sum, b) => sum + b.totalPrice,
  );

  final dynamicBanners = banners.length;

  return AdminDashboardStats(
    totalUsers: totalUsers,
    providers: providers,
    activeServices: activeServices,
    pendingApprovals: pendingApprovals,
    totalBookings: totalBookings,
    totalRevenue: totalRevenue,
    dynamicBanners: dynamicBanners,
    isHealthy: true, // Mocked for UI
  );
});
