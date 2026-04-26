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
import '../../shared/models/service_model.dart';

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
        title = 'Apartment Bookings';
        break;
      case ProviderType.apartment:
        title = 'Apartment Bookings';
        break;
      case ProviderType.all:
        title = 'All Service Bookings';
        break;
      case ProviderType.tour:
        title = 'Tour Bookings';
        break;
    }

    // Sort logic
    final sortedBookings = [...bookings];
    sortedBookings.sort((a, b) {
      // Pending first
      if (a.status == BookingStatus.pending &&
          b.status != BookingStatus.pending) {
        return -1;
      }
      if (a.status != BookingStatus.pending &&
          b.status == BookingStatus.pending) {
        return 1;
      }
      // Then date
      return a.date.compareTo(b.date);
    });

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Column(
        children: [
          _buildSummary(ref, providerType),
          Expanded(
            child: sortedBookings.isEmpty
                ? const Center(child: Text('No bookings yet'))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: sortedBookings.length,
                    itemBuilder: (context, index) =>
                        _BookingCard(booking: sortedBookings[index], ref: ref),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary(WidgetRef ref, ProviderType type) {
    if (type == ProviderType.tour) return const SizedBox.shrink();

    final services = ref.watch(filteredServicesProvider);
    int totalUnits = 0;
    int bookedUnits = 0;

    for (final s in services) {
      final category = s.category.toLowerCase();
      if (category.contains('hotel')) {
        totalUnits += (s.metadata['rooms'] as num?)?.toInt() ?? 1;
        bookedUnits += (s.metadata['bookedRooms'] as num?)?.toInt() ?? 0;
      } else if (category.contains('apartment') || category.contains('home')) {
        totalUnits += 1;
        if (s.status == ServiceStatus.inactive) {
          bookedUnits += 1;
        }
      }
    }

    if (totalUnits == 0) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primary.withAlpha(200)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withAlpha(76),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      type == ProviderType.hotel
                          ? 'Room Capacity'
                          : 'Availability',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$bookedUnits units booked / $totalUnits total',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(50),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  type == ProviderType.hotel ? Icons.hotel : Icons.apartment,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: totalUnits > 0 ? bookedUnits / totalUnits : 0,
              backgroundColor: Colors.white.withAlpha(50),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${totalUnits - bookedUnits} units left',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (bookedUnits > 0)
                const Text(
                  'Updated automatically',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 10,
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
          OutlinedButton.icon(
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
            icon: const Icon(Icons.chat_bubble_outline, size: 18),
            label: const Text('Chat'),
          ),
          ElevatedButton(
            onPressed: () => _updateStatus(context, BookingStatus.completed),
            child: const Text('Mark Completed'),
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
              _buildInfoRow(
                'Tax',
                '\$${booking.taxes.toStringAsFixed(2)}',
              ),
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
        crossAxisAlignment:
            isLong ? CrossAxisAlignment.start : CrossAxisAlignment.center,
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
        actionNoun = 'Reject';
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
