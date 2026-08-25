import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/services/booking_repository.dart';
import '../../shared/services/service_repository.dart';
import '../../shared/models/booking_model.dart';
import 'chat_screen.dart';
import 'booking/booking_detail_screen.dart';
import '../../shared/models/review_model.dart';
import '../../core/providers/localization_provider.dart';
import '../../shared/services/review_repository.dart';
import '../../shared/services/auth_service.dart';
import '../../shared/services/receipt_pdf_service.dart';
import 'package:uuid/uuid.dart';

class TravelerBookingsScreen extends ConsumerWidget {
  const TravelerBookingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allBookings = ref.watch(filteredBookingsProvider);
    final loc = ref.watch(localizationProvider);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(
            loc.translate('my_bookings'),
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.white,
          foregroundColor: AppColors.dark,
          elevation: 0,
          bottom: TabBar(
            labelColor: AppColors.primary,
            unselectedLabelColor: Colors.grey,
            indicatorColor: AppColors.primary,
            indicatorWeight: 3,
            labelStyle: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
            tabs: [
              Tab(text: loc.translate('upcoming')),
              Tab(text: loc.translate('completed')),
              Tab(text: loc.translate('canceled')),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _BookingList(
              bookings: allBookings
                  .where(
                    (b) =>
                        b.status == BookingStatus.confirmed ||
                        b.status == BookingStatus.pending,
                  )
                  .toList(),
              emptyMessage: loc.translate('no_upcoming_trips'),
            ),
            _BookingList(
              bookings: allBookings
                  .where((b) => b.status == BookingStatus.completed)
                  .toList(),
              emptyMessage: loc.translate('no_completed_trips'),
            ),
            _BookingList(
              bookings: allBookings
                  .where((b) => b.status == BookingStatus.cancelled)
                  .toList(),
              emptyMessage: loc.translate('no_canceled_bookings'),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookingList extends ConsumerWidget {
  final List<Booking> bookings;
  final String emptyMessage;

  const _BookingList({required this.bookings, required this.emptyMessage});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listContent = bookings.isEmpty
        ? Center(
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.book_online_outlined,
                    size: 64,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    emptyMessage,
                    style: GoogleFonts.poppins(
                      color: Colors.grey,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          )
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: bookings.length,
            itemBuilder: (context, index) {
              final booking = bookings[index];
              return _BookingCard(booking: booking);
            },
          );

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(bookingProvider.notifier).fetchBookings();
      },
      color: AppColors.primary,
      child: listContent,
    );
  }
}

class _BookingCard extends ConsumerWidget {
  final Booking booking;

  const _BookingCard({required this.booking});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final services = ref.watch(serviceProvider);
    final loc = ref.watch(localizationProvider);
    final service = services
        .where((s) => s.id == booking.serviceId)
        .firstOrNull;
    final imageUrl = service?.images.isNotEmpty == true
        ? service!.images.first
        : 'https://picsum.photos/seed/hotel/200/200';
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            // Status Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: booking.statusColor.withValues(alpha: 0.1),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: booking.statusColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    loc.translate(booking.status.name.toLowerCase()),
                    style: GoogleFonts.poppins(
                      color: booking.statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  Flexible(
                    child: Text(
                      "${loc.translate('ref')}: #${booking.id.toUpperCase()}",
                      style: GoogleFonts.poppins(
                        color: Colors.grey[500],
                        fontSize: 10,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Thumbnail Placeholder or Image
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                          image: DecorationImage(
                            image: NetworkImage(imageUrl),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              booking.serviceTitle,
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: AppColors.dark,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            _buildInfoMiniRow(
                              Icons.calendar_today_outlined,
                              "${booking.checkIn.day}/${booking.checkIn.month} - ${booking.checkOut.day}/${booking.checkOut.month}/${booking.checkOut.year}",
                            ),
                            const SizedBox(height: 4),
                            _buildInfoMiniRow(
                              Icons.people_alt_outlined,
                              "${booking.guests} ${booking.guests == 1 ? loc.translate('guest') : loc.translate('guests')}",
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const Divider(height: 24),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            loc.translate('total_price'),
                            style: GoogleFonts.poppins(
                              color: Colors.grey[500],
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            '\$${booking.totalPrice.toStringAsFixed(2)}',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          // Icon-based Actions for space efficiency
                          Tooltip(
                            message: loc.translate('view_details'),
                            child: IconButton(
                              icon: const Icon(Icons.visibility_outlined),
                              color: AppColors.primary,
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        BookingDetailScreen(booking: booking),
                                  ),
                                );
                              },
                            ),
                          ),
                          Tooltip(
                            message: 'Download Receipt',
                            child: IconButton(
                              icon: const Icon(Icons.picture_as_pdf_outlined),
                              color: Colors.grey[700],
                              onPressed: () =>
                                  ReceiptPdfService.generateAndShare(booking),
                            ),
                          ),
                          if (booking.status == BookingStatus.confirmed ||
                              booking.status == BookingStatus.pending) ...[
                            Tooltip(
                              message: loc.translate('cancel_booking'),
                              child: OutlinedButton(
                                onPressed: () =>
                                    _showCancelDialog(context, ref),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  side: const BorderSide(
                                    color: Colors.red,
                                    width: 1.2,
                                  ),
                                  shape: const CircleBorder(),
                                  padding: const EdgeInsets.all(8),
                                  minimumSize: Size.zero,
                                ),
                                child: const Icon(Icons.close, size: 20),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Tooltip(
                              message: loc.translate('chat_provider'),
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ChatScreen(
                                        bookingId: booking.id,
                                        chatTitle: 'Provider',
                                      ),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.all(10),
                                  minimumSize: Size.zero,
                                ),
                                child: const Icon(
                                  Icons.chat_bubble_outline,
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                          if (booking.status == BookingStatus.completed)
                            OutlinedButton.icon(
                              onPressed: () => _showReviewDialog(context, ref),
                              icon: const Icon(Icons.star_outline, size: 18),
                              label: Text(loc.translate('review')),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.secondary,
                                side: const BorderSide(
                                  color: AppColors.secondary,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCancelDialog(BuildContext context, WidgetRef ref) {
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final loc = ref.read(localizationProvider);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          loc.translate('cancel_booking'),
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.red,
          ),
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${loc.translate('cancel_confirm_message')} ${booking.serviceTitle}.',
                style:
                    GoogleFonts.poppins(fontSize: 13, color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: reasonController,
                maxLines: 3,
                style: GoogleFonts.poppins(fontSize: 14),
                decoration: InputDecoration(
                  hintText: loc.translate('cancel_reason_hint'),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.red),
                  ),
                ),
                validator: (v) => v == null || v.trim().isEmpty
                    ? loc.translate('provide_reason')
                    : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              loc.translate('keep_booking'),
              style: GoogleFonts.poppins(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState?.validate() ?? false) {
                final updatedBooking = booking.copyWith(
                  status: BookingStatus.cancelled,
                  metadata: {
                    ...booking.metadata,
                    'cancel_reason': reasonController.text.trim(),
                    'cancelled_by': 'traveler',
                    'cancelled_at': DateTime.now().toIso8601String(),
                  },
                );

                await ref
                    .read(bookingProvider.notifier)
                    .updateBooking(updatedBooking);

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(loc.translate('cancel_success')),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              loc.translate('confirm_cancel'),
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showReviewDialog(BuildContext context, WidgetRef ref) {
    int localRating = 5;
    final commentController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Review your stay',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'How was your experience at ${booking.serviceTitle}?',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return IconButton(
                    icon: Icon(
                      index < localRating ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 32,
                    ),
                    onPressed: () => setState(() => localRating = index + 1),
                  );
                }),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: commentController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Write your comment here...',
                  hintStyle: GoogleFonts.poppins(fontSize: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primary),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final user = ref.read(authProvider);
                if (user == null) return;

                final review = Review(
                  id: const Uuid().v4(),
                  serviceId: booking.serviceId,
                  providerId: booking.providerId,
                  serviceTitle: booking.serviceTitle,
                  travelerId: user.id,
                  travelerName: user.name,
                  rating: localRating,
                  comment: commentController.text,
                  createdAt: DateTime.now(),
                );

                await ref.read(reviewProvider.notifier).addReview(review);

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Thank you for your review!'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Submit',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoMiniRow(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.primary.withValues(alpha: 0.6)),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 12),
        ),
      ],
    );
  }
}
