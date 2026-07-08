import 'package:supabase/supabase.dart';
import 'dart:io';

void main() async {
  final url = 'https://skzsfxqnyxbxepjbvvvz.supabase.co';
  final anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNrenNmeHFueXhieGVwamJ2dnZ6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODI1NDU4MTQsImV4cCI6MjA5ODEyMTgxNH0.4wlPuS26OjSTRK3VVIhmFcHJTRklAwTdeUtF5M8CFbQ';

  print('Supabase URL: $url');
  final supabase = SupabaseClient(url, anonKey);

  // We want to see what tables are there or if we can query some known tables
  final tables = ['suppliers', 'purchase_orders', 'supplier_payments', 'loans', 'sales'];

  for (var table in tables) {
    print('--- Checking Table: $table ---');
    try {
      final response = await supabase.from(table).select().limit(5);
      if (response.isNotEmpty) {
        print('  Status: Found records');
        print('  Columns: ${response.first.keys.toList()}');
        print('  First record: ${response.first}');
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
