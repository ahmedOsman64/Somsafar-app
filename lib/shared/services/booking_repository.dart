import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import '../models/service_model.dart';
import '../models/booking_model.dart';
import '../models/notification_model.dart';
import '../models/user_model.dart';
import 'auth_service.dart';
import 'service_repository.dart';
import 'notification_repository.dart';
import '../../core/services/supabase_service.dart';

class BookingRepository extends StateNotifier<List<Booking>> {
  final Ref? _ref;
  StreamSubscription? _subscription;
  int _lastUpdateId = 0;

  BookingRepository(this._ref, {bool listen = true}) : super([]) {
    if (listen) {
      _listenToAuth();
    }
  }

  void _listenToAuth() {
    _ref?.listen<User?>(authProvider, (previous, next) {
      if (next == null) {
        // Clear state and stop stream on logout
        _subscription?.cancel();
        _subscription = null;
        state = [];
      } else if (previous?.id != next.id) {
        // Restart stream for new user
        _initStream();
        fetchBookings(); // Initial fetch
      }
    }, fireImmediately: true);
  }

  void _initStream() {
    _subscription?.cancel();
    debugPrint('BookingRepository: Initializing stream...');
    _subscription = SupabaseConfig.client
        .from('bookings')
        .stream(primaryKey: ['id'])
        .listen(
          (data) async {
            if (!mounted) return;
            
            final currentUpdateId = ++_lastUpdateId;
            
            debugPrint(
              'BookingRepository: Stream received ${data.length} records. Enriching (ID: $currentUpdateId)...',
            );
            
            // Map the raw booking data
            final bookings = data
                .where((res) => res['id'] != null && (res['id'] as String).isNotEmpty)
                .map((res) => _mapRawToBooking(res))
                .toList();

            if (bookings.isEmpty) {
              if (currentUpdateId == _lastUpdateId) state = [];
              return;
            }

            try {
              final enrichedBookings = await Future.wait(
                bookings.map((booking) async {
                  try {
                    final travelerResponse = await SupabaseConfig.client
                        .from('travelers')
                        .select()
                        .eq('booking_id', booking.id);

                    final List<TravelerDetail> travelers = (travelerResponse as List)
                        .map((t) => TravelerDetail.fromJson(t))
                        .toList();

                    return booking.copyWith(travelers: travelers);
                  } catch (e) {
                    debugPrint('Error enriching booking ${booking.id}: $e');
                    return booking;
                  }
                }),
              );

              if (mounted && currentUpdateId == _lastUpdateId) {
                state = enrichedBookings;
                debugPrint('BookingRepository: Enriched ${state.length} bookings with travelers (ID: $currentUpdateId)');
              }
            } catch (e) {
              debugPrint('BookingRepository: Enrichment error: $e');
              // Fallback to raw bookings if enrichment fails and it's still the latest
              if (mounted && currentUpdateId == _lastUpdateId) state = bookings;
            }
          },
          onError: (error) {
            debugPrint('BookingRepository: Stream error: $error');
          },
        );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _updateStateFromRaw(List<Map<String, dynamic>> rawData) {
    state = rawData
        .where((res) => res['id'] != null && (res['id'] as String).isNotEmpty)
        .map((res) => _mapRawToBooking(res))
        .toList();
  }

  Booking _mapRawToBooking(Map<String, dynamic> res) {
    return Booking(
      id: res['id'] as String,
      serviceId: (res['service_id'] as String?) ?? '',
      providerId: (res['provider_id'] as String?) ?? '',
      serviceTitle: res['service_title'] ?? 'Unknown Service',
      travelerId: (res['traveler_id'] as String?) ?? '',
      travelerName: res['traveler_name'] ?? 'Unknown Traveler',
      date: res['created_at'] != null
          ? DateTime.parse(res['created_at'])
          : (res['date'] != null
                ? DateTime.parse(res['date'])
                : DateTime.now()),
      checkIn: res['check_in'] != null
          ? DateTime.parse(res['check_in'])
          : DateTime.now(),
      checkOut: res['check_out'] != null
          ? DateTime.parse(res['check_out'])
          : DateTime.now(),
      guests: res['guests'] ?? 1,
      rooms: res['rooms'] ?? 1,
      totalPrice: (res['total_price'] as num?)?.toDouble() ?? 0.0,
      taxes: (res['taxes'] as num?)?.toDouble() ?? 0.0,
      contactPhone: res['contact_phone'] ?? '',
      contactEmail: res['contact_email'] ?? '',
      specialRequests: res['special_requests'],
      transactionId: res['transaction_id'],
      paymentMethod: res['payment_method'],
      status: BookingStatus.values.firstWhere(
        (e) => e.name == res['status'],
        orElse: () => BookingStatus.pending,
      ),
      paymentStatus: BookingPaymentStatus.values.firstWhere(
        (e) => e.name == res['payment_status'],
        orElse: () => BookingPaymentStatus.pending,
      ),
      travelers:
          (res['travelers'] as List?)
              ?.map((t) => TravelerDetail.fromJson(t))
              .toList() ??
          [],
      metadata: res['metadata'] as Map<String, dynamic>? ?? {},
    );
  }

  Future<void> fetchBookings() async {
    try {
      debugPrint('BookingRepository: Performing manual fetch...');

      // 1. Fetch Bookings
      final bookingsData = await SupabaseConfig.client
          .from('bookings')
          .select('*')
          .order('created_at', ascending: false);

      if (bookingsData.isEmpty) {
        if (mounted) state = [];
        return;
      }

      // 2. Fetch Travelers for these bookings
      final bookingIds = bookingsData.map((b) => b['id'] as String).toList();
      final travelersData = await SupabaseConfig.client
          .from('travelers')
          .select('*')
          .inFilter('booking_id', bookingIds);

      // 3. Merge in-memory
      final List<Map<String, dynamic>> combinedData = bookingsData.map((
        booking,
      ) {
        final bookingId = booking['id'] as String;
        final relevantTravelers = travelersData
            .where((t) => t['booking_id'] == bookingId)
            .toList();

        return {...booking, 'travelers': relevantTravelers};
      }).toList();

      if (!mounted) return;
      debugPrint(
        'BookingRepository: Manual fetch success, got ${combinedData.length} records',
      );
      _updateStateFromRaw(combinedData);
    } catch (e) {
      debugPrint('BookingRepository: Manual fetch error: $e');
    }
  }

  Future<void> updateBookingStatus(String id, BookingStatus status) async {
    final previousBookings = [...state];
    try {
      final bookingIndex = state.indexWhere((b) => b.id == id);
      if (bookingIndex == -1) return;

      final booking = state[bookingIndex];
      final prevStatus = booking.status;

      // Optimistic Update
      state = [
        for (final b in state)
          if (b.id == id) b.copyWith(status: status) else b,
      ];

      await SupabaseConfig.client
          .from('bookings')
          .update({'status': status.name})
          .eq('id', id);

      // --- AUTOMATIC SERVICE UPDATE LOGIC ---
      // If accepting (Confirming) a booking
      if (status == BookingStatus.confirmed &&
          prevStatus != BookingStatus.confirmed) {
        await _handleServiceAvailability(booking, isReducing: true);
      }
      // If cancelling a previously confirmed booking
      else if (status == BookingStatus.cancelled &&
          prevStatus == BookingStatus.confirmed) {
        await _handleServiceAvailability(booking, isReducing: false);
      }
      // If marking as completed, we might want to free up the apartment/rooms
      else if (status == BookingStatus.completed &&
          prevStatus == BookingStatus.confirmed) {
        // Only apartments return to active automatically when completed
        // Alternatively, wait until checkout date
        if (booking.checkOut.isBefore(DateTime.now())) {
          await _handleServiceAvailability(booking, isReducing: false);
        }
      }

      // --- SEND NOTIFICATION ---
      final title =
          'Booking ${status.name[0].toUpperCase()}${status.name.substring(1)}';
      final message =
          'Your booking for ${booking.serviceTitle} has been ${status.name}.';

      _ref
          ?.read(notificationProvider.notifier)
          .addNotification(
            userId: booking.travelerId,
            title: title,
            message: message,
            type: NotificationType.booking,
            data: {'bookingId': id},
          );
    } catch (e) {
      debugPrint('Update booking status error: $e');
      state = previousBookings;
    } finally {
      // Automatic refresh no longer needed as stream handles enrichment
    }
  }

  Future<void> _handleServiceAvailability(
    Booking booking, {
    required bool isReducing,
  }) async {
    try {
      final services = _ref?.read(serviceProvider);
      if (services == null) return;
      final serviceIndex = services.indexWhere(
        (s) => s.id == booking.serviceId,
      );
      if (serviceIndex == -1) return;

      final service = services[serviceIndex];
      final category = service.category.toLowerCase();

      if (category.contains('apartment') || category.contains('home')) {
        // Apartment Logic: Block/Unblock the entire unit
        final updatedService = service.copyWith(
          status: isReducing ? ServiceStatus.inactive : ServiceStatus.active,
          metadata: {
            ...service.metadata,
            'booked_until': isReducing
                ? booking.checkOut.toIso8601String()
                : null,
            'current_booking_id': isReducing ? booking.id : null,
          },
        );
        await _ref
            ?.read(serviceProvider.notifier)
            .updateService(updatedService);
        debugPrint(
          'Apartment ${service.title} marked as ${isReducing ? "Booked" : "Available"}',
        );
      } else if (category.contains('hotel')) {
        // Hotel Logic: Manage room counts
        final metadata = Map<String, dynamic>.from(service.metadata);
        final totalRooms = (metadata['rooms'] as num?)?.toInt() ?? 1;
        final bookedRooms = (metadata['bookedRooms'] as num?)?.toInt() ?? 0;

        int newBookedCount = isReducing
            ? (bookedRooms + booking.rooms)
            : (bookedRooms - booking.rooms);

        if (newBookedCount < 0) newBookedCount = 0;

        // Note: We use 'rooms' as total capacity and 'bookedRooms' as occupied
        metadata['bookedRooms'] = newBookedCount;
        metadata['availableRooms'] = totalRooms - newBookedCount;

        // If no rooms left, mark as inactive
        final newStatus = (totalRooms - newBookedCount) <= 0
            ? ServiceStatus.inactive
            : ServiceStatus.active;

        final updatedService = service.copyWith(
          status: newStatus,
          metadata: metadata,
        );

        await _ref
            ?.read(serviceProvider.notifier)
            .updateService(updatedService);

        debugPrint(
          'Hotel Rooms Updated: Total: $totalRooms, Booked: $newBookedCount, Left: ${totalRooms - newBookedCount}',
        );
      }
    } catch (e) {
      debugPrint('Error handling service auto-update: $e');
    }
  }

  Future<void> createBooking(Booking booking) async {
    try {
      // Use the Secure RPC for atomic transaction and concurrency control
      final response = await SupabaseConfig.client.rpc(
        'create_booking_safe',
        params: {
          'p_booking_id': booking.id,
          'p_traveler_id': booking.travelerId,
          'p_provider_id': booking.providerId,
          'p_service_id': booking.serviceId,
          'p_service_title': booking.serviceTitle,
          'p_traveler_name': booking.travelerName,
          'p_check_in': booking.checkIn.toIso8601String().split('T')[0],
          'p_check_out': booking.checkOut.toIso8601String().split('T')[0],
          'p_guests': booking.guests,
          'p_rooms': booking.rooms,
          'p_total_price': booking.totalPrice,
          'p_contact_phone': booking.contactPhone,
          'p_contact_email': booking.contactEmail,
          'p_payment_method': booking.paymentMethod ?? 'Direct',
          'p_metadata': booking.metadata.map(
            (key, value) => MapEntry(key, value is Enum ? value.name : value),
          ),
          'p_travelers': booking.travelers.map((t) => t.toJson()).toList(),
        },
      );

      if (response == null) {
        throw Exception('Failed to create secure booking');
      }

      // Optimistic Update: Add to local state immediately
      state = [...state, booking];

      // --- SEND NOTIFICATION TO PROVIDER ---
      _ref
          ?.read(notificationProvider.notifier)
          .addNotification(
            userId: booking.providerId,
            title: 'New Booking Request',
            message:
                '${booking.travelerName} requested a booking for ${booking.serviceTitle}.',
            type: NotificationType.booking,
            data: {'bookingId': booking.id},
          );
          
    } catch (e) {
      debugPrint('Create booking error: $e');
      if (e.toString().contains('Not enough slots')) {
        throw Exception(
          'The requested slots are no longer available. Please try a smaller number or a different time.',
        );
      }
      throw Exception('Database error: $e');
    }
  }

  Future<void> updateBooking(Booking booking) async {
    try {
      // Security: Ensure authorized access
      final user = _ref?.read(authProvider);
      if (user == null) throw Exception('Authentication required');
      
      final isMyTrip = booking.travelerId == user.id;
      final isMyServiceBooking = booking.providerId == (user.providerId ?? user.id);
      
      if (user.role != UserRole.admin && !isMyTrip && !isMyServiceBooking) {
        throw Exception('Security Alert: Unauthorized attempt to update booking owned by another user.');
      }

      // Optimistic Update
      state = [
        for (final b in state)
          if (b.id == booking.id) booking else b,
      ];

      await SupabaseConfig.client
          .from('bookings')
          .update({
            'service_title': booking.serviceTitle,
            'traveler_name': booking.travelerName,
            'status': booking.status.name,
            'check_in': booking.checkIn.toIso8601String().split('T')[0],
            'check_out': booking.checkOut.toIso8601String().split('T')[0],
            'guests': booking.guests,
            'rooms': booking.rooms,
            'total_price': booking.totalPrice,
            'taxes': booking.taxes,
            'contact_phone': booking.contactPhone,
            'contact_email': booking.contactEmail,
            'special_requests': booking.specialRequests,
            'transaction_id': booking.transactionId,
            'payment_method': booking.paymentMethod,
            'payment_status': booking.paymentStatus.name,
          })
          .eq('id', booking.id);
    } catch (e) {
      debugPrint('Update booking error: $e');
    }
  }

  List<Booking> get pendingBookings =>
      state.where((b) => b.status == BookingStatus.pending).toList();
}

final bookingProvider = StateNotifierProvider<BookingRepository, List<Booking>>(
  (ref) {
    return BookingRepository(ref);
  },
);

// Selector for role-based data isolation
final filteredBookingsProvider = Provider<List<Booking>>((ref) {
  final user = ref.watch(authProvider);
  final bookings = ref.watch(bookingProvider);

  if (user == null) return [];

  if (user.role == UserRole.admin) {
    return bookings;
  }

  final providerKey = user.providerId ?? user.id;

  return bookings.where((b) {
    final isMyTrip = b.travelerId == user.id;
    final isMyServiceBooking = b.providerId == providerKey;
    return isMyTrip || isMyServiceBooking;
  }).toList();
});
