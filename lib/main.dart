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
  WidgetsFlutterBinding.ensureInitialized();

  // Configure Google Fonts to always allow runtime fetching
  GoogleFonts.config.allowRuntimeFetching = true;

  // Initialize Supabase
  await SupabaseConfig.initialize();

  // Seed missing lookup data in background (essential categories, regions, etc.)
  unawaited(LookupService.seedMissingLookups().catchError((e) {
    debugPrint('Failed to seed missing lookups: $e');
  }));

  runApp(const ProviderScope(child: SomSafarApp()));
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
      builder: (context, child) => child!,
    );
  }
}
