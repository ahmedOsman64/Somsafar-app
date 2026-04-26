import 'package:flutter_test/flutter_test.dart';
import 'package:somsafar_app/shared/models/service_model.dart';

void main() {
  group('Service Model Serialization', () {
    test('toJson should move adult_price, child_price and max_guests to metadata', () {
      final service = Service(
        id: '1',
        providerId: 'p1',
        title: 'Test Tour',
        category: 'Tour',
        price: 100.0,
        location: 'Mogadishu',
        description: 'Description',
        status: ServiceStatus.active,
        images: [],
        metadata: {'existing': 'data'},
        adultPrice: 50.0,
        childPrice: 25.0,
        maxGuests: 10,
      );

      final json = service.toJson();

      // Should NOT be at top level
      expect(json.containsKey('adult_price'), isFalse);
      expect(json.containsKey('child_price'), isFalse);
      expect(json.containsKey('max_guests'), isFalse);

      // Should BE in metadata
      final metadata = json['metadata'] as Map<String, dynamic>;
      expect(metadata['adult_price'], 50.0);
      expect(metadata['child_price'], 25.0);
      expect(metadata['max_guests'], 10);
      expect(metadata['existing'], 'data');
    });

    test('fromJson should handle metadata fallbacks for adult_price, child_price and max_guests', () {
      final json = {
        'id': '1',
        'provider_id': 'p1',
        'title': 'Test Tour',
        'category': 'Tour',
        'price': 100.0,
        'location': 'Mogadishu',
        'description': 'Description',
        'status': 'active',
        'images': [],
        'metadata': {
          'adult_price': 50.0,
          'child_price': 25.0,
          'max_guests': 10,
        },
      };

      final service = Service.fromJson(json);

      expect(service.adultPrice, 50.0);
      expect(service.childPrice, 25.0);
      expect(service.maxGuests, 10);
    });

    test('fromJson should favor top-level columns if they exist (backward compatibility)', () {
      final json = {
        'id': '1',
        'provider_id': 'p1',
        'title': 'Test Tour',
        'category': 'Tour',
        'price': 100.0,
        'location': 'Mogadishu',
        'description': 'Description',
        'status': 'active',
        'images': [],
        'adult_price': 60.0, // Top level exists
        'child_price': 30.0,
        'max_guests': 12,
        'metadata': {
          'adult_price': 50.0, // Metadata also exists
        },
      };

      final service = Service.fromJson(json);

      expect(service.adultPrice, 60.0); // Favors top level
      expect(service.childPrice, 30.0);
      expect(service.maxGuests, 12);
    });
  });
}
