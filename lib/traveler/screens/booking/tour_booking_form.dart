import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/booking_model.dart';
import '../../../shared/models/booking_forms_model.dart';
import '../../../shared/services/booking_form_service.dart';
import '../../../shared/services/lookup_service.dart';
import '../../../shared/services/auth_service.dart';
import 'widgets/booking_form_widgets.dart';
import 'enhanced_payment_screen.dart';
import '../../../shared/services/tax_repository.dart';
import '../../../shared/models/service_model.dart';
import '../../../shared/services/system_settings_repository.dart';
import '../../../shared/services/special_offer_repository.dart';
import '../../../shared/services/discount_repository.dart';


class TourBookingForm extends ConsumerStatefulWidget {
  final Service service;
  final TourPackage initialPackage;

  const TourBookingForm({
    required this.service,
    required this.initialPackage,
    super.key,
  });

  @override
  ConsumerState<TourBookingForm> createState() => _TourBookingFormState();
}

class _TourBookingFormState extends ConsumerState<TourBookingForm>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  int _currentStep = 0;
  bool _isLoading = false;
  String? _errorMessage;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // Tour Details
  DateTime? _tourDate;
  int _adultsCount = 1;
  int _childrenCount = 0;
  int _infantsCount = 0;
  late TourPackage _package;

  // Traveler Information (Lead)
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passportNumberController = TextEditingController();
  final _locationController = TextEditingController();

  // Multi-Travelers
  final List<Map<String, TextEditingController>> _additionalTravelers = [];

  // Jumma Specific
  String _preferredLocation = 'Mogadishu';
  String _jummaTransport = 'Car';
  String _accommodationType = 'Hotel';
  bool _includeLunch = true;
  final _specialInformationController = TextEditingController();

  // Eid Specific
  String _eidType = 'Eid al-Fitr';
  final _destinationController = TextEditingController();
  int _numberOfDays = 3;
  String _eidTransport = 'Bus';
  int _hotelRating = 4;
  final List<String> _selectedActivities = [];
  String _foodPackage = 'Full board';
  final _childSpecificNeedsController = TextEditingController();

  // Custom Specific
  final List<String> _preferredServices = [];

  // Preferences
  LanguageGuide _languageGuide = LanguageGuide.english;
  MealPreference _mealPreference = MealPreference.noPreference;
  final _pickupLocationController = TextEditingController();

  // Health / Notes
  final _medicalConditionsController = TextEditingController();
  final _specialInstructionsController = TextEditingController();

  BookingSummary? _bookingSummary;

  List<String> get _stepLabels => _package == TourPackage.custom
      ? ['Tour', 'Traveler', 'Options', 'Safety']
      : ['Tour', 'Traveler', 'Safety'];

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider);
    if (user != null) {
      _fullNameController.text = user.name;
      _emailController.text = user.email;
      _phoneController.text = user.phone ?? '';
      _locationController.text = user.location ?? '';
    }

    _package = widget.initialPackage;

    // Set initial package from service metadata if available (fallback)
    final packageStr = widget.service.metadata['package']?.toString().toLowerCase();
    if (packageStr != null) {
      for (final pkg in TourPackage.values) {
        if (pkg.name.toLowerCase() == packageStr) {
          _package = pkg;
          break;
        }
      }
    }

    if (_package == TourPackage.custom) {
      _numberOfDays = 1;
    }

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    _fadeController.forward();

    // Initial automatic date
    _updateAutomaticDate();

    // Populate metadata for Juma/Eid if available
    final metadata = widget.service.metadata;
    if (metadata.isNotEmpty) {
      if (metadata['package'] == 'jumma') {
        _preferredLocation = metadata['preferredLocation'] ?? _preferredLocation;
        _destinationController.text = _preferredLocation; // Added
        _jummaTransport = metadata['jummaTransport'] ?? _jummaTransport;
        _accommodationType = metadata['accommodationType'] ?? _accommodationType;
        _includeLunch = false;
      } else if (metadata['package'] == 'eid') {
        _eidType = metadata['eidType'] ?? _eidType;
        _destinationController.text = metadata['destination'] ?? 'Eid Destination'; // Added
        _numberOfDays = metadata['numberOfDays'] ?? _numberOfDays;
        _eidTransport = metadata['eidTransport'] ?? _eidTransport;
        _hotelRating = metadata['hotelRating'] ?? _hotelRating;
        _foodPackage = metadata['foodPackage'] ?? _foodPackage;
      }
    }
  }

  void _updateAutomaticDate() {
    if (_package == TourPackage.jumma) {
      _tourDate = _getNextFriday();
    } else if (_package == TourPackage.eid) {
      _tourDate = _getEidDate();
    }
  }

  DateTime _getNextFriday() {
    DateTime now = DateTime.now();
    int daysUntilFriday = (DateTime.friday - now.weekday + 7) % 7;
    // If today is Friday, the user might want this Friday or the next. 
    // Usually, tours are booked at least a day in advance.
    if (daysUntilFriday == 0) daysUntilFriday = 7; 
    return DateTime(now.year, now.month, now.day).add(Duration(days: daysUntilFriday));
  }

  DateTime _getEidDate() {
    // Check service metadata for a fixed Eid date
    final eidDateStr = widget.service.metadata['eidDate']?.toString();
    if (eidDateStr != null) {
      try {
        return DateTime.parse(eidDateStr);
      } catch (_) {}
    }
    // Default to a future date if not specified (e.g., 30 days from now)
    return DateTime.now().add(const Duration(days: 30));
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passportNumberController.dispose();
    _pickupLocationController.dispose();
    _medicalConditionsController.dispose();
    _specialInstructionsController.dispose();
    _specialInformationController.dispose();
    _locationController.dispose();
    _childSpecificNeedsController.dispose();
    super.dispose();
  }

  void _goToStep(int step) {
    _fadeController.reset();
    setState(() {
      _currentStep = step;
      _errorMessage = null;
    });
    _fadeController.forward();
  }

  void _clearError() {
    if (_errorMessage != null) {
      setState(() => _errorMessage = null);
    }
  }

  void _updateBookingSummary() {
    _clearError();
    if (_tourDate != null) {
      TourBookingData bookingData;

      if (_package == TourPackage.jumma) {
        bookingData = JummaBookingData(
          checkIn: _tourDate!,
          checkOut: _tourDate!,
          guests: _adultsCount + _childrenCount + _infantsCount,
          fullName: _fullNameController.text,
          email: _emailController.text,
          phone: _phoneController.text,
          tourDate: _tourDate!,
          travelers: _adultsCount + _childrenCount, // Only paying travelers
          adultTravelers: _adultsCount,
          childTravelers: _childrenCount,
          infantTravelers: _infantsCount,
          location: _locationController.text, // Added
          preferredLocation: _destinationController.text, // Use destination controller
          transportOption: _jummaTransport,
          accommodationType: _accommodationType,
          includeLunch: _includeLunch,
          specialInformation: _specialInformationController.text.isNotEmpty ? _specialInformationController.text : null,
        );
      } else if (_package == TourPackage.eid) {
        bookingData = EidBookingData(
          checkIn: _tourDate!,
          checkOut: _tourDate!.add(Duration(days: _numberOfDays - 1)),
          guests: _adultsCount + _childrenCount + _infantsCount,
          fullName: _fullNameController.text,
          email: _emailController.text,
          phone: _phoneController.text,
          tourDate: _tourDate!,
          location: _locationController.text, // Added
          eidType: _eidType,
          destination: _destinationController.text,
          numberOfDays: _numberOfDays,
          transportOption: _eidTransport,
          hotelRating: _hotelRating,
          activities: _selectedActivities,
          foodPackage: _foodPackage,
          childSpecificNeeds: _childSpecificNeedsController.text.isNotEmpty ? _childSpecificNeedsController.text : null,
          specialInformation: _specialInformationController.text.isNotEmpty ? _specialInformationController.text : null,
          travelers: _adultsCount + _childrenCount, // Only paying travelers
          adultTravelers: _adultsCount,
          childTravelers: _childrenCount,
          infantTravelers: _infantsCount,
        );
      } else if (_package == TourPackage.custom) {
        bookingData = CustomTourBookingData(
          checkIn: _tourDate!,
          checkOut: _tourDate!.add(Duration(days: _numberOfDays - 1)),
          guests: _adultsCount + _childrenCount + _infantsCount,
          fullName: _fullNameController.text,
          email: _emailController.text,
          phone: _phoneController.text,
          tourDate: _tourDate!,
          location: _locationController.text, // Fixed line 269 reference
          travelers: _adultsCount + _childrenCount, // Only paying travelers
          adultTravelers: _adultsCount,
          childTravelers: _childrenCount,
          infantTravelers: _infantsCount,
          destination: _destinationController.text,
          preferredServices: _preferredServices,
          numberOfDays: _numberOfDays,
          notes: _specialInstructionsController.text,
          specialInformation: _specialInformationController.text.isNotEmpty ? _specialInformationController.text : null,
        );
      } else {
        bookingData = TourBookingData(
          checkIn: _tourDate!,
          checkOut: _tourDate!,
          guests: _adultsCount + _childrenCount + _infantsCount,
          fullName: _fullNameController.text,
          email: _emailController.text,
          phone: _phoneController.text,
          tourDate: _tourDate!,
          travelers: _adultsCount + _childrenCount, // Only paying travelers
          adultTravelers: _adultsCount,
          childTravelers: _childrenCount,
          infantTravelers: _infantsCount,
          location: _locationController.text, // Added
          package: _package,
          languageGuide: _languageGuide,
          mealPreference: _mealPreference,
          pickupLocation: _pickupLocationController.text,
          specialInformation: _specialInformationController.text.isNotEmpty ? _specialInformationController.text : null,
        );
      }

      setState(() {
        final settings = ref.read(systemSettingsProvider);
        final packages = ref.read(travelPackagesProvider).value ?? [];
        final selectedPkg = packages.firstWhere(
          (p) => p.key.toLowerCase() == _package.name.toLowerCase(),
          orElse: () => LookupItem(key: _package.name, label: _package.name),
        );
        final multiplier = selectedPkg.multiplier ?? 1.0;

        final activeDiscount = DiscountRepository.getBestDiscount(
          ref.read(discountRepositoryProvider),
          widget.service.id,
          widget.service.providerId,
        );

        _bookingSummary = BookingFormService.calculateTourPrice(
          bookingData,
          widget.service,
          ref.read(activeTaxesProvider),
          platformFeePercentage: settings.platformFee,
          packageMultiplier: multiplier,
          activeOffers: ref.read(activeSpecialOffersProvider),
          activeDiscount: activeDiscount,
        );
      });
    }
  }


  // ── Step 0: Package Specific Details ────────────────────────────────────
  Widget _buildTourDetailsStep() {
    final packages = ref.watch(travelPackagesProvider).value ?? [];
    final selectedPkg = packages.firstWhere(
      (p) => p.key.toLowerCase() == _package.name.toLowerCase(),
      orElse: () => LookupItem(key: _package.name, label: _package.name),
    );
    final multiplier = selectedPkg.multiplier;


    // Pricing info from provider
    final adultPrice = widget.service.adultPrice ?? widget.service.price;
    final childPrice = widget.service.childPrice ?? adultPrice * 0.5;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BookingSectionHeader(
            title: '${_formatPackageName(_package, multiplier)} Details',
            icon: _getPackageIcon(_package),
          ),

          // ── Price Overview Card ──────────────────────────────────────
          Container(
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary,
                  AppColors.primary.withValues(alpha: 0.80),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.sell_outlined,
                            color: Colors.white, size: 18),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Price Overview',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _priceChip(
                        icon: Icons.person_outline,
                        label: 'Adult',
                        sublabel: '15+ yrs',
                        amount: adultPrice,
                      ),
                      const SizedBox(width: 10),
                      _priceChip(
                        icon: Icons.child_care_outlined,
                        label: 'Child',
                        sublabel: '2–14 yrs',
                        amount: childPrice,
                      ),
                      const SizedBox(width: 10),
                      _priceChip(
                        icon: Icons.baby_changing_station_outlined,
                        label: 'Infant',
                        sublabel: 'Under 2',
                        amount: 0,
                        isFree: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline,
                            color: Colors.white70, size: 14),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Price per person · Final total shown below',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // ─────────────────────────────────────────────────────────────

          DatePickerTile(
            label: _package == TourPackage.custom ? 'Start Date' : 'Tour Date',
            value: _tourDate != null
                ? DateFormat('EEE, MMM d, yyyy').format(_tourDate!)
                : null,
            onTap: (_package == TourPackage.jumma || _package == TourPackage.eid) ? null : () => _selectTourDate(),
          ),
          if (_package == TourPackage.jumma || _package == TourPackage.eid)
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 12),
              child: Text(
                'Note: Date is automatically selected for this package.',
                style: TextStyle(color: AppColors.primary, fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ),
          if (_package == TourPackage.custom) ...[
            const SizedBox(height: 16),
            CounterRow(
              label: 'Tourism Days',
              subtitle: 'Select duration (1 - 30 days)',
              value: _numberOfDays,
              onDecrement: () => setState(() {
                if (_numberOfDays > 1) {
                  _numberOfDays--;
                  _updateBookingSummary();
                }
              }),
              onIncrement: () => setState(() {
                if (_numberOfDays < 30) {
                  _numberOfDays++;
                  _updateBookingSummary();
                }
              }),
            ),
          ],
          const SizedBox(height: 24),
          if (_package == TourPackage.jumma)
            _buildPackageSpecificSection('Juma Package Details', _buildJummaFields()),
          if (_package == TourPackage.eid)
            _buildPackageSpecificSection('${_formatPackageName(_package, multiplier)} Details', _buildEidFields()),
          
          _buildPackageSpecificSection(
            '${_formatPackageName(_package, multiplier)} Preferences', 
            _buildCustomFields()
          ),
          const SizedBox(height: 24),
          CounterRow(
            label: 'Adults',
            subtitle: '15 years and older',
            value: _adultsCount,
            onDecrement: () => setState(() {
              if (_adultsCount > 1) {
                _adultsCount--;
                _updateBookingSummary();
              }
            }),
            onIncrement: () => setState(() {
              final metadataTravelers = widget.service.metadata['maxTravelers'] != null 
                  ? int.tryParse(widget.service.metadata['maxTravelers'].toString()) 
                  : null;
              final maxTravelers = metadataTravelers ?? 100;

              if (_adultsCount + _childrenCount + _infantsCount < maxTravelers) {
                _adultsCount++;
                _updateBookingSummary();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Maximum travelers reached for this tour.')),
                );
              }
            }),
          ),
          const SizedBox(height: 16),
          CounterRow(
            label: 'Children',
            subtitle: '2 - 14 years old',
            value: _childrenCount,
            onDecrement: () => setState(() {
              if (_childrenCount > 0) {
                _childrenCount--;
                _updateBookingSummary();
              }
            }),
            onIncrement: () => setState(() {
              final metadataTravelers = widget.service.metadata['maxTravelers'] != null 
                  ? int.tryParse(widget.service.metadata['maxTravelers'].toString()) 
                  : null;
              final maxTravelers = metadataTravelers ?? 100;

              if (_adultsCount + _childrenCount + _infantsCount < maxTravelers) {
                _childrenCount++;
                _updateBookingSummary();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Maximum travelers reached for this tour.')),
                );
              }
            }),
          ),
          const SizedBox(height: 16),
          CounterRow(
            label: 'Infants',
            subtitle: 'Under 2 years old (Free)',
            value: _infantsCount,
            onDecrement: () => setState(() {
              if (_infantsCount > 0) {
                _infantsCount--;
                _updateBookingSummary();
              }
            }),
            onIncrement: () => setState(() {
              final metadataTravelers = widget.service.metadata['maxTravelers'] != null 
                  ? int.tryParse(widget.service.metadata['maxTravelers'].toString()) 
                  : null;
              final maxTravelers = metadataTravelers ?? 100;

              if (_adultsCount + _childrenCount + _infantsCount < maxTravelers) {
                _infantsCount++;
                _updateBookingSummary();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Maximum travelers reached for this tour.')),
                );
              }
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildPackageSpecificSection(String title, Widget content) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 20),
          content,
        ],
      ),
    );
  }

  Widget _buildJummaFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoTile('Location', _preferredLocation, Icons.location_on_outlined),
        const SizedBox(height: 12),
        _buildInfoTile('Transport', _jummaTransport, Icons.directions_bus_outlined),
        const SizedBox(height: 12),
        _buildInfoTile('Accommodation', _accommodationType, Icons.hotel_outlined),
        const SizedBox(height: 12),
        _buildInfoTile('Lunch Included', _includeLunch ? 'Yes' : 'No', Icons.restaurant_outlined),
      ],
    );
  }

  Widget _buildEidFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoTile('Package Type', _eidType, Icons.card_giftcard_outlined),
        const SizedBox(height: 12),
        _buildInfoTile('Destination', _destinationController.text.isNotEmpty ? _destinationController.text : 'Fixed Destination', Icons.map_outlined),
        const SizedBox(height: 12),
        _buildInfoTile('Duration', '$_numberOfDays Days', Icons.timer_outlined),
        const SizedBox(height: 12),
        _buildInfoTile('Transport', _eidTransport, Icons.directions_bus_outlined),
        const SizedBox(height: 12),
        _buildInfoTile('Food Package', _foodPackage, Icons.restaurant_outlined),
        const Divider(height: 32),
        _premiumTextField(
          controller: _childSpecificNeedsController,
          label: 'Child Specific Needs (Optional)',
          icon: Icons.child_care_outlined,
        ),
      ],
    );
  }

  Widget _buildCustomFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _premiumTextField(
          controller: _locationController,
          label: 'Location (Where you live)',
          icon: Icons.location_on_outlined,
        ),
        const SizedBox(height: 16),
        _premiumTextField(
          controller: _destinationController,
          label: 'Destination',
          icon: Icons.map_outlined,
        ),
        const SizedBox(height: 16),
        if (_package == TourPackage.custom) ...[
          const Text('Preferred Services', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ['Guide', 'Private Transport', 'Photographer', 'VIP Access', 'Translator'].map((service) {
              final isSelected = _preferredServices.contains(service);
              return FilterChip(
                label: Text(service),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _preferredServices.add(service);
                    } else {
                      _preferredServices.remove(service);
                    }
                    _updateBookingSummary();
                  });
                },
                selectedColor: AppColors.primary.withValues(alpha: 0.2),
                checkmarkColor: AppColors.primary,
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
        ],
        _premiumTextField(
          controller: _specialInformationController,
          label: 'Special Information (Optional)',
          icon: Icons.info_outline,
          hint: 'Any additional information you may need',
        ),
      ],
    );
  }

  Widget _buildInfoTile(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
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
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String value,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: value,
          items: items.map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(),
          onChanged: onChanged,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Colors.grey[50],
          ),
        ),
      ],
    );
  }


  // ── Step 1: Traveler(s) Info ───────────────────────────────────────────
  Widget _buildTravelerInfoStep() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BookingSectionHeader(
            title: 'Lead Traveler',
            icon: Icons.person_outline,
          ),
          _premiumTextField(
            controller: _fullNameController,
            label: 'Full Name',
            icon: Icons.badge_outlined,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _premiumTextField(
                  controller: _emailController,
                  label: 'Email',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _premiumTextField(
                  controller: _phoneController,
                  label: 'Phone',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Additional Travelers',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
              TextButton.icon(
                onPressed: _addTraveler,
                icon: const Icon(Icons.add),
                label: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _additionalTravelers.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) => _buildTravelerCard(index),
          ),
          if (_additionalTravelers.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text('No additional travelers added', style: TextStyle(color: Colors.grey[500], fontStyle: FontStyle.italic)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTravelerCard(int index) {
    final controllers = _additionalTravelers[index];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Traveler ${index + 2}', style: const TextStyle(fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                onPressed: () => _removeTraveler(index),
              ),
            ],
          ),
          _premiumTextField(
            controller: controllers['name']!,
            label: 'Full Name',
            icon: Icons.person_outline,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _premiumTextField(
                  controller: controllers['age']!,
                  label: 'Age',
                  icon: Icons.cake_outlined,
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDropdownField(
                  label: 'Gender',
                  value: controllers['gender']!.text.isEmpty ? 'Male' : controllers['gender']!.text,
                  items: ['Male', 'Female', 'Other'],
                  onChanged: (v) => setState(() => controllers['gender']!.text = v!),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _addTraveler() {
    setState(() {
      _additionalTravelers.add({
        'name': TextEditingController(),
        'age': TextEditingController(),
        'gender': TextEditingController(text: 'Male'),
        'passport': TextEditingController(),
      });
    });
  }

  void _removeTraveler(int index) {
    setState(() {
      for (final controller in _additionalTravelers[index].values) {
        controller.dispose();
      }
      _additionalTravelers.removeAt(index);
    });
  }

  // ── Step 2: Options & Preferences ───────────────────────────────────────
  Widget _buildPreferencesStep() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BookingSectionHeader(
            title: 'Tour Preferences',
            icon: Icons.settings_outlined,
          ),
          const Text(
            'Language Guide',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<LanguageGuide>(
            initialValue: _languageGuide,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.translate, color: AppColors.primary),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.grey[50],
            ),
            items: LanguageGuide.values
                .map(
                  (lang) => DropdownMenuItem(
                    value: lang,
                    child: Text(_formatLanguageName(lang)),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => _languageGuide = v!),
          ),
          const SizedBox(height: 20),
          const Text(
            'Meal Preference',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<MealPreference>(
            initialValue: _mealPreference,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.restaurant, color: AppColors.primary),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.grey[50],
            ),
            items: MealPreference.values
                .map(
                  (meal) => DropdownMenuItem(
                    value: meal,
                    child: Text(_formatMealName(meal)),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => _mealPreference = v!),
          ),
          const SizedBox(height: 20),
          _premiumTextField(
            controller: _pickupLocationController,
            label: 'Pickup Location',
            icon: Icons.location_on_outlined,
            hint: 'Hotel name, airport, or address',
            onChanged: (v) => _clearError(),
          ),
        ],
      ),
    );
  }

  // ── Step 3: Health & Safety ──────────────────────────────────────────────
  Widget _buildHealthSafetyStep() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BookingSectionHeader(
            title: 'Health & Safety',
            icon: Icons.health_and_safety_outlined,
          ),
          const InfoBanner(
            text:
                'Please inform us of any medical conditions or allergies for your safety.',
            color: Colors.orange,
            icon: Icons.warning_amber_rounded,
          ),
          const SizedBox(height: 20),
          _premiumTextField(
            controller: _medicalConditionsController,
            label: 'Medical Conditions (Optional)',
            icon: Icons.healing_outlined,
          ),
          const SizedBox(height: 14),
          _premiumTextField(
            controller: _specialInstructionsController,
            label: 'Special Requests',
            icon: Icons.note_alt_outlined,
            hint: 'Any specific needs or requests?',
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.info.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Tour Safety Notice',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                SizedBox(height: 8),
                Text(
                  '• Always follow the guide\'s instructions.\n'
                  '• Stay with the group at all times.\n'
                  '• Weather may affect tour schedule.\n'
                  '• Emergency contact details provided at start.',
                  style: TextStyle(fontSize: 13, height: 1.6),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Helper Widgets ──────────────────────────────────────────────────────

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildTourDetailsStep();
      case 1:
        return _buildTravelerInfoStep();
      case 2:
        return _package == TourPackage.custom
            ? _buildPreferencesStep()
            : _buildHealthSafetyStep();
      case 3:
        return _buildHealthSafetyStep();
      default:
        return const SizedBox.shrink();
    }
  }

  // ── Price Chip Helper ───────────────────────────────────────────────────
  Widget _priceChip({
    required IconData icon,
    required String label,
    required String sublabel,
    required double amount,
    bool isFree = false,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.white70, size: 14),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              sublabel,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.65),
                fontSize: 10,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isFree ? 'Free' : '\$${amount.toStringAsFixed(2)}',
              style: TextStyle(
                color: isFree ? const Color(0xFF90EE90) : Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  TextFormField _premiumTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
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
        hintText: hint,
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
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  IconData _getPackageIcon(TourPackage pkg) {
    switch (pkg) {
      case TourPackage.jumma:
        return Icons.mosque_outlined;
      case TourPackage.eid:
        return Icons.celebration_outlined;
      case TourPackage.custom:
        return Icons.edit_note_outlined;
    }
  }

  String _formatPackageName(TourPackage package, [double? multiplier]) {
    switch (package) {
      case TourPackage.jumma:
        return 'Juma Package';
      case TourPackage.eid:
        final percentage = multiplier != null && multiplier > 1.0
            ? ' (+${((multiplier - 1.0) * 100).toStringAsFixed(0)}%)'
            : '';
        return 'Eid Package$percentage';
      case TourPackage.custom:
        return 'Custom Package';
    }
  }


  String _formatLanguageName(LanguageGuide lang) {
    switch (lang) {
      case LanguageGuide.english:
        return 'English';
      case LanguageGuide.somali:
        return 'Somali';
      case LanguageGuide.arabic:
        return 'Arabic';
      case LanguageGuide.italian:
        return 'Italian';
    }
  }

  String _formatMealName(MealPreference meal) {
    switch (meal) {
      case MealPreference.somaliTraditional:
        return '🍖 Somali Traditional';
      case MealPreference.seafood:
        return '🐟 Seafood';
      case MealPreference.grilled:
        return '🥩 Grilled & BBQ';
      case MealPreference.vegetarian:
        return '🥗 Vegetarian';
      case MealPreference.noPreference:
        return '🍽️ No Preference';
    }
  }

  Future<void> _selectTourDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _tourDate ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now().add(const Duration(days: 1)),
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
        _tourDate = picked;
        _updateBookingSummary();
      });
    }
  }

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0:
        if (_tourDate == null) {
          setState(() => _errorMessage = 'Please select a tour date');
          return false;
        }
        return true;
      case 1:
      case 2:
      case 3:
        return true; // All steps after date selection are optional
      default:
        return false;
    }
  }

  void _nextStep() {
    setState(() => _errorMessage = null);

    if (_validateCurrentStep()) {
      final maxStep = _package == TourPackage.custom ? 3 : 2;
      if (_currentStep < maxStep) {
        _goToStep(_currentStep + 1);
      } else {
        _submitBooking();
      }
    } else {
      if (_errorMessage == null) {
        setState(() {
          if (_currentStep == 0) {
            _errorMessage = 'Please select a tour date and package';
          } else if (_currentStep == 1) {
            _errorMessage = 'Please provide valid traveler information';
          } else if (_currentStep == 2) {
            _errorMessage = 'Please complete all tour preferences';
          } else {
            _errorMessage = 'Please fill in all required fields to proceed';
          }
        });
      }
    }
  }

  Future<void> _submitBooking() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      _updateBookingSummary();
      if (_bookingSummary == null) {
        setState(() {
          _errorMessage = 'Please select a tour date first';
          _isLoading = false;
        });
        return;
      }

      final travelersList = <TravelerDetail>[
        TravelerDetail(
          name: _fullNameController.text,
          age: 30, // Default for lead
          gender: 'Male', // Default
        ),
      ];

      for (var t in _additionalTravelers) {
        travelersList.add(TravelerDetail(
          name: t['name']!.text,
          age: int.tryParse(t['age']!.text) ?? 20,
          gender: t['gender']!.text,
        ));
      }

      final metadata = <String, dynamic>{
        'package_type': _package.name,
        'serviceType': 'tour',
      };

      if (_package == TourPackage.jumma) {
        metadata.addAll({
          'preferredLocation': _preferredLocation,
          'transportOption': _jummaTransport,
          'accommodationType': _accommodationType,
          'includeLunch': _includeLunch,
          'specialInformation': _specialInformationController.text,
        });
      } else if (_package == TourPackage.eid) {
        metadata.addAll({
          'eidType': _eidType,
          'destination': _destinationController.text,
          'numberOfDays': _numberOfDays,
          'transportOption': _eidTransport,
          'hotelRating': _hotelRating,
          'activities': _selectedActivities,
          'foodPackage': _foodPackage,
          'childSpecificNeeds': _childSpecificNeedsController.text,
          'specialInformation': _specialInformationController.text,
        });
      } else if (_package == TourPackage.custom) {
        metadata.addAll({
          'location': _locationController.text,
          'destination': _destinationController.text,
          'preferredServices': _preferredServices,
        });
      }

      // Add age breakdown to metadata
      metadata.addAll({
        'adultsCount': _adultsCount,
        'childrenCount': _childrenCount,
        'infantsCount': _infantsCount,
        'totalTravelers': _adultsCount + _childrenCount + _infantsCount,
      });

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EnhancedPaymentScreen(
            serviceId: widget.service.id,
            providerId: widget.service.providerId,
            serviceTitle: widget.service.title,
            serviceType: ServiceType.tour,
            basePrice: widget.service.price,
            checkIn: _tourDate!,
            checkOut: _tourDate!.add(Duration(days: _numberOfDays - 1)),
            guests: travelersList.length,
            rooms: 1,
            totalPrice: _bookingSummary!.totalPrice,
            contactName: _fullNameController.text,
            contactEmail: _emailController.text,
            contactPhone: _phoneController.text,
            location: _locationController.text,
            specialRequests: _specialInstructionsController.text,
            travelers: travelersList,
            metadata: metadata,
          ),
        ),
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
        _isLoading = false;
      });
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
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildHeader(),
                BookingStepIndicator(
                  totalSteps: _package == TourPackage.custom ? 4 : 3,
                  currentStep: _currentStep,
                  stepLabels: _stepLabels,
                ),
                if (_errorMessage != null) ErrorBanner(message: _errorMessage!),
                Expanded(
                  child: Form(
                    key: _formKey,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          if (_currentStep == 0)
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
                if (_bookingSummary != null && _currentStep > 0)
                  LivePriceSummaryBar(summary: _bookingSummary!),
                BookingNavControls(
                  isFirstStep: _currentStep == 0,
                  isLastStep:
                      _currentStep == (_package == TourPackage.custom ? 3 : 2),
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
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Booking Tour Package',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 12,
                      ),
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
}
