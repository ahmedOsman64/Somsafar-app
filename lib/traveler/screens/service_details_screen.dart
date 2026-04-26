import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/services/service_repository.dart';
import '../../shared/models/service_model.dart';

class ServiceDetailsScreen extends ConsumerWidget {
  final String serviceId;

  const ServiceDetailsScreen({required this.serviceId, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final services = ref.watch(filteredServicesProvider);
    final service = services.firstWhere(
      (s) => s.id == serviceId,
      orElse: () => throw Exception('Service not found'),
    );

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: ServiceImageCarousel(images: service.images),
            ),
          ),
          SliverList(
            delegate: SliverChildListDelegate([
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            service.title,
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withAlpha(
                              (0.1 * 255).round(),
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            service.category,
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on,
                          size: 16,
                          color: AppColors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          service.location,
                          style: const TextStyle(color: AppColors.grey),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Description',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      service.description,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Amenities',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (service.amenities != null && service.amenities!.isNotEmpty)
                      Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: service.amenities!.map((amenity) {
                          return _AmenityChip(
                            icon: _getIconForAmenity(amenity),
                            label: amenity,
                          );
                        }).toList(),
                      )
                    else
                      Text(
                        'No specific amenities listed.',
                        style: TextStyle(color: Colors.grey[500], fontStyle: FontStyle.italic),
                      ),
                    const SizedBox(height: 24),
                    _buildSpecificationsSection(context, service),
                    const SizedBox(height: 100), // Space for bottom bar
                  ],
                ),
              ),
            ]),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha((0.05 * 255).round()),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '\$${service.price.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  Text(
                    (service.category.toString().toLowerCase().contains('apartment'))
                        ? 'per month'
                        : (service.category.toString().toLowerCase().contains('tour'))
                            ? 'per person'
                            : 'per night',
                    style: const TextStyle(color: AppColors.grey),
                  ),
                ],
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: () {
                  _navigateToBooking(context, service);
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
                child: const Text('Book Now', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildSpecificationsSection(BuildContext context, Service service) {
    final metadata = service.metadata;
    final category = service.category.toString().toLowerCase();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Information & Policies',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            children: [
              if (category.contains('hotel')) ...[
                _buildInfoRow(
                  Icons.schedule,
                  'Check-in / Out',
                  '${metadata['checkIn'] ?? '2:00 PM'} / ${metadata['checkOut'] ?? '11:00 AM'}',
                ),
                _buildInfoRow(
                  Icons.bed,
                  'Standard Bed',
                  metadata['bedType'] ?? 'Double Bed',
                ),
                /*
                _buildInfoRow(
                  Icons.meeting_room,
                  'Available Rooms',
                  '${metadata['rooms'] ?? 'N/A'}',
                ),
                */
                _buildInfoRow(
                  Icons.smoke_free,
                  'Smoking',
                  metadata['smokingPreference'] ?? 'Non-Smoking',
                ),
                if (service.maxGuests != null)
                  _buildInfoRow(
                    Icons.people_outline,
                    'Capacity',
                    '${service.maxGuests} Guests',
                  ),
              ] else if (category.contains('apartment')) ...[
                _buildInfoRow(
                  Icons.layers,
                  'Floor',
                  '${metadata['floorNumber'] ?? 'N/A'}',
                ),
                _buildInfoRow(
                  Icons.people,
                  'Max Guests',
                  '${metadata['maxGuests'] ?? 'N/A'}',
                ),
                _buildInfoRow(
                  Icons.king_bed,
                  'Bedrooms',
                  '${metadata['bedrooms'] ?? 'N/A'}',
                ),
                if (service.cleaningPrice != null && service.cleaningPrice! > 0)
                  _buildInfoRow(
                    Icons.cleaning_services,
                    'Cleaning Fee',
                    '\$${service.cleaningPrice}',
                  ),
                if (service.earlyCheckInPrice != null &&
                    service.earlyCheckInPrice! > 0)
                  _buildInfoRow(
                    Icons.wb_sunny_outlined,
                    'Early Check-in',
                    '\$${service.earlyCheckInPrice}',
                  ),
                if (service.lateCheckoutPrice != null &&
                    service.lateCheckoutPrice! > 0)
                  _buildInfoRow(
                    Icons.nightlight_outlined,
                    'Late Checkout fee',
                    '\$${service.lateCheckoutPrice}',
                  ),
              ] else if (category.contains('tour')) ...[
                // Package Type Highlight
                if (metadata['package'] != null)
                  _buildInfoRow(
                    Icons.inventory_2_outlined,
                    'Package Type',
                    metadata['package'].toString().toUpperCase(),
                  ),

                // Common Tour Info
                _buildInfoRow(
                  Icons.timer,
                  'Duration',
                  metadata['duration'] ?? 'N/A',
                ),
                _buildInfoRow(
                  Icons.place,
                  'Meeting Point',
                  metadata['meetingPoint'] ?? 'N/A',
                ),
                _buildInfoRow(
                  Icons.group,
                  'Max Travelers',
                  '${metadata['maxTravelers'] ?? 'N/A'}',
                ),

                // Package Specific Info
                if (metadata['package'] == 'jumma') ...[
                  _buildInfoRow(Icons.mosque_outlined, 'Prayer Location', metadata['preferredLocation'] ?? 'N/A'),
                  _buildInfoRow(Icons.directions_bus_outlined, 'Transport', metadata['jummaTransport'] ?? 'N/A'),
                  _buildInfoRow(Icons.apartment_outlined, 'Stay Type', metadata['accommodationType'] ?? 'N/A'),
                  _buildInfoRow(Icons.restaurant_outlined, 'Lunch', metadata['includeLunch'] == true ? 'Included' : 'Not Included'),
                ] else if (metadata['package'] == 'eid') ...[
                  _buildInfoRow(Icons.celebration_outlined, 'Eid Package', metadata['eidType'] ?? 'N/A'),
                  _buildInfoRow(Icons.map_outlined, 'Destination', metadata['destination'] ?? 'N/A'),
                  _buildInfoRow(Icons.calendar_month_outlined, 'Duration', '${metadata['numberOfDays'] ?? 'N/A'} Days'),
                  // _buildInfoRow(Icons.hotel_outlined, 'Hotel Rating', '${metadata['hotelRating'] ?? 'N/A'} Stars'),
                  _buildInfoRow(Icons.restaurant_outlined, 'Food Package', metadata['foodPackage'] ?? 'N/A'),
                ] else if (metadata['package'] == 'custom') ...[
                  _buildInfoRow(Icons.account_balance_wallet_outlined, 'Suggested Budget', metadata['budgetRange'] ?? 'N/A'),
                  if (metadata['availableServices'] != null)
                    _buildInfoRow(
                      Icons.room_service_outlined,
                      'Services Provided',
                      (metadata['availableServices'] as List).join(', '),
                    ),
                ],

                if (metadata['languages'] != null &&
                    (metadata['languages'] as List).isNotEmpty)
                  _buildInfoRow(
                    Icons.translate,
                    'Languages',
                    (metadata['languages'] as List).join(', '),
                  ),
                if (metadata['includes'] != null &&
                    (metadata['includes'] as List).isNotEmpty)
                  _buildInfoRow(
                    Icons.check_circle_outline,
                    'Included',
                    (metadata['includes'] as List).join(', '),
                  ),
              ],
              
              // Extras & Prices
              if (service.breakfastPrice != null && service.breakfastPrice! > 0)
                _buildInfoRow(
                  Icons.restaurant,
                  'Breakfast',
                  '\$${service.breakfastPrice!.toStringAsFixed(0)} / person',
                ),
              if (service.airportPickupPrice != null && service.airportPickupPrice! > 0)
                _buildInfoRow(
                  Icons.local_airport,
                  'Airport Pickup',
                  '\$${service.airportPickupPrice!.toStringAsFixed(0)} flat fee',
                ),
              if (service.extraBedPrice != null && service.extraBedPrice! > 0)
                _buildInfoRow(
                  Icons.single_bed,
                  'Extra Bed',
                  '\$${service.extraBedPrice!.toStringAsFixed(0)} / night',
                ),

              // Policy Highlights
              const Divider(height: 24),
              Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.blue[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Early Check-in: ${metadata['earlyCheckInAllowed'] == true ? 'Yes' : 'Request only'}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.blue[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Late Checkout: ${metadata['lateCheckoutAllowed'] == true ? 'Yes' : 'Request only'}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 12),
          Text(
            '$label:',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(color: Colors.grey[700]),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIconForAmenity(String amenity) {
    final a = amenity.toLowerCase();
    if (a.contains('wifi')) return Icons.wifi;
    if (a.contains('ac') || a.contains('air condition')) return Icons.ac_unit;
    if (a.contains('pool')) return Icons.pool;
    if (a.contains('parking')) return Icons.local_parking;
    if (a.contains('breakfast')) return Icons.free_breakfast;
    if (a.contains('gym') || a.contains('fitness')) return Icons.fitness_center;
    if (a.contains('tv')) return Icons.tv;
    if (a.contains('restaurant') || a.contains('food')) return Icons.restaurant;
    if (a.contains('spa')) return Icons.spa;
    if (a.contains('security') || a.contains('safe')) return Icons.lock_outline;
    if (a.contains('coffee')) return Icons.coffee_maker_outlined;
    if (a.contains('transport') || a.contains('pickup')) return Icons.airport_shuttle;
    return Icons.done;
  }

  void _navigateToBooking(BuildContext context, Service service) {
    context.push(
      '/traveler/booking/${service.id}',
      extra: service,
    );
  }
}

class ServiceImageCarousel extends StatefulWidget {
  final List<String> images;

  const ServiceImageCarousel({required this.images, super.key});

  @override
  State<ServiceImageCarousel> createState() => _ServiceImageCarouselState();
}

class _ServiceImageCarouselState extends State<ServiceImageCarousel> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.images.isEmpty) {
      return Container(
        color: Colors.grey[200],
        child: const Icon(Icons.image_not_supported, size: 50, color: Colors.grey),
      );
    }

    return Stack(
      children: [
        PageView.builder(
          controller: _pageController,
          itemCount: widget.images.length,
          onPageChanged: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          itemBuilder: (context, index) {
            return Hero(
              tag: 'service_image_${widget.images[index]}',
              child: Image.network(
                widget.images[index],
                fit: BoxFit.cover,
                errorBuilder: (c, o, s) => Container(
                  color: Colors.grey[200],
                  child: const Icon(Icons.broken_image, color: Colors.grey),
                ),
              ),
            );
          },
        ),
        // Gradient overlay for back button and indicators
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withAlpha((0.3 * 255).round()),
                  Colors.transparent,
                  Colors.transparent,
                  Colors.black.withAlpha((0.3 * 255).round()),
                ],
                stops: const [0.0, 0.2, 0.8, 1.0],
              ),
            ),
          ),
        ),
        // Indicators
        if (widget.images.length > 1)
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                widget.images.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  height: 8,
                  width: _currentIndex == index ? 24 : 8,
                  decoration: BoxDecoration(
                    color: _currentIndex == index
                        ? Colors.white
                        : Colors.white.withAlpha((0.5 * 255).round()),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ),
        // Photo Counter Label (optional premium feel)
        Positioned(
          bottom: 20,
          right: 20,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha((0.5 * 255).round()),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${_currentIndex + 1} / ${widget.images.length}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AmenityChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _AmenityChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withAlpha((0.05 * 255).round()),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.primary.withAlpha((0.1 * 255).round()),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.primary, size: 18),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
