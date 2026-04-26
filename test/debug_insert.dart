import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

void main() {
  test('Debug: Check if bookings table has metadata column', () async {
    // Note: We can only run this if Supabase is initialized.
    // Since we are in a test, we have to provide URL/Key.
    final supabase = SupabaseClient(
      'https://japigvtsdlhhbhsjntut.supabase.co',
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImphcGlndnRzZGxoaGJoc2pudHV0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzMwODMzNzIsImV4cCI6MjA4ODY1OTM3Mn0.wMycYukBZmitfoXo9JcqwNiQkmL4vT-nzmsMygT1_Fs',
    );

    try {
      final bookingId = const Uuid().v4();
      
      print('Attempting to insert test booking...');
      
      // We'll try to insert ONLY the columns we KNOW exist from supabase_schema.sql
      // to see if THAT works.
      await supabase.from('bookings').insert({
        'id': bookingId,
        'traveler_id': '00000000-0000-0000-0000-000000000000', 
        'provider_id': '00000000-0000-0000-0000-000000000000',
        'service_id': '00000000-0000-0000-0000-000000000000',
        'total_price': 100.0,
        'taxes': 10.0, // Checking for this one too
      });
      
      print('Insert success!');
    } catch (e) {
      print('Insert failed with error: $e');
      if (e is PostgrestException) {
         print('Postgrest Error: ${e.message}, Code: ${e.code}, Hint: ${e.hint}');
      }
    }
  });
}
