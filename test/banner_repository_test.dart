import 'package:flutter_test/flutter_test.dart';
import 'package:somsafar_app/shared/services/banner_repository.dart';

void main() {
  group('BannerRepository Tests', () {
    late BannerRepository repository;

    setUp(() {
      repository = BannerRepository();
    });

    test('Initial state should have default banners', () {
      expect(repository.state.length, 2);
    });

    test('addBanner should respect 10-image limit', () {
      // Add until 10
      for (int i = 0; i < 8; i++) {
        repository.addBanner('https://test.com/$i.jpg', 'Caption $i');
      }
      expect(repository.state.length, 10);

      // Try adding 11th
      final error = repository.addBanner('https://test.com/11.jpg', 'Too many');
      expect(error, 'Maximum 10 images allowed.');
      expect(repository.state.length, 10);
    });

    test('removeBanner should reorder remaining banners', () {
      final initialCount = repository.state.length;
      final idToRemove = repository.state[0].id;

      repository.removeBanner(idToRemove);

      expect(repository.state.length, initialCount - 1);
      expect(repository.state[0].order, 0);
    });

    test('updateOrder should correctly update display sequence', () {
      final banners = repository.state;
      final reversed = banners.reversed.toList();

      repository.updateOrder(reversed);

      expect(repository.state[0].id, reversed[0].id);
      expect(repository.state[0].order, 0);
      expect(repository.state[1].order, 1);
    });

    test('toggleStatus should flip isActive flag', () {
      final id = repository.state[0].id;
      final initialState = repository.state[0].isActive;

      repository.toggleStatus(id);
      expect(repository.state[0].isActive, !initialState);

      repository.toggleStatus(id);
      expect(repository.state[0].isActive, initialState);
    });
  });
}
