import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/service_model.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class FavoritesNotifier extends StateNotifier<List<Service>> {
  FavoritesNotifier() : super([]) {
    _loadFromPrefs();
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
  }

  bool isFavorite(String serviceId) {
    return state.any((s) => s.id == serviceId);
  }
}

final favoritesProvider =
    StateNotifierProvider<FavoritesNotifier, List<Service>>((ref) {
      return FavoritesNotifier();
    });
