import 'package:supabase/supabase.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:io';

void main() async {
  await dotenv.load(fileName: 'assets/env');
  final supabase = SupabaseClient(
    dotenv.env['SUPABASE_URL'] ?? '',
    dotenv.env['SUPABASE_ANON_KEY'] ?? '',
  );

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
