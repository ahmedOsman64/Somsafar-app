import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SupabaseConfig {
  static const String _fallbackUrl = 'https://japigvtsdlhhbhsjntut.supabase.co';
  static const String _fallbackAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImphcGlndnRzZGxoaGJoc2pudHV0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzMwODMzNzIsImV4cCI6MjA4ODY1OTM3Mn0.wMycYukBZmitfoXo9JcqwNiQkmL4vT-nzmsMygT1_Fs';

  static String? _customUrl;
  static String? _customAnonKey;

  static String get url =>
      _customUrl ??
      (dotenv.isInitialized ? (dotenv.env['SUPABASE_URL'] ?? _fallbackUrl) : _fallbackUrl);
  static String get anonKey =>
      _customAnonKey ??
      (dotenv.isInitialized
          ? (dotenv.env['SUPABASE_ANON_KEY'] ?? _fallbackAnonKey)
          : _fallbackAnonKey);

  static Future<void> initialize() async {
    final results = await Future.wait([
      dotenv.load(fileName: 'assets/.env').catchError((e) {
        debugPrint('Warning: Failed to load .env file. Using fallback or custom configuration.');
      }),
      SharedPreferences.getInstance(),
    ]);

    final prefs = results[1] as SharedPreferences;
    _customUrl = prefs.getString('sys_supabase_url');
    _customAnonKey = prefs.getString('sys_supabase_anon_key');

    final supabaseUrl = url;
    final supabaseAnonKey = anonKey;

    if (supabaseUrl.isEmpty || !supabaseUrl.startsWith('http')) {
      debugPrint('Error: Invalid Supabase URL: "$supabaseUrl". Initialization aborted.');
      return;
    }

    // Check if already initialized
    try {
      Supabase.instance;
      debugPrint('Supabase already initialized. Skipping.');
      return;
    } catch (_) {
      // Not initialized, continue
    }

    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
}
