import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/booking_forms_model.dart';
import '../models/booking_model.dart';
import '../models/user_model.dart';
import 'auth_service.dart';
import 'system_activity_repository.dart';
import 'financial_repository.dart';
import 'user_repository.dart';
import 'booking_repository.dart';

final bookingBackendProvider = Provider<BookingBackendService>((ref) {
  return BookingBackendService(ref);
});

class BookingBackendService {
  final Ref _ref;
  BookingBackendService(this._ref);

  // Create a new booking
  Future<Booking> createBooking({
    required String serviceId,
    required String providerId,
    required String serviceTitle,
    required String travelerId,
    required String travelerName,
    required DateTime checkIn,
    required DateTime checkOut,
    required int guests,
    required int rooms,
    required double totalPrice,
    double taxes = 0.0,
    required String contactPhone,
    required String contactEmail,
    String? specialRequests,
    required PaymentData paymentData,
    ServiceType serviceType = ServiceType.hotel,
    Map<String, dynamic> metadata = const {},
  }) async {
    // Security Check
    final currentUser = _ref.read(authProvider);
    if (currentUser == null) {
      throw Exception('Authentication required to create a booking.');
    }

    try {
      final bookingId = const Uuid().v4();

      await Future.delayed(const Duration(seconds: 1));

      final booking = Booking(
        id: bookingId,
        serviceId: serviceId,
        providerId: providerId,
        serviceTitle: serviceTitle,
        travelerId: travelerId,
        travelerName: travelerName,
        date: DateTime.now(),
        checkIn: checkIn,
        checkOut: checkOut,
        guests: guests,
        rooms: rooms,
        totalPrice: totalPrice,
        taxes: taxes,
        contactPhone: contactPhone,
        contactEmail: contactEmail,
        specialRequests: specialRequests,
        paymentMethod: paymentData.method == PaymentMethod.mobileMoney 
            ? '${paymentData.mobileProvider} Mobile Money' 
            : (paymentData.method == PaymentMethod.bank 
                ? '${paymentData.mobileProvider} Bank Transfer' 
                : paymentData.method.name),
        metadata: metadata,
        status: BookingStatus.pending,
        paymentStatus: _getPaymentStatus(paymentData.method),
      );

      // --- FULL CONNECTION: Notify Admin and Provider via Activity Log ---
      _ref
          .read(activityProvider.notifier)
          .logBooking(
            travelerName: travelerName,
            serviceTitle: serviceTitle,
            price: totalPrice,
            providerId: providerId,
            userId: travelerId,
          );

      // --- NEW: AUTOMATIC FINANCIAL RECORDING WITH PROVIDER PAYOUT ---
      final isPaid =
          paymentData.method == PaymentMethod.card ||
          paymentData.method == PaymentMethod.mobileMoney;
      
      // Look up provider details for payout
      final allUsers = _ref.read(userProvider);
      final provider = allUsers.firstWhere(
        (u) => u.id == providerId || u.providerId == providerId,
        orElse: () => User(id: providerId, name: 'Unknown Provider', email: '', password: '', role: UserRole.provider),
      );
      
      final defaultPayout = provider.paymentAccounts.isEmpty 
        ? null 
        : provider.paymentAccounts.firstWhere((a) => a.isDefault, orElse: () => provider.paymentAccounts.first);

      _ref
          .read(financialProvider.notifier)
          .addTransaction(
            userName: travelerName,
            amount: totalPrice,
            bookingId: bookingId,
            isPaid: isPaid,
            providerId: providerId,
            providerName: provider.name,
            receivingAccount: defaultPayout != null 
              ? '${defaultPayout.providerName} (${defaultPayout.accountNumber})' 
              : 'No Account Set',
          );

      await _sendBookingConfirmations(booking, paymentData);

      // --- NEW: PERSIST TO SUPABASE ---
      await _ref.read(bookingProvider.notifier).createBooking(booking);

      return booking;
    } catch (e) {
      debugPrint('Error creating booking: $e');
      throw Exception('Failed to create booking: $e');
    }
  }

  // Update booking status
  Future<bool> updateBookingStatus({
    required String bookingId,
    required BookingStatus status,
    required BookingPaymentStatus paymentStatus,
  }) async {
    final currentUser = _ref.read(authProvider);
    if (currentUser == null || currentUser.role == UserRole.traveler) {
      throw Exception(
        'Unauthorized: Only Providers and Admins can update status.',
      );
    }

    try {
      await Future.delayed(const Duration(milliseconds: 500));
      _ref
          .read(activityProvider.notifier)
          .logStatusUpdate(currentUser.name, 'Booking $bookingId', status.name);
      return true;
    } catch (e) {
      debugPrint('Error updating booking status: $e');
      return false;
    }
  }

  // Public methods
  Future<bool> checkAvailability({
    required String serviceId,
    required DateTime checkIn,
    required DateTime checkOut,
    int guests = 1,
    int rooms = 1,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return true;
  }

  Future<bool> validateServiceAvailability({
    required String serviceId,
    required DateTime checkIn,
    required DateTime checkOut,
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));
    return true;
  }

  Future<Map<String, dynamic>> processPayment({
    required PaymentData paymentData,
    required double amount,
    required String bookingId,
  }) async {
    await Future.delayed(const Duration(seconds: 2));
    return {
      'success': true,
      'transactionId': 'tx_${const Uuid().v4()}',
      'message': 'Payment successful',
    };
  }

  Future<Map<String, dynamic>> applyDiscountCode({
    required String code,
    required double amount,
    required String serviceId,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (code.toUpperCase() == 'WELCOME10') {
      return {
        'success': true,
        'discount': amount * 0.1,
        'finalAmount': amount * 0.9,
        'message': '10% discount applied',
      };
    }
    return {'success': false, 'message': 'Invalid code'};
  }

  Future<void> _sendBookingConfirmations(
    Booking booking,
    PaymentData paymentData,
  ) async {
    debugPrint('Confirmation sent to ${booking.contactEmail}');
  }

  BookingPaymentStatus _getPaymentStatus(PaymentMethod method) {
    if (method == PaymentMethod.card || method == PaymentMethod.mobileMoney) {
      return BookingPaymentStatus.paid;
    }
    // Bank transfers are pending until verified by provider
    return BookingPaymentStatus.pending;
  }
}
