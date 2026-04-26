import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/service_model.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class RecentlyViewedNotifier extends StateNotifier<List<Service>> {
  RecentlyViewedNotifier() : super([]) {
    _loadFromPrefs();
  }

  static const _prefsKey =
      'recently_viewed_services_v2'; // unique key in case model changed

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonStr = prefs.getString(_prefsKey);
      if (jsonStr != null) {
        final List<dynamic> decodedList = jsonDecode(jsonStr);
        final List<Service> services = decodedList.map((item) {
          // This assumes Service has a fromMap or fromJson factory.
          // Since Service model structure is in shared/models/service_model.dart,
          // let's just make sure it loads.
          // Note: if Service does not have fromMap, this will fail.
          return Service.fromJson(item as Map<String, dynamic>);
        }).where((s) => s.id.isNotEmpty).toList();
        state = services;
      }
    } catch (e) {
      // In case of error (e.g. model mismatch), ignore and start fresh
      print("Error loading recently viewed: $e");
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
      print("Error saving recently viewed: $e");
    }
  }

  void addService(Service service) {
    if (service.id.isEmpty) return;
    // Remove if already exists to move it to the front
    final currentList = state.where((s) => s.id != service.id).toList();
    // Add to the front
    currentList.insert(0, service);
    // Keep only top 10
    if (currentList.length > 10) {
      currentList.removeLast();
    }
    state = currentList;
    _saveToPrefs(currentList);
  }
}

final recentlyViewedProvider =
    StateNotifierProvider<RecentlyViewedNotifier, List<Service>>((ref) {
      return RecentlyViewedNotifier();
    });
