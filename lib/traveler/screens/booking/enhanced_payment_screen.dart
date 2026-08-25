import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/booking_forms_model.dart';
import '../../../shared/services/booking_form_service.dart';
import '../../../shared/services/media_service.dart';

import '../../../shared/services/auth_service.dart';
import '../../../shared/services/booking_integration_service.dart';
import '../../../shared/services/user_repository.dart';
import '../../../shared/models/user_model.dart';
import '../../../shared/models/payment_account_model.dart';
import 'booking_success_screen.dart';
import '../../../shared/widgets/status_dialogs.dart';
import '../../../core/providers/localization_provider.dart';

class EnhancedPaymentScreen extends ConsumerStatefulWidget {
  final String serviceId;
  final String providerId;
  final String serviceTitle;
  final ServiceType serviceType;
  final DateTime checkIn;
  final DateTime checkOut;
  final int guests;
  final int rooms;
  final double totalPrice;
  final double basePrice;
  final double taxes;
  final double discount;
  final Map<String, dynamic> extras;
  final String contactName;
  final String contactEmail;
  final String contactPhone;
  final String? specialRequests;
  final String location;
  final bool acceptHouseRules;
  final bool acceptRentalTerms;
  final List<dynamic>? travelers;
  final Map<String, dynamic>? metadata;

  const EnhancedPaymentScreen({
    required this.serviceId,
    required this.providerId,
    required this.serviceTitle,
    required this.serviceType,
    required this.checkIn,
    required this.checkOut,
    required this.guests,
    required this.rooms,
    required this.totalPrice,
    required this.basePrice,
    this.taxes = 0.0,
    this.discount = 0.0,
    this.extras = const {},
    required this.contactName,
    required this.contactEmail,
    required this.contactPhone,
    this.location = '',
    this.specialRequests,
    this.acceptHouseRules = false,
    this.acceptRentalTerms = false,
    this.travelers,
    this.metadata,
    super.key,
  });

  @override
  ConsumerState<EnhancedPaymentScreen> createState() =>
      _EnhancedPaymentScreenState();
}

class _EnhancedPaymentScreenState extends ConsumerState<EnhancedPaymentScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  PaymentMethod _selectedMethod = PaymentMethod.payLater;
  bool _isProcessing = false;
  String? _errorMessage;
  bool _acceptHouseRules = false;
  bool _acceptRentalTerms = false;

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  // Card Payment
  final _cardholderNameController = TextEditingController();
  final _cardNumberController = TextEditingController();
  final _expiryDateController = TextEditingController();
  final _cvvController = TextEditingController();
  final _billingCountryController = TextEditingController(text: 'Somalia');

  // Mobile Money
  String?
  _mobileProvider; // Let's keep it null initially so we can set it dynamically
  final _mobileNumberController = TextEditingController();
  final _transactionReferenceController = TextEditingController();

  // Bank Transfer
  String? _bankProvider;
  final _bankTransactionReferenceController = TextEditingController();

  // Pay Later Verification
  final _verificationIdController = TextEditingController();
  final _alternativePhoneController = TextEditingController();
  XFile? _idDocumentFile;
  Uint8List? _idDocumentBytes;
  String? _idDocumentUrl;

  bool _showSummary = true;

  @override
  void initState() {
    super.initState();
    _cardholderNameController.text = widget.contactName;
    _mobileNumberController.text =
        widget.contactPhone; // Pre-fill from booking form
    _acceptHouseRules = widget.acceptHouseRules;
    _acceptRentalTerms = widget.acceptRentalTerms;
    if (widget.metadata?['idDocumentUrl'] != null) {
      _idDocumentUrl = widget.metadata!['idDocumentUrl'] as String?;
    }

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _cardholderNameController.dispose();
    _cardNumberController.dispose();
    _expiryDateController.dispose();
    _cvvController.dispose();
    _billingCountryController.dispose();
    _mobileNumberController.dispose();
    _transactionReferenceController.dispose();
    _bankTransactionReferenceController.dispose();
    _verificationIdController.dispose();
    _alternativePhoneController.dispose();
    super.dispose();
  }



  void _changeMethod(PaymentMethod method) {
    _animController.reset();
    setState(() {
      _selectedMethod = method;
      _errorMessage = null;
    });
    _animController.forward();
  }

  @override
  Widget build(BuildContext context) {
    // Use providerDetailProvider (direct Supabase fetch) to bypass RLS stream
    // limitations — this ensures payment accounts are always loaded.
    final providerAsync = ref.watch(providerDetailProvider(widget.providerId));

    return providerAsync.when(
      loading: () => Scaffold(
        backgroundColor: AppColors.background,
        body: Column(
          children: [
            _buildHeader(),
            const Expanded(child: Center(child: CircularProgressIndicator())),
          ],
        ),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: AppColors.background,
        body: Column(
          children: [
            _buildHeader(),
            Expanded(child: Center(child: Text('Error loading provider: $e'))),
          ],
        ),
      ),
      data: (providerData) {
        final provider =
            providerData ??
            User(
              id: widget.providerId,
              name: 'Provider',
              email: '',
              password: '',
              role: UserRole.provider,
            );

        final hasMobileMoney = true; // Always enabled globally
        final hasCard = true; // Enabled globally via Waafi Pay Live
        final hasBank = false; // Disabled bank transfers completely

        final bool payLaterEnabled =
            provider.metadata['pay_later_enabled'] ?? true;

        // Safety: If Pay Later is selected but disabled, switch to first available method
        if (_selectedMethod == PaymentMethod.payLater && !payLaterEnabled) {
          _selectedMethod = PaymentMethod.mobileMoney;
        }

        // Initialize mobile provider from actual accounts
        final mobileAccounts = provider.paymentAccounts
            .where((a) => a.type == PaymentAccountType.mobileMoney)
            .toList();
        if (_mobileProvider == null ||
            !mobileAccounts.any(
              (a) => a.providerName == _mobileProvider,
            )) {
          _mobileProvider = mobileAccounts.isNotEmpty
              ? mobileAccounts.first.providerName
              : 'Hormuud EVC Plus';
        }

        // Initialize bank provider from actual accounts
        final bankAccounts = provider.paymentAccounts
            .where((a) => a.type == PaymentAccountType.bank)
            .toList();
        if (_bankProvider == null ||
            !bankAccounts.any(
              (a) => a.providerName == _bankProvider,
            )) {
          _bankProvider = bankAccounts.isNotEmpty
              ? bankAccounts.first.providerName
              : null;
        }

        return _buildScaffold(provider, hasCard, hasMobileMoney, hasBank);
      },
    );
  }

  Widget _buildScaffold(
    User provider,
    bool hasCard,
    bool hasMobileMoney,
    bool hasBank,
  ) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _isProcessing
          ? _buildProcessingState()
          : Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Booking Summary Card
                        _buildBookingSummaryCard(),
                        const SizedBox(height: 24),

                        // Payment Method Selection
                        _buildPaymentMethodSelection(
                          provider,
                          hasCard,
                          hasMobileMoney,
                          hasBank,
                        ),
                        const SizedBox(height: 20),

                        // Payment Form
                        FadeTransition(
                          opacity: _fadeAnimation,
                          child: _buildPaymentForm(provider),
                        ),

                        // Agreements (House Rules / Terms)
                        if (widget.serviceType == ServiceType.apartment ||
                            widget.serviceType == ServiceType.vehicle) ...[
                          const SizedBox(height: 20),
                          _buildAgreementsSection(),
                        ],

                        // Security Notice
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 12),
                          _buildErrorBanner(_errorMessage!),
                        ],
                        
                        const SizedBox(height: 12),

                        // Security Notice
                        _buildSecurityNotice(),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
              ],
            ),
      bottomNavigationBar: _isProcessing ? null : _buildPayButton(),
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
                      ref.watch(localizationProvider).translate('secure_payment'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    Text(
                      ref.watch(localizationProvider).translate('payment_encrypted'),
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.lock_outline,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBookingSummaryCard() {
    final dateFormat = DateFormat('MMM d, yyyy');
    return Column(
      children: [
        GestureDetector(
          onTap: () => setState(() => _showSummary = !_showSummary),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _getServiceIcon(widget.serviceType),
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.serviceTitle,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 17,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${dateFormat.format(widget.checkIn)} → ${dateFormat.format(widget.checkOut)}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            '${widget.guests} guest${widget.guests > 1 ? 's' : ''}${widget.rooms > 1 ? ' · ${widget.rooms} rooms' : ''}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '\$${widget.totalPrice.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                          ),
                        ),
                        Text(
                          'Total',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (_showSummary) ...[
                  const SizedBox(height: 16),
                  Container(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                  const SizedBox(height: 12),
                  _buildSummaryRow(
                    ref.watch(localizationProvider).translate('base_price'),
                    '\$${widget.basePrice.toStringAsFixed(2)}',
                  ),
                  ...widget.extras.entries.map(
                    (e) => _buildSummaryRow(
                      _formatExtraLabel(e.key),
                      e.value is String
                          ? e.value
                          : '+\$${(e.value as double).toStringAsFixed(2)}',
                    ),
                  ),
                  if (widget.discount > 0)
                    _buildSummaryRow(
                      '🏷 ${ref.watch(localizationProvider).translate('discount')}',
                      '-\$${widget.discount.toStringAsFixed(2)}',
                      isDiscount: true,
                    ),
                  if (widget.taxes > 0)
                    _buildSummaryRow(
                      ref.watch(localizationProvider).translate('taxes_fees'),
                      '\$${widget.taxes.toStringAsFixed(2)}',
                    ),
                  const SizedBox(height: 8),
                  Container(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'TOTAL',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          letterSpacing: 1,
                        ),
                      ),
                      Text(
                        '\$${widget.totalPrice.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _showSummary ? Icons.expand_less : Icons.expand_more,
                      color: Colors.white70,
                      size: 20,
                    ),
                    Text(
                      _showSummary ? 'Hide details' : 'Show details',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        // Contact info chip
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primary,
                child: Icon(Icons.person, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.contactName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      widget.contactEmail,
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ),
              Text(
                widget.contactPhone,
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value, {
    bool isDiscount = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: isDiscount
                    ? const Color(0xFF86EFAC) // green tint for discount
                    : Colors.white.withValues(alpha: 0.75),
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: TextStyle(
              color: isDiscount ? const Color(0xFF86EFAC) : Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodSelection(
    User provider,
    bool hasCard,
    bool hasMobileMoney,
    bool hasBank,
  ) {
    final payLaterEnabled = provider.metadata['pay_later_enabled'] ?? true;

    final loc = ref.watch(localizationProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          loc.translate('payment_method'),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 17,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            // Calculate width for 2 items per row, with 12px spacing
            final double itemWidth = (constraints.maxWidth - 12) / 2;

            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                if (payLaterEnabled)
                  SizedBox(
                    width:
                        (hasMobileMoney || hasBank || hasCard)
                            ? itemWidth
                            : constraints.maxWidth,
                    child: _buildMethodCard(
                      PaymentMethod.payLater,
                      loc.translate('pay_later'),
                      Icons.schedule,
                    ),
                  ),
                if (hasMobileMoney)
                  SizedBox(
                    width:
                        (payLaterEnabled || hasBank || hasCard)
                            ? itemWidth
                            : constraints.maxWidth,
                    child: _buildMethodCard(
                      PaymentMethod.mobileMoney,
                      loc.translate('mobile_money'),
                      Icons.phone_android,
                    ),
                  ),
                if (hasBank)
                  SizedBox(
                    width:
                        (payLaterEnabled || hasMobileMoney || hasCard)
                            ? itemWidth
                            : constraints.maxWidth,
                    child: _buildMethodCard(
                      PaymentMethod.bank,
                      loc.translate('bank_transfer'),
                      Icons.account_balance,
                    ),
                  ),
                if (hasCard)
                  SizedBox(
                    width:
                        (payLaterEnabled || hasMobileMoney || hasBank)
                            ? itemWidth
                            : constraints.maxWidth,
                    child: _buildMethodCard(
                      PaymentMethod.card,
                      'MasterCard / Visa',
                      Icons.credit_card,
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildMethodCard(PaymentMethod method, String label, IconData icon) {
    final isSelected = _selectedMethod == method;
    return GestureDetector(
      onTap: () => _changeMethod(method),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey[200]!,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.grey[500],
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : Colors.grey[600],
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentForm(User provider) {
    switch (_selectedMethod) {
      case PaymentMethod.card:
        return _buildCardForm(provider);
      case PaymentMethod.mobileMoney:
        return _buildMobileMoneyForm(provider);
      case PaymentMethod.bank:
        return _buildBankTransferForm(provider);
      case PaymentMethod.payLater:
        return _buildPayLaterInfo();
    }
  }

  Widget _buildCardForm(User provider) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel(label: 'Card Details', icon: Icons.credit_card),
          const SizedBox(height: 12),
          _paymentTextField(
            controller: _cardholderNameController,
            label: 'Cardholder Name',
            icon: Icons.person_outline,
            validator: (v) => v?.trim().isEmpty ?? true ? 'Required' : null,
          ),
          const SizedBox(height: 12),
          _paymentTextField(
            controller: _cardNumberController,
            label: 'Card Number',
            icon: Icons.credit_card,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              _CardNumberFormatter(),
            ],
            maxLength: 19,
            validator: (v) {
              if (v?.trim().isEmpty ?? true) return 'Required';
              if (!BookingFormService.isValidCardNumber(v!)) {
                return 'Invalid card number';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _paymentTextField(
                  controller: _expiryDateController,
                  label: 'MM/YY',
                  icon: Icons.date_range,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    _ExpiryDateFormatter(),
                  ],
                  maxLength: 5,
                  validator: (v) {
                    if (v?.trim().isEmpty ?? true) return 'Required';
                    if (!BookingFormService.isValidExpiryDate(v!)) {
                      return 'Expired or invalid';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _paymentTextField(
                  controller: _cvvController,
                  label: 'CVV',
                  icon: Icons.lock_outline,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  maxLength: 4,
                  obscureText: true,
                  validator: (v) {
                    if (v?.trim().isEmpty ?? true) return 'Required';
                    if (v!.length < 3 || v.length > 4) return '3-4 digits';
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _paymentTextField(
            controller: _billingCountryController,
            label: 'Billing Country',
            icon: Icons.flag_outlined,
            validator: (v) => v?.trim().isEmpty ?? true ? 'Required' : null,
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.success.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.verified_user,
                  color: AppColors.success,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  'Your card details are never stored',
                  style: TextStyle(color: AppColors.success, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileMoneyForm(User provider) {

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel(label: 'Mobile Money', icon: Icons.phone_android),
          const SizedBox(height: 12),

          // Automatic Payment Notice
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.sms_outlined,
                  size: 20,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    ref.watch(localizationProvider).translate('sms_payment_notice'),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.business,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ref.watch(localizationProvider).translate('provider'),
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        (() {
                          final String p = _mobileProvider ?? 'Hormuud EVC Plus';
                          final String icon = p.contains('Hormuud')
                              ? '🟢'
                              : p.contains('Zaad')
                              ? '🔵'
                              : p.contains('Sahal')
                              ? '🟡'
                              : p.contains('eDahab')
                              ? '🟡'
                              : p.contains('Golis')
                              ? '🔴'
                              : p.contains('Telesom')
                              ? '🟣'
                              : '💰';
                          return '$icon $p';
                        })(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _paymentTextField(
            controller: _mobileNumberController,
            label: 'Mobile Number',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 10),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
            ),
            child: const Column(
              children: [
                Text(
                  '📱 You will receive a payment SMS. Please complete it within 30 minutes.',
                  style: TextStyle(fontSize: 13, height: 1.5),
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.sd_card_alert_outlined, color: AppColors.error, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Ensure your SIM card is active to receive the SMS.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.error,
                          fontWeight: FontWeight.bold,
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


  Widget _buildBankTransferForm(User provider) {
    final hasBank = provider.paymentAccounts.any(
      (a) => a.type == PaymentAccountType.bank,
    );
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel(
            label: 'Bank Transfer',
            icon: Icons.account_balance,
          ),
          const SizedBox(height: 12),

          // --- PROVIDER BANK DETAILS HIDDEN ---

          if (hasBank) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.account_balance,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Designated Bank',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _bankProvider ?? 'Bank',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          _paymentTextField(
            controller: _bankTransactionReferenceController,
            label: 'Transaction Reference',
            icon: Icons.receipt_outlined,
            hintText: 'Enter the transfer reference ID',
            validator: (v) => v?.trim().isEmpty ?? true ? 'Required' : null,
          ),
          const SizedBox(height: 12),
          _buildSecurityNotice(),
        ],
      ),
    );
  }

  Widget _buildPayLaterInfo() {
    return Form(
      key: _formKey,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.info.withValues(alpha: 0.07),
              AppColors.info.withValues(alpha: 0.03),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            const Icon(Icons.schedule, color: AppColors.info, size: 48),
            const SizedBox(height: 12),
            const Text(
              'Pay at Arrival',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: AppColors.info,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You will pay at arrival / check-in. Your booking will be held for a limited time.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[700], height: 1.5),
            ),
            const SizedBox(height: 20),

            // Verification Title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.verified_user_outlined,
                    color: AppColors.info,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  ref.watch(localizationProvider).translate('booking_verification'),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            _buildIdDocumentUploader(),
            const SizedBox(height: 12),
            _paymentTextField(
              controller: _alternativePhoneController,
              label: ref.watch(localizationProvider).translate('alt_phone_label'),
              icon: Icons.phone_android_outlined,
              hintText: ref.watch(localizationProvider).translate('alt_phone_hint'),
              keyboardType: TextInputType.phone,
              validator: (v) {
                final loc = ref.read(localizationProvider);
                if (v?.trim().isEmpty ?? true) {
                  return loc.translate('alt_phone_required');
                }
                if (v!.length < 8) {
                  return loc.translate('valid_phone');
                }
                return null;
              },
            ),

            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber,
                    color: Colors.amber,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      ref.watch(localizationProvider).translate('pay_later_notice'),
                      style: const TextStyle(fontSize: 12, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _InfoPoint(text: ref.watch(localizationProvider).translate('no_upfront')),
                _InfoPoint(text: ref.watch(localizationProvider).translate('free_cancellation')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIdDocumentUploader() {
    final hasUploaded = _idDocumentFile != null || _idDocumentUrl != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: const Text(
                'Your Photo',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            if (hasUploaded)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF10B981), width: 0.8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF10B981),
                      size: 14,
                    ),
                    SizedBox(width: 4),
                    Text(
                      '✓ Uploaded',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF10B981),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),

        if (hasUploaded) ...[
          // Uploaded State Banner & Preview
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF10B981).withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _idDocumentBytes != null
                      ? Image.memory(
                          _idDocumentBytes!,
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                        )
                      : (_idDocumentUrl != null && _idDocumentUrl!.startsWith('http')
                          ? Image.network(
                              _idDocumentUrl!,
                              width: 56,
                              height: 56,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 56,
                                height: 56,
                                color: Colors.grey[200],
                                child: const Icon(Icons.badge_outlined, color: Colors.grey),
                              ),
                            )
                          : Container(
                              width: 56,
                              height: 56,
                              color: Colors.grey[200],
                              child: const Icon(Icons.badge_outlined, color: Colors.grey),
                            )),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            color: Color(0xFF10B981),
                            size: 16,
                          ),
                          SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'ID Photo Uploaded!',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _idDocumentFile?.name ?? 'ID_Passport_Photo.jpg',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<ImageSource>(
                  onSelected: (source) => _pickIdDocument(source),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: ImageSource.camera,
                      child: Row(
                        children: [
                          Icon(Icons.camera_alt_outlined, size: 18),
                          SizedBox(width: 8),
                          Text('Take Photo'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: ImageSource.gallery,
                      child: Row(
                        children: [
                          Icon(Icons.photo_library_outlined, size: 18),
                          SizedBox(width: 8),
                          Text('Choose from Gallery'),
                        ],
                      ),
                    ),
                  ],
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: const Text(
                      'Change',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _idDocumentFile = null;
                      _idDocumentBytes = null;
                      _idDocumentUrl = null;
                    });
                  },
                  icon: const Icon(Icons.close_rounded, size: 18, color: Colors.red),
                  tooltip: 'Remove',
                ),
              ],
            ),
          ),
        ] else ...[
          // Empty State Upload Box
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.add_a_photo_outlined,
                        color: AppColors.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Upload Your Photo',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Take photo with camera or choose from gallery',
                            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickIdDocument(ImageSource.camera),
                        icon: const Icon(Icons.camera_alt_outlined, size: 16),
                        label: const Text('Camera', style: TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _pickIdDocument(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library_outlined, size: 16),
                        label: const Text('Gallery', style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _pickIdDocument(ImageSource source) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: source,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );

    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        _idDocumentFile = image;
        _idDocumentBytes = bytes;
        _idDocumentUrl = image.path;
      });

      try {
        final mediaService = MediaService();
        final url = await mediaService.uploadImage(image);
        if (url != null && mounted) {
          setState(() {
            _idDocumentUrl = url;
          });
        }
      } catch (e) {
        debugPrint('Upload error: $e');
      }
    }
  }

  Widget _buildAgreementsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.serviceType == ServiceType.apartment)
          _agreementTile(
            title: ref.watch(localizationProvider).translate('accept_house_rules'),
            value: _acceptHouseRules,
            onChanged: (v) => setState(() => _acceptHouseRules = v!),
            icon: Icons.gavel,
          ),
        if (widget.serviceType == ServiceType.vehicle)
          _agreementTile(
            title: ref.watch(localizationProvider).translate('accept_rental_terms'),
            value: _acceptRentalTerms,
            onChanged: (v) => setState(() => _acceptRentalTerms = v!),
            icon: Icons.description_outlined,
          ),
      ],
    );
  }

  Widget _agreementTile({
    required String title,
    required bool value,
    required ValueChanged<bool?> onChanged,
    required IconData icon,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: value ? AppColors.success.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: value ? AppColors.success : Colors.grey[200]!,
          width: value ? 1.5 : 1,
        ),
      ),
      child: CheckboxListTile(
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: value ? AppColors.success : Colors.black87,
          ),
        ),
        value: value,
        onChanged: onChanged,
        secondary: Icon(
          icon,
          color: value ? AppColors.success : Colors.grey[600],
        ),
        activeColor: AppColors.success,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildSecurityNotice() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock, color: AppColors.success, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ref.watch(localizationProvider).translate('encrypted_label'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                Text(
                  ref.watch(localizationProvider).translate('encrypted_desc'),
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
        gradient: LinearGradient(
          colors: [Colors.white, Colors.grey[50]!],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFFFF5252),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Color(0x40FF5252),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(Icons.close, color: Colors.white, size: 32),
          ),
          const SizedBox(height: 20),
          const Text(
            'Payment Declined',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 20,
              color: Color(0xFF2D3748),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
              height: 1.6,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: 200,
            child: OutlinedButton(
              onPressed: () => setState(() => _errorMessage = null),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFE2E8F0)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
                backgroundColor: const Color(0xFFF8FAFC),
              ),
              child: const Text(
                'TRY AGAIN',
                style: TextStyle(
                  color: Color(0xFF4A5568),
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  letterSpacing: 1.1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPayButton() {
    final loc = ref.watch(localizationProvider);
    final labels = {
      PaymentMethod.card: '${loc.translate('pay_amount')} \$${widget.totalPrice.toStringAsFixed(2)}',
      PaymentMethod.mobileMoney: loc.translate('send_payment'),
      PaymentMethod.bank: loc.translate('bank_transferred'),
      PaymentMethod.payLater: loc.translate('confirm_booking'),
    };
    final icons = {
      PaymentMethod.card: Icons.credit_card,
      PaymentMethod.mobileMoney: Icons.phone_android,
      PaymentMethod.bank: Icons.account_balance,
      PaymentMethod.payLater: Icons.check_circle_outline,
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        child: FilledButton.icon(
          onPressed: () {
            if (_formKey.currentState?.validate() ?? false) {
              _processPayment();
            }
          },
          icon: Icon(
            icons[_selectedMethod], 
            color: Colors.white
          ),
          label: Text(
            labels[_selectedMethod]!,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            minimumSize: const Size(double.infinity, 56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProcessingState() {
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 80,
                  height: 80,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const CircularProgressIndicator(
                        color: AppColors.primary,
                        strokeWidth: 6,
                      ),
                      const Icon(
                        Icons.credit_card,
                        color: AppColors.primary,
                        size: 30,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  _selectedMethod == PaymentMethod.mobileMoney
                      ? 'Check your phone'
                      : 'Processing payment...',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    _selectedMethod == PaymentMethod.mobileMoney
                        ? 'Enter your PIN on your phone.'
                        : 'Do not close the app.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: LinearProgressIndicator(
                    backgroundColor: Colors.grey[200],
                    color: AppColors.secondary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  TextFormField _paymentTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hintText,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    int? maxLength,
    bool obscureText = false,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      maxLength: maxLength,
      obscureText: obscureText,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
        counterText: '',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error),
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

  Future<void> _processPayment() async {
     // Re-routed to specialized method to avoid logic conflicts
     _processPaymentStep2();
  }

  Future<void> _processPaymentStep2() async {
    final loc = ref.read(localizationProvider);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final paymentData = PaymentData(
        method: _selectedMethod,
        cardholderName: _selectedMethod == PaymentMethod.card
            ? _cardholderNameController.text
            : null,
        cardNumber: _selectedMethod == PaymentMethod.card
            ? _cardNumberController.text
            : null,
        expiryDate: _selectedMethod == PaymentMethod.card
            ? _expiryDateController.text
            : null,
        cvv: _selectedMethod == PaymentMethod.card ? _cvvController.text : null,
        billingCountry: _selectedMethod == PaymentMethod.card
            ? _billingCountryController.text
            : null,
        mobileProvider: _selectedMethod == PaymentMethod.mobileMoney
            ? _mobileProvider ?? 'Hormuud'
            : (_selectedMethod == PaymentMethod.bank ? _bankProvider : null),
        mobileNumber: _selectedMethod == PaymentMethod.mobileMoney
            ? _mobileNumberController.text
            : null,
        transactionReference: _selectedMethod == PaymentMethod.mobileMoney
            ? _transactionReferenceController.text
            : (_selectedMethod == PaymentMethod.bank
                  ? _bankTransactionReferenceController.text
                  : null),
      );

      final user = ref.read(authProvider);
      if (user == null) {
        throw Exception('Authentication required to complete booking');
      }

      final bookingData = {
        'serviceId': widget.serviceId,
        'providerId': widget.providerId,
        'serviceTitle': widget.serviceTitle,
        'travelerId': user.id,
        'travelerName': widget.contactName.trim(),
        'fullName': widget.contactName.trim(), // Added for compatibility
        'checkIn': widget.checkIn,
        'checkOut': widget.checkOut,
        'guests': widget.guests,
        'rooms': widget.rooms,
        'totalPrice': widget.totalPrice,
        'taxes': widget.taxes,
        'contactPhone': widget.contactPhone.trim(),
        'phone': widget.contactPhone.trim(), // Added for compatibility
        'contactEmail': widget.contactEmail.trim(),
        'email': widget.contactEmail.trim(), // Added for compatibility
        'specialRequests': widget.specialRequests,
        'location': widget.location.trim().isNotEmpty
            ? widget.location.trim()
            : (_billingCountryController.text.trim().isNotEmpty
                  ? _billingCountryController.text.trim()
                  : (widget.metadata?['location']?.toString().trim() ?? '')),
        'acceptHouseRules': _acceptHouseRules,
        'acceptRentalTerms': _acceptRentalTerms,
        'travelers': widget.travelers,
        'metadata': {
          ...widget.metadata ?? {},
          if (widget.discount > 0) 'discount_amount': widget.discount,
          if (_verificationIdController.text.trim().isNotEmpty)
            'verificationId': _verificationIdController.text.trim(),
          if (_alternativePhoneController.text.trim().isNotEmpty)
            'alternativePhone': _alternativePhoneController.text.trim(),
          if (_idDocumentUrl != null && _idDocumentUrl!.trim().isNotEmpty)
            'idDocumentUrl': _idDocumentUrl!.trim(),
          if (_idDocumentFile?.name != null)
            'idDocumentFileName': _idDocumentFile!.name,
          if (_selectedMethod == PaymentMethod.payLater)
            'verifiedAtArrival': true,
        },
        'bookingType': widget.serviceType.name,
        // Extract traveler counts from metadata for compatibility/validation logic
        if (widget.metadata != null) ...{
          if (widget.metadata!['adultsCount'] != null)
            'adultTravelers': widget.metadata!['adultsCount'],
          if (widget.metadata!['childrenCount'] != null)
            'childTravelers': widget.metadata!['childrenCount'],
          if (widget.metadata!['infantsCount'] != null)
            'infantTravelers': widget.metadata!['infantsCount'],
          if (widget.metadata!['package_type'] != null)
            'package': TourPackage.values.firstWhere(
              (e) => e.name == widget.metadata!['package_type'],
              orElse: () => TourPackage.custom,
            ),
        },
      };

      // --- FULL CONNECTION: Use Integration Service ---
      final result = await ref
          .read(bookingIntegrationProvider)
          .completeBooking(
            serviceType: widget.serviceType,
            bookingData: bookingData,
            paymentData: paymentData,
          );

      if (!mounted) return;

      if (result.success) {
        if (result.status == 'pending_redirect' && result.paymentUrl != null) {
          final uri = Uri.parse(result.paymentUrl!);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
            
            if (!mounted) return;
            setState(() {
              _isProcessing = false;
            });

            StatusDialog.show(
              context,
              isSuccess: true,
              title: loc.translate('secure_payment'),
              message: loc.translate('card_payment_notice'),
              buttonText: 'OK',
            );
            return;
          }
        }

        // Existing success logic for mobile money
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => BookingSuccessScreen(
              bookingId: result.booking?.id ?? const Uuid().v4(),
              paymentMethod: _selectedMethod,
              totalPaid: widget.totalPrice,
            ),
          ),
        );
      } else {
        setState(() {
          _errorMessage =
              result.error ?? 'Booking failed at step: ${result.step}';
          _isProcessing = false;
        });

        // Show premium dialog for significant errors
        StatusDialog.show(
          context,
          isSuccess: false,
          title: loc.translate('warning'),
          message: _errorMessage!,
          buttonText: 'OK',
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'An error occurred: $e';
        _isProcessing = false;
      });

      StatusDialog.show(
        context,
        isSuccess: false,
        title: loc.translate('warning'),
        message: loc.translate('technical_issue'),
        buttonText: 'OK',
      );
    }
  }

  IconData _getServiceIcon(ServiceType t) {
    switch (t) {
      case ServiceType.hotel:
        return Icons.hotel;
      case ServiceType.apartment:
        return Icons.apartment;
      case ServiceType.tour:
        return Icons.map_outlined;
      case ServiceType.vehicle:
        return Icons.directions_car;
    }
  }

  String _formatExtraLabel(String key) {
    switch (key) {
      case 'breakfast':
        return 'Breakfast';
      case 'airportPickup':
        return 'Airport Pickup';
      case 'extraBed':
        return 'Extra Bed';
      case 'cleaningService':
        return 'Cleaning Service';
      case 'earlyCheckIn':
        return 'Early Check-in';
      case 'lateCheckout':
        return 'Late Checkout';
      case 'packageUpgrade':
        return 'Package Upgrade';
      case 'driver':
        return 'Driver Service';
      case 'insurance':
        return 'Insurance';
      case 'childSeat':
        return 'Child Seat';
      default:
        return key[0].toUpperCase() + key.substring(1);
    }
  }
}

// ─────────────────────────────────────────────
//  Helpers
// ─────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  final IconData icon;

  const _SectionLabel({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }
}

class _InfoPoint extends StatelessWidget {
  final String text;

  const _InfoPoint({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.check, color: AppColors.success, size: 16),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            style: const TextStyle(fontSize: 12.5),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
//  Input Formatters
// ─────────────────────────────────────────────
class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(digits[i]);
    }
    final string = buffer.toString();
    return TextEditingValue(
      text: string,
      selection: TextSelection.collapsed(offset: string.length),
    );
  }
}

class _ExpiryDateFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length && i < 4; i++) {
      if (i == 2) buffer.write('/');
      buffer.write(digits[i]);
    }
    final string = buffer.toString();
    return TextEditingValue(
      text: string,
      selection: TextSelection.collapsed(offset: string.length),
    );
  }
}
