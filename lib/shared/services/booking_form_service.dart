import '../models/booking_forms_model.dart';
import '../models/tax_model.dart';
import '../models/user_model.dart';
import '../models/service_model.dart';
import '../models/special_offer_model.dart';
import '../models/discount_model.dart';

class BookingFormService {
  // Form validation methods
  static FormValidationState validateHotelBooking(HotelBookingData data) {
    final errors = <String, String>{};

    // Check-in/Check-out validation
    if (data.checkIn.isAfter(data.checkOut)) {
      errors['checkOut'] = 'Check-out date must be after check-in date';
    }

    if (data.checkIn.isBefore(
      DateTime.now().subtract(const Duration(days: 1)),
    )) {
      errors['checkIn'] = 'Check-in date cannot be in the past';
    }

    // Guest validation
    if (data.guests <= 0) {
      errors['guests'] = 'Number of guests must be at least 1';
    }

    // Room validation
    if (data.rooms <= 0) {
      errors['rooms'] = 'Number of rooms must be at least 1';
    }

    // Email validation
    if (!RegExp(
      r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
    ).hasMatch(data.email.trim())) {
      errors['email'] = 'Please enter a valid email address';
    }

    // Phone validation
    if (data.phone.length < 8) {
      errors['phone'] = 'Phone number must be at least 8 digits';
    }

    // Name validation
    if (data.fullName.trim().isEmpty) {
      errors['fullName'] = 'Full name is required';
    }

    // Location validation
    if (data.location.trim().isEmpty) {
      errors['location'] = 'Location is required';
    }

    return FormValidationState(isValid: errors.isEmpty, errors: errors);
  }

  static FormValidationState validateApartmentBooking(
    ApartmentBookingData data,
  ) {
    final errors = <String, String>{};

    // Check-in/Check-out validation
    if (data.checkIn.isAfter(data.checkOut)) {
      errors['checkOut'] = 'Check-out date must be after check-in date';
    }

    if (data.checkIn.isBefore(
      DateTime.now().subtract(const Duration(days: 1)),
    )) {
      errors['checkIn'] = 'Check-in date cannot be in the past';
    }

    // Guest validation
    if (data.guests <= 0) {
      errors['guests'] = 'Number of guests must be at least 1';
    }

    // Email validation
    if (!RegExp(
      r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
    ).hasMatch(data.email.trim())) {
      errors['email'] = 'Please enter a valid email address';
    }

    // Phone validation
    if (data.phone.length < 8) {
      errors['phone'] = 'Phone number must be at least 8 digits';
    }

    // Name validation
    if (data.fullName.trim().isEmpty) {
      errors['fullName'] = 'Full name is required';
    }

    // House rules validation
    if (!data.acceptHouseRules) {
      errors['acceptHouseRules'] = 'You must accept the house rules';
    }

    return FormValidationState(isValid: errors.isEmpty, errors: errors);
  }

  static FormValidationState validateTourBooking(TourBookingData data) {
    final errors = <String, String>{};

    // Tour date validation
    if (data.tourDate.isBefore(
      DateTime.now().subtract(const Duration(days: 1)),
    )) {
      errors['tourDate'] = 'Tour date cannot be in the past';
    }

    // Travelers validation
    if (data.travelers <= 0) {
      errors['travelers'] = 'Number of travelers must be at least 1';
    }

    // Contact and preferences are optional as per requested flow

    return FormValidationState(isValid: errors.isEmpty, errors: errors);
  }

  static FormValidationState validateJummaBooking(JummaBookingData data) {
    final errors = <String, String>{};

    if (data.fullName.isEmpty) {
      errors['fullName'] = 'Full name is required';
    }
    if (data.preferredLocation.isEmpty) {
      errors['preferredLocation'] = 'Location is required';
    }
    if (data.tourDate.weekday != DateTime.friday) {
      errors['tourDate'] = 'Jumma package is only available on Fridays';
    }

    return FormValidationState(isValid: errors.isEmpty, errors: errors);
  }

  static FormValidationState validateEidBooking(EidBookingData data) {
    final errors = <String, String>{};

    if (data.fullName.isEmpty) {
      errors['fullName'] = 'Full name is required';
    }
    if (data.destination.isEmpty) {
      errors['destination'] = 'Destination is required';
    }
    if (data.numberOfDays <= 0) {
      errors['numberOfDays'] = 'Number of days must be at least 1';
    }

    return FormValidationState(isValid: errors.isEmpty, errors: errors);
  }

  static FormValidationState validateCustomTourBooking(
    CustomTourBookingData data,
  ) {
    final errors = <String, String>{};

    if (data.fullName.isEmpty) {
      errors['fullName'] = 'Full name is required';
    }
    if (data.location.trim().isEmpty) {
      errors['location'] = 'Location is required';
    }
    if (data.destination.isEmpty) {
      errors['destination'] = 'Destination is required';
    }

    return FormValidationState(isValid: errors.isEmpty, errors: errors);
  }

  static FormValidationState validateVehicleBooking(VehicleBookingData data) {
    final errors = <String, String>{};

    // Pickup/Return validation
    if (data.pickupDateTime.isAfter(data.returnDateTime)) {
      errors['returnDateTime'] = 'Return date must be after pickup date';
    }

    if (data.pickupDateTime.isBefore(
      DateTime.now().subtract(const Duration(hours: 1)),
    )) {
      errors['pickupDateTime'] = 'Pickup date cannot be in the past';
    }

    // Email validation
    if (!RegExp(
      r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
    ).hasMatch(data.email.trim())) {
      errors['email'] = 'Please enter a valid email address';
    }

    // Phone validation
    if (data.phone.length < 8) {
      errors['phone'] = 'Phone number must be at least 8 digits';
    }

    // Name validation
    if (data.fullName.trim().isEmpty) {
      errors['fullName'] = 'Full name is required';
    }

    // License validation
    if (data.driverLicenseNumber.trim().isEmpty) {
      errors['driverLicenseNumber'] = 'Driver license number is required';
    }

    if (data.licenseExpiryDate.isBefore(DateTime.now())) {
      errors['licenseExpiryDate'] = 'License has expired';
    }

    // Location validation
    if (data.pickupLocation.trim().isEmpty) {
      errors['pickupLocation'] = 'Pickup location is required';
    }

    if (data.dropoffLocation.trim().isEmpty) {
      errors['dropoffLocation'] = 'Drop-off location is required';
    }

    // Terms validation
    if (!data.acceptRentalTerms) {
      errors['acceptRentalTerms'] = 'You must accept the rental terms';
    }

    return FormValidationState(isValid: errors.isEmpty, errors: errors);
  }

  static FormValidationState validatePayment(PaymentData data) {
    final errors = <String, String>{};

    switch (data.method) {
      case PaymentMethod.card:
        if (data.cardholderName?.trim().isEmpty ?? true) {
          errors['cardholderName'] = 'Cardholder name is required';
        }
        if (data.cardNumber?.trim().isEmpty ?? true) {
          errors['cardNumber'] = 'Card number is required';
        } else if (!isValidCardNumber(data.cardNumber!)) {
          errors['cardNumber'] = 'Invalid card number';
        }
        if (data.expiryDate?.trim().isEmpty ?? true) {
          errors['expiryDate'] = 'Expiry date is required';
        } else if (!isValidExpiryDate(data.expiryDate!)) {
          errors['expiryDate'] = 'Invalid or expired card';
        }
        if (data.cvv?.trim().isEmpty ?? true) {
          errors['cvv'] = 'CVV is required';
        } else if (data.cvv!.length < 3 || data.cvv!.length > 4) {
          errors['cvv'] = 'CVV must be 3-4 digits';
        }
        break;

      case PaymentMethod.mobileMoney:
        if (data.mobileProvider?.trim().isEmpty ?? true) {
          errors['mobileProvider'] = 'Mobile provider is required';
        }
        break;

      case PaymentMethod.bank:
        if (data.mobileProvider?.trim().isEmpty ?? true) {
          errors['mobileProvider'] = 'Bank name is required';
        }
        if (data.transactionReference?.trim().isEmpty ?? true) {
          errors['transactionReference'] = 'Transaction reference is required';
        }
        break;

      case PaymentMethod.payLater:
        // No validation needed for pay later
        break;
    }

    return FormValidationState(isValid: errors.isEmpty, errors: errors);
  }

  // Price calculation methods
  static BookingSummary calculateHotelPrice(
    HotelBookingData data,
    Service service,
    List<TaxModel> activeTaxes, {
    double platformFeePercentage = 0,
    List<SpecialOffer> activeOffers = const [],
    Discount? activeDiscount,
  }) {
    double basePrice = service.price;
    double totalPrice = basePrice;
    final extras = <String, dynamic>{};

    // Calculate room price
    final nights = data.checkOut.difference(data.checkIn).inDays;
    totalPrice *= nights * data.rooms;

    // Add extras
    if (data.breakfastIncluded) {
      final breakfastCost = (data.breakfastPrice ?? 0.0) * data.guests * nights;
      totalPrice += breakfastCost;
      extras['breakfast'] = breakfastCost;
    }

    if (data.airportPickup) {
      final pickupCost = data.airportPickupPrice ?? 0.0;
      totalPrice += pickupCost;
      extras['airportPickup'] = pickupCost;
    }

    if (data.extraBed) {
      final bedCost = (data.extraBedPrice ?? 0.0) * nights;
      totalPrice += bedCost;
      extras['extraBed'] = bedCost;
    }

    double subtotal = totalPrice;

    double totalDiscount = 0;

    // Apply special offer discount (before taxes)
    final offerResult = applySpecialOfferDiscount(
      serviceId: service.id,
      priceBeforeTaxes: totalPrice,
      activeOffers: activeOffers,
    );
    if (offerResult != null) {
      final offerAmount = offerResult['discountAmount'] as double;
      totalPrice -= offerAmount;
      totalDiscount += offerAmount;
      extras['specialOffer'] = offerResult['label'];
    }

    // Apply Automatic Discount (before taxes)
    if (activeDiscount != null) {
      double discountAmount = 0;
      if (activeDiscount.isPercentage) {
        discountAmount = totalPrice * (activeDiscount.value / 100);
      } else {
        discountAmount = activeDiscount.value;
      }
      totalPrice -= discountAmount;
      totalDiscount += discountAmount;
      extras['automaticDiscount'] = activeDiscount.discountText;
      extras['discountLabel'] = activeDiscount.badgeText;
    }

    // Calculate taxes from active taxes
    double totalTaxAmount = 0;
    final relevantTaxes = activeTaxes.where(
      (t) =>
          t.providerType == ProviderType.hotel ||
          t.providerType == ProviderType.all,
    );

    for (final tax in relevantTaxes) {
      if (tax.taxType == TaxType.percentage) {
        totalTaxAmount += (totalPrice * (tax.rate / 100));
      } else {
        totalTaxAmount += tax.rate;
      }
    }

    totalPrice += totalTaxAmount;

    // Apply System Fee
    if (platformFeePercentage > 0) {
      final systemFeeAmount = totalPrice * (platformFeePercentage / 100);
      totalPrice += systemFeeAmount;
      extras['systemFee'] =
          'System Fee (${platformFeePercentage.toStringAsFixed(1)}%) : \$${systemFeeAmount.toStringAsFixed(2)}';
    }

    return BookingSummary(
      serviceType: ServiceType.hotel,
      serviceTitle: 'Hotel Booking',
      basePrice: basePrice * nights * data.rooms,
      subtotal: subtotal,
      taxes: totalTaxAmount,
      discount: totalDiscount,
      totalPrice: totalPrice,
      extras: extras,
    );
  }

  static BookingSummary calculateApartmentPrice(
    ApartmentBookingData data,
    Service service,
    List<TaxModel> activeTaxes, {
    double platformFeePercentage = 0,
    List<SpecialOffer> activeOffers = const [],
    Discount? activeDiscount,
  }) {
    double basePrice = service.price;
    double totalPrice = basePrice;
    final extras = <String, dynamic>{};

    // Calculate stay price
    final nights = data.checkOut.difference(data.checkIn).inDays;
    final pricingType = data.pricingType?.toLowerCase() ?? 'monthly';

    if (pricingType == 'nightly') {
      totalPrice = basePrice * nights;
    } else {
      totalPrice = (basePrice / 30) * nights;
    }

    // Add extras
    if (data.cleaningService) {
      final cleaningCost = data.cleaningPrice ?? 0.0;
      totalPrice += cleaningCost;
      extras['cleaningService'] = cleaningCost;
    }

    if (data.earlyCheckIn) {
      final earlyCheckInCost = data.earlyCheckInPrice ?? 0.0;
      totalPrice += earlyCheckInCost;
      extras['earlyCheckIn'] = earlyCheckInCost;
    }

    if (data.lateCheckout) {
      final lateCheckoutCost = data.lateCheckoutPrice ?? 0.0;
      totalPrice += lateCheckoutCost;
      extras['lateCheckout'] = lateCheckoutCost;
    }

    double subtotal = totalPrice;

    double totalDiscount = 0;

    // Apply special offer discount (before taxes)
    final offerResult = applySpecialOfferDiscount(
      serviceId: service.id,
      priceBeforeTaxes: totalPrice,
      activeOffers: activeOffers,
    );
    if (offerResult != null) {
      final offerAmount = offerResult['discountAmount'] as double;
      totalPrice -= offerAmount;
      totalDiscount += offerAmount;
      extras['specialOffer'] = offerResult['label'];
    }

    // Apply Automatic Discount (before taxes)
    if (activeDiscount != null) {
      double discountAmount = 0;
      if (activeDiscount.isPercentage) {
        discountAmount = totalPrice * (activeDiscount.value / 100);
      } else {
        discountAmount = activeDiscount.value;
      }
      totalPrice -= discountAmount;
      totalDiscount += discountAmount;
      extras['automaticDiscount'] = activeDiscount.discountText;
      extras['discountLabel'] = activeDiscount.badgeText;
    }

    // Calculate taxes from active taxes
    double totalTaxAmount = 0;
    final relevantTaxes = activeTaxes.where(
      (t) =>
          t.providerType == ProviderType.apartment ||
          t.providerType == ProviderType.home ||
          t.providerType == ProviderType.all,
    );

    for (final tax in relevantTaxes) {
      if (tax.taxType == TaxType.percentage) {
        totalTaxAmount += (totalPrice * (tax.rate / 100));
      } else {
        totalTaxAmount += tax.rate;
      }
    }

    totalPrice += totalTaxAmount;

    // Apply System Fee
    if (platformFeePercentage > 0) {
      final systemFeeAmount = totalPrice * (platformFeePercentage / 100);
      totalPrice += systemFeeAmount;
      extras['systemFee'] =
          'System Fee (${platformFeePercentage.toStringAsFixed(1)}%) : \$${systemFeeAmount.toStringAsFixed(2)}';
    }

    return BookingSummary(
      serviceType: ServiceType.apartment,
      serviceTitle: 'Apartment Booking',
      basePrice: (basePrice / 30) * nights,
      subtotal: subtotal,
      taxes: totalTaxAmount,
      discount: totalDiscount,
      totalPrice: totalPrice,
      extras: extras,
    );
  }

  static BookingSummary calculateTourPrice(
    TourBookingData data,
    Service service,
    List<TaxModel> activeTaxes, {
    double platformFeePercentage = 0,
    double packageMultiplier = 1.0,
    List<SpecialOffer> activeOffers = const [],
    Discount? activeDiscount,
  }) {
    double adultPrice = service.adultPrice ?? service.price;
    double childPrice =
        service.childPrice ?? (service.adultPrice ?? service.price) * 0.5;
    // Calculate base price based on travelers and multiply by days
    double baseTotalPrice =
        (adultPrice * data.adultTravelers) + (childPrice * data.childTravelers);
    double totalPrice = baseTotalPrice * data.numberOfDays;

    // Apply dynamic multiplier
    totalPrice *= packageMultiplier;

    final extras = <String, dynamic>{};
    if (data.numberOfDays > 1) {
      extras['duration'] = '${data.numberOfDays} Days (x${data.numberOfDays})';
    }

    // Multipliers (Jumma/Eid) - Labels only now as multiplier is dynamic
    switch (data.package) {
      case TourPackage.jumma:
        extras['packageUpgrade'] = 'Jumma Package';
        break;
      case TourPackage.eid:
        if (packageMultiplier > 1.0) {
          extras['packageUpgrade'] =
              'Eid Package (+${((packageMultiplier - 1.0) * 100).toStringAsFixed(0)}%)';
        } else {
          extras['packageUpgrade'] = 'Eid Package';
        }
        break;
      case TourPackage.custom:
        extras['packageUpgrade'] = 'Custom Package';
        break;
    }

    // Add Preferred Services Prices
    final extraPrices =
        service.metadata['extraServicePrices'] as Map<String, dynamic>? ?? {};
    if (data.preferredServices != null) {
      for (final serviceName in data.preferredServices!) {
        final price = extraPrices[serviceName];
        if (price != null && price is num && price > 0) {
          final totalExtraPrice = price.toDouble() * data.numberOfDays;
          totalPrice += totalExtraPrice;
          extras['extra_$serviceName'] = data.numberOfDays > 1
              ? '$serviceName (\$+${price.toStringAsFixed(2)} x ${data.numberOfDays} days = \$${totalExtraPrice.toStringAsFixed(2)})'
              : '$serviceName (+\$${price.toStringAsFixed(2)})';
        }
      }
    }

    double subtotal = totalPrice;

    double totalDiscount = 0;

    // Apply special offer discount (before taxes)
    final offerResult = applySpecialOfferDiscount(
      serviceId: service.id,
      priceBeforeTaxes: totalPrice,
      activeOffers: activeOffers,
    );
    if (offerResult != null) {
      final offerAmount = offerResult['discountAmount'] as double;
      totalPrice -= offerAmount;
      totalDiscount += offerAmount;
      extras['specialOffer'] = offerResult['label'];
    }

    // Apply Automatic Discount (before taxes)
    if (activeDiscount != null) {
      double discountAmount = 0;
      if (activeDiscount.isPercentage) {
        discountAmount = totalPrice * (activeDiscount.value / 100);
      } else {
        discountAmount = activeDiscount.value;
      }
      totalPrice -= discountAmount;
      totalDiscount += discountAmount;
      extras['automaticDiscount'] = activeDiscount.discountText;
      extras['discountLabel'] = activeDiscount.badgeText;
    }

    // Calculate taxes from active taxes
    double totalTaxAmount = 0;
    final relevantTaxes = activeTaxes.where(
      (t) =>
          t.providerType == ProviderType.tour ||
          t.providerType == ProviderType.all,
    );

    for (final tax in relevantTaxes) {
      if (tax.taxType == TaxType.percentage) {
        totalTaxAmount += (totalPrice * (tax.rate / 100));
      } else {
        totalTaxAmount += tax.rate;
      }
    }

    totalPrice += totalTaxAmount;

    // Apply System Fee
    if (platformFeePercentage > 0) {
      final systemFeeAmount = totalPrice * (platformFeePercentage / 100);
      totalPrice += systemFeeAmount;
      extras['systemFee'] =
          'System Fee (${platformFeePercentage.toStringAsFixed(1)}%) : \$${systemFeeAmount.toStringAsFixed(2)}';
    }

    return BookingSummary(
      serviceType: ServiceType.tour,
      serviceTitle: 'Tour Booking',
      basePrice: baseTotalPrice * data.numberOfDays * packageMultiplier,
      subtotal: subtotal,
      taxes: totalTaxAmount,
      discount: totalDiscount,
      totalPrice: totalPrice,
      extras: extras,
    );
  }

  static BookingSummary calculateVehiclePrice(
    VehicleBookingData data,
    Service service,
    List<TaxModel> activeTaxes, {
    double platformFeePercentage = 0,
    List<SpecialOffer> activeOffers = const [],
    Discount? activeDiscount,
  }) {
    double basePrice = service.price;
    double totalPrice = basePrice;
    final extras = <String, dynamic>{};

    // Calculate rental duration (in days)
    final days = data.returnDateTime.difference(data.pickupDateTime).inDays;
    if (days == 0) {
      totalPrice *= 1; // Minimum 1 day charge
    } else {
      totalPrice *= days;
    }

    // Add driver option
    if (data.driverOption == DriverOption.withDriver) {
      final driverCost = 50.0 * days;
      totalPrice += driverCost;
      extras['driver'] = driverCost;
    }

    // Add insurance
    switch (data.insuranceOption) {
      case InsuranceOption.basic:
        final insuranceCost = 15.0 * days;
        totalPrice += insuranceCost;
        extras['insurance'] = insuranceCost;
        break;
      case InsuranceOption.comprehensive:
        final insuranceCost = 25.0 * days;
        totalPrice += insuranceCost;
        extras['insurance'] = insuranceCost;
        break;
      case InsuranceOption.none:
        break;
    }

    if (data.childSeat) {
      final seatCost = 10.0 * days;
      totalPrice += seatCost;
      extras['childSeat'] = seatCost;
    }

    double subtotal = totalPrice;

    double totalDiscount = 0;

    // Apply special offer discount (before taxes)
    final offerResult = applySpecialOfferDiscount(
      serviceId: service.id,
      priceBeforeTaxes: totalPrice,
      activeOffers: activeOffers,
    );
    if (offerResult != null) {
      final offerAmount = offerResult['discountAmount'] as double;
      totalPrice -= offerAmount;
      totalDiscount += offerAmount;
      extras['specialOffer'] = offerResult['label'];
    }

    // Apply Automatic Discount (before taxes)
    if (activeDiscount != null) {
      double discountAmount = 0;
      if (activeDiscount.isPercentage) {
        discountAmount = totalPrice * (activeDiscount.value / 100);
      } else {
        discountAmount = activeDiscount.value;
      }
      totalPrice -= discountAmount;
      totalDiscount += discountAmount;
      extras['automaticDiscount'] = activeDiscount.discountText;
      extras['discountLabel'] = activeDiscount.badgeText;
    }

    // Calculate taxes from active taxes
    double totalTaxAmount = 0;
    // Vehicles don't have a specific ProviderType but we can use 'all' or add one
    final relevantTaxes = activeTaxes.where(
      (t) => t.providerType == ProviderType.all,
    );

    for (final tax in relevantTaxes) {
      if (tax.taxType == TaxType.percentage) {
        totalTaxAmount += (totalPrice * (tax.rate / 100));
      } else {
        totalTaxAmount += tax.rate;
      }
    }

    totalPrice += totalTaxAmount;

    // Apply System Fee
    if (platformFeePercentage > 0) {
      final systemFeeAmount = totalPrice * (platformFeePercentage / 100);
      totalPrice += systemFeeAmount;
      extras['systemFee'] =
          'System Fee (${platformFeePercentage.toStringAsFixed(1)}%) : \$${systemFeeAmount.toStringAsFixed(2)}';
    }

    return BookingSummary(
      serviceType: ServiceType.vehicle,
      serviceTitle: 'Vehicle Booking',
      basePrice: basePrice * (days == 0 ? 1 : days),
      subtotal: subtotal,
      taxes: totalTaxAmount,
      discount: totalDiscount,
      totalPrice: totalPrice,
      extras: extras,
    );
  }

  // ─── Special Offer Discount ────────────────────────────────────────────────
  /// Checks if any active special offer is linked to [serviceId].
  /// Returns a map with 'discountAmount' (double) and 'label' (String),
  /// or null if no applicable offer is found.
  static Map<String, dynamic>? applySpecialOfferDiscount({
    required String serviceId,
    required double priceBeforeTaxes,
    required List<SpecialOffer> activeOffers,
  }) {
    final offer = activeOffers
        .where(
          (o) =>
              o.isActive &&
              o.linkedServiceId == serviceId &&
              (o.discountPercent ?? 0) > 0,
        )
        .firstOrNull;

    if (offer == null) return null;

    final discountAmount = priceBeforeTaxes * (offer.discountPercent! / 100);
    return {
      'discountAmount': discountAmount,
      'label':
          '${offer.title} (${offer.discount}) — \$${discountAmount.toStringAsFixed(2)} saved',
      'offer': offer,
    };
  }
  // ──────────────────────────────────────────────────────────────────────────

  // Helper validation methods
  static bool isValidCardNumber(String cardNumber) {
    // Remove spaces and dashes
    final cleanNumber = cardNumber.replaceAll(RegExp(r'[\s-]'), '');

    // Check if it's all digits and has valid length
    if (!RegExp(r'^\d+$').hasMatch(cleanNumber) ||
        cleanNumber.length < 13 ||
        cleanNumber.length > 19) {
      return false;
    }

    // Luhn algorithm
    int sum = 0;
    bool alternate = false;

    for (int i = cleanNumber.length - 1; i >= 0; i--) {
      int digit = int.parse(cleanNumber[i]);

      if (alternate) {
        digit *= 2;
        if (digit > 9) {
          digit = (digit % 10) + 1;
        }
      }

      sum += digit;
      alternate = !alternate;
    }

    return sum % 10 == 0;
  }

  static bool isValidExpiryDate(String expiryDate) {
    // Format: MM/YY
    final match = RegExp(r'^(0[1-9]|1[0-2])\/(\d{2})$').firstMatch(expiryDate);
    if (match == null) return false;

    final month = int.parse(match.group(1)!);
    final year = int.parse('20${match.group(2)!}');

    final expiry = DateTime(year, month);
    final now = DateTime.now();

    // Check if expiry is after current month
    // Card is valid until the end of the month
    final currentMonthStart = DateTime(now.year, now.month);
    return !expiry.isBefore(currentMonthStart);
  }

  static bool isValidMobileNumber(String mobileNumber) {
    // Remove spaces and dashes
    final cleanNumber = mobileNumber.replaceAll(RegExp(r'[\s-]'), '');

    // Check if it's all digits and has valid length (8-15 digits)
    return RegExp(r'^\d{8,15}$').hasMatch(cleanNumber);
  }
}
