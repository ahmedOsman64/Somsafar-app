import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';

// Provider for Supabase client
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return SupabaseConfig.client;
});

// Provider for database service using Supabase
final databaseServiceProvider = Provider<SupabaseService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return SupabaseService(client);
});

class SupabaseService {
  final SupabaseClient _client;
  
  SupabaseService(this._client);
  
  // Get the Supabase client
  SupabaseClient get client => _client;
  
  // Authentication methods
  Future<AuthResponse> signInWithEmail(String email, String password) async {
    return await _client.auth.signInWithPassword(email: email, password: password);
  }
  
  Future<AuthResponse> signUpWithEmail(String email, String password) async {
    return await _client.auth.signUp(email: email, password: password);
  }
  
  Future<void> signOut() async {
    await _client.auth.signOut();
  }
  
  User? get currentUser => _client.auth.currentUser;
  
  Stream<User?> get authStateChanges => _client.auth.onAuthStateChange.map((event) => event.session?.user);
  
  // Generic database operations
  Future<List<Map<String, dynamic>>> getData(String tableName, {Map<String, dynamic>? filters}) async {
    var query = _client.from(tableName).select();
    
    if (filters != null) {
      for (var entry in filters.entries) {
        query = query.eq(entry.key, entry.value);
      }
    }
    
    final response = await query;
    return List<Map<String, dynamic>>.from(response);
  }
  
  Future<Map<String, dynamic>> insertData(String tableName, Map<String, dynamic> data) async {
    final response = await _client.from(tableName).insert(data).select();
    return response.first;
  }
  
  Future<Map<String, dynamic>> updateData(String tableName, String id, Map<String, dynamic> data) async {
    final response = await _client.from(tableName).update(data).eq('id', id).select();
    return response.first;
  }
  
  Future<void> deleteData(String tableName, String id) async {
    await _client.from(tableName).delete().eq('id', id);
  }
}
