import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/responsive.dart';
import '../../shared/services/booking_repository.dart';
import '../../shared/models/booking_model.dart';
import '../../shared/services/auth_service.dart';
import '../../shared/widgets/confirmation_dialog.dart';
import '../../shared/services/service_repository.dart';
import '../../shared/models/user_model.dart';
import '../../shared/services/receipt_pdf_service.dart';
import 'provider_chat_screen.dart';

final bookingTabFilterProvider = StateProvider<String>((ref) => 'pending');

class ProviderBookingsScreen extends ConsumerWidget {
  const ProviderBookingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookings = ref.watch(filteredBookingsProvider);
    final user = ref.watch(authProvider);
    final activeTab = ref.watch(bookingTabFilterProvider);
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
    }

    final pendingList =
        bookings.where((b) => b.status == BookingStatus.pending).toList();
    final confirmedList =
        bookings.where((b) => b.status == BookingStatus.confirmed).toList();
    final completedList =
        bookings.where((b) => b.status == BookingStatus.completed).toList();

    List<Booking> displayedBookings;
    if (activeTab == 'confirmed') {
      displayedBookings = confirmedList;
    } else if (activeTab == 'completed') {
      displayedBookings = completedList;
    } else if (activeTab == 'all') {
      displayedBookings = [...bookings];
    } else {
      displayedBookings = pendingList;
    }

    displayedBookings.sort((a, b) => b.date.compareTo(a.date));

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ── Full-Width Gradient Header Banner ────────────────
            _buildHeader(
              context,
              ref,
              title,
              activeTab,
              pendingList.length,
              confirmedList.length,
              completedList.length,
              bookings.length,
            ),

            const SizedBox(height: 20),

            // ── Live Room Occupancy Summary Card ─────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildOccupancySummary(ref, providerType),
            ),

            const SizedBox(height: 20),

            // ── Booking List Cards ───────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: displayedBookings.isEmpty
                  ? _buildEmptyState(activeTab)
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: displayedBookings.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 16),
                      itemBuilder: (context, index) => _BookingCard(
                        booking: displayedBookings[index],
                        ref: ref,
                      ),
                    ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    WidgetRef ref,
    String title,
    String activeTab,
    int pendingCount,
    int confirmedCount,
    int completedCount,
    int totalCount,
  ) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E3A8A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(context.isMobile ? 0 : 32),
          bottomRight: Radius.circular(context.isMobile ? 0 : 32),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, 20, 24, context.isMobile ? 24 : 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(25),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.assignment_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const Text(
                        'Manage stay requests, guest check-ins & status',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Tab Pill Selector Bar
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildTabPill(
                      ref,
                      'Pending',
                      'pending',
                      pendingCount,
                      activeTab,
                    ),
                    const SizedBox(width: 8),
                    _buildTabPill(
                      ref,
                      'Confirmed',
                      'confirmed',
                      confirmedCount,
                      activeTab,
                    ),
                    const SizedBox(width: 8),
                    _buildTabPill(
                      ref,
                      'Completed',
                      'completed',
                      completedCount,
                      activeTab,
                    ),
                    const SizedBox(width: 8),
                    _buildTabPill(
                      ref,
                      'All Bookings',
                      'all',
                      totalCount,
                      activeTab,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabPill(
    WidgetRef ref,
    String label,
    String key,
    int count,
    String activeTab,
  ) {
    final isSelected = activeTab == key;
    return GestureDetector(
      onTap: () {
        ref.read(bookingTabFilterProvider.notifier).state = key;
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.secondary : Colors.white.withAlpha(20),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppColors.secondary
                : Colors.white.withAlpha(40),
          ),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 13,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withAlpha(50)
                      : Colors.white.withAlpha(30),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOccupancySummary(WidgetRef ref, ProviderType type) {
    if (type == ProviderType.tour) return const SizedBox.shrink();

    final services = ref.watch(filteredServicesProvider);
    final bookings = ref.watch(filteredBookingsProvider);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    int totalUnits = 0;
    int bookedUnits = 0;

    for (final s in services) {
      final category = s.category.toLowerCase();

      if (category.contains('hotel')) {
        totalUnits += (s.metadata['rooms'] as num?)?.toInt() ?? 1;

        final activeStaysRooms = bookings
            .where((b) {
              if (b.serviceId != s.id) return false;
              if (b.status != BookingStatus.confirmed) return false;

              final startsOnOrBeforeToday = !b.checkIn.isAfter(today);
              final endsAfterToday = b.checkOut.isAfter(today);

              return startsOnOrBeforeToday && endsAfterToday;
            })
            .fold<int>(0, (sum, b) => sum + b.rooms);

        bookedUnits += activeStaysRooms;
      } else if (category.contains('apartment') || category.contains('home')) {
        totalUnits += 1;

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

    final availableUnits = totalUnits - bookedUnits;

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
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(20),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      type == ProviderType.hotel
                          ? Icons.bedtime_rounded
                          : Icons.apartment_rounded,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        type == ProviderType.hotel
                            ? 'Room Occupancy Rate'
                            : 'Property Capacity Status',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        '$bookedUnits occupied / $totalUnits total capacity',
                        style:
                            TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withAlpha(20),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF10B981)),
                ),
                child: Text(
                  '$availableUnits active units left',
                  style: const TextStyle(
                    color: Color(0xFF10B981),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: totalUnits > 0
                  ? (bookedUnits / totalUnits).clamp(0.0, 1.0)
                  : 0.0,
              minHeight: 8,
              backgroundColor: const Color(0xFFF1F5F9),
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String activeTab) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
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
        children: [
          Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No $activeTab bookings found',
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'New customer bookings in this status category will show up here automatically.',
            style: TextStyle(color: Colors.grey[500], fontSize: 13),
            textAlign: TextAlign.center,
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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
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
          // Header: Status & TRX ID
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: booking.statusColor.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: booking.statusColor),
                ),
                child: Text(
                  booking.statusLabel,
                  style: TextStyle(
                    color: booking.statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
              Text(
                'TRX-${booking.id.substring(0, 4).toUpperCase()} · ${DateFormat('MMM d, yyyy').format(booking.date)}',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Customer Info Row
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.primary.withAlpha(20),
                child: Text(
                  booking.travelerName.isNotEmpty
                      ? booking.travelerName[0].toUpperCase()
                      : 'G',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      booking.serviceTitle,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFF0F172A),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Customer: ${booking.travelerName}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Text(
                '\$${booking.totalPrice.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(height: 1, color: Color(0xFFF1F5F9)),
          ),

          // Stay Details Grid
          Row(
            children: [
              Expanded(
                child: _buildDetailRow(
                  Icons.calendar_month_rounded,
                  'Stay Dates',
                  '${DateFormat('MMM d').format(booking.checkIn)} - ${DateFormat('MMM d').format(booking.checkOut)}',
                ),
              ),
              Expanded(
                child: _buildDetailRow(
                  Icons.group_rounded,
                  'Occupants',
                  '${booking.guests} Guest(s), ${booking.rooms} Room(s)',
                ),
              ),
            ],
          ),

          if (booking.contactPhone.isNotEmpty ||
              booking.contactEmail.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                if (booking.contactPhone.isNotEmpty) ...[
                  Icon(Icons.phone_rounded, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(
                    booking.contactPhone,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(width: 14),
                ],
                if (booking.contactEmail.isNotEmpty) ...[
                  Icon(Icons.email_rounded, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      booking.contactEmail,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ],

          if (booking.specialRequests != null &&
              booking.specialRequests!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Text(
                'Note: ${booking.specialRequests}',
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey[700],
                ),
              ),
            ),
          ],

          // 🛡️ Traveler Identity Verification & Document Photo (Provider View)
          if ((booking.metadata['verificationId'] as String?)?.isNotEmpty == true ||
              (booking.metadata['alternativePhone'] as String?)?.isNotEmpty == true ||
              (booking.metadata['guestIdDocumentUrl'] as String?)?.isNotEmpty == true ||
              (booking.metadata['paymentIdDocumentUrl'] as String?)?.isNotEmpty == true ||
              (booking.metadata['idDocumentUrl'] as String?)?.isNotEmpty == true) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withAlpha(12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF10B981).withAlpha(60)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.verified_user_rounded,
                        size: 16,
                        color: Color(0xFF10B981),
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Traveler Verification & ID Document',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (booking.metadata['verificationId'] != null &&
                      (booking.metadata['verificationId'] as String).isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.badge_outlined,
                            size: 14,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'ID / Passport #: ',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          Text(
                            booking.metadata['verificationId'].toString(),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (booking.metadata['alternativePhone'] != null &&
                      (booking.metadata['alternativePhone'] as String).isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.phone_android_outlined,
                            size: 14,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Alt Contact Phone: ',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          Text(
                            booking.metadata['alternativePhone'].toString(),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Builder(
                    builder: (context) {
                      final guestDocUrl = (booking.metadata['guestIdDocumentUrl'] ??
                          (booking.metadata['paymentIdDocumentUrl'] == null ? booking.metadata['idDocumentUrl'] : null)) as String?;
                      final guestDocFileName = (booking.metadata['guestIdDocumentFileName'] ?? booking.metadata['idDocumentFileName']) as String?;
                      final paymentDocUrl = (booking.metadata['paymentIdDocumentUrl'] ?? booking.metadata['verificationIdDocumentUrl']) as String?;
                      final paymentDocFileName = (booking.metadata['paymentIdDocumentFileName'] ?? booking.metadata['idDocumentFileName']) as String?;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (guestDocUrl != null && guestDocUrl.isNotEmpty)
                            _buildDocumentTile(
                              context,
                              url: guestDocUrl,
                              label: 'Guest Info Photo',
                              fileName: guestDocFileName,
                            ),
                          if (paymentDocUrl != null && paymentDocUrl.isNotEmpty && paymentDocUrl != guestDocUrl)
                            _buildDocumentTile(
                              context,
                              url: paymentDocUrl,
                              label: 'Payment Verification Photo',
                              fileName: paymentDocFileName,
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Action Buttons Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
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
                    icon: const Icon(Icons.chat_bubble_outline_rounded,
                        size: 15),
                    label: const Text('Chat'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () =>
                        ReceiptPdfService.generateAndShare(booking),
                    icon: const Icon(Icons.picture_as_pdf_rounded, size: 15),
                    label: const Text('Receipt'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey[700],
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () =>
                        _showFullBookingDetailsModal(context, booking),
                    icon: const Icon(Icons.visibility_outlined, size: 15),
                    label: const Text('View Details'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  if (booking.status == BookingStatus.pending) ...[
                    ElevatedButton.icon(
                      onPressed: () => _updateBookingStatus(
                        context,
                        ref,
                        booking,
                        BookingStatus.confirmed,
                        'Confirm Booking',
                      ),
                      icon: const Icon(Icons.check_rounded, size: 16),
                      label: const Text('Confirm'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () => _updateBookingStatus(
                        context,
                        ref,
                        booking,
                        BookingStatus.cancelled,
                        'Reject Booking',
                      ),
                      icon: const Icon(Icons.close_rounded, size: 16),
                      label: const Text('Reject'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                  if (booking.status == BookingStatus.confirmed) ...[
                    ElevatedButton.icon(
                      onPressed: () => _updateBookingStatus(
                        context,
                        ref,
                        booking,
                        BookingStatus.completed,
                        'Mark Stay Completed',
                      ),
                      icon: const Icon(Icons.task_alt_rounded, size: 16),
                      label: const Text('Complete Stay'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[500]),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 10, color: Colors.grey[500]),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _updateBookingStatus(
    BuildContext context,
    WidgetRef ref,
    Booking booking,
    BookingStatus status,
    String actionLabel,
  ) async {
    final confirmed = await ConfirmationDialog.show(
      context: context,
      title: '$actionLabel?',
      message:
          'Confirm Action: Are you sure you want to change this booking status to ${status.name}?',
      confirmLabel: actionLabel,
      type: status == BookingStatus.cancelled
          ? ConfirmationDialogType.danger
          : ConfirmationDialogType.info,
      icon: status == BookingStatus.confirmed
          ? Icons.check_circle_outline
          : Icons.info_outline,
    );

    if (confirmed == true) {
      await ref
          .read(bookingProvider.notifier)
          .updateBookingStatus(booking.id, status);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Booking ${status.name} successfully!'),
            backgroundColor: status == BookingStatus.cancelled
                ? Colors.red
                : const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  void _showDocumentPhotoDialog(
      BuildContext context, String imageUrl, String title) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Color(0xFF0F172A),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Container(
              constraints: const BoxConstraints(maxHeight: 550),
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: _buildDocumentImageWidget(
                  imageUrl,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  static Widget _buildDocumentImageWidget(String imageUrl,
      {double? width, double? height, BoxFit fit = BoxFit.cover}) {
    if (imageUrl.startsWith('http://') ||
        imageUrl.startsWith('https://') ||
        imageUrl.startsWith('blob:')) {
      return Image.network(
        imageUrl,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, __, ___) => Container(
          width: width,
          height: height,
          color: Colors.grey[200],
          child: const Icon(Icons.insert_drive_file, color: Colors.grey),
        ),
      );
    } else if (!kIsWeb && File(imageUrl).existsSync()) {
      return Image.file(
        File(imageUrl),
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, __, ___) => Container(
          width: width,
          height: height,
          color: Colors.grey[200],
          child: const Icon(Icons.insert_drive_file, color: Colors.grey),
        ),
      );
    } else {
      return Image.network(
        imageUrl,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, __, ___) => Container(
          width: width,
          height: height,
          color: Colors.grey[200],
          child: const Icon(Icons.insert_drive_file, color: Colors.grey),
        ),
      );
    }
  }

  void _showFullBookingDetailsModal(BuildContext context, Booking booking) {
    final nights = booking.checkOut.difference(booking.checkIn).inDays;
    final formattedCheckIn =
        DateFormat('EEE, MMM d, yyyy').format(booking.checkIn);
    final formattedCheckOut =
        DateFormat('EEE, MMM d, yyyy').format(booking.checkOut);
    final formattedDate =
        DateFormat('MMM d, yyyy · h:mm a').format(booking.date);

    final verificationId = booking.metadata['verificationId'] as String?;
    final altPhone = booking.metadata['alternativePhone'] as String?;
    final guestDocUrl = (booking.metadata['guestIdDocumentUrl'] ??
        (booking.metadata['paymentIdDocumentUrl'] == null ? booking.metadata['idDocumentUrl'] : null)) as String?;
    final guestDocFileName = (booking.metadata['guestIdDocumentFileName'] ?? booking.metadata['idDocumentFileName']) as String?;
    final paymentDocUrl = (booking.metadata['paymentIdDocumentUrl'] ?? booking.metadata['verificationIdDocumentUrl']) as String?;
    final paymentDocFileName = (booking.metadata['paymentIdDocumentFileName'] ?? booking.metadata['idDocumentFileName']) as String?;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Banner
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            booking.serviceTitle,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'TRX-${booking.id.substring(0, 8).toUpperCase()} · Created $formattedDate',
                            style:
                                TextStyle(fontSize: 11, color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: booking.statusColor.withAlpha(20),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: booking.statusColor),
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
                  ],
                ),

                const Divider(height: 24),

                // 👤 Customer & Contact Information
                _buildModalSectionHeader(
                    Icons.person_outline_rounded, 'Customer Information'),
                const SizedBox(height: 10),
                _buildModalDetailRow(
                    'Full Name:',
                    booking.travelerName.isNotEmpty
                        ? booking.travelerName
                        : 'Guest Traveler'),
                if (booking.contactPhone.isNotEmpty)
                  _buildModalDetailRow('Primary Phone:', booking.contactPhone,
                      isSelectable: true),
                if (altPhone != null && altPhone.isNotEmpty)
                  _buildModalDetailRow('Alt Contact Phone:', altPhone,
                      isSelectable: true),
                if (booking.contactEmail.isNotEmpty)
                  _buildModalDetailRow('Email Address:', booking.contactEmail,
                      isSelectable: true),

                const SizedBox(height: 16),

                // 📅 Stay Details & Occupancy
                _buildModalSectionHeader(
                    Icons.calendar_month_outlined, 'Stay & Occupancy Details'),
                const SizedBox(height: 10),
                _buildModalDetailRow('Check-in Date:', formattedCheckIn),
                _buildModalDetailRow('Check-out Date:', formattedCheckOut),
                _buildModalDetailRow(
                    'Duration of Stay:', '${nights > 0 ? nights : 1} night(s)'),
                _buildModalDetailRow('Occupants:',
                    '${booking.guests} Guest(s) · ${booking.rooms} Room(s) / Unit(s)'),

                // 🛡️ Traveler Identity Verification & Document Photo
                if ((verificationId != null && verificationId.isNotEmpty) ||
                    (guestDocUrl != null && guestDocUrl.isNotEmpty) ||
                    (paymentDocUrl != null && paymentDocUrl.isNotEmpty)) ...[
                  const SizedBox(height: 16),
                  _buildModalSectionHeader(Icons.verified_user_outlined,
                      'Identity Verification & Documents'),
                  const SizedBox(height: 10),
                  if (verificationId != null && verificationId.isNotEmpty)
                    _buildModalDetailRow('ID / Passport #:', verificationId,
                        isHighlight: true),
                  if (guestDocUrl != null && guestDocUrl.isNotEmpty)
                    _buildDocumentTile(
                      context,
                      url: guestDocUrl,
                      label: 'Guest Info Photo',
                      fileName: guestDocFileName,
                    ),
                  if (paymentDocUrl != null && paymentDocUrl.isNotEmpty && paymentDocUrl != guestDocUrl)
                    _buildDocumentTile(
                      context,
                      url: paymentDocUrl,
                      label: 'Payment Verification Photo',
                      fileName: paymentDocFileName,
                    ),
                ],

                const SizedBox(height: 16),

                // 💵 Financial Breakdown & Payment Status
                _buildModalSectionHeader(
                    Icons.payments_outlined, 'Financial & Payment Info'),
                const SizedBox(height: 10),
                _buildModalDetailRow('Total Booking Price:',
                    '\$${booking.totalPrice.toStringAsFixed(2)}',
                    isHighlight: true),
                _buildModalDetailRow('Payment Method:',
                    booking.paymentMethod ?? 'Pay at Arrival'),
                _buildModalDetailRow('Payment Status:',
                    booking.paymentStatus.name.toUpperCase()),
                if (booking.transactionId != null &&
                    booking.transactionId!.isNotEmpty)
                  _buildModalDetailRow(
                      'Transaction Ref:', booking.transactionId!),

                if (booking.specialRequests != null &&
                    booking.specialRequests!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildModalSectionHeader(
                      Icons.sticky_note_2_outlined, 'Special Requests / Notes'),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Text(
                      booking.specialRequests!,
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey[800], height: 1.4),
                    ),
                  ),
                ],

                const SizedBox(height: 20),

                // Action Bar inside Modal
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          ReceiptPdfService.generateAndShare(booking);
                        },
                        icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                        label: const Text('Receipt PDF'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey[800],
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
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
                        icon: const Icon(Icons.chat_bubble_outline_rounded,
                            size: 16),
                        label: const Text('Chat'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDocumentTile(
    BuildContext context, {
    required String url,
    required String label,
    String? fileName,
  }) {
    return GestureDetector(
      onTap: () => _showDocumentPhotoDialog(
        context,
        url,
        fileName ?? label,
      ),
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.primary.withAlpha(80)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: _buildDocumentImageWidget(
                url,
                width: 52,
                height: 52,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    fileName ?? 'Tap to view full resolution photo 🔍',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.open_in_full_rounded,
              size: 16,
              color: AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModalSectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  Widget _buildModalDetailRow(String label, String value,
      {bool isHighlight = false, bool isSelectable = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: isSelectable
                ? SelectableText(
                    value,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          isHighlight ? FontWeight.bold : FontWeight.w600,
                      color: isHighlight
                          ? AppColors.primary
                          : const Color(0xFF0F172A),
                    ),
                    textAlign: TextAlign.end,
                  )
                : Text(
                    value,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          isHighlight ? FontWeight.bold : FontWeight.w600,
                      color: isHighlight
                          ? AppColors.primary
                          : const Color(0xFF0F172A),
                    ),
                    textAlign: TextAlign.end,
                    overflow: TextOverflow.ellipsis,
                  ),
          ),
        ],
      ),
    );
  }
}
