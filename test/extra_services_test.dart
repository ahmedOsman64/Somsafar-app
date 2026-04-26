import 'package:flutter_test/flutter_test.dart';
import 'package:somsafar_app/shared/models/booking_forms_model.dart';
import 'package:somsafar_app/shared/models/service_model.dart';
import 'package:somsafar_app/shared/services/booking_form_service.dart';

void main() {
  group('Extra Services Pricing Tests', () {
    test('calculateTourPrice should include extra services from metadata', () {
      final service = Service(
        id: '1',
        providerId: 'p1',
        title: 'Custom Tour',
        category: 'Tour',
        price: 100.0,
        location: 'Mogadishu',
        description: 'Test Description',
        status: ServiceStatus.active,
        images: [],
        metadata: {
          'adultPrice': 100.0,
          'childPrice': 50.0,
          'extraServicePrices': {
            'Guide': 50.0,
            'Private Transport': 100.0,
          },
        },
      );

      final data = CustomTourBookingData(
        checkIn: DateTime.now(),
        checkOut: DateTime.now(),
        guests: 2,
        fullName: 'John Doe',
        email: 'john@example.com',
        phone: '123456',
        tourDate: DateTime.now(),
        travelers: 2,
        adultTravelers: 2,
        childTravelers: 0,
        location: 'USA',
        destination: 'Mogadishu',
        preferredServices: ['Guide', 'Private Transport'],
        numberOfDays: 1,
      );

      final summary = BookingFormService.calculateTourPrice(data, service, []);

      // (100 * 2) + 50 (Guide) + 100 (Transport) = 350
      expect(summary.totalPrice, 350.0);
      expect(summary.extras.containsKey('extra_Guide'), true);
      expect(summary.extras.containsKey('extra_Private Transport'), true);
    });

    test('calculateTourPrice should multiply total by numberOfDays', () {
      final service = Service(
        id: '1',
        providerId: 'p1',
        title: 'Custom Tour',
        category: 'Tour',
        price: 100.0,
        location: 'Mogadishu',
        description: 'Test Description',
        status: ServiceStatus.active,
        images: [],
        metadata: {
          'adultPrice': 100.0,
          'extraServicePrices': {
            'Guide': 50.0,
          },
        },
      );

      final data = CustomTourBookingData(
        checkIn: DateTime.now(),
        checkOut: DateTime.now(),
        guests: 1,
        fullName: 'John Doe',
        email: 'john@example.com',
        phone: '123456',
        tourDate: DateTime.now(),
        travelers: 1,
        adultTravelers: 1,
        childTravelers: 0,
        location: 'USA',
        destination: 'Mogadishu',
        preferredServices: ['Guide'],
        numberOfDays: 3,
      );

      final summary = BookingFormService.calculateTourPrice(data, service, []);

      // ((100 * 1) + 50 (Guide)) * 3 days = 150 * 3 = 450
      expect(summary.totalPrice, 450.0);
      expect(summary.extras['duration'], '3 Days (x3)');
      expect(summary.extras['extra_Guide']?.toString().contains('x 3 days'), true);
    });

    test('calculateTourPrice should handle missing extra service prices correctly', () {
      final service = Service(
        id: '1',
        providerId: 'p1',
        title: 'Custom Tour',
        category: 'Tour',
        price: 100.0,
        location: 'Mogadishu',
        description: 'Test Description',
        status: ServiceStatus.active,
        images: [],
        metadata: {
          'adultPrice': 100.0,
          'childPrice': 50.0,
          'extraServicePrices': {
            'Guide': 50.0,
          },
        },
      );

      final data = CustomTourBookingData(
        checkIn: DateTime.now(),
        checkOut: DateTime.now(),
        guests: 1,
        fullName: 'John Doe',
        email: 'john@example.com',
        phone: '123456',
        tourDate: DateTime.now(),
        travelers: 1,
        adultTravelers: 1,
        childTravelers: 0,
        location: 'USA',
        destination: 'Mogadishu',
        preferredServices: ['Guide', 'Translator'], // Translator price is missing
        numberOfDays: 1,
      );

      final summary = BookingFormService.calculateTourPrice(data, service, []);

      // (100 * 1) + 50 (Guide) + 0 (Translator) = 150
      expect(summary.totalPrice, 150.0);
      expect(summary.extras.containsKey('extra_Guide'), true);
      expect(summary.extras.containsKey('extra_Translator'), false);
    });
  });
}
