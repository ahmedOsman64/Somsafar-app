import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:somsafar_app/shared/models/user_model.dart';
import 'package:somsafar_app/shared/services/auth_service.dart';

void main() {
  group('AuthService Tests', () {
    test('Initial state is null', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(authProvider), null);
    });

    test('Login as Traveler updates state', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container
          .read(authServiceProvider)
          .login('john@example.com', 'password123');

      final user = container.read(authProvider);
      expect(user, isNotNull);
      expect(user!.role, UserRole.traveler);
    });

    test('Login as Provider updates state', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container
          .read(authServiceProvider)
          .login('sarah@example.com', 'password123');

      final user = container.read(authProvider);
      expect(user, isNotNull);
      expect(user!.role, UserRole.provider);
    });

    test('Logout clears state', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container
          .read(authServiceProvider)
          .login('admin@somsafar.com', 'adminpassword');
      expect(container.read(authProvider), isNotNull);

      container.read(authServiceProvider).logout();
      expect(container.read(authProvider), null);
    });
  });
}
