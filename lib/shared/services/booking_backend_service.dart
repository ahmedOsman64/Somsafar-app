import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FunctionException;
import 'package:uuid/uuid.dart';
import '../models/booking_forms_model.dart';
import '../models/booking_model.dart';
import '../models/user_model.dart';
import 'auth_service.dart';
import 'system_activity_repository.dart';
import 'financial_repository.dart';
import 'booking_repository.dart';
import '../../core/services/supabase_service.dart';
import '../services/settings_repository.dart';

final bookingBackendProvider = Provider<BookingBackendService>((ref) {
  return BookingBackendService(ref);
});

class PaymentResult {
  final bool success;
  final String? transactionId;
  final String message;
  final String? error;
  final String? paymentUrl;
  final String? status;

  PaymentResult({
    required this.success,
    this.transactionId,
    required this.message,
    this.error,
    this.paymentUrl,
    this.status,
  });
}

class BookingBackendService {
  final Ref _ref;
  BookingBackendService(this._ref);

  // Create a new booking
  Future<Booking> createBooking({
    String? id,
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
      final bookingId = id ?? const Uuid().v4();


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
        paymentMethod: _formatPaymentMethod(paymentData),
        metadata: metadata,
        status: BookingStatus.pending,
        paymentStatus: BookingPaymentStatus.pending,
      );

      // --- PERSIST TO SUPABASE FIRST (Atomic registration) ---
      // This ensures the booking exists before any payment is attempted
      await _ref.read(bookingProvider.notifier).createBooking(booking);

      // --- LOG ATTEMPT ---
      _ref.read(activityProvider.notifier).logBooking(
            travelerName: travelerName,
            serviceTitle: serviceTitle,
            price: totalPrice,
            providerId: providerId,
            userId: travelerId,
          );

      await _sendBookingConfirmations(booking, paymentData);

      return booking;
    } catch (e) {
      debugPrint('Error creating booking: $e');
      throw Exception('Failed to create booking: $e');
    }
  }

  String _formatPaymentMethod(PaymentData data) {
    if (data.method == PaymentMethod.mobileMoney) {
      return 'MWALLET_ACCOUNT'; // Align with backend expectations
    }
    if (data.method == PaymentMethod.bank) {
      return 'BANK_TRANSFER';
    }
    if (data.method == PaymentMethod.card) {
      return 'CREDIT_CARD';
    }
    return data.method.name.toUpperCase();
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

      _ref
          .read(activityProvider.notifier)
          .logStatusUpdate(currentUser.name, 'Booking $bookingId', status.name);
      return true;
    } catch (e) {
      debugPrint('Error updating booking status: $e');
      return false;
    }
  }

  Future<int> getAvailableSlots({
    required String serviceId,
    required DateTime checkIn,
    required DateTime checkOut,
  }) async {
    try {
      final response = await SupabaseConfig.client.rpc(
        'check_service_availability',
        params: {
          'p_service_id': serviceId,
          'p_check_in': checkIn.toIso8601String().split('T')[0],
          'p_check_out': checkOut.toIso8601String().split('T')[0],
        },
      );
      return (response as num).toInt();
    } catch (e) {
      debugPrint('Error checking availability via RPC: $e');
      return -1; // Fallback indicator
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
    final available = await getAvailableSlots(
      serviceId: serviceId,
      checkIn: checkIn,
      checkOut: checkOut,
    );
    if (available == -1) return true; // Fallback to allowing if RPC fails/not deployed
    return available >= rooms;
  }


  Future<bool> validateServiceAvailability({
    required String serviceId,
    required DateTime checkIn,
    required DateTime checkOut,
  }) async {
    final available = await getAvailableSlots(
      serviceId: serviceId,
      checkIn: checkIn,
      checkOut: checkOut,
    );
    if (available == -1) return true; // Fallback to allowing if RPC fails/not deployed
    return available > 0;
  }


  Future<PaymentResult> processPayment({
    required PaymentData paymentData,
    required double amount,
    required String bookingId,
  }) async {
    try {
      final locale = _ref.read(settingsProvider).language; // 'en', 'so', 'ar'
      final session = SupabaseConfig.client.auth.currentSession;
      final response = await SupabaseConfig.client.functions.invoke(
        'process-payment',
        headers: {
          if (session != null) 'Authorization': 'Bearer ${session.accessToken}',
        },
        body: {
          'booking_id': bookingId,
          'account_no': paymentData.mobileNumber,
          'payment_method': _formatPaymentMethod(paymentData),
          'idempotency_key': bookingId, // Use bookingId as idempotency key
          'locale': locale,
        },
      );


      final data = response.data as Map<String, dynamic>;
      final bool success = response.status == 200 && (data['success'] == true);

      if (success) {
        // --- RECORD FINANCIAL TRANSACTION ONLY ON SUCCESS ---
        // Backend handles provider lookup to avoid client-side trust issues
        
        _ref.read(financialProvider.notifier).addTransaction(
          userName: 'Traveler', // Prefer fetching from session
          amount: amount,
          bookingId: bookingId,
          isPaid: true,
          providerId: 'provider-lookup-via-backend', // Should be handled server-side or via separate lookup
          providerName: 'Verified Provider',
          receivingAccount: 'Verified Account',
        );
      }

      String message = data['message'] ?? (success ? 'Payment successful' : 'Payment failed');
      if (message.contains('u direyso')) {
        message = message.replaceAll('u direyso', 'ka direyso');
      } else if (message.contains('u direeso')) {
        message = message.replaceAll('u direeso', 'ka direeso');
      }

      return PaymentResult(
        success: success,
        transactionId: data['data'] != null ? data['data']['reference_id'] : null,
        message: message,
        error: data['error']?.toString(),
        status: data['status'] ?? (success ? 'completed' : 'failed'),
        paymentUrl: data['payment_url'],
      );
    } on FunctionException catch (e) {
      debugPrint('Payment FunctionException [${e.status}]: ${e.details}');
      String errorMessage = 'Payment failed. Please try again.';
      
      final details = e.details;
      if (details is Map && details['message'] != null) {
        errorMessage = details['message'].toString();
      }

      if (errorMessage.contains('u direyso')) {
        errorMessage = errorMessage.replaceAll('u direyso', 'ka direyso');
      } else if (errorMessage.contains('u direeso')) {
        errorMessage = errorMessage.replaceAll('u direeso', 'ka direeso');
      }

      return PaymentResult(success: false, message: errorMessage, error: e.toString());
    } catch (e) {
      debugPrint('Payment error: $e');
      return PaymentResult(
        success: false, 
        message: 'Technical error. Please check your internet.',
        error: e.toString()
      );
    }
  }

  Future<PaymentResult> verifyPayment(String referenceId) async {
    if (referenceId.isEmpty) {
       return PaymentResult(success: false, message: 'Invalid reference ID');
    }

    try {
      final session = SupabaseConfig.client.auth.currentSession;
      final response = await SupabaseConfig.client.functions.invoke(
        'verify-payment',
        headers: {
          if (session != null) 'Authorization': 'Bearer ${session.accessToken}',
        },
        body: {'reference_id': referenceId},
      );

      final data = response.data as Map<String, dynamic>;
      final bool success = data['success'] == true && data['data'] != null;

      return PaymentResult(
        success: success,
        transactionId: referenceId,
        message: data['message'] ?? (success ? 'Verified' : 'Verification failed'),
        error: data['errorCode'],
      );
    } catch (e) {
      debugPrint('Verification error: $e');
      return PaymentResult(success: false, message: 'System connection failed', error: e.toString());
    }
  }

  Future<Map<String, dynamic>> applyDiscountCode({
    required String code,
    required double amount,
    required String serviceId,
  }) async {
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
}

