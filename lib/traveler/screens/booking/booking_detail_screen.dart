import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../shared/services/receipt_pdf_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/booking_model.dart';
import '../../../shared/models/user_model.dart';

import '../../../shared/services/user_repository.dart';

class BookingDetailScreen extends ConsumerWidget {
  final Booking booking;

  const BookingDetailScreen({super.key, required this.booking});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Fetch provider to get public email
    final users = ref.watch(userProvider);
    final provider = users.cast<User?>().firstWhere(
      (u) => u?.id == booking.providerId,
      orElse: () => null,
    );
    final publicEmail = provider?.publicEmail;
    final metadata = booking.metadata;
    final type =
        metadata['serviceType']?.toString().toLowerCase() ??
        _inferServiceType(booking);

    final isTour = type == 'tour';
    final isVehicle = type == 'vehicle';
    final isHotel = type == 'hotel';
    final isApartment = type == 'apartment';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Booking Receipt',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.dark,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Service Information
            _buildSectionTitle('Service Information'),
            _buildInfoRow('Service', booking.serviceTitle),
            _buildInfoRow(
              'Status',
              booking.statusLabel,
              color: booking.statusColor,
              isBold: true,
            ),
            _buildInfoRow(
              'Booking Date',
              DateFormat('MMM dd, yyyy HH:mm').format(booking.date),
            ),
            _buildInfoRow('Reference', '#${booking.id.toUpperCase()}'),

            const Divider(height: 32),

            // Traveler Details
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

            // Booking Details
            _buildSectionTitle('Booking Details'),
            if (isTour) ...[
              _buildInfoRow(
                booking.checkIn == booking.checkOut
                    ? 'Tour Date'
                    : 'Start Date',
                DateFormat('MMM dd, yyyy').format(booking.checkIn),
              ),
              if (booking.checkIn != booking.checkOut)
                _buildInfoRow(
                  'End Date',
                  DateFormat('MMM dd, yyyy').format(booking.checkOut),
                ),
            ] else if (isVehicle) ...[
              _buildInfoRow(
                'Pickup',
                DateFormat('MMM dd, yyyy HH:mm').format(booking.checkIn),
              ),
              _buildInfoRow(
                'Return',
                DateFormat('MMM dd, yyyy HH:mm').format(booking.checkOut),
              ),
              if (metadata['pickupLocation'] != null)
                _buildInfoRow('Pickup Loc', metadata['pickupLocation']),
              if (metadata['dropoffLocation'] != null)
                _buildInfoRow('Drop-off Loc', metadata['dropoffLocation']),
            ] else ...[
              _buildInfoRow(
                'Check-in',
                DateFormat('MMM dd, yyyy').format(booking.checkIn),
              ),
              _buildInfoRow(
                'Check-out',
                DateFormat('MMM dd, yyyy').format(booking.checkOut),
              ),
            ],

            _buildInfoRow(
              isVehicle ? 'Rental Type' : 'Guests',
              isVehicle
                  ? (metadata['driverOption']?.toString() ?? 'Self Drive')
                  : _buildTravelerBreakdown(booking),
            ),

            if ((isHotel || isApartment) && booking.rooms > 0)
              _buildInfoRow('Rooms/Units', '${booking.rooms} Rooms'),

            if (booking.specialRequests != null &&
                booking.specialRequests!.isNotEmpty)
              _buildInfoRow(
                'Special Requests',
                booking.specialRequests!,
                isLong: true,
              ),

            const Divider(height: 32),

            // Provider Contact (Visible only if booking is made)
            if (publicEmail != null && publicEmail.isNotEmpty) ...[
              _buildSectionTitle('Provider Contact'),
              _buildInfoRow(
                'Business Email',
                publicEmail,
                color: const Color(0xFFF43F5E),
                isBold: true,
              ),
              const Divider(height: 32),
            ],

            // Payment Information
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
              (booking.paymentMethod == 'payLater' ||
                      booking.paymentMethod == 'PaymentMethod.payLater')
                  ? 'PAY AT ARRIVAL'
                  : booking.paymentStatus.name.toUpperCase(),
              color:
                  (booking.paymentMethod == 'payLater' ||
                      booking.paymentMethod == 'PaymentMethod.payLater')
                  ? Colors.orange
                  : AppColors.success,
              isBold: true,
            ),

            if (booking.status == BookingStatus.confirmed) ...[
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => ReceiptPdfService.generateAndShare(booking),
                  icon: const Icon(Icons.download_rounded),
                  label: Text(
                    'Download Receipt',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 48),

            // Footer
            Center(
              child: Text(
                'Thank you for booking with SomSafar!',
                style: GoogleFonts.poppins(
                  color: Colors.grey[400],
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 15,
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
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: isLong
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[500]),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
                color: color ?? AppColors.dark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatPaymentMethod(String method) {
    final m = method.toLowerCase();
    if (m.contains('card')) return '💳 Credit/Debit Card';
    if (m.contains('mobile')) return '📱 Mobile Money';
    if (m.contains('bank')) return '🏦 Bank Transfer';
    if (m.contains('paylater')) return '🕒 Pay Later';
    return method.replaceAll('PaymentMethod.', '').toUpperCase();
  }

  String _buildTravelerBreakdown(Booking booking) {
    final adults =
        booking.metadata['adultsCount'] ?? booking.metadata['adult_travelers'];
    final children =
        booking.metadata['childrenCount'] ??
        booking.metadata['child_travelers'];
    final infants =
        booking.metadata['infantsCount'] ??
        booking.metadata['infant_travelers'];

    if (adults == null && children == null && infants == null) {
      return '${booking.guests} Persons';
    }

    final parts = <String>[];
    if (adults != null && adults > 0) {
      parts.add('$adults Adult${adults > 1 ? 's' : ''}');
    }
    if (children != null && children > 0) {
      parts.add('$children Child${children > 1 ? 'ren' : ''}');
    }
    if (infants != null && infants > 0) {
      parts.add('$infants Infant${infants > 1 ? 's' : ''}');
    }

    return parts.isEmpty ? '${booking.guests} Persons' : parts.join(', ');
  }

  String _inferServiceType(Booking booking) {
    if (booking.metadata.containsKey('package_type')) return 'tour';
    if (booking.metadata.containsKey('pickupLocation')) return 'vehicle';
    if (booking.metadata.containsKey('bedType')) return 'hotel';
    if (booking.metadata.containsKey('stayPurpose')) return 'apartment';

    final title = booking.serviceTitle.toLowerCase();
    if (title.contains('tour') || title.contains('tourism')) return 'tour';
    if (title.contains('car') ||
        title.contains('vehicle') ||
        title.contains('rent')) {
      return 'vehicle';
    }
    if (title.contains('apartment') || title.contains('home')) {
      return 'apartment';
    }
    if (title.contains('hotel') || title.contains('resort')) {
      return 'hotel';
    }

    return 'hotel'; // Default
  }
}
