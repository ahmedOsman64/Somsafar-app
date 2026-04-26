import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../shared/models/booking_model.dart';
import '../../shared/services/booking_repository.dart';
import '../../core/theme/app_colors.dart';

class AdminBookingsScreen extends ConsumerStatefulWidget {
  const AdminBookingsScreen({super.key});

  @override
  ConsumerState<AdminBookingsScreen> createState() =>
      _AdminBookingsScreenState();
}

class _AdminBookingsScreenState extends ConsumerState<AdminBookingsScreen> {
  String _searchQuery = '';
  BookingStatus? _filterStatus;

  @override
  Widget build(BuildContext context) {
    final bookings = ref.watch(bookingProvider);

    final filteredBookings = bookings.where((b) {
      final matchesSearch =
          b.serviceTitle.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          b.travelerName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          b.id.contains(_searchQuery);
      final matchesStatus = _filterStatus == null || b.status == _filterStatus;
      return matchesSearch && matchesStatus;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('All Bookings'),
        backgroundColor: AppColors.dark,
      ),
      body: Column(
        children: [
          _buildFilters(),
          Expanded(
            child: filteredBookings.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredBookings.length,
                    itemBuilder: (context, index) {
                      final booking = filteredBookings[index];
                      return _buildBookingCard(booking);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        children: [
          TextField(
            decoration: InputDecoration(
              hintText: 'Search by service, traveler or ID...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey[50],
            ),
            onChanged: (val) => setState(() => _searchQuery = val),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  label: const Text('All'),
                  selected: _filterStatus == null,
                  onSelected: (_) => setState(() => _filterStatus = null),
                ),
                const SizedBox(width: 8),
                ...BookingStatus.values.map((status) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: FilterChip(
                      label: Text(status.name.toUpperCase()),
                      selected: _filterStatus == status,
                      onSelected: (selected) {
                        setState(
                          () => _filterStatus = selected ? status : null,
                        );
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingCard(Booking booking) {
    final dateFormat = DateFormat('MMM d, yyyy');
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        title: Text(
          booking.serviceTitle,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          'Traveler: ${booking.travelerName} • ${dateFormat.format(booking.date)}',
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: booking.statusColor.withAlpha(26),
            borderRadius: BorderRadius.circular(8),
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
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow('Booking ID', booking.id),
                _buildInfoRow('Check-in', dateFormat.format(booking.checkIn)),
                _buildInfoRow('Check-out', dateFormat.format(booking.checkOut)),
                _buildInfoRow('Total Price', '\$${booking.totalPrice}'),
                _buildInfoRow('Guest Count', '${booking.guests} Guests'),
                _buildInfoRow(
                  'Payment',
                  booking.paymentStatus.name.toUpperCase(),
                ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (booking.status != BookingStatus.cancelled)
                      OutlinedButton.icon(
                        icon: const Icon(Icons.cancel, color: Colors.red),
                        label: const Text(
                          'Force Cancel',
                          style: TextStyle(color: Colors.red),
                        ),
                        onPressed: () =>
                            _updateStatus(booking, BookingStatus.cancelled),
                      ),
                    const SizedBox(width: 8),
                    if (booking.status == BookingStatus.pending)
                      ElevatedButton.icon(
                        icon: const Icon(Icons.check),
                        label: const Text('Confirm'),
                        onPressed: () =>
                            _updateStatus(booking, BookingStatus.confirmed),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.book_online_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text(
            'No bookings found',
            style: TextStyle(color: Colors.grey, fontSize: 18),
          ),
        ],
      ),
    );
  }

  void _updateStatus(Booking booking, BookingStatus newStatus) {
    final updated = Booking(
      id: booking.id,
      serviceId: booking.serviceId,
      providerId: booking.providerId,
      serviceTitle: booking.serviceTitle,
      travelerId: booking.travelerId,
      travelerName: booking.travelerName,
      date: booking.date,
      checkIn: booking.checkIn,
      checkOut: booking.checkOut,
      guests: booking.guests,
      rooms: booking.rooms,
      totalPrice: booking.totalPrice,
      contactPhone: booking.contactPhone,
      contactEmail: booking.contactEmail,
      status: newStatus,
      paymentStatus: booking.paymentStatus,
    );
    ref.read(bookingProvider.notifier).updateBooking(updated);
  }
}
