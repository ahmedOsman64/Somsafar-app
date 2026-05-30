import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/supabase_service.dart';

class LookupItem {
  final String key;
  final String label;
  final String? icon;
  final double? multiplier;

  LookupItem({
    required this.key,
    required this.label,
    this.icon,
    this.multiplier,
  });

  factory LookupItem.fromJson(Map<String, dynamic> json) {
    return LookupItem(
      key: json['key'] ?? json['slug'] ?? '',
      label: json['label'] ?? json['name'] ?? '',
      icon: json['icon'],
      multiplier: json['multiplier'] != null
          ? (json['multiplier'] as num).toDouble()
          : null,
    );
  }
}

class LookupService {
  static Future<List<LookupItem>> getByType(
    String category, {
    String tableName = 'lookups',
  }) async {
    try {
      final query = SupabaseConfig.client.from(tableName).select();

      final response = (tableName == 'lookups')
          ? await query
                .eq('category', category)
                .eq('is_active', true)
                .order('label')
          : await query.eq('is_active', true).order('name');

      return response.map((e) => LookupItem.fromJson(e)).toList();
    } catch (e) {
      print('Error fetching lookups for $category from $tableName: $e');
      return [];
    }
  }

  static Future<void> seedMissingLookups() async {
    final List<Map<String, dynamic>> essentialLookups = [
      // Categories
      {
        'category': 'category',
        'key': 'hotel',
        'label': 'Hotel',
        'icon': 'hotel',
      },
      {
        'category': 'category',
        'key': 'apartment',
        'label': 'Apartment',
        'icon': 'apartment',
      },
      {'category': 'category', 'key': 'tour', 'label': 'Tour', 'icon': 'tour'},

      // Regions
      {
        'category': 'region',
        'key': 'banaadir',
        'label': 'Banaadir',
        'icon': 'map',
      },
      {'category': 'region', 'key': 'bari', 'label': 'Bari', 'icon': 'map'},
      {'category': 'region', 'key': 'gedo', 'label': 'Gedo', 'icon': 'map'},
      {'category': 'region', 'key': 'mudug', 'label': 'Mudug', 'icon': 'map'},
      {'category': 'region', 'key': 'nugaal', 'label': 'Nugaal', 'icon': 'map'},
      {
        'category': 'region',
        'key': 'hiiraan',
        'label': 'Hiiraan',
        'icon': 'map',
      },
      {'category': 'region', 'key': 'bay', 'label': 'Bay', 'icon': 'map'},
      {'category': 'region', 'key': 'bakool', 'label': 'Bakool', 'icon': 'map'},
      {
        'category': 'region',
        'key': 'lower_juba',
        'label': 'Jubbada Hoose',
        'icon': 'map',
      },
      {
        'category': 'region',
        'key': 'middle_juba',
        'label': 'Jubbada Dhexe',
        'icon': 'map',
      },
      {
        'category': 'region',
        'key': 'lower_shabelle',
        'label': 'Shabeellaha Hoose',
        'icon': 'map',
      },
      {
        'category': 'region',
        'key': 'middle_shabelle',
        'label': 'Shabeellaha Dhexe',
        'icon': 'map',
      },
      {
        'category': 'region',
        'key': 'galguduud',
        'label': 'Galguduud',
        'icon': 'map',
      },
      {'category': 'region', 'key': 'awdal', 'label': 'Awdal', 'icon': 'map'},
      {
        'category': 'region',
        'key': 'togdheer',
        'label': 'Togdheer',
        'icon': 'map',
      },
      {'category': 'region', 'key': 'sool', 'label': 'Sool', 'icon': 'map'},
      {'category': 'region', 'key': 'sanaag', 'label': 'Sanaag', 'icon': 'map'},
      {
        'category': 'region',
        'key': 'woqooyi_galbeed',
        'label': 'Woqooyi Galbeed',
        'icon': 'map',
      },

      // Amenities (Hotel)
      {
        'category': 'amenity_hotel',
        'key': 'wifi',
        'label': 'WiFi',
        'icon': 'wifi',
      },
      {
        'category': 'amenity_hotel',
        'key': 'breakfast',
        'label': 'Breakfast',
        'icon': 'restaurant',
      },
      {
        'category': 'amenity_hotel',
        'key': 'pool',
        'label': 'Pool',
        'icon': 'pool',
      },
      {
        'category': 'amenity_hotel',
        'key': 'parking',
        'label': 'Parking',
        'icon': 'local_parking',
      },
      {
        'category': 'amenity_hotel',
        'key': 'gym',
        'label': 'Gym',
        'icon': 'fitness_center',
      },
      {
        'category': 'amenity_hotel',
        'key': 'spa',
        'label': 'Spa',
        'icon': 'spa',
      },
      {
        'category': 'amenity_hotel',
        'key': 'ac',
        'label': 'AC',
        'icon': 'ac_unit',
      },

      // Amenities (Apartment)
      {
        'category': 'amenity_apt',
        'key': 'kitchen',
        'label': 'Kitchen',
        'icon': 'kitchen',
      },
      {
        'category': 'amenity_apt',
        'key': 'washing_machine',
        'label': 'Washing Machine',
        'icon': 'local_laundry_service',
      },
      {
        'category': 'amenity_apt',
        'key': 'balcony',
        'label': 'Balcony',
        'icon': 'balcony',
      },
      {'category': 'amenity_apt', 'key': 'tv', 'label': 'TV', 'icon': 'tv'},

      // Languages
      {
        'category': 'language',
        'key': 'en',
        'label': 'English',
        'icon': 'language',
      },
      {
        'category': 'language',
        'key': 'so',
        'label': 'Somali',
        'icon': 'language',
      },
      {
        'category': 'language',
        'key': 'ar',
        'label': 'Arabic',
        'icon': 'language',
      },
      {
        'category': 'language',
        'key': 'it',
        'label': 'Italian',
        'icon': 'language',
      },

      // Preferred Services (Custom Tour)
      {
        'category': 'service',
        'key': 'guide',
        'label': 'Guide',
        'icon': 'person',
      },
      {
        'category': 'service',
        'key': 'transport',
        'label': 'Private Transport',
        'icon': 'directions_car',
      },
      {
        'category': 'service',
        'key': 'photographer',
        'label': 'Photographer',
        'icon': 'camera_alt',
      },
      {
        'category': 'service',
        'key': 'vip',
        'label': 'VIP Access',
        'icon': 'star',
      },
      {
        'category': 'service',
        'key': 'translator',
        'label': 'Translator',
        'icon': 'translate',
      },
    ];

    try {
      // Fetch existing keys first to avoid overwriting user edits (like icons)
      final List<dynamic> existing = await SupabaseConfig.client
          .from('lookups')
          .select('category, key');

      final existingKeys = existing
          .map((e) => '${e['category']}:${e['key']}')
          .toSet();

      final List<Map<String, dynamic>> missingData = [];
      for (final item in essentialLookups) {
        final keyString = '${item['category']}:${item['key']}';
        if (!existingKeys.contains(keyString)) {
          missingData.add({...item, 'is_active': true});
        }
      }

      if (missingData.isNotEmpty) {
        await SupabaseConfig.client
            .from('lookups')
            .upsert(missingData, onConflict: 'category,key');
        debugPrint('Seeded ${missingData.length} new lookup items.');
      } else {
        debugPrint('All essential lookups already exist. Skipping seeding.');
      }
    } on PostgrestException catch (e) {
      if (e.code == '42501') {
        debugPrint(
          'Seeding skipped: Permission denied (Row-Level Security). Please run seeding via SQL if needed.',
        );
      } else {
        debugPrint('Postgrest error seeding lookups: ${e.message}');
      }
    } catch (e) {
      debugPrint('Unexpected error seeding lookups: $e');
    }
  }

  static Future<void> ensureRegionExists(String regionLabel) async {
    if (regionLabel.isEmpty) return;

    // Normalize key: lowercase, no spaces, for slug
    final String key = regionLabel.toLowerCase().replaceAll(' ', '_').trim();

    try {
      // Check if it already exists
      final existing = await SupabaseConfig.client
          .from('lookups')
          .select('key')
          .eq('category', 'region')
          .eq('key', key)
          .maybeSingle();

      if (existing == null) {
        // Insert new region
        await SupabaseConfig.client.from('lookups').insert({
          'category': 'region',
          'key': key,
          'label': regionLabel.trim(),
          'icon': 'map', // Default icon
          'is_active': true,
        });
        debugPrint('Auto-added new region to lookups: $regionLabel');
      }
    } catch (e) {
      debugPrint('Error ensuring region exists: $e');
    }
  }

  static Future<void> updateLookup(
    String category,
    String key,
    Map<String, dynamic> updates,
  ) async {
    try {
      // Security: Only Admins can modify lookups
      final user = SupabaseConfig.client.auth.currentUser;
      if (user == null) throw Exception('Authentication required');

      // In a real app, we would verify the role from the JWT or a separate check.
      // For now, we rely on RLS, but we can add a basic check if we have the profile.

      final response = await SupabaseConfig.client
          .from('lookups')
          .update(updates)
          .eq('category', category)
          .eq('key', key)
          .select();

      if (response.isEmpty) {
        debugPrint(
          'No row found to update for $category:$key. Row may be inactive or missing.',
        );
      } else {
        debugPrint('Successfully updated lookup $category:$key to $updates');
      }
    } catch (e) {
      debugPrint('Error updating lookup $category:$key with $updates: $e');
      rethrow;
    }
  }
}

// Riverpod Providers for common lookups using Realtime Streams
final categoriesProvider = StreamProvider<List<LookupItem>>((ref) {
  return SupabaseConfig.client
      .from('lookups')
      .stream(primaryKey: ['id'])
      .eq('category', 'category')
      .order('label')
      .map(
        (data) => data
            .where((json) => json['is_active'] == true)
            .map((json) => LookupItem.fromJson(json))
            .toList(),
      );
});

final regionsProvider = StreamProvider<List<LookupItem>>((ref) {
  return SupabaseConfig.client
      .from('lookups')
      .stream(primaryKey: ['id'])
      .eq('category', 'region')
      .map((data) {
        final List<LookupItem> items = data
            .where((json) => json['is_active'] == true)
            .map((json) => LookupItem.fromJson(json))
            .toList();

        // We want to ensure unique labels and keys, prioritizing the ones with icons
        final Map<String, LookupItem> uniqueRegions = {};

        for (final item in items) {
          String normalizedKey = item.key.toLowerCase().trim();
          // Normalize synonyms to canonical keys
          if (normalizedKey == 'banadir') normalizedKey = 'banaadir';
          if (normalizedKey == 'hiran') normalizedKey = 'hiiraan';
          if (normalizedKey == 'bakol') normalizedKey = 'bakool';
          if (normalizedKey == 'shabeellaha_hoose') normalizedKey = 'lower_shabelle';
          if (normalizedKey == 'shabeellaha_dhexe') normalizedKey = 'middle_shabelle';
          if (normalizedKey == 'jubbada_hoose') normalizedKey = 'lower_juba';
          if (normalizedKey == 'jubbada_dhexe') normalizedKey = 'middle_juba';

          final existing = uniqueRegions[normalizedKey];
          bool shouldReplace = existing == null;
          if (existing != null) {
            bool currentHasIcon =
                item.icon != null &&
                item.icon != 'map' &&
                item.icon!.isNotEmpty;
            bool existingHasIcon =
                existing.icon != null &&
                existing.icon != 'map' &&
                existing.icon!.isNotEmpty;
            if (currentHasIcon && !existingHasIcon) {
              shouldReplace = true;
            }
          }

          if (shouldReplace) {
            uniqueRegions[normalizedKey] = item;
          }
        }

        return uniqueRegions.values.toList()
          ..sort((a, b) => a.label.compareTo(b.label));
      });
});

final amenitiesHotelProvider = StreamProvider<List<LookupItem>>((ref) {
  return SupabaseConfig.client
      .from('lookups')
      .stream(primaryKey: ['id'])
      .eq('category', 'amenity_hotel')
      .order('label')
      .map(
        (data) => data
            .where((json) => json['is_active'] == true)
            .map((json) => LookupItem.fromJson(json))
            .toList(),
      );
});

final amenitiesApartmentProvider = StreamProvider<List<LookupItem>>((ref) {
  return SupabaseConfig.client
      .from('lookups')
      .stream(primaryKey: ['id'])
      .eq('category', 'amenity_apt')
      .order('label')
      .map(
        (data) => data
            .where((json) => json['is_active'] == true)
            .map((json) => LookupItem.fromJson(json))
            .toList(),
      );
});

final languagesProvider = StreamProvider<List<LookupItem>>((ref) {
  return SupabaseConfig.client
      .from('lookups')
      .stream(primaryKey: ['id'])
      .eq('category', 'language')
      .order('label')
      .map(
        (data) => data
            .where((json) => json['is_active'] == true)
            .map((json) => LookupItem.fromJson(json))
            .toList(),
      );
});

final lookupServicesProvider = StreamProvider<List<LookupItem>>((ref) {
  return SupabaseConfig.client
      .from('lookups')
      .stream(primaryKey: ['id'])
      .eq('category', 'service')
      .order('label')
      .map(
        (data) => data
            .where((json) => json['is_active'] == true)
            .map((json) => LookupItem.fromJson(json))
            .toList(),
      );
});

final travelPackagesProvider = StreamProvider<List<LookupItem>>((ref) {
  return SupabaseConfig.client
      .from('travel_packages')
      .stream(primaryKey: ['id'])
      .order('name')
      .map(
        (data) => data
            .where((json) => json['is_active'] == true)
            .map((json) => LookupItem.fromJson(json))
            .toList(),
      );
});
