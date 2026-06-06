import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/service_model.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import 'auth_service.dart';
import 'service_repository.dart';
import 'dart:async';

class FavoritesNotifier extends StateNotifier<List<Service>> {
  final Ref? _ref;
  
  FavoritesNotifier([this._ref]) : super([]) {
    _loadFromPrefs();
    _listenToAuth();
  }

  void _listenToAuth() {
    _ref?.listen<User?>(authProvider, (previous, next) {
      if (next != null) {
        if (previous?.id != next.id) {
          _syncWithServer(next);
        }
      } else {
        // Logged out: Clear memory but keep local storage for guest use if needed
        state = [];
      }
    }, fireImmediately: true);
  }

  Future<void> _syncWithServer(User user) async {
    final List<dynamic>? serverFavIds = user.metadata['favorites'];
    if (serverFavIds == null) return;

    final List<String> favoriteIds = List<String>.from(serverFavIds);
    
    // We need the full Service objects. We can try to find them in the serviceProvider
    final allServices = _ref?.read(serviceProvider) ?? [];
    final List<Service> syncedServices = [];
    
    for (final id in favoriteIds) {
      final service = allServices.firstWhere((s) => s.id == id, orElse: () => Service(id: '', providerId: '', title: '', category: '', price: 0, location: '', description: '', status: ServiceStatus.active, images: []));
      if (service.id.isNotEmpty) {
        syncedServices.add(service);
      }
    }

    // Merge with local (prioritize server or combine)
    final Map<String, Service> merged = {};
    for (final s in state) {
      merged[s.id] = s;
    }
    for (final s in syncedServices) {
      merged[s.id] = s;
    }

    state = merged.values.toList();
    _saveToPrefs(state);
  }

  static const _prefsKey = 'favorite_services_v1';

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonStr = prefs.getString(_prefsKey);
      if (jsonStr != null) {
        final List<dynamic> decodedList = jsonDecode(jsonStr);
        final List<Service> services = decodedList.map((item) {
          return Service.fromJson(item as Map<String, dynamic>);
        }).where((s) => s.id.isNotEmpty).toList();
        state = services;
      }
    } catch (e) {
      print("Error loading favorites: $e");
    }
  }

  Future<void> _saveToPrefs(List<Service> services) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<Map<String, dynamic>> mapList = services
          .map((s) => s.toJson())
          .toList();
      final String jsonStr = jsonEncode(mapList);
      await prefs.setString(_prefsKey, jsonStr);
    } catch (e) {
      print("Error saving favorites: $e");
    }
  }

  void toggleFavorite(Service service) {
    if (service.id.isEmpty) return;
    bool isFav = state.any((s) => s.id == service.id);
    List<Service> newList;
    if (isFav) {
      newList = state.where((s) => s.id != service.id).toList();
    } else {
      newList = [service, ...state];
    }
    state = newList;
    _saveToPrefs(newList);
    _syncToSupabase(newList);
  }

  Future<void> _syncToSupabase(List<Service> services) async {
    final user = _ref?.read(authProvider);
    if (user == null) return;

    final favoriteIds = services.map((s) => s.id).toList();
    
    try {
      await _ref?.read(authServiceProvider).updateProfile(
        metadata: {
          ...user.metadata,
          'favorites': favoriteIds,
        },
      );
      print("Favorites synced to Supabase.");
    } catch (e) {
      print("Error syncing favorites: $e");
    }
  }

  bool isFavorite(String serviceId) {
    return state.any((s) => s.id == serviceId);
  }

  /// Clears all favorites from memory and persistent storage.
  /// Call this on logout or password reset so a new user starts fresh.
  Future<void> clearFavorites() async {
    state = [];
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKey);
    } catch (e) {
      print("Error clearing favorites: $e");
    }
  }
}

final favoritesProvider =
    StateNotifierProvider<FavoritesNotifier, List<Service>>((ref) {
      return FavoritesNotifier(ref);
    });
