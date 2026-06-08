import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:somsafar_app/provider/screens/provider_service_form_screen.dart';
import 'package:somsafar_app/traveler/screens/booking/tour_booking_form.dart';
import 'package:somsafar_app/shared/models/service_model.dart';
import 'package:somsafar_app/shared/models/booking_forms_model.dart';
import 'package:somsafar_app/shared/models/user_model.dart';
import 'package:somsafar_app/shared/services/auth_service.dart';
import 'package:somsafar_app/shared/services/lookup_service.dart';

void main() {
  testWidgets('ProviderServiceFormScreen builds without null errors', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWithValue(User(id: '1', email: 'test@test.com', name: 'Test', role: UserRole.provider, password: '', providerType: ProviderType.tour)),
          categoriesProvider.overrideWith((ref) => Future.value([LookupItem(key: 'tour', label: 'Tour')])),
          regionsProvider.overrideWith((ref) => Future.value([LookupItem(key: 'banadir', label: 'Banaadir')])),
          amenitiesHotelProvider.overrideWith((ref) => Future.value([LookupItem(key: 'wifi', label: 'WiFi')])),
          amenitiesApartmentProvider.overrideWith((ref) => Future.value([LookupItem(key: 'kitchen', label: 'Kitchen')])),
          languagesProvider.overrideWith((ref) => Future.value([LookupItem(key: 'en', label: 'English')])),
          lookupServicesProvider.overrideWith((ref) => Future.value([LookupItem(key: 'guide', label: 'Guide')])),
        ],
        child: const MaterialApp(
          home: ProviderServiceFormScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ProviderServiceFormScreen), findsOneWidget);
    expect(find.text('Service Title *'), findsOneWidget);
    expect(find.text('Region (Gobal) *'), findsOneWidget);
    expect(find.text('District / Degmo *'), findsOneWidget);
  });

  for (final pkg in ['jumma', 'eid', 'custom']) {
    testWidgets('TourBookingForm builds without null errors for $pkg', (WidgetTester tester) async {
      final mockService = Service(
        id: '1',
        providerId: 'p1',
        title: 'Test Tour',
        description: 'Desc',
        category: 'Tour',
        price: 100,
        location: 'Mogadishu',
        images: [],
        metadata: {'package': pkg},
        status: ServiceStatus.active,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWithValue(User(id: '1', email: 'test@test.com', name: 'Test', role: UserRole.traveler, password: '')),
            regionsProvider.overrideWith((ref) => Future.value([LookupItem(key: 'banadir', label: 'Banaadir')])),
            amenitiesHotelProvider.overrideWith((ref) => Future.value([LookupItem(key: 'wifi', label: 'WiFi')])),
            amenitiesApartmentProvider.overrideWith((ref) => Future.value([LookupItem(key: 'kitchen', label: 'Kitchen')])),
            languagesProvider.overrideWith((ref) => Future.value([LookupItem(key: 'en', label: 'English')])),
            lookupServicesProvider.overrideWith((ref) => Future.value([LookupItem(key: 'guide', label: 'Guide')])),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: TourBookingForm(
                service: mockService,
                initialPackage: TourPackage.values.firstWhere((e) => e.name == pkg),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TourBookingForm), findsOneWidget);
    });
  }
}
