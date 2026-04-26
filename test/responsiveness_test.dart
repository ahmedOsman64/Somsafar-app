import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:somsafar_app/provider/widgets/provider_shell.dart';

void main() {
  testWidgets('ProviderShell shows NavigationRail on Desktop', (
    WidgetTester tester,
  ) async {
    // Set screen size to Desktop width
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(
      const MaterialApp(home: ProviderShell(child: SizedBox())),
    );

    // Should receive NavigationRail
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(Drawer), findsNothing);

    // Reset view
    addTearDown(tester.view.resetPhysicalSize);
  });

  testWidgets('ProviderShell shows Drawer/AppBar on Mobile', (
    WidgetTester tester,
  ) async {
    // Set screen size to Mobile width
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(
      const MaterialApp(home: ProviderShell(child: SizedBox())),
    );

    // Should receive AppBar (which implies Drawer capability) and NO NavigationRail
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.byType(AppBar), findsOneWidget);

    // Open drawer to verify it exists
    await tester.tap(find.byType(IconButton)); // Menu button
    await tester.pumpAndSettle();

    expect(find.byType(Drawer), findsOneWidget);

    addTearDown(tester.view.resetPhysicalSize);
  });
}
