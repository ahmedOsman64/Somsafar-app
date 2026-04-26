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
    try {
      await dotenv.load(fileName: 'assets/.env');
    } catch (e) {
      debugPrint(
        'Warning: Failed to load .env file. Using fallback or custom configuration.',
      );
    }

    // Load custom configuration from SharedPreferences if it exists
    final prefs = await SharedPreferences.getInstance();
    _customUrl = prefs.getString('sys_supabase_url');
    _customAnonKey = prefs.getString('sys_supabase_anon_key');

    await Supabase.initialize(url: url, anonKey: anonKey);
  }

  static SupabaseClient get client => Supabase.instance.client;
}
