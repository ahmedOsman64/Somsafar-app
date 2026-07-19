enum ServiceType { hotel, apartment, tour, vehicle }

enum PaymentMethod { card, mobileMoney, bank, payLater }

enum BedType { single, double, twin }

enum SmokingPreference { smoking, nonSmoking, any }

enum StayPurpose { business, vacation, family, longTerm }

enum TourPackage { 
  jumma, // Labeled in UI as "Dalxiis Maalinle ah (Single Day Tour / Day Trip)"
  eid,    // Labeled in UI as "Safar Dhowr Maalmood ah (Multi-Day Tour / Group Package)"
  custom, // Labeled in UI as "Dalxiis Gaar ah / Dalab (Custom & Private Tour)"
}

enum LanguageGuide { english, somali, arabic, italian }

enum MealPreference {
  somaliTraditional,
  seafood,
  grilled,
  vegetarian,
  noPreference,
}

enum DriverOption { withDriver, selfDrive }

enum InsuranceOption { basic, comprehensive, none }

// Base booking form data
abstract class BookingFormData {
  final DateTime checkIn;
  final DateTime checkOut;
  final int guests;
  final String fullName;
  final String email;
  final String phone;
  final String? specialRequests;

  BookingFormData({
    required this.checkIn,
    required this.checkOut,
    required this.guests,
    required this.fullName,
    required this.email,
    required this.phone,
    this.specialRequests,
  });
}

// Hotel Booking Data
class HotelBookingData extends BookingFormData {
  final int rooms;
  final BedType bedType;
  final SmokingPreference smokingPreference;
  final bool breakfastIncluded;
  final bool airportPickup;
  final bool extraBed;
  final String location;
  final double? breakfastPrice;
  final double? airportPickupPrice;
  final double? extraBedPrice;
  final List<String> selectedCustomOptionIds;

  HotelBookingData({
    required super.checkIn,
    required super.checkOut,
    required super.guests,
    required super.fullName,
    required super.email,
    required super.phone,
    required this.rooms,
    required this.bedType,
    required this.smokingPreference,
    this.breakfastIncluded = false,
    this.airportPickup = false,
    this.extraBed = false,
    required this.location,
    this.breakfastPrice,
    this.airportPickupPrice,
    this.extraBedPrice,
    this.selectedCustomOptionIds = const [],
    super.specialRequests,
  });
}

// Apartment Booking Data
class ApartmentBookingData extends BookingFormData {
  final StayPurpose stayPurpose;
  final bool cleaningService;
  final bool earlyCheckIn;
  final bool lateCheckout;
  final bool acceptHouseRules;
  final double? cleaningPrice;
  final double? earlyCheckInPrice;
  final double? lateCheckoutPrice;
  final String? pricingType;

  ApartmentBookingData({
    required super.checkIn,
    required super.checkOut,
    required super.guests,
    required super.fullName,
    required super.email,
    required super.phone,
    required this.stayPurpose,
    this.cleaningService = false,
    this.earlyCheckIn = false,
    this.lateCheckout = false,
    this.acceptHouseRules = false,
    this.cleaningPrice,
    this.earlyCheckInPrice,
    this.lateCheckoutPrice,
    this.pricingType,
    super.specialRequests,
  });
}

// Tour Booking Data
class TourBookingData extends BookingFormData {
  final DateTime tourDate;
  final int travelers;
  final TourPackage package;
  final String? passportNumber;
  final String location; // Moved here
  final LanguageGuide languageGuide;
  final MealPreference mealPreference;
  final String pickupLocation;
  final String? medicalConditions;
  final String? specialInformation;
  final int adultTravelers;
  final int childTravelers;
  final int infantTravelers;
  final List<String>? preferredServices;
  final int numberOfDays;

  TourBookingData({
    required super.checkIn,
    required super.checkOut,
    required super.guests,
    required super.fullName,
    required super.email,
    required super.phone,
    required this.tourDate,
    required this.travelers,
    required this.package,
    this.passportNumber,
    required this.location,
    required this.languageGuide,
    required this.mealPreference,
    required this.pickupLocation,
    this.medicalConditions,
    this.specialInformation,
    this.adultTravelers = 1,
    this.childTravelers = 0,
    this.infantTravelers = 0,
    this.numberOfDays = 1,
    this.preferredServices,
    super.specialRequests,
  });
}

// Jumma Package Data
class JummaBookingData extends TourBookingData {
  final String preferredLocation;
  final String transportOption;
  final String accommodationType;
  final bool includeLunch;

  JummaBookingData({
    required super.checkIn,
    required super.checkOut,
    required super.guests,
    required super.fullName,
    required super.email,
    required super.phone,
    required super.tourDate,
    required super.travelers,
    required super.location,
    required this.preferredLocation,
    required this.transportOption,
    required this.accommodationType,
    required this.includeLunch,
    super.specialInformation,
    super.package = TourPackage.jumma,
    super.languageGuide = LanguageGuide.somali,
    super.mealPreference = MealPreference.somaliTraditional,
    super.pickupLocation = '',
    super.adultTravelers = 1,
    super.childTravelers = 0,
    super.infantTravelers = 0,
    super.specialRequests,
    super.preferredServices,
  });
}

// Eid Package Data
class EidBookingData extends TourBookingData {
  final String eidType; // Eid al-Fitr / Eid al-Adha
  final String destination;
  final String transportOption;
  final int hotelRating;
  final List<String> activities;
  final String foodPackage;
  final String? childSpecificNeeds;

  EidBookingData({
    required super.checkIn,
    required super.checkOut,
    required super.guests,
    required super.fullName,
    required super.email,
    required super.phone,
    required super.tourDate,
    required super.travelers,
    required super.location,
    required this.eidType,
    required this.destination,
    required super.numberOfDays,
    required this.transportOption,
    required this.hotelRating,
    this.activities = const [],
    required this.foodPackage,
    this.childSpecificNeeds,
    super.specialInformation,
    super.package = TourPackage.eid,
    super.languageGuide = LanguageGuide.somali,
    super.mealPreference = MealPreference.somaliTraditional,
    super.pickupLocation = '',
    super.adultTravelers = 1,
    super.childTravelers = 0,
    super.infantTravelers = 0,
    super.specialRequests,
    super.preferredServices,
  });
}

// Custom Tourist Package Data
class CustomTourBookingData extends TourBookingData {
  final String destination;
  final String? notes;

  CustomTourBookingData({
    required super.checkIn,
    required super.checkOut,
    required super.guests,
    required super.fullName,
    required super.email,
    required super.phone,
    required super.tourDate,
    required super.travelers,
    required super.location,
    required this.destination,
    required super.preferredServices,
    this.notes,
    super.specialInformation,
    super.package = TourPackage.custom,
    super.languageGuide = LanguageGuide.english,
    super.mealPreference = MealPreference.noPreference,
    super.pickupLocation = '',
    super.passportNumber,
    super.adultTravelers = 1,
    super.childTravelers = 0,
    super.infantTravelers = 0,
    required super.numberOfDays,
    super.specialRequests,
  });
}

// Vehicle Booking Data
class VehicleBookingData extends BookingFormData {
  final DateTime pickupDateTime;
  final DateTime returnDateTime;
  final String pickupLocation;
  final String dropoffLocation;
  final String driverLicenseNumber;
  final DateTime licenseExpiryDate;
  final DriverOption driverOption;
  final InsuranceOption insuranceOption;
  final bool childSeat;
  final bool acceptRentalTerms;

  VehicleBookingData({
    required super.checkIn,
    required super.checkOut,
    required super.guests,
    required super.fullName,
    required super.email,
    required super.phone,
    required this.pickupDateTime,
    required this.returnDateTime,
    required this.pickupLocation,
    required this.dropoffLocation,
    required this.driverLicenseNumber,
    required this.licenseExpiryDate,
    required this.driverOption,
    required this.insuranceOption,
    this.childSeat = false,
    this.acceptRentalTerms = false,
    super.specialRequests,
  });
}

// Payment Data
class PaymentData {
  final PaymentMethod method;
  final String? cardholderName;
  final String? cardNumber;
  final String? expiryDate;
  final String? cvv;
  final String? billingCountry;
  final String? mobileProvider;
  final String? mobileNumber;
  final String? transactionReference;

  PaymentData({
    required this.method,
    this.cardholderName,
    this.cardNumber,
    this.expiryDate,
    this.cvv,
    this.billingCountry,
    this.mobileProvider,
    this.mobileNumber,
    this.transactionReference,
  });
}

// Booking Summary
class BookingSummary {
  final ServiceType serviceType;
  final String serviceTitle;
  final double basePrice;
  final double subtotal;
  final double taxes;
  final double discount;
  final double totalPrice;
  final Map<String, dynamic> extras;

  BookingSummary({
    required this.serviceType,
    required this.serviceTitle,
    required this.basePrice,
    required this.subtotal,
    this.taxes = 0.0,
    this.discount = 0.0,
    required this.totalPrice,
    this.extras = const {},
  });
}

// Form Validation State
class FormValidationState {
  final bool isValid;
  final Map<String, String> errors;

  FormValidationState({required this.isValid, this.errors = const {}});
}

// Booking Form State
class BookingFormState {
  final bool isLoading;
  final FormValidationState validation;
  final String? errorMessage;

  BookingFormState({
    this.isLoading = false,
    required this.validation,
    this.errorMessage,
  });

  BookingFormState copyWith({
    bool? isLoading,
    FormValidationState? validation,
    String? errorMessage,
  }) {
    return BookingFormState(
      isLoading: isLoading ?? this.isLoading,
      validation: validation ?? this.validation,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
