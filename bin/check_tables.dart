import 'package:supabase/supabase.dart';
import 'dart:io';

void main() async {
  final url = 'https://skzsfxqnyxbxepjbvvvz.supabase.co';
  final anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNrenNmeHFueXhieGVwamJ2dnZ6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODI1NDU4MTQsImV4cCI6MjA5ODEyMTgxNH0.4wlPuS26OjSTRK3VVIhmFcHJTRklAwTdeUtF5M8CFbQ';

  final supabase = SupabaseClient(url, anonKey);

  print('--- Querying pg_tables or information_schema ---');
  try {
    // Let's call a simple RPC or query that runs raw SQL or see if there is any other way.
    // Wait, in Supabase we can try to query pg_catalog or information_schema.
    // Let's see if we can do that via RPC or just retrieve a list of common table names.
    final list = [
      'suppliers', 'purchases', 'purchase_orders', 'supplier_bills', 'bills', 'payments', 
      'supplier_payments', 'expenses', 'products', 'inventory', 'businesses', 'loans', 'categories'
    ];
    for (var name in list) {
      try {
        final res = await supabase.from(name).select().limit(1);
        print('Table "$name": EXISTS (found ${res.length} rows)');
        if (res.isNotEmpty) {
          print('  Columns: ${res.first.keys.toList()}');
        }
      } catch (e) {
        if (e.toString().contains('does not exist')) {
          // Table does not exist
        } else {
          print('Table "$name": EXISTS but errored: $e');
        }
      }
    }
  } catch (e) {
    print('Error: $e');
  }
  exit(0);
}
