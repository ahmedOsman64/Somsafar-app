import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/services/service_repository.dart';
import '../../../shared/widgets/app_network_image.dart';
import 'traveler_identity_screen.dart';

class BookingSummaryScreen extends ConsumerWidget {
  final String serviceId;
  final DateTime checkIn;
  final DateTime checkOut;
  final int guests;
  final int rooms;
  final String? specialRequests;

  const BookingSummaryScreen({
    required this.serviceId,
    required this.checkIn,
    required this.checkOut,
    required this.guests,
    required this.rooms,
    this.specialRequests,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final services = ref.watch(filteredServicesProvider);
    final service = services.firstWhere(
      (s) => s.id == serviceId,
      orElse: () => throw Exception('Service not found'),
    );

    final nights = checkOut.difference(checkIn).inDays;
    final totalCost = service.price * nights * rooms;

    return Scaffold(
      appBar: AppBar(title: const Text('Booking Summary'), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Property Card
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha((0.05 * 255).round()),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  AppNetworkImage(
                    imageUrl: service.images.first,
                    height: 150,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    memCacheHeight: 300, // Optimize for 150 logical pixels
                    errorWidget: Container(
                      height: 150,
                      color: Colors.grey[300],
                      child: const Center(child: Icon(Icons.broken_image)),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          service.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          service.location,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Details
            _buildDetailRow(
              'Dates',
              '${DateFormat('MMM dd').format(checkIn)} - ${DateFormat('MMM dd').format(checkOut)}',
              Icons.calendar_today,
            ),
            const Divider(height: 24),
            _buildDetailRow(
              'Guests',
              service.category.toLowerCase().contains('apartment')
                  ? '$guests Guests · Full Apartment'
                  : '$guests Guests, $rooms Room(s)',
              Icons.people_outline,
            ),
            if (specialRequests != null && specialRequests!.isNotEmpty) ...[
              const Divider(height: 24),
              _buildDetailRow(
                'Special Requests',
                specialRequests!,
                Icons.note_alt_outlined,
              ),
            ],

            const SizedBox(height: 32),

            // Price Breakdown
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                children: [
                  _buildPriceRow(
                    '\$${service.price.toStringAsFixed(0)} x $nights nights',
                    '\$${(service.price * nights).toStringAsFixed(0)}',
                  ),
                  if (rooms > 1) ...[
                    const SizedBox(height: 8),
                    _buildPriceRow('x $rooms rooms', '', isMuted: true),
                  ],
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Divider(),
                  ),
                  _buildPriceRow(
                    'Total',
                    '\$${totalCost.toStringAsFixed(0)}',
                    isTotal: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TravelerIdentityScreen(
                    serviceId: serviceId,
                    checkIn: checkIn,
                    checkOut: checkOut,
                    guests: guests,
                    rooms: rooms,
                    totalPrice: totalCost,
                    specialRequests: specialRequests,
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: AppColors.primary,
            ),
            child: const Text(
              'Book Now',
              style: TextStyle(fontSize: 16, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPriceRow(
    String label,
    String value, {
    bool isTotal = false,
    bool isMuted = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 18 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            color: isMuted ? Colors.grey : Colors.black,
          ),
        ),
        if (value.isNotEmpty)
          Text(
            value,
            style: TextStyle(
              fontSize: isTotal ? 18 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.bold,
              color: isTotal ? AppColors.primary : Colors.black,
            ),
          ),
      ],
    );
  }
}
