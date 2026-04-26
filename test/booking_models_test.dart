import 'package:flutter_test/flutter_test.dart';
import 'package:somsafar_app/shared/models/booking_forms_model.dart';

void main() {
  group('BookingFormsModel Tests', () {
    test('JummaBookingData contains new fields', () {
      final data = JummaBookingData(
        checkIn: DateTime.now(),
        checkOut: DateTime.now(),
        guests: 1,
        fullName: 'Test User',
        email: 'test@example.com',
        phone: '123456789',
        tourDate: DateTime.now(),
        travelers: 1,
        adultTravelers: 1,
        childTravelers: 0,
        infantTravelers: 0,
        location: 'Somali',
        preferredLocation: 'Mogadishu',
        transportOption: 'Car',
        accommodationType: 'Hotel',
        includeLunch: true,
        specialInformation: 'Near the entrance',
      );

      expect(data.specialInformation, 'Near the entrance');
    });

    test('EidBookingData contains new fields', () {
      final data = EidBookingData(
        checkIn: DateTime.now(),
        checkOut: DateTime.now(),
        guests: 2,
        fullName: 'Test User',
        email: 'test@example.com',
        phone: '123456789',
        tourDate: DateTime.now(),
        travelers: 2,
        adultTravelers: 2,
        childTravelers: 0,
        infantTravelers: 0,
        location: 'Somali',
        eidType: 'Eid al-Fitr',
        destination: 'Istanbul',
        numberOfDays: 7,
        transportOption: 'Flight',
        hotelRating: 5,
        foodPackage: 'Full board',
        childSpecificNeeds: 'Baby cot required',
        specialInformation: 'First time visiting',
      );

      expect(data.childSpecificNeeds, 'Baby cot required');
      expect(data.specialInformation, 'First time visiting');
    });

    test('CustomTourBookingData contains new fields', () {
      final data = CustomTourBookingData(
        checkIn: DateTime.now(),
        checkOut: DateTime.now(),
        guests: 2,
        fullName: 'Test User',
        email: 'test@example.com',
        phone: '123456789',
        tourDate: DateTime.now(),
        travelers: 1,
        adultTravelers: 1,
        childTravelers: 0,
        infantTravelers: 0,
        location: 'Somali',
        destination: 'Jazeera Beach',
        preferredServices: ['Guide', 'Lunch'],
        numberOfDays: 3,
        notes: 'Photography focus',
      );

      expect(data.notes, 'Photography focus');
    });
  });
}
