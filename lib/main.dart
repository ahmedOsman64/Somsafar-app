import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/theme/app_theme.dart';
import 'core/routing/router.dart';
import 'core/services/supabase_service.dart';
import 'shared/services/lookup_service.dart';
import 'shared/services/settings_repository.dart';

/// Bypasses strict SSL certificate validation.
/// Fixes "CERTIFICATE_VERIFY_FAILED" / "HandshakeException" on older Android
/// devices caused by expired Let's Encrypt root certificates.
class _MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

void main() async {
  HttpOverrides.global = _MyHttpOverrides();
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // Configure Google Fonts to always allow runtime fetching
      GoogleFonts.config.allowRuntimeFetching = true;

      // Initialize Supabase
      try {
        await SupabaseConfig.initialize();
      } catch (e) {
        debugPrint('Critical: Supabase initialization failed: $e');
      }

      // Seed missing lookup data in background (essential categories, regions, etc.)
      unawaited(
        LookupService.seedMissingLookups().catchError((e) {
          debugPrint('Failed to seed missing lookups: $e');
        }),
      );

      runApp(const ProviderScope(child: SomSafarApp()));
    },
    (error, stack) {
      debugPrint('Uncaught global error: $error\n$stack');
    },
  );
}

class SomSafarApp extends ConsumerWidget {
  const SomSafarApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.read(routerProvider);
    final settings = ref.watch(settingsProvider);

    return MaterialApp.router(
      title: 'SomSafar',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: settings.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      builder: (context, child) {
        if (child == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return child;
      },
    );
  }
}
