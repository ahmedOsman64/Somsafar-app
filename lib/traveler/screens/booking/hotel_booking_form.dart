import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/booking_forms_model.dart';
import '../../../shared/models/service_model.dart';
import '../../../shared/services/booking_form_service.dart';
import '../../../shared/services/special_offer_repository.dart';
import '../../../shared/services/auth_service.dart';
import 'widgets/booking_form_widgets.dart';
import 'enhanced_payment_screen.dart';
import '../../../shared/services/tax_repository.dart';
import '../../../shared/services/system_settings_repository.dart';
import '../../../shared/services/user_repository.dart';
import '../../../shared/models/user_model.dart';
import '../../../shared/services/discount_repository.dart';
import '../../../shared/services/booking_repository.dart';

class HotelBookingForm extends ConsumerStatefulWidget {
  final Service service;

  const HotelBookingForm({required this.service, super.key});

  @override
  ConsumerState<HotelBookingForm> createState() => _HotelBookingFormState();
}

class _HotelBookingFormState extends ConsumerState<HotelBookingForm>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  int _currentStep = 0;
  bool _isLoading = false;
  String? _errorMessage;

  // Animation
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // Stay Details
  DateTime? _checkInDate;
  DateTime? _checkOutDate;
  int _guests = 2;
  int _rooms = 1;

  // Availability (date-based)
  // null = not checked yet, -1 = fully booked for those dates, >=0 = rooms available
  int? _availableRoomsForDates;

  // Guest Info
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _locationController = TextEditingController();

  // Room Preferences
  BedType _bedType = BedType.double;
  SmokingPreference _smokingPreference = SmokingPreference.nonSmoking;
  final _specialRequestsController = TextEditingController();

  // Extras
  bool _breakfastIncluded = false;
  bool _airportPickup = false;
  bool _extraBed = false;
  final List<String> _selectedCustomOptionIds = [];

  BookingSummary? _bookingSummary;

  static const _stepLabels = ['Stay', 'Guest', 'Prefs', 'Extras'];

  @override
  void initState() {
    super.initState();
    // Pre-fill guest info from profile
    final user = ref.read(authProvider);
    if (user != null) {
      _fullNameController.text = user.name;
      _emailController.text = user.email;
      _phoneController.text = user.phone ?? '';
      // Location can be derived from profile if available, otherwise remains empty
      if (user.location != null) {
        _locationController.text = user.location!;
      }
    }

    // Pre-fill preferences from metadata if available
    final metadata = widget.service.metadata;
    final dynamicBeds = metadata['bed_types_dynamic'] as Map<String, dynamic>?;
    if (dynamicBeds != null) {
      if (dynamicBeds['double']?['enabled'] == true) {
        _bedType = BedType.double;
      } else if (dynamicBeds['single']?['enabled'] == true) {
        _bedType = BedType.single;
      } else if (dynamicBeds['twin']?['enabled'] == true) {
        _bedType = BedType.twin;
      }
    } else if (metadata['bedType'] != null) {
      final bedString = metadata['bedType'].toString().toLowerCase();
      if (bedString.contains('single')) {
        _bedType = BedType.single;
      } else if (bedString.contains('twin')) {
        _bedType = BedType.twin;
      } else {
        _bedType = BedType.double;
      }
    }

    if (metadata['smokingPreference'] != null) {
      final smokeString = metadata['smokingPreference'].toString().toLowerCase();
      if (smokeString.contains('non')) {
        _smokingPreference = SmokingPreference.nonSmoking;
      } else if (smokeString.contains('smoke')) {
        _smokingPreference = SmokingPreference.smoking;
      }
    }

    // Extras are off by default, traveler must manually opt-in
    _breakfastIncluded = false;
    _airportPickup = false;
    _extraBed = false;

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    _specialRequestsController.dispose();
    super.dispose();
  }

  void _updateBookingSummary() {
    if (_checkInDate != null && _checkOutDate != null) {
      final provider = ref.watch(userProvider).firstWhere(
        (u) => u.id == widget.service.providerId,
        orElse: () => User(id: '', name: '', email: '', password: '', role: UserRole.traveler),
      );

      final bookingData = HotelBookingData(
        checkIn: _checkInDate!,
        checkOut: _checkOutDate!,
        guests: _guests,
        fullName: _fullNameController.text,
        email: _emailController.text,
        phone: _phoneController.text,
        rooms: _rooms,
        bedType: _bedType,
        smokingPreference: _smokingPreference,
        breakfastIncluded: _breakfastIncluded,
        airportPickup: _airportPickup,
        extraBed: _extraBed,
        location: _locationController.text,
        breakfastPrice: widget.service.breakfastPrice ?? 
            double.tryParse(provider.metadata['breakfast_price']?.toString() ?? '') ?? 0.0,
        airportPickupPrice: widget.service.airportPickupPrice ?? 
            double.tryParse(provider.metadata['airport_pickup_price']?.toString() ?? '') ?? 0.0,
        extraBedPrice: widget.service.extraBedPrice ?? 
            double.tryParse(provider.metadata['extra_bed_price']?.toString() ?? '') ?? 0.0,
        selectedCustomOptionIds: _selectedCustomOptionIds,
      );

      final activeDiscount = DiscountRepository.getBestDiscount(
        ref.read(discountRepositoryProvider),
        widget.service.id,
        widget.service.providerId,
      );

      setState(() {
        _bookingSummary = BookingFormService.calculateHotelPrice(
          bookingData,
          widget.service,
          ref.read(activeTaxesProvider),
          platformFeePercentage: ref.read(systemSettingsProvider).platformFee,
          activeOffers: ref.read(activeSpecialOffersProvider),
          activeDiscount: activeDiscount,
        );
      });
    }
  }

  int get _nights => _checkInDate != null && _checkOutDate != null
      ? _checkOutDate!.difference(_checkInDate!).inDays
      : 1;

  Widget _buildStayDetailsStep() {
    final bool datesSelected = _checkInDate != null && _checkOutDate != null;
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BookingSectionHeader(title: 'Stay Details', icon: Icons.hotel),
          DatePickerTile(
            label: 'Check-in Date',
            value: _checkInDate != null
                ? DateFormat('EEE, MMM d, yyyy').format(_checkInDate!)
                : null,
            onTap: _selectCheckInDate,
          ),
          const SizedBox(height: 12),
          DatePickerTile(
            label: 'Check-out Date',
            value: _checkOutDate != null
                ? DateFormat('EEE, MMM d, yyyy').format(_checkOutDate!)
                : null,
            onTap: _selectCheckOutDate,
          ),
          if (datesSelected) ...[
            const SizedBox(height: 10),
            InfoBanner(
              text:
                  '$_nights night${_nights > 1 ? 's' : ''} · '
                  '${DateFormat('MMM d').format(_checkInDate!)} → '
                  '${DateFormat('MMM d').format(_checkOutDate!)}',
              color: AppColors.info,
              icon: Icons.nights_stay_outlined,
            ),
            const SizedBox(height: 8),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 20),
          CounterRow(
            label: 'Guests',
            subtitle: 'Adults & children',
            value: _guests,
            onDecrement: () => setState(() {
              _guests--;
              _updateBookingSummary();
            }),
            onIncrement: () => setState(() {
              _guests++;
              _updateBookingSummary();
            }),
          ),
          const SizedBox(height: 12),
          CounterRow(
            label: 'Rooms',
            subtitle: 'Number of rooms needed',
            value: _rooms,
            onDecrement: () => setState(() {
              _rooms--;
              _updateBookingSummary();
            }),
            onIncrement: () => setState(() {
              // Don't exceed available rooms
              if (_availableRoomsForDates == null || _rooms < _availableRoomsForDates!) {
                _rooms++;
              }
              _updateBookingSummary();
            }),
          ),
        ],
      ),
    );
  }


  Widget _buildGuestInfoStep() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BookingSectionHeader(
            title: 'Guest Information',
            icon: Icons.person_outline,
          ),
          _premiumTextField(
            controller: _fullNameController,
            label: 'Full Name',
            icon: Icons.badge_outlined,
            keyboardType: TextInputType.name,
            validator: (v) =>
                v?.trim().isEmpty ?? true ? 'Full name is required' : null,
            onChanged: (_) => _updateBookingSummary(),
          ),
          const SizedBox(height: 14),
          _premiumTextField(
            controller: _emailController,
            label: 'Email Address',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            validator: (v) {
              if (v?.trim().isEmpty ?? true) return 'Email is required';
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v!)) {
                return 'Enter a valid email address';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          _premiumTextField(
            controller: _phoneController,
            label: 'Phone Number',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            validator: (v) {
              if (v?.trim().isEmpty ?? true) return 'Phone is required';
              if (v!.length < 8) return 'Phone number too short';
              return null;
            },
          ),
          const SizedBox(height: 14),
          _premiumTextField(
            controller: _locationController,
            label: 'Location (Where you live)',
            icon: Icons.location_on_outlined,
            keyboardType: TextInputType.text,
            validator: (v) =>
                v?.trim().isEmpty ?? true ? 'Location is required' : null,
          ),
        ],
      ),
    );
  }

  Widget _buildPreferencesStep() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BookingSectionHeader(
            title: 'Room Preferences',
            icon: Icons.bed_outlined,
          ),
          const Text(
            'Bed Type',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 10),
          ...BedType.values.where((type) {
          final dynamicBeds = widget.service.metadata['bed_types_dynamic'] as Map<String, dynamic>?;
          if (dynamicBeds == null) return true;
          return dynamicBeds[type.name.toLowerCase()]?['enabled'] ?? false;
        }).map(
          (type) {
            final dynamicBeds = widget.service.metadata['bed_types_dynamic'] as Map<String, dynamic>?;
            double? price;
            bool isAvailable = true;
            
            if (dynamicBeds != null && _checkInDate != null && _checkOutDate != null) {
              final bedKey = type.name.toLowerCase();
              price = (dynamicBeds[bedKey]?['price'] as num?)?.toDouble();
              
              final availableCount = ref.read(bookingProvider.notifier).getAvailableRoomsForDates(
                serviceId: widget.service.id,
                checkIn: _checkInDate!,
                checkOut: _checkOutDate!,
                bedType: type.name,
              );
              isAvailable = availableCount > 0;
            }

            return _buildOptionCard<BedType>(
              value: type,
              groupValue: _bedType,
              title: _formatBedType(type),
              subtitle: type == BedType.single 
                  ? 'Standard room price'
                  : (price != null && price > 0 
                      ? '+\$${price.toStringAsFixed(0)} extra' 
                      : _getBedTypeSubtitle(type)),
              icon: Icons.king_bed_outlined,
              isEnabled: isAvailable,
              onTap: () => setState(() {
                _bedType = type;
                _updateBookingSummary();
              }),
            );
          },
        ),
          const SizedBox(height: 16),
          const Text(
            'Smoking Preference',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 10),
          ...SmokingPreference.values.map(
            (pref) => _buildOptionCard<SmokingPreference>(
              value: pref,
              groupValue: _smokingPreference,
              title: _formatSmokingPref(pref),
              subtitle: _getSmokingPrefSubtitle(pref),
              icon: pref == SmokingPreference.smoking
                  ? Icons.smoking_rooms
                  : Icons.smoke_free,
              onTap: () => setState(() {
                _smokingPreference = pref;
                _updateBookingSummary();
              }),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _specialRequestsController,
            decoration: InputDecoration(
              labelText: 'Special Requests (Optional)',
              hintText: 'e.g. High floor, near pool...',
              prefixIcon: const Icon(Icons.comment_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey[50],
            ),
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  Widget _buildExtrasStep() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BookingSectionHeader(
            title: 'Add Extras',
            icon: Icons.add_shopping_cart,
          ),
          if (widget.service.breakfastPrice != null && widget.service.breakfastPrice! > 0)
            PremiumSwitchTile(
              title: 'Breakfast Included',
              subtitle: '\$${widget.service.breakfastPrice!.toStringAsFixed(0)} per guest per night',
              value: _breakfastIncluded,
              icon: Icons.free_breakfast_outlined,
              onChanged: (v) => setState(() {
                _breakfastIncluded = v;
                _updateBookingSummary();
              }),
            ),
          if (widget.service.airportPickupPrice != null && widget.service.airportPickupPrice! > 0)
            PremiumSwitchTile(
              title: 'Airport Pickup',
              subtitle: '\$${widget.service.airportPickupPrice!.toStringAsFixed(0)} flat fee',
              value: _airportPickup,
              icon: Icons.local_airport_outlined,
              onChanged: (v) => setState(() {
                _airportPickup = v;
                _updateBookingSummary();
              }),
            ),
          if (widget.service.extraBedPrice != null && widget.service.extraBedPrice! > 0)
            PremiumSwitchTile(
              title: 'Extra Bed',
              subtitle: '\$${widget.service.extraBedPrice!.toStringAsFixed(0)} per night',
              value: _extraBed,
              icon: Icons.single_bed_outlined,
              onChanged: (v) => setState(() {
                _extraBed = v;
                _updateBookingSummary();
              }),
            ),

          if (widget.service.metadata['custom_room_options'] != null) ...[
            const SizedBox(height: 16),
            const Text(
              'Other Options',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary),
            ),
            const SizedBox(height: 8),
            ...(widget.service.metadata['custom_room_options'] as List).map((opt) {
              final id = opt['id'];
              final title = opt['title'];
              final price = (opt['price'] as num).toDouble();
              final isSelected = _selectedCustomOptionIds.contains(id);

              return PremiumSwitchTile(
                title: title,
                subtitle: '+\$${price.toStringAsFixed(0)} flat fee',
                value: isSelected,
                icon: Icons.add_circle_outline,
                onChanged: (v) => setState(() {
                  if (v) {
                    _selectedCustomOptionIds.add(id);
                  } else {
                    _selectedCustomOptionIds.remove(id);
                  }
                  _updateBookingSummary();
                }),
              );
            }),
          ],

          const SizedBox(height: 12),
          const InfoBanner(
            text: 'Free cancellation up to 24 hours before check-in.',
            color: AppColors.success,
            icon: Icons.verified_outlined,
          ),
        ],
      ),
    );
  }

  Widget _buildOptionCard<T>({
    required T value,
    required T groupValue,
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    bool isEnabled = true,
  }) {
    final isSelected = value == groupValue;

    return GestureDetector(
      onTap: isEnabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: !isEnabled
              ? Colors.grey[100]
              : isSelected
                  ? AppColors.primary.withValues(alpha: 0.06)
                  : Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: !isEnabled
                ? Colors.grey[300]!
                : isSelected
                    ? AppColors.primary
                    : Colors.grey[200]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Opacity(
          opacity: isEnabled ? 1.0 : 0.5,
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected ? AppColors.primary : Colors.grey[500],
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isSelected ? AppColors.primary : Colors.black87,
                      ),
                    ),
                    Text(
                      !isEnabled ? 'Sold Out' : subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: !isEnabled ? Colors.red[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              if (isEnabled)
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: isSelected
                      ? Icon(
                          Icons.check_circle,
                          color: AppColors.primary,
                          key: const ValueKey(true),
                        )
                      : Icon(
                          Icons.circle_outlined,
                          color: Colors.grey[300],
                          key: const ValueKey(false),
                        ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  TextFormField _premiumTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey[50],
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }

  Future<void> _selectCheckInDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _checkInDate ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _checkInDate = picked;
        if (_checkOutDate != null && _checkOutDate!.isBefore(_checkInDate!)) {
          _checkOutDate = _checkInDate!.add(const Duration(days: 1));
        }
        _availableRoomsForDates = null; // reset until both dates confirmed
        _updateBookingSummary();
      });
      if (_checkOutDate != null) _checkDateAvailability();
    }
  }

  Future<void> _selectCheckOutDate() async {
    final DateTime firstPossible =
        _checkInDate?.add(const Duration(days: 1)) ??
        DateTime.now().add(const Duration(days: 1));

    // Ensure initialDate is not before firstDate
    DateTime initial =
        _checkOutDate ?? DateTime.now().add(const Duration(days: 2));
    if (initial.isBefore(firstPossible)) {
      initial = firstPossible;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstPossible,
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _checkOutDate = picked;
        _updateBookingSummary();
      });
      _checkDateAvailability(); // Check availability immediately after checkout selected
    }
  }


  /// Checks how many rooms are free for the selected date window and updates state.
  void _checkDateAvailability() {
    if (_checkInDate == null || _checkOutDate == null) { return; }
    final available = ref.read(bookingProvider.notifier).getAvailableRoomsForDates(
      serviceId: widget.service.id,
      checkIn: _checkInDate!,
      checkOut: _checkOutDate!,
    );
    setState(() {
      _availableRoomsForDates = available;
      // Clamp rooms to what's actually available
      if (available > 0 && _rooms > available) {
        _rooms = available;
      }
    });
  }

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0:
        if (_checkInDate == null || _checkOutDate == null) { return false; }
        // Block if no rooms available for the selected dates
        if (_availableRoomsForDates != null && _availableRoomsForDates! <= 0) { return false; }
        return true;
      case 1:
        return _formKey.currentState?.validate() ?? false;
      case 2:
        return true;
      case 3:
        return true;
      default:
        return false;
    }
  }



  void _goToStep(int step) {
    _fadeController.reset();
    setState(() {
      _currentStep = step;
      _errorMessage = null;
    });
    _fadeController.forward();
  }

  void _nextStep() {
    if (_validateCurrentStep()) {
      if (_currentStep < 3) {
        _goToStep(_currentStep + 1);
      } else {
        _submitBooking();
      }
    } else {
      setState(() {
        if (_currentStep == 0) {
          if (_checkInDate == null || _checkOutDate == null) {
            _errorMessage = 'Please select check-in and check-out dates';
          } else if (_availableRoomsForDates != null && _availableRoomsForDates! <= 0) {
            _errorMessage = 'These dates are not available. Please select different dates.';
          } else {
            _errorMessage = 'Please select check-in and check-out dates';
          }
        } else {
          _errorMessage = 'Please fill in all required fields';
        }
      });
    }
  }

  Future<void> _submitBooking() async {
    if (!(_formKey.currentState?.validate() ?? true)) return;

    // Final availability double-check before proceeding to payment
    if (_checkInDate != null && _checkOutDate != null) {
      final available = ref.read(bookingProvider.notifier).getAvailableRoomsForDates(
        serviceId: widget.service.id,
        checkIn: _checkInDate!,
        checkOut: _checkOutDate!,
      );
      if (available <= 0) {
        setState(() {
          _errorMessage = 'These dates are no longer available. Please choose different dates.';
          _currentStep = 0; // Send back to step 0
          _availableRoomsForDates = 0;
        });
        return;
      }
      if (_rooms > available) {
        setState(() {
          _errorMessage = 'Only $available room(s) available for these dates. Please reduce your room count.';
          _currentStep = 0;
          _availableRoomsForDates = available;
          _rooms = available;
        });
        return;
      }
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final provider = ref.watch(userProvider).firstWhere(
        (u) => u.id == widget.service.providerId,
        orElse: () => User(id: '', name: '', email: '', password: '', role: UserRole.traveler),
      );

      final bookingData = HotelBookingData(
        checkIn: _checkInDate!,
        checkOut: _checkOutDate!,
        guests: _guests,
        fullName: _fullNameController.text,
        email: _emailController.text,
        phone: _phoneController.text,
        rooms: _rooms,
        bedType: _bedType,
        smokingPreference: _smokingPreference,
        breakfastIncluded: _breakfastIncluded,
        airportPickup: _airportPickup,
        extraBed: _extraBed,
        location: _locationController.text,
        breakfastPrice: widget.service.breakfastPrice ?? 
            double.tryParse(provider.metadata['breakfast_price']?.toString() ?? '') ?? 0.0,
        airportPickupPrice: widget.service.airportPickupPrice ?? 
            double.tryParse(provider.metadata['airport_pickup_price']?.toString() ?? '') ?? 0.0,
        extraBedPrice: widget.service.extraBedPrice ?? 
            double.tryParse(provider.metadata['extra_bed_price']?.toString() ?? '') ?? 0.0,
        selectedCustomOptionIds: _selectedCustomOptionIds,
        specialRequests: _specialRequestsController.text.isEmpty
            ? null
            : _specialRequestsController.text,
      );

      final validation = BookingFormService.validateHotelBooking(bookingData);
      if (!validation.isValid) {
        setState(() {
          _errorMessage = validation.errors.values.first;
          _isLoading = false;
        });
        return;
      }

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EnhancedPaymentScreen(
            serviceId: widget.service.id,
            providerId: widget.service.providerId,
            serviceTitle: widget.service.title,
            serviceType: ServiceType.hotel,
            checkIn: bookingData.checkIn,
            checkOut: bookingData.checkOut,
            guests: bookingData.guests,
            rooms: bookingData.rooms,
            totalPrice: _bookingSummary!.totalPrice,
            basePrice: _bookingSummary!.basePrice,
            taxes: _bookingSummary!.taxes,
            extras: _bookingSummary!.extras,
            contactName: bookingData.fullName,
            contactEmail: bookingData.email,
            contactPhone: bookingData.phone,
            location: bookingData.location,
            specialRequests: bookingData.specialRequests,
            metadata: {
              'serviceType': 'hotel',
            },
          ),
        ),
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'Something went wrong: $e';
        _isLoading = false;
      });
    }
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildStayDetailsStep();
      case 1:
        return _buildGuestInfoStep();
      case 2:
        return _buildPreferencesStep();
      case 3:
        return _buildExtrasStep();
      default:
        return const SizedBox.shrink();
    }
  }

  String _formatBedType(BedType type) {
    switch (type) {
      case BedType.single:
        return 'Single Bed';
      case BedType.double:
        return 'Double Bed';
      case BedType.twin:
        return 'Twin Beds';
    }
  }

  String _getBedTypeSubtitle(BedType type) {
    switch (type) {
      case BedType.single:
        return 'Best for solo travelers';
      case BedType.double:
        return 'Best for couples';
      case BedType.twin:
        return 'Two separate beds';
    }
  }

  String _formatSmokingPref(SmokingPreference pref) {
    switch (pref) {
      case SmokingPreference.smoking:
        return 'Smoking Room';
      case SmokingPreference.nonSmoking:
        return 'Non-Smoking';
      case SmokingPreference.any:
        return 'No Preference';
    }
  }

  String _getSmokingPrefSubtitle(SmokingPreference pref) {
    switch (pref) {
      case SmokingPreference.smoking:
        return 'Smoking is permitted in the room';
      case SmokingPreference.nonSmoking:
        return 'Smoke-free environment';
      case SmokingPreference.any:
        return 'Either type is fine';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch for changes to automatically update summary
    ref.listen(activeSpecialOffersProvider, (_, __) => _updateBookingSummary());
    ref.listen(activeTaxesProvider, (_, __) => _updateBookingSummary());
    ref.listen(systemSettingsProvider, (_, __) => _updateBookingSummary());
    ref.listen(discountRepositoryProvider, (_, __) => _updateBookingSummary());

    return Scaffold(
      backgroundColor: AppColors.background,
      body: _isLoading
          ? _buildLoadingState()
          : Column(
              children: [
                // Header
                _buildHeader(),

                // Step Indicator
                BookingStepIndicator(
                  totalSteps: 4,
                  currentStep: _currentStep,
                  stepLabels: _stepLabels,
                ),

                // Error message
                if (_errorMessage != null) ErrorBanner(message: _errorMessage!),

                // Content
                Expanded(
                  child: Form(
                    key: _formKey,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          ServiceImageGallery(images: widget.service.images),

                          _buildCurrentStep(),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
      bottomNavigationBar: _isLoading 
          ? null 
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Price Summary
                if (_bookingSummary != null && _currentStep > 0)
                  LivePriceSummaryBar(summary: _bookingSummary!),

                // Navigation
                BookingNavControls(
                  isFirstStep: _currentStep == 0,
                  isLastStep: _currentStep == 3,
                  onBack: () => _goToStep(_currentStep - 1),
                  onNext: _nextStep,
                ),
              ],
            ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: AppColors.primary,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.arrow_back, color: Colors.white),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.service.title,

                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    Text(
                      'Hotel Booking',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.hotel, color: Colors.white, size: 28),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(color: AppColors.primary),
                const SizedBox(height: 20),
                const Text(
                  'Preparing your booking...',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
