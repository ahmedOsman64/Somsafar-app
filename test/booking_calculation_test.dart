import 'package:flutter_test/flutter_test.dart';
import 'package:somsafar_app/shared/models/booking_forms_model.dart';
import 'package:somsafar_app/shared/services/booking_form_service.dart';
import 'package:somsafar_app/shared/models/service_model.dart';
import 'package:somsafar_app/shared/models/tax_model.dart';
import 'package:somsafar_app/shared/models/user_model.dart';

void main() {
  group('Booking Calculation Tests', () {
    test('calculateApartmentPrice pro-rates monthly rate by 30 days', () {
      final checkIn = DateTime(2026, 3, 22);
      final checkOut30 = DateTime(2026, 4, 21); // 30 nights
      final checkOut15 = DateTime(2026, 4, 6);  // 15 nights
      final checkOut60 = DateTime(2026, 5, 21); // 60 nights

      final data30 = ApartmentBookingData(
        checkIn: checkIn,
        checkOut: checkOut30,
        guests: 2,
        fullName: 'Test',
        email: 't@t.com',
        phone: '12345678',
        stayPurpose: StayPurpose.vacation,
      );

      final data15 = ApartmentBookingData(
        checkIn: checkIn,
        checkOut: checkOut15,
        guests: 2,
        fullName: 'Test',
        email: 't@t.com',
        phone: '12345678',
        stayPurpose: StayPurpose.vacation,
      );

      final data60 = ApartmentBookingData(
        checkIn: checkIn,
        checkOut: checkOut60,
        guests: 2,
        fullName: 'Test',
        email: 't@t.com',
        phone: '12345678',
        stayPurpose: StayPurpose.vacation,
      );

      final service = Service(
        id: 'apt-1',
        providerId: 'provider-1',
        title: 'Test Apartment',
        category: 'Apartment',
        price: 600.0,
        location: 'Mogadishu',
        description: 'Test',
        status: ServiceStatus.active,
        images: [],
      );
      
      final summary30 = BookingFormService.calculateApartmentPrice(data30, service, []);
      final summary15 = BookingFormService.calculateApartmentPrice(data15, service, []);
      final summary60 = BookingFormService.calculateApartmentPrice(data60, service, []);

      expect(summary30.totalPrice, 600.0);
      expect(summary15.totalPrice, 300.0);
      expect(summary60.totalPrice, 1200.0);
    });

    test('calculateApartmentPrice includes taxes for ProviderType.home', () {
       final checkIn = DateTime(2026, 3, 22);
       final checkOut = DateTime(2026, 4, 21); // 30 nights
 
       final data = ApartmentBookingData(
         checkIn: checkIn,
         checkOut: checkOut,
         guests: 2,
         fullName: 'Test',
         email: 't@t.com',
         phone: '12345678',
         stayPurpose: StayPurpose.vacation,
       );
 
       const monthlyPrice = 1000.0;
       
       // Mock taxes
       final activeTaxes = [
         TaxModel(
           id: 'tax-1',
           name: 'Home Tax',
           providerType: ProviderType.home,
           taxType: TaxType.percentage,
           rate: 10.0,
           isActive: true,
           createdAt: DateTime.now(),
         ),
       ];
 
       final service = Service(
         id: 'apt-tax',
         providerId: 'provider-1',
         title: 'Test Apartment',
         category: 'Apartment',
         price: monthlyPrice,
         location: 'Mogadishu',
         description: 'Test',
         status: ServiceStatus.active,
         images: [],
       );
  
       final summary = BookingFormService.calculateApartmentPrice(data, service, activeTaxes);
 
       // Base price for 30 days = 1000.0
       // Tax = 10% of 1000.0 = 100.0
       // Total = 1100.0
       expect(summary.taxes, closeTo(100.0, 0.001));
       expect(summary.totalPrice, closeTo(1100.0, 0.001));
     });

    test('calculateTourPrice for Jumma package has no price increase', () {
      final tourDate = DateTime(2026, 3, 27); // A Friday
      final data = JummaBookingData(
        checkIn: tourDate,
        checkOut: tourDate,
        guests: 3,
        tourDate: tourDate,
        travelers: 3,
        adultTravelers: 2,
        childTravelers: 1,
        location: 'Somali',
        fullName: 'Test Traveler',
        email: 'test@example.com',
        phone: '12345678',
        preferredLocation: 'Mogadishu',
        transportOption: 'Private',
        accommodationType: 'Hotel',
        includeLunch: true,
      );

      final service = Service(
        id: 'tour-1',
        providerId: 'provider-1',
        title: 'Mogadishu City Tour',
        description: 'Enjoy a tour of the city',
        price: 100.0,
        adultPrice: 100.0,
        childPrice: 50.0,
        images: [],
        category: 'Tour',
        rating: 4.5,
        reviews: 10,
        location: 'Mogadishu',
        status: ServiceStatus.active,
        metadata: {},
      );

      // (2 * 100) + (1 * 50) = 250.0
      // Previously it would be 250.0 * 1.1 = 275.0
      final summary = BookingFormService.calculateTourPrice(data, service, []);

      expect(summary.totalPrice, 250.0);
      expect(summary.extras['packageUpgrade'], 'Jumma Package');
    });
  });
}
