import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  print('Initializing Supabase...');
  await Supabase.initialize(
    url: 'https://japigvtsdlhhbhsjntut.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImphcGlndnRzZGxoaGJoc2pudHV0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzMwODMzNzIsImV4cCI6MjA4ODY1OTM3Mn0.wMycYukBZmitfoXo9JcqwNiQkmL4vT-nzmsMygT1_Fs',
  );
  
  final client = Supabase.instance.client;
  final providerId = 'b3d546fb-093c-4e1d-b254-db154c79f803';
  
  print('Listening to stream WITH provider_id filter...');
  final subscriptionWithFilter = client
      .from('reviews')
      .stream(primaryKey: ['id'])
      .eq('provider_id', providerId)
      .listen(
        (data) => print('WITH FILTER received: $data'),
        onError: (e) => print('WITH FILTER error: $e'),
      );
      
  print('Listening to stream WITHOUT filter...');
  final subscriptionWithoutFilter = client
      .from('reviews')
      .stream(primaryKey: ['id'])
      .listen(
        (data) => print('WITHOUT FILTER received: $data'),
        onError: (e) => print('WITHOUT FILTER error: $e'),
      );

  await Future.delayed(Duration(seconds: 8));
  print('Closing subscriptions...');
  await subscriptionWithFilter.cancel();
  await subscriptionWithoutFilter.cancel();
  print('Done.');
}
