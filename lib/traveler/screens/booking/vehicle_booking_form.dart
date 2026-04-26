import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/booking_forms_model.dart';
import '../../../shared/services/booking_form_service.dart';
import '../../../shared/services/auth_service.dart';
import 'widgets/booking_form_widgets.dart';
import 'enhanced_payment_screen.dart';
import '../../../shared/services/tax_repository.dart';
import '../../../shared/services/system_settings_repository.dart';
import '../../../shared/models/service_model.dart';
import '../../../shared/services/special_offer_repository.dart';
import '../../../shared/services/discount_repository.dart';


class VehicleBookingForm extends ConsumerStatefulWidget {
  final Service service;

  const VehicleBookingForm({
    required this.service,
    super.key,
  });

  @override
  ConsumerState<VehicleBookingForm> createState() => _VehicleBookingFormState();
}

class _VehicleBookingFormState extends ConsumerState<VehicleBookingForm>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  int _currentStep = 0;
  bool _isLoading = false;
  String? _errorMessage;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // Rental Details
  DateTime? _pickupDateTime;
  DateTime? _returnDateTime;
  final _pickupLocationController = TextEditingController();
  final _dropoffLocationController = TextEditingController();

  // Driver Info
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _driverLicenseNumberController = TextEditingController();
  DateTime? _licenseExpiryDate;

  // Vehicle Options
  DriverOption _driverOption = DriverOption.selfDrive;
  InsuranceOption _insuranceOption = InsuranceOption.none;
  bool _childSeat = false;

  // Agreement
  bool _acceptRentalTerms = false;

  BookingSummary? _bookingSummary;

  static const _stepLabels = ['Rental', 'Driver', 'Options', 'Terms'];

  @override
  void initState() {
    super.initState();
    // Pre-fill driver info from profile
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
    _pickupLocationController.dispose();
    _dropoffLocationController.dispose();
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _driverLicenseNumberController.dispose();
    super.dispose();
  }

  void _updateBookingSummary() {
    if (_pickupDateTime != null && _returnDateTime != null) {
      final data = VehicleBookingData(
        checkIn: _pickupDateTime!,
        checkOut: _returnDateTime!,
        guests: 1,
        fullName: _fullNameController.text,
        email: _emailController.text,
        phone: _phoneController.text,
        pickupDateTime: _pickupDateTime!,
        returnDateTime: _returnDateTime!,
        pickupLocation: _pickupLocationController.text,
        dropoffLocation: _dropoffLocationController.text,
        driverLicenseNumber: _driverLicenseNumberController.text,
        licenseExpiryDate:
            _licenseExpiryDate ?? DateTime.now().add(const Duration(days: 365)),
        driverOption: _driverOption,
        insuranceOption: _insuranceOption,
        childSeat: _childSeat,
        acceptRentalTerms: _acceptRentalTerms,
      );
      final activeDiscount = DiscountRepository.getBestDiscount(
        ref.read(discountRepositoryProvider),
        widget.service.id,
        widget.service.providerId,
      );

      setState(() {
        _bookingSummary = BookingFormService.calculateVehiclePrice(
          data,
          widget.service,
          ref.read(activeTaxesProvider),
          platformFeePercentage: ref.read(systemSettingsProvider).platformFee,
          activeOffers: ref.read(activeSpecialOffersProvider),
          activeDiscount: activeDiscount,
        );
      });
    }
  }

  int get _rentalDays {
    if (_pickupDateTime != null && _returnDateTime != null) {
      final d = _returnDateTime!.difference(_pickupDateTime!).inDays;
      return d < 1 ? 1 : d;
    }
    return 1;
  }

  // ── Step 0: Rental Details ───────────────────────────────────────────────
  Widget _buildRentalDetailsStep() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BookingSectionHeader(
            title: 'Rental Details',
            icon: Icons.directions_car_outlined,
          ),
          DatePickerTile(
            label: 'Pickup Date & Time',
            value: _pickupDateTime != null
                ? DateFormat(
                    'EEE, MMM d, yyyy · HH:mm',
                  ).format(_pickupDateTime!)
                : null,
            icon: Icons.schedule,
            onTap: _selectPickupDateTime,
          ),
          const SizedBox(height: 12),
          DatePickerTile(
            label: 'Return Date & Time',
            value: _returnDateTime != null
                ? DateFormat(
                    'EEE, MMM d, yyyy · HH:mm',
                  ).format(_returnDateTime!)
                : null,
            icon: Icons.schedule_send,
            onTap: _selectReturnDateTime,
          ),
          if (_pickupDateTime != null && _returnDateTime != null) ...[
            const SizedBox(height: 10),
            InfoBanner(
              text:
                  '$_rentalDays day${_rentalDays > 1 ? 's' : ''} rental · '
                  '${DateFormat('MMM d').format(_pickupDateTime!)} → '
                  '${DateFormat('MMM d').format(_returnDateTime!)}',
              color: AppColors.info,
              icon: Icons.timer_outlined,
            ),
          ],
          const SizedBox(height: 20),
          _premiumTextField(
            controller: _pickupLocationController,
            label: 'Pickup Location *',
            hint: 'Airport, hotel, or address',
            icon: Icons.location_on_outlined,
            validator: (v) => v?.trim().isEmpty ?? true
                ? 'Pickup location is required'
                : null,
            onChanged: (_) => _updateBookingSummary(),
          ),
          const SizedBox(height: 14),
          _premiumTextField(
            controller: _dropoffLocationController,
            label: 'Drop-off Location *',
            hint: 'Same or different from pickup',
            icon: Icons.location_off_outlined,
            validator: (v) => v?.trim().isEmpty ?? true
                ? 'Drop-off location is required'
                : null,
            onChanged: (_) => _updateBookingSummary(),
          ),
        ],
      ),
    );
  }

  // ── Step 1: Driver Info ──────────────────────────────────────────────────
  Widget _buildDriverInfoStep() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BookingSectionHeader(
            title: 'Driver Information',
            icon: Icons.drive_eta_outlined,
          ),
          _premiumTextField(
            controller: _fullNameController,
            label: 'Full Name *',
            icon: Icons.badge_outlined,
            keyboardType: TextInputType.name,
            validator: (v) => v?.trim().isEmpty ?? true ? 'Required' : null,
            onChanged: (_) => _updateBookingSummary(),
          ),
          const SizedBox(height: 14),
          _premiumTextField(
            controller: _phoneController,
            label: 'Phone Number *',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            validator: (v) {
              if (v?.trim().isEmpty ?? true) return 'Required';
              if (v!.length < 8) return 'Too short';
              return null;
            },
          ),
          const SizedBox(height: 14),
          _premiumTextField(
            controller: _emailController,
            label: 'Email Address *',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            validator: (v) {
              if (v?.trim().isEmpty ?? true) return 'Required';
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v!)) {
                return 'Invalid email';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          _premiumTextField(
            controller: _driverLicenseNumberController,
            label: 'Driver License Number *',
            icon: Icons.credit_card_outlined,
            validator: (v) =>
                v?.trim().isEmpty ?? true ? 'License number is required' : null,
          ),
          const SizedBox(height: 14),
          DatePickerTile(
            label: 'License Expiry Date',
            value: _licenseExpiryDate != null
                ? DateFormat('MMM d, yyyy').format(_licenseExpiryDate!)
                : null,
            icon: Icons.calendar_today,
            onTap: _selectLicenseExpiryDate,
          ),
          const SizedBox(height: 10),
          const InfoBanner(
            text: 'Driver must be 21+ years old with a valid license.',
            color: AppColors.info,
            icon: Icons.info_outline,
          ),
        ],
      ),
    );
  }

  // ── Step 2: Vehicle Options ──────────────────────────────────────────────
  Widget _buildVehicleOptionsStep() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BookingSectionHeader(
            title: 'Vehicle Options',
            icon: Icons.settings_outlined,
          ),

          // Driver Option
          const Text(
            'Driver Option',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 10),
          ...DriverOption.values.map(
            (opt) => _buildOptionCard<DriverOption>(
              value: opt,
              groupValue: _driverOption,
              title: _formatDriverOption(opt),
              subtitle: _getDriverOptionDescription(opt),
              icon: opt == DriverOption.withDriver
                  ? Icons.person_outlined
                  : Icons.drive_eta_outlined,
              onTap: () => setState(() {
                _driverOption = opt;
                _updateBookingSummary();
              }),
            ),
          ),
          const SizedBox(height: 16),

          // Insurance Option
          const Text(
            'Insurance Coverage',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 10),
          ...InsuranceOption.values.map(
            (ins) => _buildOptionCard<InsuranceOption>(
              value: ins,
              groupValue: _insuranceOption,
              title: _formatInsuranceOption(ins),
              subtitle: _getInsuranceDescription(ins),
              icon: _getInsuranceIcon(ins),
              onTap: () => setState(() {
                _insuranceOption = ins;
                _updateBookingSummary();
              }),
            ),
          ),
          const SizedBox(height: 16),

          // Child Seat
          PremiumSwitchTile(
            title: 'Child Seat',
            subtitle: 'For children under 12 · \$10/day',
            value: _childSeat,
            icon: Icons.child_care_outlined,
            onChanged: (v) => setState(() {
              _childSeat = v;
              _updateBookingSummary();
            }),
          ),
        ],
      ),
    );
  }

  // ── Step 3: Agreement ────────────────────────────────────────────────────
  Widget _buildAgreementStep() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BookingSectionHeader(
            title: 'Terms & Agreement',
            icon: Icons.gavel,
          ),

          // Rental Terms
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
                      'Rental Terms & Conditions',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange[800],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  '• Driver must be 21+ with valid license\n'
                  '• Security deposit required (refundable)\n'
                  '• Fuel charges not included\n'
                  '• Traffic violations are renter\'s responsibility\n'
                  '• Vehicle must be returned in same condition\n'
                  '• Late returns incur additional charges',
                  style: TextStyle(fontSize: 13, height: 1.7),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Payment Info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.payment, color: AppColors.info, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Payment Information',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.info,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  '• Security deposit: \$100 (refundable within 7 days)\n'
                  '• Full payment required at pickup\n'
                  '• Credit card or mobile money accepted',
                  style: TextStyle(fontSize: 13, height: 1.7),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Agreement Checkbox
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _acceptRentalTerms
                  ? AppColors.success.withValues(alpha: 0.07)
                  : Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _acceptRentalTerms
                    ? AppColors.success.withValues(alpha: 0.4)
                    : Colors.grey[300]!,
              ),
            ),
            child: Row(
              children: [
                Checkbox(
                  value: _acceptRentalTerms,
                  activeColor: AppColors.success,
                  onChanged: (v) => setState(() {
                    _acceptRentalTerms = v!;
                    _updateBookingSummary();
                  }),
                ),
                const Expanded(
                  child: Text(
                    'I have read and agree to the rental terms and conditions',
                    style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                  ),
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }

  Future<void> _selectPickupDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate:
          _pickupDateTime ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (c, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_pickupDateTime ?? date),
      );
      if (time != null) {
        setState(() {
          _pickupDateTime = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
          if (_returnDateTime != null &&
              _returnDateTime!.isBefore(_pickupDateTime!)) {
            _returnDateTime = _pickupDateTime!.add(const Duration(days: 1));
          }
          _updateBookingSummary();
        });
      }
    }
  }

  Future<void> _selectReturnDateTime() async {
    final DateTime firstPossible =
        _pickupDateTime ?? DateTime.now().add(const Duration(days: 1));

    // Ensure initialDate is not before firstDate
    DateTime initial =
        _returnDateTime ?? DateTime.now().add(const Duration(days: 3));
    if (initial.isBefore(firstPossible)) {
      initial = firstPossible;
    }

    final date = await showDatePicker(
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
    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_returnDateTime ?? date),
      );
      if (time != null) {
        setState(() {
          _returnDateTime = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
          _updateBookingSummary();
        });
      }
    }
  }

  Future<void> _selectLicenseExpiryDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate:
          _licenseExpiryDate ?? DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
      builder: (c, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _licenseExpiryDate = picked;
        _updateBookingSummary();
      });
    }
  }

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _pickupDateTime != null &&
            _returnDateTime != null &&
            _pickupLocationController.text.trim().isNotEmpty &&
            _dropoffLocationController.text.trim().isNotEmpty;
      case 1:
        return (_formKey.currentState?.validate() ?? false) &&
            _licenseExpiryDate != null;
      case 2:
        return true;
      case 3:
        if (!_acceptRentalTerms) {
          setState(
            () => _errorMessage = 'You must accept the rental terms to proceed',
          );
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
              ? 'Please fill in pickup/drop-off details'
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
      final bookingData = VehicleBookingData(
        checkIn: _pickupDateTime!,
        checkOut: _returnDateTime!,
        guests: 1,
        fullName: _fullNameController.text,
        email: _emailController.text,
        phone: _phoneController.text,
        pickupDateTime: _pickupDateTime!,
        returnDateTime: _returnDateTime!,
        pickupLocation: _pickupLocationController.text,
        dropoffLocation: _dropoffLocationController.text,
        driverLicenseNumber: _driverLicenseNumberController.text,
        licenseExpiryDate: _licenseExpiryDate!,
        driverOption: _driverOption,
        insuranceOption: _insuranceOption,
        childSeat: _childSeat,
        acceptRentalTerms: _acceptRentalTerms,
      );

      final validation = BookingFormService.validateVehicleBooking(bookingData);
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
          builder: (_) => EnhancedPaymentScreen(
            serviceId: widget.service.id,
            providerId: widget.service.providerId,
            serviceTitle: widget.service.title,
            serviceType: ServiceType.vehicle,
            checkIn: bookingData.checkIn,
            checkOut: bookingData.checkOut,
            guests: 1,
            rooms: 0,
            basePrice: widget.service.price,
            totalPrice: _bookingSummary!.totalPrice,
            taxes: _bookingSummary!.taxes,
            extras: _bookingSummary!.extras,
            contactName: bookingData.fullName,
            contactEmail: bookingData.email,
            contactPhone: bookingData.phone,
            specialRequests:
                'Driver: ${_formatDriverOption(_driverOption)}, Insurance: ${_formatInsuranceOption(_insuranceOption)}',
            acceptRentalTerms: bookingData.acceptRentalTerms,
            metadata: {
              'serviceType': 'vehicle',
              'pickupLocation': bookingData.pickupLocation,
              'dropoffLocation': bookingData.dropoffLocation,
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
        return _buildRentalDetailsStep();
      case 1:
        return _buildDriverInfoStep();
      case 2:
        return _buildVehicleOptionsStep();
      case 3:
        return _buildAgreementStep();
      default:
        return const SizedBox.shrink();
    }
  }

  String _formatDriverOption(DriverOption opt) {
    switch (opt) {
      case DriverOption.withDriver:
        return 'With Driver';
      case DriverOption.selfDrive:
        return 'Self Drive';
    }
  }

  String _getDriverOptionDescription(DriverOption opt) {
    switch (opt) {
      case DriverOption.withDriver:
        return 'Professional driver included · \$50/day';
      case DriverOption.selfDrive:
        return 'Drive the vehicle yourself';
    }
  }

  String _formatInsuranceOption(InsuranceOption ins) {
    switch (ins) {
      case InsuranceOption.basic:
        return 'Basic Insurance · \$15/day';
      case InsuranceOption.comprehensive:
        return 'Comprehensive Insurance · \$25/day';
      case InsuranceOption.none:
        return 'No Insurance (Not Recommended)';
    }
  }

  String _getInsuranceDescription(InsuranceOption ins) {
    switch (ins) {
      case InsuranceOption.basic:
        return 'Covers minor accidents and damage';
      case InsuranceOption.comprehensive:
        return 'Full coverage including theft';
      case InsuranceOption.none:
        return 'You are responsible for all damages';
    }
  }

  IconData _getInsuranceIcon(InsuranceOption ins) {
    switch (ins) {
      case InsuranceOption.basic:
        return Icons.shield_outlined;
      case InsuranceOption.comprehensive:
        return Icons.security;
      case InsuranceOption.none:
        return Icons.no_encryption_outlined;
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
                      'Booking: ${widget.service.title}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    Text(
                      'Vehicle Rental',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.directions_car, color: Colors.white, size: 28),
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
