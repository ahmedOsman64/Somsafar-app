import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/booking_model.dart';
import '../../../shared/services/booking_repository.dart';
import '../../../shared/services/service_repository.dart';
import '../../../shared/services/auth_service.dart';
import '../../../shared/services/financial_repository.dart';
import '../../../core/services/supabase_service.dart';
import 'booking_success_screen.dart';

class PaymentScreen extends ConsumerStatefulWidget {
  final String serviceId;
  final DateTime checkIn;
  final DateTime checkOut;
  final int guests;
  final int rooms;
  final double totalPrice;
  final String contactName;
  final String contactEmail;
  final String contactPhone;
  final String? specialRequests;

  const PaymentScreen({
    required this.serviceId,
    required this.checkIn,
    required this.checkOut,
    required this.guests,
    required this.rooms,
    required this.totalPrice,
    required this.contactName,
    required this.contactEmail,
    required this.contactPhone,
    this.specialRequests,
    super.key,
  });

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  int _selectedMethod = 0; // 0: Card, 1: Mobile Money
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payment'), centerTitle: true),
      body: _isProcessing
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  CircularProgressIndicator(color: AppColors.primary),
                  SizedBox(height: 16),
                  Text('Processing Payment...'),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Total Amount
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary,
                          AppColors.primary.withAlpha(204),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Total to Pay',
                          style: TextStyle(color: Colors.white70, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '\$${widget.totalPrice.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  Text(
                    'Select Payment Method',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Methods Tabs
                  Row(
                    children: [
                      _buildMethodTab(0, 'Credit Card', Icons.credit_card),
                      const SizedBox(width: 16),
                      _buildMethodTab(1, 'Mobile Money', Icons.phone_android),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Method Forms
                  if (_selectedMethod == 0)
                    _buildCardForm()
                  else
                    _buildMobileForm(),
                ],
              ),
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton(
            onPressed: _isProcessing ? null : _processPayment,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: AppColors.primary,
            ),
            child: const Text(
              'Pay & Confirm Booking',
              style: TextStyle(fontSize: 16, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMethodTab(int index, String label, IconData icon) {
    final isSelected = _selectedMethod == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedMethod = index),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withAlpha(26)
                : Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.primary : Colors.grey[200]!,
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? AppColors.primary : Colors.grey[600],
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isSelected ? AppColors.primary : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardForm() {
    return Column(
      children: [
        TextField(
          decoration: const InputDecoration(
            labelText: 'Card Number',
            prefixIcon: Icon(Icons.numbers),
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextField(
                decoration: const InputDecoration(
                  labelText: 'Expiry Date',
                  hintText: 'MM/YY',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextField(
                decoration: const InputDecoration(
                  labelText: 'CVV',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          decoration: const InputDecoration(
            labelText: 'Cardholder Name',
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileForm() {
    return Column(
      children: [
        DropdownButtonFormField<String>(
          initialValue: 'EVC Plus',
          items: [
            'EVC Plus',
            'Sahal',
            'Zaad',
          ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          decoration: const InputDecoration(
            labelText: 'Provider',
            border: OutlineInputBorder(),
          ),
          onChanged: (v) {},
        ),
        const SizedBox(height: 16),
        TextField(
          decoration: const InputDecoration(
            labelText: 'Mobile Number',
            prefixIcon: Icon(Icons.phone),
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.phone,
        ),
      ],
    );
  }

  Future<void> _processPayment() async {
    setState(() => _isProcessing = true);

    // Simulate Network Delay
    await Future.delayed(const Duration(seconds: 2));

    try {
      final user = ref.read(authProvider);
      if (user == null) {
        throw Exception('Authentication required to complete booking');
      }
      
      final services = ref.read(serviceProvider);
      String? providerId;
      String? serviceTitle;

      try {
        final service = services.firstWhere((s) => s.id == widget.serviceId);
        providerId = service.providerId;
        serviceTitle = service.title;
      } catch (_) {
        // Fallback: Fetch from database if not in cache
        final data = await SupabaseConfig.client
            .from('services')
            .select('provider_id, title')
            .eq('id', widget.serviceId)
            .maybeSingle();
        
        if (data != null) {
          providerId = data['provider_id'];
          serviceTitle = data['title'];
        }
      }

      if (providerId == null || serviceTitle == null) {
        throw Exception('Service details could not be found');
      }

      final paymentMethod = _selectedMethod == 0
          ? 'Credit Card'
          : 'Mobile Money';
      final transactionId =
          'TXN-${const Uuid().v4().substring(0, 8).toUpperCase()}';

      final booking = Booking(
        id: const Uuid().v4(),
        serviceId: widget.serviceId,
        providerId: providerId,
        serviceTitle: serviceTitle,
        travelerId: user.id,
        travelerName: widget.contactName,
        date: DateTime.now(),
        checkIn: widget.checkIn,
        checkOut: widget.checkOut,
        guests: widget.guests,
        rooms: widget.rooms,
        totalPrice: widget.totalPrice,
        contactPhone: widget.contactPhone,
        contactEmail: widget.contactEmail,
        specialRequests: widget.specialRequests,
        transactionId: transactionId,
        paymentMethod: paymentMethod,
        status: BookingStatus.pending,
        paymentStatus: BookingPaymentStatus.paid,
      );

      ref.read(bookingProvider.notifier).createBooking(booking);

      // Record transaction
      ref
          .read(financialProvider.notifier)
          .addTransaction(
            userName: widget.contactName,
            amount: widget.totalPrice,
            bookingId: booking.id,
            isPaid: true,
          );

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => BookingSuccessScreen(bookingId: booking.id),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }
}
