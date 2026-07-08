import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/services/booking_repository.dart';
import '../../shared/models/booking_model.dart';
import 'provider_chat_screen.dart';
import '../../shared/services/auth_service.dart';
import '../../shared/widgets/confirmation_dialog.dart';
import '../../shared/services/service_repository.dart';
import '../../shared/models/user_model.dart';

class ProviderBookingsScreen extends ConsumerWidget {
  const ProviderBookingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookings = ref.watch(filteredBookingsProvider);
    final user = ref.watch(authProvider);
    final providerType = user?.providerType ?? ProviderType.hotel;

    String title = 'Booking Requests';
    switch (providerType) {
      case ProviderType.hotel:
        title = 'Room Bookings';
        break;
      case ProviderType.home:
      case ProviderType.apartment:
        title = 'Apartment Bookings';
        break;
      case ProviderType.all:
        title = 'All Service Bookings';
        break;
      case ProviderType.tour:
        title = 'Tour Bookings';
        break;
      case ProviderType.tailor:
        title = 'Dalabaadka Harqaanka';
        break;
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
          foregroundColor: Colors.white,
          bottom: TabBar(
            tabs: [
              _buildTab(
                'Pending',
                bookings.where((b) => b.status == BookingStatus.pending).length,
              ),
              _buildTab(
                'Confirmed',
                bookings
                    .where((b) => b.status == BookingStatus.confirmed)
                    .length,
              ),
              _buildTab(
                'Completed',
                bookings
                    .where((b) => b.status == BookingStatus.completed)
                    .length,
              ),
            ],
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white.withValues(alpha: 0.6),
            labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        body: Column(
          children: [
            _buildSummary(ref, providerType),
            Expanded(
              child: TabBarView(
                children: [
                  _buildBookingList(
                    context,
                    ref,
                    bookings,
                    BookingStatus.pending,
                  ),
                  _buildBookingList(
                    context,
                    ref,
                    bookings,
                    BookingStatus.confirmed,
                  ),
                  _buildBookingList(
                    context,
                    ref,
                    bookings,
                    BookingStatus.completed,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(String label, int count) {
    return Tab(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label),
          if (count > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                count.toString(),
                style: const TextStyle(fontSize: 10),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBookingList(
    BuildContext context,
    WidgetRef ref,
    List<Booking> allBookings,
    BookingStatus status,
  ) {
    final bookings = allBookings.where((b) => b.status == status).toList();

    // Sort logic
    bookings.sort((a, b) => b.date.compareTo(a.date)); // Newest first

    if (bookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No ${status.name} bookings',
              style: TextStyle(color: Colors.grey[500], fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: bookings.length,
      itemBuilder: (context, index) =>
          _BookingCard(booking: bookings[index], ref: ref),
    );
  }

  Widget _buildSummary(WidgetRef ref, ProviderType type) {
    if (type == ProviderType.tour) return const SizedBox.shrink();

    final services = ref.watch(filteredServicesProvider);
    final bookings = ref.watch(filteredBookingsProvider);

    // Get today at midnight for comparison
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    int totalUnits = 0;
    int bookedUnits = 0;

    for (final s in services) {
      final category = s.category.toLowerCase();

      if (category.contains('hotel')) {
        totalUnits += (s.metadata['rooms'] as num?)?.toInt() ?? 1;

        // Dynamic Calculation: Count rooms from confirmed stays covering today
        final activeStaysRooms = bookings
            .where((b) {
              if (b.serviceId != s.id) return false;
              if (b.status != BookingStatus.confirmed) return false;

              // Check if stay overlaps with today (stay starts on/before today AND ends after today)
              final startsOnOrBeforeToday = !b.checkIn.isAfter(today);
              final endsAfterToday = b.checkOut.isAfter(today);

              return startsOnOrBeforeToday && endsAfterToday;
            })
            .fold<int>(0, (sum, b) => sum + b.rooms);

        bookedUnits += activeStaysRooms;
      } else if (category.contains('apartment') || category.contains('home')) {
        totalUnits += 1;

        // Dynamic Calculation: Check if there's a confirmed stay covering today
        final isOccupied = bookings.any((b) {
          if (b.serviceId != s.id) return false;
          if (b.status != BookingStatus.confirmed) return false;

          final startsOnOrBeforeToday = !b.checkIn.isAfter(today);
          final endsAfterToday = b.checkOut.isAfter(today);

          return startsOnOrBeforeToday && endsAfterToday;
        });

        if (isOccupied) {
          bookedUnits += 1;
        }
      }
    }

    if (totalUnits == 0) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D3B66), Color(0xFF1B62A4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0D3B66).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  type == ProviderType.hotel
                      ? Icons.bedtime_outlined
                      : Icons.apartment_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      type == ProviderType.hotel
                          ? 'Room Occupancy'
                          : 'Property Availability',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$bookedUnits units booked / $totalUnits total',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Stack(
            children: [
              Container(
                height: 10,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              FractionallySizedBox(
                widthFactor: totalUnits > 0
                    ? (bookedUnits / totalUnits).clamp(0.0, 1.0)
                    : 0,
                child: Container(
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.3),
                        blurRadius: 8,
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
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${totalUnits - bookedUnits} active units left',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                'Live Data',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  final Booking booking;
  final WidgetRef ref;

  const _BookingCard({required this.booking, required this.ref});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Badge & Date
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: booking.statusColor.withAlpha(26),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: booking.statusColor.withAlpha(128),
                    ),
                  ),
                  child: Text(
                    booking.statusLabel,
                    style: TextStyle(
                      color: booking.statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  "Booked: ${DateFormat('MMM dd').format(booking.date)}",
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Service Title
            Text(
              booking.serviceTitle,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const Divider(height: 24),

            // Details Grid
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailItem(
                        Icons.calendar_today,
                        'Dates',
                        '${DateFormat('MMM dd').format(booking.checkIn)} - ${DateFormat('MMM dd').format(booking.checkOut)}',
                      ),
                      const SizedBox(height: 12),
                      _buildDetailItem(
                        Icons.people,
                        'Guests',
                        '${booking.guests} Guests, ${booking.rooms} Rooms',
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailItem(
                        Icons.person,
                        'Traveler',
                        booking.travelerName,
                      ),
                      const SizedBox(height: 12),
                      _buildDetailItem(
                        Icons.attach_money,
                        'Total Price',
                        '\$${booking.totalPrice.toStringAsFixed(0)}',
                      ),
                    ],
                  ),
                ),
              ],
            ),

            if (booking.specialRequests != null &&
                booking.specialRequests!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Note: ${booking.specialRequests}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],

            if (booking.contactPhone.isNotEmpty ||
                booking.contactEmail.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Row(
                  children: [
                    if (booking.contactPhone.isNotEmpty) ...[
                      const Icon(Icons.phone, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          booking.contactPhone,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    if (booking.contactEmail.isNotEmpty) ...[
                      const Icon(Icons.email, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          booking.contactEmail,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

            // Payment Reference Info
            if (booking.transactionId != null ||
                booking.paymentMethod != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withAlpha(50)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Payment Details',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (booking.paymentMethod != null)
                      Text(
                        'Method: ${booking.paymentMethod}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    if (booking.transactionId != null)
                      Text(
                        'Ref/TXN: ${booking.transactionId}',
                        style: const TextStyle(fontSize: 12),
                      ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),
            _buildActions(context),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 10, color: Colors.grey[600]),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActions(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        OutlinedButton.icon(
          onPressed: () => _showBookingDetails(context),
          icon: const Icon(Icons.visibility_outlined, size: 18),
          label: const Text('View'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12),
          ),
        ),
        if (booking.status == BookingStatus.pending) ...[
          OutlinedButton(
            onPressed: () => _updateStatus(context, BookingStatus.cancelled),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Reject'),
          ),
          ElevatedButton(
            onPressed: () => _updateStatus(context, BookingStatus.confirmed),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            child: const Text('Accept'),
          ),
        ] else if (booking.status == BookingStatus.confirmed) ...[
          OutlinedButton(
            onPressed: () => _updateStatus(context, BookingStatus.cancelled),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Cancel'),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: () async {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Attempting to send email receipt...'),
                  duration: Duration(seconds: 1),
                ),
              );
              final success = await ref
                  .read(bookingProvider.notifier)
                  .resendConfirmationEmail(booking.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? 'Receipt email sent successfully!'
                          : 'Failed to send email. Check credentials.',
                    ),
                    backgroundColor: success
                        ? AppColors.success
                        : AppColors.error,
                  ),
                );
              }
            },
            icon: const Icon(Icons.email_outlined, size: 18),
            label: const Text('Resend Receipt'),
          ),
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProviderChatScreen(
                    bookingId: booking.id,
                    travelerName: booking.travelerName,
                  ),
                ),
              );
            },
            icon: const Icon(
              Icons.chat_bubble_outline,
              color: AppColors.primary,
            ),
            tooltip: 'Chat with Traveler',
          ),
        ],
      ],
    );
  }

  void _showBookingDetails(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.receipt_long, color: AppColors.primary),
            const SizedBox(width: 12),
            const Expanded(child: Text('Booking Details')),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('Service Information'),
              _buildInfoRow('Service', booking.serviceTitle),
              _buildInfoRow(
                'Status',
                booking.statusLabel,
                color: booking.statusColor,
              ),
              _buildInfoRow(
                'Booking Date',
                DateFormat('MMM dd, yyyy HH:mm').format(booking.date),
              ),

              const Divider(height: 32),
              _buildSectionTitle('Traveler Details'),
              _buildInfoRow('Name', booking.travelerName),
              _buildInfoRow(
                'Phone',
                booking.contactPhone.isEmpty
                    ? 'Not provided'
                    : booking.contactPhone,
              ),
              _buildInfoRow(
                'Email',
                booking.contactEmail.isEmpty
                    ? 'Not provided'
                    : booking.contactEmail,
              ),

              const Divider(height: 32),
              _buildSectionTitle('Booking Details'),
              _buildInfoRow(
                'Check-in',
                DateFormat('MMM dd, yyyy').format(booking.checkIn),
              ),
              _buildInfoRow(
                'Check-out',
                DateFormat('MMM dd, yyyy').format(booking.checkOut),
              ),
              _buildInfoRow('Guests', '${booking.guests} Guests'),
              _buildInfoRow('Rooms/Units', '${booking.rooms} Rooms'),
              if (booking.specialRequests != null &&
                  booking.specialRequests!.isNotEmpty)
                _buildInfoRow(
                  'Special Requests',
                  booking.specialRequests!,
                  isLong: true,
                ),

              const Divider(height: 32),
              _buildSectionTitle('Payment Information'),
              _buildInfoRow(
                'Subtotal',
                '\$${(booking.totalPrice - booking.taxes).toStringAsFixed(2)}',
              ),
              _buildInfoRow('Tax', '\$${booking.taxes.toStringAsFixed(2)}'),
              _buildInfoRow(
                'Total Price',
                '\$${booking.totalPrice.toStringAsFixed(2)}',
                isBold: true,
                color: AppColors.primary,
              ),
              const SizedBox(height: 12),
              if (booking.paymentMethod != null)
                _buildInfoRow(
                  'Method',
                  _formatPaymentMethod(booking.paymentMethod!),
                ),
              _buildInfoRow(
                'Payment Status',
                booking.paymentStatus.name.toUpperCase(),
                color: _getPaymentStatusColor(booking.paymentStatus),
                isBold: true,
              ),
              if (booking.transactionId != null)
                _buildInfoRow('Transaction ID', booking.transactionId!),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value, {
    Color? color,
    bool isBold = false,
    bool isLong = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: isLong
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 110, // Increased width slightly
            child: Text(
              '$label:',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatPaymentMethod(String method) {
    if (method.toLowerCase().contains('mobile')) return '📱 Mobile Money';
    if (method.toLowerCase().contains('bank')) return '🏦 Bank Transfer';
    if (method.toLowerCase().contains('paylater')) return '🕒 Pay Later';
    return method.toUpperCase();
  }

  Color _getPaymentStatusColor(BookingPaymentStatus status) {
    switch (status) {
      case BookingPaymentStatus.paid:
        return AppColors.success;
      case BookingPaymentStatus.failed:
        return AppColors.error;
      case BookingPaymentStatus.pending:
        return Colors.orange;
    }
  }

  void _updateStatus(BuildContext context, BookingStatus status) async {
    String actionNoun = '';
    Color themeColor = AppColors.primary;

    switch (status) {
      case BookingStatus.confirmed:
        actionNoun = 'Accept';
        themeColor = AppColors.success;
        break;
      case BookingStatus.cancelled:
        actionNoun = booking.status == BookingStatus.pending
            ? 'Reject'
            : 'Cancel';
        themeColor = AppColors.error;
        break;
      case BookingStatus.completed:
        actionNoun = 'Complete';
        themeColor = AppColors.primary;
        break;
      default:
        actionNoun = 'Update';
    }

    final confirmed = await ConfirmationDialog.show(
      context: context,
      title: '$actionNoun Booking?',
      message:
          'Are you sure you want to $actionNoun this booking for ${booking.travelerName}?',
      confirmLabel: 'Yes, $actionNoun',
      type: status == BookingStatus.cancelled
          ? ConfirmationDialogType.danger
          : ConfirmationDialogType.info,
      icon: status == BookingStatus.cancelled
          ? Icons.cancel_outlined
          : status == BookingStatus.confirmed
          ? Icons.check_circle_outline
          : Icons.done_all,
    );

    if (confirmed == true) {
      ref
          .read(bookingProvider.notifier)
          .updateBookingStatus(booking.id, status);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Booking ${status.name} successfully!'),
            backgroundColor: themeColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}
