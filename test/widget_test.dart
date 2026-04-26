import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:somsafar_app/main.dart';
import 'package:somsafar_app/core/services/supabase_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await SupabaseConfig.initialize();
  });

  testWidgets('App basic load test', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: SomSafarApp()));
    await tester.pump(const Duration(seconds: 3));
    expect(find.byType(SomSafarApp), findsOneWidget);
  });
}
