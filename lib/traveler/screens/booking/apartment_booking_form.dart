import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/booking_forms_model.dart';
import '../../../shared/services/booking_form_service.dart';
import '../../../shared/services/special_offer_repository.dart';
import '../../../shared/services/auth_service.dart';
import 'widgets/booking_form_widgets.dart';
import 'enhanced_payment_screen.dart';
import '../../../shared/models/service_model.dart';
import '../../../shared/services/tax_repository.dart';
import '../../../shared/services/system_settings_repository.dart';
import '../../../shared/services/user_repository.dart';
import '../../../shared/models/user_model.dart';
import '../../../shared/services/discount_repository.dart';


 class ApartmentBookingForm extends ConsumerStatefulWidget {
   final Service service;
 
   ApartmentBookingForm({
     required this.service,
     super.key,
   });
 
   @override
   ConsumerState<ApartmentBookingForm> createState() =>
       _ApartmentBookingFormState();
 }

class _ApartmentBookingFormState extends ConsumerState<ApartmentBookingForm>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  int _currentStep = 0;
  bool _isLoading = false;
  String? _errorMessage;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // Reservation
  DateTime? _checkInDate;
  DateTime? _checkOutDate;
  int _guests = 2;

  // Guest Details
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  // Stay Purpose
  StayPurpose _stayPurpose = StayPurpose.vacation;

  // Add-ons
  bool _cleaningService = false;
  bool _earlyCheckIn = false;
  bool _lateCheckout = false;
  final _specialRequestsController = TextEditingController();
  bool _acceptHouseRules = false;

  BookingSummary? _bookingSummary;

  static const _stepLabels = ['Dates', 'Guest', 'Purpose', 'Add-ons'];

  @override
  void initState() {
    super.initState();
    // Pre-fill guest info from profile
     // Pre-fill from metadata
    final metadata = widget.service.metadata;
    
    if (metadata['stayPurpose'] != null) {
      final purpose = metadata['stayPurpose'].toString().toLowerCase();
      if (purpose.contains('bus')) {
        _stayPurpose = StayPurpose.business;
      } else if (purpose.contains('fam')) {
        _stayPurpose = StayPurpose.family;
      } else if (purpose.contains('long')) {
        _stayPurpose = StayPurpose.longTerm;
      }
    }

    // Add-ons are off by default
    _cleaningService = false;
    _earlyCheckIn = false;
    _lateCheckout = false;

    final user = ref.read(authProvider);
    if (user != null) {
      _fullNameController.text = user.name;
      _emailController.text = user.email;
      _phoneController.text = user.phone ?? '';
    }

    // Dates start null — customer must select them manually

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
    _specialRequestsController.dispose();
    super.dispose();
  }

  void _updateBookingSummary() {
    if (_checkInDate != null && _checkOutDate != null) {
        final provider = ref.watch(userProvider).firstWhere(
          (u) => u.id == widget.service.providerId,
          orElse: () => User(id: '', name: '', email: '', password: '', role: UserRole.traveler),
        );

        final bookingData = ApartmentBookingData(
          checkIn: _checkInDate!,
          checkOut: _checkOutDate!,
          guests: _guests,
          fullName: _fullNameController.text,
          email: _emailController.text,
          phone: _phoneController.text,
          stayPurpose: _stayPurpose,
          cleaningService: _cleaningService,
          earlyCheckIn: _earlyCheckIn,
          lateCheckout: _lateCheckout,
          acceptHouseRules: _acceptHouseRules,
          cleaningPrice: widget.service.cleaningPrice ?? 
              double.tryParse(provider.metadata['cleaning_price']?.toString() ?? '') ?? 0.0,
          earlyCheckInPrice: widget.service.earlyCheckInPrice ?? 
              double.tryParse(provider.metadata['early_checkin_price']?.toString() ?? '') ?? 0.0,
          lateCheckoutPrice: widget.service.lateCheckoutPrice ?? 
              double.tryParse(provider.metadata['late_checkout_price']?.toString() ?? '') ?? 0.0,
          pricingType: widget.service.pricingType,
        );
        final activeDiscount = DiscountRepository.getBestDiscount(
          ref.read(discountRepositoryProvider),
          widget.service.id,
          widget.service.providerId,
        );

        setState(() {
          _bookingSummary = BookingFormService.calculateApartmentPrice(
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

  // ── Step 0: Reservation ──────────────────────────────────────────────────
  Widget _buildReservationStep() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BookingSectionHeader(
            title: 'Reservation Info',
            icon: Icons.apartment,
          ),
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
          if (_checkInDate != null && _checkOutDate != null) ...[
            const SizedBox(height: 10),
            InfoBanner(
              text:
                  _nights >= 30 
                  ? '$_nights nights · ~${(_nights / 30).toStringAsFixed(1)} months · '
                    '${DateFormat('MMM d').format(_checkInDate!)} → ${DateFormat('MMM d').format(_checkOutDate!)}'
                  : '$_nights night${_nights > 1 ? 's' : ''} · '
                    '${DateFormat('MMM d').format(_checkInDate!)} → ${DateFormat('MMM d').format(_checkOutDate!)}',
              color: AppColors.info,
              icon: Icons.nights_stay_outlined,
            ),
          ],
          const SizedBox(height: 20),
          CounterRow(
            label: 'Guests',
            subtitle: 'Max capacity: ${widget.service.maxGuests ?? widget.service.metadata['max_guests'] ?? widget.service.metadata['maxGuests'] ?? 'N/A'} guests',
            value: _guests,
            maxValue: widget.service.maxGuests ?? 
                int.tryParse(widget.service.metadata['max_guests']?.toString() ?? '') ?? 
                int.tryParse(widget.service.metadata['maxGuests']?.toString() ?? '') ?? 10,
            onDecrement: () => setState(() {
              _guests--;
              _updateBookingSummary();
            }),
            onIncrement: () => setState(() {
              _guests++;
              _updateBookingSummary();
            }),
          ),
        ],
      ),
    );
  }

  // ── Step 1: Guest Details ────────────────────────────────────────────────
  Widget _buildGuestDetailsStep() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BookingSectionHeader(
            title: 'Guest Details',
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
        ],
      ),
    );
  }

  // ── Step 2: Stay Purpose ─────────────────────────────────────────────────
  Widget _buildStayPurposeStep() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BookingSectionHeader(
            title: 'Purpose of Stay',
            icon: Icons.travel_explore,
          ),
          ...StayPurpose.values.map(
            (purpose) => _buildOptionCard<StayPurpose>(
              value: purpose,
              groupValue: _stayPurpose,
              title: _formatStayPurpose(purpose),
              subtitle: _getStayPurposeDescription(purpose),
              icon: _getStayPurposeIcon(purpose),
              onTap: () => setState(() {
                _stayPurpose = purpose;
                _updateBookingSummary();
              }),
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 3: Add-ons ──────────────────────────────────────────────────────
  Widget _buildAddonsStep() {
    final provider = ref.watch(userProvider).firstWhere(
          (u) => u.id == widget.service.providerId,
          orElse: () => User(id: '', name: '', email: '', password: '', role: UserRole.traveler),
        );
    final cPrice = widget.service.cleaningPrice ??
        double.tryParse(provider.metadata['cleaning_price']?.toString() ?? '') ?? 0.0;
    final ePrice = widget.service.earlyCheckInPrice ??
        double.tryParse(provider.metadata['early_checkin_price']?.toString() ?? '') ?? 0.0;
    final lPrice = widget.service.lateCheckoutPrice ??
        double.tryParse(provider.metadata['late_checkout_price']?.toString() ?? '') ?? 0.0;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BookingSectionHeader(
            title: 'Add-ons & Agreement',
            icon: Icons.add_box_outlined,
          ),
                if (cPrice > 0)
                  PremiumSwitchTile(
                    title: 'Cleaning Service',
                    subtitle: 'One-time professional cleaning · \$$cPrice',
                    value: _cleaningService,
                    icon: Icons.cleaning_services_outlined,
                    onChanged: (v) => setState(() {
                      _cleaningService = v;
                      _updateBookingSummary();
                    }),
                  ),
                if (ePrice > 0)
                  PremiumSwitchTile(
                    title: 'Early Check-in',
                    subtitle: 'Check-in before 2 PM · \$$ePrice',
                    value: _earlyCheckIn,
                    icon: Icons.wb_sunny_outlined,
                    onChanged: (v) => setState(() {
                      _earlyCheckIn = v;
                      _updateBookingSummary();
                    }),
                  ),
                if (lPrice > 0)
                  PremiumSwitchTile(
                    title: 'Late Checkout',
                    subtitle: 'Checkout after 12 PM · \$$lPrice',
                    value: _lateCheckout,
                    icon: Icons.nightlight_outlined,
                    onChanged: (v) => setState(() {
                      _lateCheckout = v;
                      _updateBookingSummary();
                    }),
                  ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _specialRequestsController,
            decoration: InputDecoration(
              labelText: 'Special Requests (Optional)',
              hintText: 'Anything we should know...',
              prefixIcon: const Icon(Icons.comment_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey[50],
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 16),

          // House Rules
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.gavel, color: Colors.orange[700], size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'House Rules',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange[800],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  '• No smoking inside\n'
                  '• No parties after 10 PM\n'
                  '• Respect neighbors & property\n'
                  '• Report any damages immediately',
                  style: TextStyle(fontSize: 13, height: 1.6),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Checkbox(
                      value: _acceptHouseRules,
                      activeColor: AppColors.primary,
                      onChanged: (v) => setState(() {
                        _acceptHouseRules = v!;
                        _updateBookingSummary();
                      }),
                    ),
                    const Expanded(
                      child: Text(
                        'I accept and agree to follow the house rules',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
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

  Widget _buildOptionCard<T>({
    required T value,
    required T groupValue,
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final isSelected = value == groupValue;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.06)
              : Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey[200]!,
            width: isSelected ? 2 : 1,
          ),
        ),
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
                    subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: isSelected
                  ? const Icon(
                      Icons.check_circle,
                      color: AppColors.primary,
                      key: ValueKey(true),
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
      builder: (c, child) => Theme(
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
        _updateBookingSummary();
      });
    }
  }

  Future<void> _selectCheckOutDate() async {
    final DateTime firstPossible =
        _checkInDate?.add(const Duration(days: 1)) ??
        DateTime.now().add(const Duration(days: 1));

    // Ensure initialDate is not before firstDate
    DateTime initial =
        _checkOutDate ?? DateTime.now().add(const Duration(days: 4));
    if (initial.isBefore(firstPossible)) {
      initial = firstPossible;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstPossible,
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (c, child) => Theme(
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
    }
  }

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _checkInDate != null && _checkOutDate != null;
      case 1:
        return _formKey.currentState?.validate() ?? false;
      case 2:
        return true;
      case 3:
        if (!_acceptHouseRules) {
          setState(() => _errorMessage = 'You must accept the house rules');
          return false;
        }
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
      if (_errorMessage == null) {
        setState(() {
          _errorMessage = _currentStep == 0
              ? 'Please select check-in and check-out dates'
              : 'Please fill in all required fields';
        });
      }
    }
  }

  Future<void> _submitBooking() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final provider = ref.watch(userProvider).firstWhere(
        (u) => u.id == widget.service.providerId,
        orElse: () => User(id: '', name: '', email: '', password: '', role: UserRole.traveler),
      );

      final bookingData = ApartmentBookingData(
        checkIn: _checkInDate!,
        checkOut: _checkOutDate!,
        guests: _guests,
        fullName: _fullNameController.text,
        email: _emailController.text,
        phone: _phoneController.text,
        stayPurpose: _stayPurpose,
        cleaningService: _cleaningService,
        earlyCheckIn: _earlyCheckIn,
        lateCheckout: _lateCheckout,
        acceptHouseRules: _acceptHouseRules,
        cleaningPrice: widget.service.cleaningPrice ?? 
            double.tryParse(provider.metadata['cleaning_price']?.toString() ?? '') ?? 0.0,
        earlyCheckInPrice: widget.service.earlyCheckInPrice ?? 
            double.tryParse(provider.metadata['early_checkin_price']?.toString() ?? '') ?? 0.0,
        lateCheckoutPrice: widget.service.lateCheckoutPrice ?? 
            double.tryParse(provider.metadata['late_checkout_price']?.toString() ?? '') ?? 0.0,
        pricingType: widget.service.pricingType,
        specialRequests: _specialRequestsController.text.isEmpty
            ? null
            : _specialRequestsController.text,
      );

      final validation = BookingFormService.validateApartmentBooking(
        bookingData,
      );
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
            serviceType: ServiceType.apartment,
            basePrice: widget.service.price,
            checkIn: bookingData.checkIn,
            checkOut: bookingData.checkOut,
            guests: bookingData.guests,
            rooms: 1,
            totalPrice: _bookingSummary!.totalPrice,
            taxes: _bookingSummary!.taxes,
            extras: _bookingSummary!.extras,
            contactName: bookingData.fullName,
            contactEmail: bookingData.email,
            contactPhone: bookingData.phone,
            specialRequests: bookingData.specialRequests,
            acceptHouseRules: bookingData.acceptHouseRules,
            metadata: {
              'serviceType': 'apartment',
            },
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

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildReservationStep();
      case 1:
        return _buildGuestDetailsStep();
      case 2:
        return _buildStayPurposeStep();
      case 3:
        return _buildAddonsStep();
      default:
        return const SizedBox.shrink();
    }
  }

  String _formatStayPurpose(StayPurpose p) {
    switch (p) {
      case StayPurpose.business:
        return 'Business';
      case StayPurpose.vacation:
        return 'Vacation';
      case StayPurpose.family:
        return 'Family Stay';
      case StayPurpose.longTerm:
        return 'Long-term Stay';
    }
  }

  String _getStayPurposeDescription(StayPurpose p) {
    switch (p) {
      case StayPurpose.business:
        return 'Work-related stay with flexible check-in';
      case StayPurpose.vacation:
        return 'Leisure and relaxation';
      case StayPurpose.family:
        return 'Family-friendly, extra amenities available';
      case StayPurpose.longTerm:
        return 'Extended stay with special rates';
    }
  }

  IconData _getStayPurposeIcon(StayPurpose p) {
    switch (p) {
      case StayPurpose.business:
        return Icons.work_outline;
      case StayPurpose.vacation:
        return Icons.beach_access;
      case StayPurpose.family:
        return Icons.family_restroom;
      case StayPurpose.longTerm:
        return Icons.calendar_month_outlined;
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
                _buildHeader(),
                BookingStepIndicator(
                  totalSteps: 4,
                  currentStep: _currentStep,
                  stepLabels: _stepLabels,
                ),
                if (_errorMessage != null) ErrorBanner(message: _errorMessage!),
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
                if (_bookingSummary != null && _currentStep > 0)
                  LivePriceSummaryBar(summary: _bookingSummary!),
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
                      'Apartment Booking',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.apartment, color: Colors.white, size: 28),
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
        const Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: AppColors.primary),
                SizedBox(height: 20),
                Text(
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
