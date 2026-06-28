import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/booking_forms_model.dart';
import '../models/service_model.dart';
import '../services/tax_repository.dart';
import '../../core/services/supabase_service.dart';
import 'booking_backend_service.dart';
import 'booking_form_service.dart';
import 'service_repository.dart';
import 'discount_repository.dart';
import 'system_settings_repository.dart';
import 'special_offer_repository.dart';

final bookingIntegrationProvider = Provider<BookingIntegrationService>((ref) {
  return BookingIntegrationService(ref);
});

class BookingIntegrationService {
  final Ref _ref;
  BookingIntegrationService(this._ref);

  // Helper to ensure providerId and serviceTitle are fetched from DB if missing
  Future<Map<String, dynamic>> _ensureServiceDetails(
    Map<String, dynamic> bookingData,
  ) async {
    final serviceId = bookingData['serviceId'];
    if (serviceId == null) return bookingData;

    final currentProviderId = bookingData['providerId'];
    final currentTitle = bookingData['serviceTitle'];

    // Check if we already have valid data
    if (currentProviderId != null &&
        currentProviderId != '00000000-0000-0000-0000-000000000000' &&
        currentProviderId != 'unknown' &&
        currentTitle != null &&
        currentTitle.isNotEmpty) {
      return bookingData;
    }

    // 1. Try local cache first
    final services = _ref.read(serviceProvider);
    final cached = services.where((s) => s.id == serviceId);
    if (cached.isNotEmpty) {
      final s = cached.first;
      final newData = Map<String, dynamic>.from(bookingData);
      newData['providerId'] = s.providerId;
      newData['serviceTitle'] = s.title;
      debugPrint('Auto-filled service details from local cache for $serviceId');
      return newData;
    }

    // 2. Fetch from database
    try {
      final data = await SupabaseConfig.client
          .from('services')
          .select('provider_id, title')
          .eq('id', serviceId)
          .maybeSingle();

      if (data != null) {
        final newData = Map<String, dynamic>.from(bookingData);
        newData['providerId'] = data['provider_id'];
        newData['serviceTitle'] = data['title'];
        debugPrint('Auto-filled service details from database for $serviceId');
        return newData;
      }
    } catch (e) {
      debugPrint('Error auto-fetching service details: $e');
    }

    return bookingData;
  }

  // Complete booking flow for all service types
  Future<BookingResult> completeBooking({
    required ServiceType serviceType,
    required Map<String, dynamic> bookingData,
    required PaymentData paymentData,
  }) async {
    final backend = _ref.read(bookingBackendProvider);

    try {
      // Step 0: Automatic Service Detail Fetching (Provider ID & Title)
      final enrichedData = await _ensureServiceDetails(bookingData);

      // Step 1: Validate booking data
      final validation = _validateBookingData(serviceType, enrichedData);
      if (!validation.isValid) {
        return BookingResult(
          success: false,
          error: validation.errors.values.first,
          step: 'validation',
        );
      }

      // Step 2: Check availability
      final availability = await backend.checkAvailability(
        serviceId: enrichedData['serviceId'],
        checkIn: enrichedData['checkIn'],
        checkOut: enrichedData['checkOut'],
        guests: enrichedData['guests'],
        rooms: enrichedData['rooms'] ?? 1,
      );

      if (!availability) {
        return BookingResult(
          success: false,
          error: 'Service is not available for the selected dates',
          step: 'availability',
        );
      }

      // Step 3: Validate service availability (prevent double booking)
      final serviceAvailability = await backend.validateServiceAvailability(
        serviceId: enrichedData['serviceId'],
        checkIn: enrichedData['checkIn'],
        checkOut: enrichedData['checkOut'],
      );

      if (!serviceAvailability) {
        return BookingResult(
          success: false,
          error: 'This service is already booked for the selected dates',
          step: 'double_booking_check',
        );
      }

      // Step 4: Create booking (initially pending)
      final bookingId = const Uuid().v4();
      final booking = await backend.createBooking(
        id: bookingId,
        serviceId: enrichedData['serviceId'],
        providerId: enrichedData['providerId'],
        serviceTitle: enrichedData['serviceTitle'],
        travelerId: enrichedData['travelerId'],
        travelerName: enrichedData['travelerName'],
        checkIn: enrichedData['checkIn'],
        checkOut: enrichedData['checkOut'],
        guests: enrichedData['guests'],
        rooms: enrichedData['rooms'] ?? 1,
        totalPrice: enrichedData['totalPrice'],
        taxes: enrichedData['taxes'] ?? 0.0,
        contactPhone: enrichedData['contactPhone'],
        contactEmail: enrichedData['contactEmail'],
        specialRequests: enrichedData['specialRequests'],
        paymentData: paymentData,
        serviceType: serviceType,
        metadata: enrichedData['metadata'] ?? {},
      );

      // Step 5: Process payment (via Edge Function)
      // Pay Later bookings skip the real-time payment gateway but still go through backend logic
      if (paymentData.method != PaymentMethod.payLater) {
        final paymentResult = await backend.processPayment(
          paymentData: paymentData,
          amount: enrichedData['totalPrice'],
          bookingId: booking.id, // Use the real booking ID
        );

        if (!paymentResult.success) {
          return BookingResult(
            success: false,
            error: paymentResult.message,
            step: 'payment',
            booking: booking,
            paymentUrl: paymentResult.paymentUrl,
            status: paymentResult.status,
          );
        }

        return BookingResult(
          success: true,
          booking: booking,
          transactionId: paymentResult.transactionId,
          step: 'completed',
          paymentUrl: paymentResult.paymentUrl,
          status: paymentResult.status,
        );
      }

      // If Pay Later, it's already created as pending/unpaid
      return BookingResult(
        success: true,
        booking: booking,
        step: 'completed',
      );
    } catch (e) {
      debugPrint('Booking integration error: $e');
      return BookingResult(
        success: false,
        error: 'An unexpected error occurred: $e',
        step: 'integration',
      );
    }
  }

  // Quick booking with minimal validation
  Future<BookingResult> quickBooking({
    required String serviceId,
    required String serviceTitle,
    required String travelerId,
    required String travelerName,
    required DateTime checkIn,
    required DateTime checkOut,
    required int guests,
    required double totalPrice,
    required String contactPhone,
    required String contactEmail,
    required PaymentData paymentData,
    ServiceType serviceType = ServiceType.hotel,
  }) async {
    final backend = _ref.read(bookingBackendProvider);

    try {
      if (checkIn.isAfter(checkOut)) {
        return BookingResult(
          success: false,
          error: 'Check-in date must be before check-out date',
          step: 'quick_validation',
        );
      }

      final paymentResult = await backend.processPayment(
        paymentData: paymentData,
        amount: totalPrice,
        bookingId: const Uuid().v4(),
      );

      if (!paymentResult.success) {
        return BookingResult(
          success: false,
          error: paymentResult.message,
          step: 'payment',
        );
      }

      final enrichedData = await _ensureServiceDetails({
        'serviceId': serviceId,
        'serviceTitle': serviceTitle,
      });

      final booking = await backend.createBooking(
        serviceId: serviceId,
        providerId: enrichedData['providerId'],
        serviceTitle: enrichedData['serviceTitle'],
        travelerId: travelerId,
        travelerName: travelerName,
        checkIn: checkIn,
        checkOut: checkOut,
        guests: guests,
        rooms: 1,
        totalPrice: totalPrice,
        taxes:
            0.0, // Taxes should be calculated from settings or set to 0 as fallback
        contactPhone: contactPhone,
        contactEmail: contactEmail,
        paymentData: paymentData,
        serviceType: serviceType,
        metadata: {'quick_booking': true, 'serviceType': serviceType.name},
      );

      return BookingResult(
        success: true,
        booking: booking,
        transactionId: paymentResult.transactionId,
        step: 'quick_completed',
      );
    } catch (e) {
      debugPrint('Quick booking error: $e');
      return BookingResult(
        success: false,
        error: 'Quick booking failed: $e',
        step: 'quick_integration',
      );
    }
  }

  // Calculate total price
  Future<BookingSummary> calculateTotalPrice({
    required ServiceType serviceType,
    required Map<String, dynamic> bookingData,
    required double basePrice,
    Service? service,
    String? discountCode,
  }) async {
    final backend = _ref.read(bookingBackendProvider);

    try {
      // 1. Identify the provider and service for discount/tax lookup
      final enriched = await _ensureServiceDetails(bookingData);
      final providerId = service?.providerId ?? enriched['providerId'];
      final serviceId = bookingData['serviceId'] ?? '';

      // 2. Check for automatic discounts using the central repository logic
      final allDiscounts = _ref.read(discountRepositoryProvider);
      final activeDiscount = DiscountRepository.getBestDiscount(
        allDiscounts,
        serviceId,
        providerId,
      );

      BookingSummary summary;

      switch (serviceType) {
        case ServiceType.hotel:
          final hotelData = HotelBookingData(
            checkIn: bookingData['checkIn'],
            checkOut: bookingData['checkOut'],
            guests: bookingData['guests'],
            fullName: bookingData['fullName'] ?? '',
            email: bookingData['email'] ?? '',
            phone: bookingData['phone'] ?? '',
            rooms: bookingData['rooms'] ?? 1,
            bedType: bookingData['bedType'] ?? BedType.double,
            smokingPreference:
                bookingData['smokingPreference'] ??
                SmokingPreference.nonSmoking,
            breakfastIncluded: bookingData['breakfastIncluded'] ?? false,
            airportPickup: bookingData['airportPickup'] ?? false,
            extraBed: bookingData['extraBed'] ?? false,
            location: bookingData['location'] ?? '',
          );
          summary = BookingFormService.calculateHotelPrice(
            hotelData,
            service ??
                Service(
                  id: serviceId,
                  providerId: providerId,
                  title: '',
                  category: 'Hotel',
                  price: basePrice,
                  location: '',
                  description: '',
                  status: ServiceStatus.active,
                  images: [],
                ),
            _ref.read(activeTaxesProvider),
            platformFeePercentage: _ref
                .read(systemSettingsProvider)
                .platformFee,
            activeOffers: _ref.read(activeSpecialOffersProvider),
            activeDiscount: activeDiscount,
          );
          break;

        case ServiceType.apartment:
          final apartmentData = ApartmentBookingData(
            checkIn: bookingData['checkIn'],
            checkOut: bookingData['checkOut'],
            guests: bookingData['guests'],
            fullName: bookingData['fullName'] ?? '',
            email: bookingData['email'] ?? '',
            phone: bookingData['phone'] ?? '',
            stayPurpose: bookingData['stayPurpose'] ?? StayPurpose.vacation,
            cleaningService: bookingData['cleaningService'] ?? false,
            earlyCheckIn: bookingData['earlyCheckIn'] ?? false,
            lateCheckout: bookingData['lateCheckout'] ?? false,
            acceptHouseRules: bookingData['acceptHouseRules'] ?? false,
            pricingType: service?.pricingType ?? bookingData['pricingType'],
          );
          summary = BookingSummary(
            serviceType: ServiceType.apartment,
            serviceTitle: 'Apartment Booking',
            basePrice:
                (basePrice / 30) *
                apartmentData.checkOut.difference(apartmentData.checkIn).inDays,
            subtotal: basePrice,
            totalPrice: basePrice,
          ); // Fallback init
          summary = BookingFormService.calculateApartmentPrice(
            apartmentData,
            service ??
                Service(
                  id: serviceId,
                  providerId: providerId,
                  title: '',
                  category: 'Apartment',
                  price: basePrice,
                  location: '',
                  description: '',
                  status: ServiceStatus.active,
                  images: [],
                ),
            _ref.read(activeTaxesProvider),
            platformFeePercentage: _ref
                .read(systemSettingsProvider)
                .platformFee,
            activeOffers: _ref.read(activeSpecialOffersProvider),
            activeDiscount: activeDiscount,
          );
          break;

        case ServiceType.tour:
          if (bookingData['package'] == TourPackage.jumma) {
            final jummaData = JummaBookingData(
              checkIn: bookingData['checkIn'],
              checkOut: bookingData['checkOut'],
              guests: bookingData['guests'],
              fullName: bookingData['fullName'] ?? '',
              email: bookingData['email'] ?? '',
              phone: bookingData['phone'] ?? '',
              tourDate: bookingData['tourDate'] ?? bookingData['checkIn'],
              travelers: bookingData['travelers'] ?? bookingData['guests'],
              adultTravelers: bookingData['adultTravelers'] ?? 1,
              childTravelers: bookingData['childTravelers'] ?? 0,
              infantTravelers: bookingData['infantTravelers'] ?? 0,
              location: bookingData['location'] ?? '',
              preferredLocation: bookingData['preferredLocation'] ?? '',
              transportOption: bookingData['transportOption'] ?? '',
              accommodationType: bookingData['accommodationType'] ?? '',
              includeLunch: bookingData['includeLunch'] ?? false,
            );
            summary = BookingFormService.calculateTourPrice(
              jummaData,
              service ??
                  Service(
                    id: serviceId,
                    providerId: providerId,
                    title: '',
                    category: 'Tour',
                    price: basePrice,
                    location: '',
                    description: '',
                    status: ServiceStatus.active,
                    images: [],
                  ),
              _ref.read(activeTaxesProvider),
              platformFeePercentage: _ref
                  .read(systemSettingsProvider)
                  .platformFee,
              activeOffers: _ref.read(activeSpecialOffersProvider),
              activeDiscount: activeDiscount,
            );
          } else if (bookingData['package'] == TourPackage.eid) {
            final eidData = EidBookingData(
              checkIn: bookingData['checkIn'],
              checkOut: bookingData['checkOut'],
              guests: bookingData['guests'],
              fullName: bookingData['fullName'] ?? '',
              email: bookingData['email'] ?? '',
              phone: bookingData['phone'] ?? '',
              tourDate: bookingData['tourDate'] ?? bookingData['checkIn'],
              location: bookingData['location'] ?? '',
              eidType: bookingData['eidType'] ?? '',
              destination: bookingData['destination'] ?? '',
              numberOfDays: bookingData['numberOfDays'] ?? 1,
              transportOption: bookingData['transportOption'] ?? '',
              hotelRating: bookingData['hotelRating'] ?? 3,
              activities: List<String>.from(bookingData['activities'] ?? []),
              foodPackage: bookingData['foodPackage'] ?? '',
              travelers: bookingData['travelers'] ?? bookingData['guests'],
              adultTravelers: bookingData['adultTravelers'] ?? 1,
              childTravelers: bookingData['childTravelers'] ?? 0,
              infantTravelers: bookingData['infantTravelers'] ?? 0,
            );
            summary = BookingFormService.calculateTourPrice(
              eidData,
              service ??
                  Service(
                    id: serviceId,
                    providerId: providerId,
                    title: '',
                    category: 'Tour',
                    price: basePrice,
                    location: '',
                    description: '',
                    status: ServiceStatus.active,
                    images: [],
                  ),
              _ref.read(activeTaxesProvider),
              platformFeePercentage: _ref
                  .read(systemSettingsProvider)
                  .platformFee,
              activeOffers: _ref.read(activeSpecialOffersProvider),
              activeDiscount: activeDiscount,
            );
          } else if (bookingData['package'] == TourPackage.custom) {
            final customData = CustomTourBookingData(
              checkIn: bookingData['checkIn'],
              checkOut: bookingData['checkOut'],
              guests: bookingData['guests'],
              fullName: bookingData['fullName'] ?? '',
              email: bookingData['email'] ?? '',
              phone: bookingData['phone'] ?? '',
              tourDate: bookingData['tourDate'] ?? bookingData['checkIn'],
              location: bookingData['location'] ?? '',
              travelers: bookingData['travelers'] ?? bookingData['guests'],
              destination: bookingData['destination'] ?? '',
              preferredServices: List<String>.from(
                bookingData['preferredServices'] ?? [],
              ),
              numberOfDays: bookingData['numberOfDays'] ?? 1,
              notes: bookingData['notes'],
              adultTravelers: bookingData['adultTravelers'] ?? 1,
              childTravelers: bookingData['childTravelers'] ?? 0,
              infantTravelers: bookingData['infantTravelers'] ?? 0,
            );
            summary = BookingFormService.calculateTourPrice(
              customData,
              service ??
                  Service(
                    id: serviceId,
                    providerId: providerId,
                    title: '',
                    category: 'Tour',
                    price: basePrice,
                    location: '',
                    description: '',
                    status: ServiceStatus.active,
                    images: [],
                  ),
              _ref.read(activeTaxesProvider),
              platformFeePercentage: _ref
                  .read(systemSettingsProvider)
                  .platformFee,
              activeOffers: _ref.read(activeSpecialOffersProvider),
              activeDiscount: activeDiscount,
            );
          } else {
            final tourData = TourBookingData(
              checkIn: bookingData['checkIn'],
              checkOut: bookingData['checkOut'],
              guests: bookingData['guests'],
              fullName: bookingData['fullName'] ?? '',
              email: bookingData['email'] ?? '',
              phone: bookingData['phone'] ?? '',
              tourDate: bookingData['tourDate'] ?? bookingData['checkIn'],
              travelers: bookingData['travelers'] ?? bookingData['guests'],
              package: bookingData['package'] ?? TourPackage.custom,
              location: bookingData['location'] ?? '',
              languageGuide:
                  bookingData['languageGuide'] ?? LanguageGuide.english,
              mealPreference:
                  bookingData['mealPreference'] ?? MealPreference.noPreference,
              pickupLocation: bookingData['pickupLocation'] ?? '',
              adultTravelers: bookingData['adultTravelers'] ?? 1,
              childTravelers: bookingData['childTravelers'] ?? 0,
              infantTravelers: bookingData['infantTravelers'] ?? 0,
            );
            summary = BookingFormService.calculateTourPrice(
              tourData,
              service ??
                  Service(
                    id: serviceId,
                    providerId: providerId,
                    title: '',
                    category: 'Tour',
                    price: basePrice,
                    location: '',
                    description: '',
                    status: ServiceStatus.active,
                    images: [],
                  ),
              _ref.read(activeTaxesProvider),
              platformFeePercentage: _ref
                  .read(systemSettingsProvider)
                  .platformFee,
              activeOffers: _ref.read(activeSpecialOffersProvider),
              activeDiscount: activeDiscount,
            );
          }
          break;

        case ServiceType.vehicle:
          final vehicleData = VehicleBookingData(
            checkIn: bookingData['checkIn'],
            checkOut: bookingData['checkOut'],
            guests: 1,
            fullName: bookingData['fullName'] ?? '',
            email: bookingData['email'] ?? '',
            phone: bookingData['phone'] ?? '',
            pickupDateTime:
                bookingData['pickupDateTime'] ?? bookingData['checkIn'],
            returnDateTime:
                bookingData['returnDateTime'] ?? bookingData['checkOut'],
            pickupLocation: bookingData['pickupLocation'] ?? '',
            dropoffLocation: bookingData['dropoffLocation'] ?? '',
            driverLicenseNumber: bookingData['driverLicenseNumber'] ?? '',
            licenseExpiryDate:
                bookingData['licenseExpiryDate'] ??
                DateTime.now().add(const Duration(days: 365)),
            driverOption: bookingData['driverOption'] ?? DriverOption.selfDrive,
            insuranceOption:
                bookingData['insuranceOption'] ?? InsuranceOption.basic,
            childSeat: bookingData['childSeat'] ?? false,
            acceptRentalTerms: bookingData['acceptRentalTerms'] ?? false,
          );
          summary = BookingFormService.calculateVehiclePrice(
            vehicleData,
            service ??
                Service(
                  id: serviceId,
                  providerId: providerId,
                  title: '',
                  category: 'Vehicle',
                  price: basePrice,
                  location: '',
                  description: '',
                  status: ServiceStatus.active,
                  images: [],
                ),
            _ref.read(activeTaxesProvider),
            platformFeePercentage: _ref
                .read(systemSettingsProvider)
                .platformFee,
            activeOffers: _ref.read(activeSpecialOffersProvider),
            activeDiscount: activeDiscount,
          );
          break;
      }

      if (discountCode != null && discountCode.isNotEmpty) {
        final discountResult = await backend.applyDiscountCode(
          code: discountCode,
          amount: summary.totalPrice,
          serviceId: bookingData['serviceId'] ?? '',
        );

        if (discountResult['success']) {
          summary = BookingSummary(
            serviceType: summary.serviceType,
            serviceTitle: summary.serviceTitle,
            basePrice: summary.basePrice,
            subtotal: summary.subtotal,
            taxes: summary.taxes,
            discount:
                summary.discount +
                (discountResult['discount'] as num).toDouble(),
            totalPrice: (discountResult['finalAmount'] as num).toDouble(),
            extras: summary.extras,
          );
        }
      }

      return summary;
    } catch (e) {
      debugPrint('Error calculating total price: $e');
      return BookingSummary(
        serviceType: serviceType,
        serviceTitle: bookingData['serviceTitle'] ?? 'Service',
        basePrice: basePrice,
        subtotal: basePrice,
        taxes: 0.0,
        totalPrice: basePrice,
      );
    }
  }

  FormValidationState _validateBookingData(
    ServiceType serviceType,
    Map<String, dynamic> bookingData,
  ) {
    switch (serviceType) {
      case ServiceType.hotel:
        final hotelData = HotelBookingData(
          checkIn: bookingData['checkIn'],
          checkOut: bookingData['checkOut'],
          guests: bookingData['guests'],
          fullName:
              bookingData['fullName'] ?? bookingData['travelerName'] ?? '',
          email: (bookingData['email'] ?? bookingData['contactEmail'] ?? '')
              .toString()
              .trim(),
          phone: bookingData['phone'] ?? bookingData['contactPhone'] ?? '',
          rooms: bookingData['rooms'] ?? 1,
          bedType: bookingData['bedType'] ?? BedType.double,
          smokingPreference:
              bookingData['smokingPreference'] ?? SmokingPreference.nonSmoking,
          breakfastIncluded: bookingData['breakfastIncluded'] ?? false,
          airportPickup: bookingData['airportPickup'] ?? false,
          extraBed: bookingData['extraBed'] ?? false,
          location:
              (bookingData['location']?.toString().trim().isNotEmpty == true)
              ? bookingData['location'].toString().trim()
              : (bookingData['metadata']?['location']?.toString().trim() ?? ''),
        );
        return BookingFormService.validateHotelBooking(hotelData);

      case ServiceType.apartment:
        final apartmentData = ApartmentBookingData(
          checkIn: bookingData['checkIn'],
          checkOut: bookingData['checkOut'],
          guests: bookingData['guests'],
          fullName:
              bookingData['fullName'] ?? bookingData['travelerName'] ?? '',
          email: (bookingData['email'] ?? bookingData['contactEmail'] ?? '')
              .toString()
              .trim(),
          phone: bookingData['phone'] ?? bookingData['contactPhone'] ?? '',
          stayPurpose: bookingData['stayPurpose'] ?? StayPurpose.vacation,
          cleaningService: bookingData['cleaningService'] ?? false,
          earlyCheckIn: bookingData['earlyCheckIn'] ?? false,
          lateCheckout: bookingData['lateCheckout'] ?? false,
          acceptHouseRules: bookingData['acceptHouseRules'] ?? false,
          pricingType:
              bookingData['pricingType'] ??
              (bookingData['metadata']?['pricing_type']),
        );
        return BookingFormService.validateApartmentBooking(apartmentData);

      case ServiceType.tour:
        final metadata = bookingData['metadata'] ?? {};
        final travelersVal = bookingData['travelers'];
        final travelersCount = (travelersVal is List)
            ? (metadata['totalTravelers'] ?? travelersVal.length)
            : (travelersVal ?? bookingData['guests'] ?? 1);

        final adultTravelers =
            bookingData['adultTravelers'] ?? metadata['adultsCount'] ?? 1;
        final childTravelers =
            bookingData['childTravelers'] ?? metadata['childrenCount'] ?? 0;
        final infantTravelers =
            bookingData['infantTravelers'] ?? metadata['infantsCount'] ?? 0;

        if (bookingData['package'] == TourPackage.jumma) {
          final jummaData = JummaBookingData(
            checkIn: bookingData['checkIn'],
            checkOut: bookingData['checkOut'],
            guests: bookingData['guests'],
            fullName:
                bookingData['fullName'] ?? bookingData['travelerName'] ?? '',
            email: (bookingData['email'] ?? bookingData['contactEmail'] ?? '')
                .toString()
                .trim(),
            phone: bookingData['phone'] ?? bookingData['contactPhone'] ?? '',
            tourDate: bookingData['tourDate'] ?? bookingData['checkIn'],
            travelers: travelersCount is int
                ? travelersCount
                : (int.tryParse(travelersCount.toString()) ?? 1),
            location: bookingData['location'] ?? metadata['location'] ?? '',
            preferredLocation:
                bookingData['preferredLocation'] ??
                metadata['preferredLocation'] ??
                '',
            transportOption:
                bookingData['transportOption'] ??
                metadata['transportOption'] ??
                '',
            accommodationType:
                bookingData['accommodationType'] ??
                metadata['accommodationType'] ??
                '',
            includeLunch:
                bookingData['includeLunch'] ??
                metadata['includeLunch'] ??
                false,
          );
          return BookingFormService.validateJummaBooking(jummaData);
        } else if (bookingData['package'] == TourPackage.eid) {
          final eidData = EidBookingData(
            checkIn: bookingData['checkIn'],
            checkOut: bookingData['checkOut'],
            guests: bookingData['guests'],
            fullName:
                bookingData['fullName'] ?? bookingData['travelerName'] ?? '',
            email: (bookingData['email'] ?? bookingData['contactEmail'] ?? '')
                .toString()
                .trim(),
            phone: bookingData['phone'] ?? bookingData['contactPhone'] ?? '',
            tourDate: bookingData['tourDate'] ?? bookingData['checkIn'],
            travelers: travelersCount is int
                ? travelersCount
                : (int.tryParse(travelersCount.toString()) ?? 1),
            adultTravelers: adultTravelers is int
                ? adultTravelers
                : (int.tryParse(adultTravelers.toString()) ?? 1),
            childTravelers: childTravelers is int
                ? childTravelers
                : (int.tryParse(childTravelers.toString()) ?? 0),
            infantTravelers: infantTravelers is int
                ? infantTravelers
                : (int.tryParse(infantTravelers.toString()) ?? 0),
            location: bookingData['location'] ?? metadata['location'] ?? '',
            eidType: bookingData['eidType'] ?? metadata['eidType'] ?? '',
            destination:
                bookingData['destination'] ?? metadata['destination'] ?? '',
            numberOfDays:
                bookingData['numberOfDays'] ?? metadata['numberOfDays'] ?? 1,
            transportOption:
                bookingData['transportOption'] ??
                metadata['transportOption'] ??
                '',
            hotelRating:
                bookingData['hotelRating'] ?? metadata['hotelRating'] ?? 3,
            activities: List<String>.from(
              bookingData['activities'] ?? metadata['activities'] ?? [],
            ),
            foodPackage:
                bookingData['foodPackage'] ?? metadata['foodPackage'] ?? '',
          );
          return BookingFormService.validateEidBooking(eidData);
        } else if (bookingData['package'] == TourPackage.custom) {
          final customData = CustomTourBookingData(
            checkIn: bookingData['checkIn'],
            checkOut: bookingData['checkOut'],
            guests: bookingData['guests'],
            fullName:
                bookingData['fullName'] ?? bookingData['travelerName'] ?? '',
            email: (bookingData['email'] ?? bookingData['contactEmail'] ?? '')
                .toString()
                .trim(),
            phone: bookingData['phone'] ?? bookingData['contactPhone'] ?? '',
            tourDate: bookingData['tourDate'] ?? bookingData['checkIn'],
            travelers: travelersCount is int
                ? travelersCount
                : (int.tryParse(travelersCount.toString()) ?? 1),
            adultTravelers: adultTravelers is int
                ? adultTravelers
                : (int.tryParse(adultTravelers.toString()) ?? 1),
            childTravelers: childTravelers is int
                ? childTravelers
                : (int.tryParse(childTravelers.toString()) ?? 0),
            infantTravelers: infantTravelers is int
                ? infantTravelers
                : (int.tryParse(infantTravelers.toString()) ?? 0),
            location:
                (bookingData['location']?.toString().trim().isNotEmpty == true)
                ? bookingData['location'].toString().trim()
                : (metadata['location']?.toString().trim() ?? ''),
            destination:
                bookingData['destination'] ?? metadata['destination'] ?? '',
            preferredServices: List<String>.from(
              bookingData['preferredServices'] ??
                  metadata['preferredServices'] ??
                  [],
            ),
            numberOfDays:
                bookingData['numberOfDays'] ?? metadata['numberOfDays'] ?? 1,
            notes: bookingData['notes'] ?? metadata['notes'],
          );
          return BookingFormService.validateCustomTourBooking(customData);
        } else {
          final tourData = TourBookingData(
            checkIn: bookingData['checkIn'],
            checkOut: bookingData['checkOut'],
            guests: bookingData['guests'],
            fullName:
                bookingData['fullName'] ?? bookingData['travelerName'] ?? '',
            email: (bookingData['email'] ?? bookingData['contactEmail'] ?? '')
                .toString()
                .trim(),
            phone: bookingData['phone'] ?? bookingData['contactPhone'] ?? '',
            tourDate: bookingData['tourDate'] ?? bookingData['checkIn'],
            travelers: travelersCount is int
                ? travelersCount
                : (int.tryParse(travelersCount.toString()) ?? 1),
            adultTravelers: adultTravelers is int
                ? adultTravelers
                : (int.tryParse(adultTravelers.toString()) ?? 1),
            childTravelers: childTravelers is int
                ? childTravelers
                : (int.tryParse(childTravelers.toString()) ?? 0),
            infantTravelers: infantTravelers is int
                ? infantTravelers
                : (int.tryParse(infantTravelers.toString()) ?? 0),
            package: bookingData['package'] ?? TourPackage.custom,
            location: bookingData['location'] ?? metadata['location'] ?? '',
            languageGuide:
                bookingData['languageGuide'] ?? LanguageGuide.english,
            mealPreference:
                bookingData['mealPreference'] ?? MealPreference.noPreference,
            pickupLocation: bookingData['pickupLocation'] ?? '',
          );
          return BookingFormService.validateTourBooking(tourData);
        }

      case ServiceType.vehicle:
        final vehicleData = VehicleBookingData(
          checkIn: bookingData['checkIn'],
          checkOut: bookingData['checkOut'],
          guests: 1,
          fullName:
              bookingData['fullName'] ?? bookingData['travelerName'] ?? '',
          email: (bookingData['email'] ?? bookingData['contactEmail'] ?? '')
              .toString()
              .trim(),
          phone: bookingData['phone'] ?? bookingData['contactPhone'] ?? '',
          pickupDateTime:
              bookingData['pickupDateTime'] ?? bookingData['checkIn'],
          returnDateTime:
              bookingData['returnDateTime'] ?? bookingData['checkOut'],
          pickupLocation: bookingData['pickupLocation'] ?? '',
          dropoffLocation: bookingData['dropoffLocation'] ?? '',
          driverLicenseNumber: bookingData['driverLicenseNumber'] ?? '',
          licenseExpiryDate:
              bookingData['licenseExpiryDate'] ??
              DateTime.now().add(const Duration(days: 365)),
          driverOption: bookingData['driverOption'] ?? DriverOption.selfDrive,
          insuranceOption:
              bookingData['insuranceOption'] ?? InsuranceOption.basic,
          childSeat: bookingData['childSeat'] ?? false,
          acceptRentalTerms: bookingData['acceptRentalTerms'] ?? false,
        );
        return BookingFormService.validateVehicleBooking(vehicleData);
    }
  }
}

class BookingResult {
  final bool success;
  final dynamic booking;
  final String? transactionId;
  final String? error;
  final String step;
  final String? paymentUrl;
  final String? status;

  BookingResult({
    required this.success,
    this.booking,
    this.transactionId,
    this.error,
    required this.step,
    this.paymentUrl,
    this.status,
  });
}
