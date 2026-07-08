import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/theme/app_theme.dart';
import 'core/routing/router.dart';
import 'core/services/supabase_service.dart';
import 'shared/services/lookup_service.dart';
import 'shared/services/settings_repository.dart';
void main() async {
  runZonedGuarded(
    () async {
      // MUST be called first, before any async work inside the zone
      WidgetsFlutterBinding.ensureInitialized();

      // Configure Google Fonts to always allow runtime fetching
      GoogleFonts.config.allowRuntimeFetching = true;

      debugPrint('main(): Starting Supabase initialization...');
      bool initSuccess = false;
      try {
        await SupabaseConfig.initialize(
          url: 'https://japigvtsdlhhbhsjntut.supabase.co',
          anonKey:
              'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImphcGlndnRzZGxoaGJoc2pudHV0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzMwODMzNzIsImV4cCI6MjA4ODY1OTM3Mn0.wMycYukBZmitfoXo9JcqwNiQkmL4vT-nzmsMygT1_Fs',
        );
        initSuccess = true;
        debugPrint('main(): Supabase initialized successfully.');
      } catch (e) {
        debugPrint('main(): CRITICAL - Supabase initialization failed: $e');
      }

      if (!initSuccess) {
        runApp(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              backgroundColor: const Color(0xFF003366), // Somsafar primary
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.wifi_off, color: Colors.white, size: 80),
                      const SizedBox(height: 24),
                      const Text(
                        'Connection is Unavailable',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Please check your internet connection to use SomSafar.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton(
                        onPressed: () {
                          // Restarting app by re-calling main
                          main();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF003366),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 12,
                          ),
                        ),
                        child: const Text('Try Again'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        return;
      }

      try {
        // Seed missing lookup data (essential categories, regions, etc.)
        await LookupService.seedMissingLookups().catchError((e) {
          debugPrint('Failed to seed missing lookups: $e');
        });
      } catch (e) {
        debugPrint('Error during background seeding: $e');
      }

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
    final router = ref.watch(routerProvider);
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
