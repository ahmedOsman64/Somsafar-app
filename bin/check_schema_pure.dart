import 'package:supabase/supabase.dart';
import 'dart:io';

void main() async {
  print('Loading assets/env manually...');
  final envFile = File('assets/env');
  if (!envFile.existsSync()) {
    print('Error: assets/env file not found');
    exit(1);
  }

  final lines = envFile.readAsLinesSync();
  String url = '';
  String anonKey = '';

  for (var line in lines) {
    line = line.trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    final parts = line.split('=');
    if (parts.length >= 2) {
      final key = parts[0].trim();
      final val = parts.sublist(1).join('=').trim();
      if (key == 'SUPABASE_URL') url = val;
      if (key == 'SUPABASE_ANON_KEY') anonKey = val;
    }
  }

  print('Supabase URL: $url');
  final supabase = SupabaseClient(url, anonKey);

  final tables = ['users', 'services', 'bookings', 'chats'];

  for (var table in tables) {
    print('--- Checking Table: $table ---');
    try {
      final response = await supabase.from(table).select().limit(1);
      if (response.isNotEmpty) {
        print('  Status: Found records');
        print('  Columns: ${response.first.keys.toList()}');
      } else {
        print('  Status: Empty or restricted');
      }
    } catch (e) {
      print('  Error: $e');
    }
    print('');
  }
  exit(0);
}
