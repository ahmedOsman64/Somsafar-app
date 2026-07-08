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
import 'email_service.dart';
import 'booking_backend_service.dart';
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
              final bookingIds = bookings.map((b) => b.id).toList();
              final travelersResponse = await SupabaseConfig.client
                  .from('travelers')
                  .select()
                  .inFilter('booking_id', bookingIds);

              final List<dynamic> travelersList = travelersResponse as List;

              final List<Booking> enrichedBookings = bookings.map((booking) {
                final relevantTravelers = travelersList
                    .where((t) => t['booking_id'] == booking.id)
                    .map((t) => TravelerDetail.fromJson(t))
                    .toList();
                return booking.copyWith(travelers: relevantTravelers);
              }).toList();

              if (mounted && currentUpdateId == _lastUpdateId) {
                state = enrichedBookings;
                debugPrint('BookingRepository: Enriched ${state.length} bookings with travelers (ID: $currentUpdateId)');
                _autoCompleteExpiredBookings();
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
      confirmedAt: (res['metadata'] as Map?)?['confirmed_at'] != null
          ? DateTime.parse(res['metadata']['confirmed_at'])
          : null,
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
      _autoCompleteExpiredBookings();
      _autoManagePendingBookings();
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

      final updates = <String, dynamic>{'status': status.name};
      
      // Record confirmation time for performance scoring
      if (status == BookingStatus.confirmed && (prevStatus == BookingStatus.pending)) {
        final confirmedAt = DateTime.now();
        final updatedMeta = {...booking.metadata, 'confirmed_at': confirmedAt.toIso8601String()};
        updates['metadata'] = updatedMeta;
      }

      await SupabaseConfig.client
          .from('bookings')
          .update(updates)
          .eq('id', id);

      // --- AUTOMATIC SERVICE UPDATE LOGIC ---
      // If accepting (Confirming) a booking
      if (status == BookingStatus.confirmed &&
          prevStatus != BookingStatus.confirmed) {
        await _handleServiceAvailability(booking, isReducing: true);

        // --- AUTO EMAIL: Send PDF receipt to traveler ---
        final confirmedBooking = booking.copyWith(status: BookingStatus.confirmed);
        EmailService.sendBookingConfirmationEmail(confirmedBooking);
        // Fire-and-forget: runs in background, does not block UI
      }
      // If cancelling a booking (Rejecting from pending or cancelling from confirmed)
      else if (status == BookingStatus.cancelled &&
          (prevStatus == BookingStatus.confirmed || prevStatus == BookingStatus.pending)) {
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

      // --- DEFERRED SERVICE CLEANUP ---
      if (status == BookingStatus.completed || status == BookingStatus.cancelled) {
        await _checkAndCleanupService(booking.serviceId);
      }
    } catch (e) {
      debugPrint('Update booking status error: $e');
      state = previousBookings;
    } finally {
      // Automatic refresh no longer needed as stream handles enrichment
    }
  }

  /// Manually resend the confirmation email with PDF receipt
  Future<bool> resendConfirmationEmail(String id) async {
    try {
      final bookingIndex = state.indexWhere((b) => b.id == id);
      if (bookingIndex == -1) return false;

      final booking = state[bookingIndex];
      
      // Ensure it's confirmed or completed
      if (booking.status != BookingStatus.confirmed && booking.status != BookingStatus.completed) {
        debugPrint('BookingRepository: Cannot send receipt for non-confirmed booking.');
        return false;
      }

      debugPrint('BookingRepository: Manually resending email for ${booking.id}...');
      await EmailService.sendBookingConfirmationEmail(booking);
      return true;
    } catch (e) {
      debugPrint('BookingRepository: Resend email error: $e');
      return false;
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
          availableSlots: isReducing ? 0 : 1,
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
          availableSlots: totalRooms - newBookedCount,
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

  /// Recalculates availability for all services owned by the current provider.
  /// Only counts confirmed bookings that are currently active (checkOut in the future).
  /// Past bookings (checkOut <= now) do NOT block availability.
  Future<void> syncAllServicesAvailability() async {
    final user = _ref?.read(authProvider);
    if (user == null) return;

    final services = _ref?.read(serviceProvider) ?? [];
    final providerServices = services.where((s) => s.providerId == (user.providerId ?? user.id));
    final bookings = _ref?.read(bookingProvider) ?? [];
    final now = DateTime.now();

    for (final service in providerServices) {
      final category = service.category.toLowerCase();

      if (category.contains('hotel')) {
        final totalRooms = (service.metadata['rooms'] as num?)?.toInt() ?? 1;

        // Only count rooms from confirmed bookings that haven't checked out yet
        final currentBooked = bookings.where((b) {
          return b.serviceId == service.id &&
                 b.status == BookingStatus.confirmed &&
                 b.checkOut.isAfter(now); // ignore past bookings
        }).fold<int>(0, (sum, b) => sum + b.rooms);

        final updatedService = service.copyWith(
          availableSlots: totalRooms - currentBooked,
          status: (totalRooms - currentBooked) <= 0
              ? ServiceStatus.inactive
              : ServiceStatus.active,
          metadata: {
            ...service.metadata,
            'bookedRooms': currentBooked,
            'availableRooms': totalRooms - currentBooked,
          },
        );
        await _ref?.read(serviceProvider.notifier).updateService(updatedService);
      } else if (category.contains('apartment') || category.contains('home')) {
        // An apartment is occupied only if a confirmed booking hasn't checked out yet
        final isCurrentlyBooked = bookings.any(
          (b) => b.serviceId == service.id &&
                 b.status == BookingStatus.confirmed &&
                 b.checkOut.isAfter(now),
        );
        final updatedService = service.copyWith(
          status: isCurrentlyBooked ? ServiceStatus.inactive : ServiceStatus.active,
          availableSlots: isCurrentlyBooked ? 0 : 1,
        );
        await _ref?.read(serviceProvider.notifier).updateService(updatedService);
      }
    }
    debugPrint('All services synchronized successfully (date-aware).');
  }

  /// Checks if a service is marked for deletion and deletes it if there are no more active bookings.
  Future<void> _checkAndCleanupService(String serviceId) async {
    try {
      final services = _ref?.read(serviceProvider);
      if (services == null) return;
      
      final serviceIndex = services.indexWhere((s) => s.id == serviceId);
      if (serviceIndex == -1) return;
      
      final service = services[serviceIndex];
      
      // Check if it's marked for deletion
      if (service.metadata['pending_deletion'] == true) {
        // Check if there are any other active bookings
        final hasActiveBookings = state.any((b) => 
          b.serviceId == serviceId && 
          (b.status == BookingStatus.pending || b.status == BookingStatus.confirmed)
        );
        
        if (!hasActiveBookings) {
          debugPrint('BookingRepository: Last active booking for ${service.title} finished. Deleting service...');
          // Trigger actual deletion. Since we checked hasActiveBookings above, 
          // deleteService will proceed with permanent deletion.
          await _ref?.read(serviceProvider.notifier).deleteService(serviceId);
        }
      }
    } catch (e) {
      debugPrint('Error during deferred service cleanup: $e');
    }
  }

  /// Returns how many rooms/units are available for [serviceId] during [checkIn]–[checkOut].
  ///
  /// Logic:
  ///   Two date ranges overlap when: bookingCheckIn < requestedCheckOut
  ///                              AND bookingCheckOut > requestedCheckIn
  /// If they do NOT overlap, that booking does not consume capacity for the
  /// requested period — so Customer 2 can book after Customer 1 checks out.
  int getAvailableRoomsForDates({
    required String serviceId,
    required DateTime checkIn,
    required DateTime checkOut,
    String? bedType,
    String? excludeBookingId,
  }) {
    final services = _ref?.read(serviceProvider);
    if (services == null) { return 0; }
 
    final serviceIndex = services.indexWhere((s) => s.id == serviceId);
    if (serviceIndex == -1) { return 0; }
 
    final service = services[serviceIndex];
    final category = service.category.toLowerCase();
 
    final int totalCapacity;
    if (category.contains('hotel')) {
      if (bedType != null && service.metadata['bed_types_dynamic'] != null) {
        final bedData = (service.metadata['bed_types_dynamic'] as Map<String, dynamic>)[bedType.toLowerCase()];
        totalCapacity = (bedData?['count'] as num?)?.toInt() ?? 0;
      } else {
        totalCapacity = (service.metadata['rooms'] as num?)?.toInt() ?? 1;
      }
    } else {
      totalCapacity = 1; // Apartment / Home: single unit
    }
 
    // Rooms occupied during the requested window
    final occupied = state.where((b) {
      if (b.serviceId != serviceId) { return false; }
      if (excludeBookingId != null && b.id == excludeBookingId) { return false; }
      
      // If checking for specific bed type, only count bookings with that bed type in metadata
      if (bedType != null) {
        final bookingBedType = b.metadata['bedType']?.toString().toLowerCase();
        if (bookingBedType != bedType.toLowerCase()) return false;
      }

      // Ignore cancelled / completed bookings
      if (b.status == BookingStatus.cancelled ||
          b.status == BookingStatus.completed) { return false; }
      // Date overlap: existing booking overlaps with requested window
      //   b.checkIn  < requested checkOut
      //   b.checkOut > requested checkIn
      return b.checkIn.isBefore(checkOut) && b.checkOut.isAfter(checkIn);
    }).fold<int>(0, (sum, b) => sum + b.rooms);
 
    final available = totalCapacity - occupied;
    return available < 0 ? 0 : available;
  }

  Future<int> getAvailableRoomsForDatesAsync({
    required String serviceId,
    required DateTime checkIn,
    required DateTime checkOut,
    String? bedType,
    String? excludeBookingId,
  }) async {
    final backend = _ref?.read(bookingBackendProvider);
    if (backend != null) {
      final slots = await backend.getAvailableSlots(
        serviceId: serviceId,
        checkIn: checkIn,
        checkOut: checkOut,
      );
      if (slots != -1) {
        return slots;
      }
    }
    // Fallback to in-memory local state calculation
    return getAvailableRoomsForDates(
      serviceId: serviceId,
      checkIn: checkIn,
      checkOut: checkOut,
      bedType: bedType,
      excludeBookingId: excludeBookingId,
    );
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
          'p_taxes': booking.taxes,
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

  /// Automatically transitions confirmed bookings past their check-out date to completed.
  void _autoCompleteExpiredBookings() {
    if (!mounted || state.isEmpty) return;

    final now = DateTime.now();
    final expired = state.where((b) =>
        b.status == BookingStatus.confirmed &&
        b.checkOut.isBefore(now)).toList();

    if (expired.isEmpty) return;

    debugPrint('BookingRepository: Auto-completing ${expired.length} expired bookings...');
    for (final booking in expired) {
      updateBookingStatus(booking.id, BookingStatus.completed);
    }
  }

  /// Manages pending bookings: Disabled on client to prevent clock manipulation.
  /// Handled via server-side database tasks.
  void _autoManagePendingBookings() {
    // Empty client-side implementation to prevent security/cheat vulnerability
  }
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
