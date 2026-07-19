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

  static Future<void> initialize({String? url, String? anonKey}) async {
    if (url != null && url.isNotEmpty && !url.contains('URL_KAAGA_HALKAN')) {
      _customUrl = url;
    }
    if (anonKey != null && anonKey.isNotEmpty && !anonKey.contains('ANON_KEY_GAAGA_HALKAN')) {
      _customAnonKey = anonKey;
    }

    final results = await Future.wait([
      dotenv.load(fileName: 'assets/env').catchError((e) {
        debugPrint('Note: assets/.env not found or failed to load. Using fallback/custom config.');
        return; // Non-fatal
      }),
      SharedPreferences.getInstance(),
    ]);

    final prefs = results[1] as SharedPreferences;
    
    // Only load from prefs if not already set by parameters or .env
    if (_customUrl == null || _customUrl!.isEmpty) {
      final savedUrl = prefs.getString('sys_supabase_url');
      if (savedUrl != null && savedUrl.isNotEmpty) _customUrl = savedUrl;
    }
    
    if (_customAnonKey == null || _customAnonKey!.isEmpty) {
      final savedKey = prefs.getString('sys_supabase_anon_key');
      if (savedKey != null && savedKey.isNotEmpty) _customAnonKey = savedKey;
    }

    final supabaseUrl = SupabaseConfig.url;
    final supabaseAnonKey = SupabaseConfig.anonKey;

    if (supabaseUrl.isEmpty || !supabaseUrl.startsWith('http')) {
      throw Exception('Invalid Supabase URL: "$supabaseUrl". Check your .env file or database settings.');
    }

    if (supabaseAnonKey.isEmpty) {
      throw Exception('Supabase Anon Key is missing. Check your .env file.');
    }

    // Check if already initialized
    try {
      if (_client != null) {
        debugPrint('Supabase already initialized. Skipping.');
        return;
      }
      // Accessing client will throw if Supabase is not initialized.
      // In release mode, the assert in Supabase.instance is stripped,
      // so accessing Supabase.instance alone does not throw an error,
      // but accessing its client field will throw.
      Supabase.instance.client;
      _client = Supabase.instance.client;
      debugPrint('Supabase already initialized. Skipping.');
      return;
    } catch (_) {
      // Not initialized, continue
    }

    debugPrint('Initializing Supabase with URL: $supabaseUrl');
    try {
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
        ),
      );
      _client = Supabase.instance.client;
      debugPrint('Supabase.initialize() call completed successfully.');
    } catch (e) {
      debugPrint('Supabase.initialize() THREW an error: $e');
      rethrow;
    }
  }

  static SupabaseClient? _client;

  static SupabaseClient get client {
    if (_client != null) return _client!;
    
    try {
      _client = Supabase.instance.client;
      return _client!;
    } catch (e) {
      debugPrint('SupabaseClient Access Error: $e');
      throw StateError(
        'Supabase has not been initialized correctly. \n'
        'Error: $e\n'
        'Ensure SupabaseConfig.initialize() is called and awaited in main() '
        'and that the URL and Anon Key are valid.'
      );
    }
  }
}
