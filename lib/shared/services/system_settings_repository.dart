import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/supabase_service.dart';

class SystemSettings {
  final bool maintenanceMode;
  final bool systemEmailNotifications;
  final double platformFee;
  final String baseCurrency;
  final String? supabaseUrl;
  final String? supabaseAnonKey;

  SystemSettings({
    this.maintenanceMode = false,
    this.systemEmailNotifications = true,
    this.platformFee = 0.0,
    this.baseCurrency = 'USD',
    this.supabaseUrl,
    this.supabaseAnonKey,
  });

  SystemSettings copyWith({
    bool? maintenanceMode,
    bool? systemEmailNotifications,
    double? platformFee,
    String? baseCurrency,
    String? supabaseUrl,
    String? supabaseAnonKey,
  }) {
    return SystemSettings(
      maintenanceMode: maintenanceMode ?? this.maintenanceMode,
      systemEmailNotifications:
          systemEmailNotifications ?? this.systemEmailNotifications,
      platformFee: platformFee ?? this.platformFee,
      baseCurrency: baseCurrency ?? this.baseCurrency,
      supabaseUrl: supabaseUrl ?? this.supabaseUrl,
      supabaseAnonKey: supabaseAnonKey ?? this.supabaseAnonKey,
    );
  }
}

class SystemSettingsRepository extends StateNotifier<SystemSettings> {
  SystemSettingsRepository() : super(SystemSettings()) {
    _loadFromPrefs();
  }

  static const String _maintenanceKey = 'sys_maintenance';
  static const String _emailNotifKey = 'sys_email_notif';
  static const String _platformFeeKey = 'sys_platform_fee';
  static const String _currencyKey = 'sys_currency';
  static const String _supabaseUrlKey = 'sys_supabase_url';
  static const String _supabaseAnonKeyKey = 'sys_supabase_anon_key';

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();

    // Load local defaults first
    state = SystemSettings(
      maintenanceMode: prefs.getBool(_maintenanceKey) ?? false,
      systemEmailNotifications: prefs.getBool(_emailNotifKey) ?? true,
      platformFee: prefs.getDouble(_platformFeeKey) ?? 0.0, // Default to 0%
      baseCurrency: prefs.getString(_currencyKey) ?? 'USD',
      supabaseUrl: prefs.getString(_supabaseUrlKey),
      supabaseAnonKey: prefs.getString(_supabaseAnonKeyKey),
    );

    // Then try to sync from Supabase
    _syncFromDatabase();
  }

  Future<void> _syncFromDatabase() async {
    try {
      final response = await SupabaseConfig.client
          .from('system_configs')
          .select()
          .maybeSingle();

      if (response != null) {
        state = state.copyWith(
          maintenanceMode: response['maintenance_mode'] as bool?,
          platformFee: (response['platform_fee'] as num?)?.toDouble(),
          baseCurrency: response['base_currency'] as String?,
          systemEmailNotifications: response['email_notifications'] as bool?,
        );

        // Save back to prefs for offline availability
        final prefs = await SharedPreferences.getInstance();
        if (response['maintenance_mode'] != null) {
          await prefs.setBool(_maintenanceKey, response['maintenance_mode']);
        }
        if (response['platform_fee'] != null) {
          await prefs.setDouble(
            _platformFeeKey,
            (response['platform_fee'] as num).toDouble(),
          );
        }
        if (response['base_currency'] != null) {
          await prefs.setString(_currencyKey, response['base_currency']);
        }
      }
    } catch (e) {
      debugPrint('Sync system settings error: $e');
    }
  }

  Future<void> updateMaintenanceMode(bool value) async {
    state = state.copyWith(maintenanceMode: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_maintenanceKey, value);

    try {
      await SupabaseConfig.client.from('system_configs').upsert({
        'maintenance_mode': value,
        'id': 1,
      }); // Assume single row with ID 1
    } catch (e) {
      debugPrint('Update maintenance mode in DB error: $e');
    }
  }

  Future<void> updateSystemEmailNotifications(bool value) async {
    state = state.copyWith(systemEmailNotifications: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_emailNotifKey, value);

    try {
      await SupabaseConfig.client.from('system_configs').upsert({
        'email_notifications': value,
        'id': 1,
      });
    } catch (e) {
      debugPrint('Update email notif in DB error: $e');
    }
  }

  Future<void> updatePlatformFee(double value) async {
    state = state.copyWith(platformFee: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_platformFeeKey, value);

    try {
      await SupabaseConfig.client.from('system_configs').upsert({
        'platform_fee': value,
        'id': 1,
      });
    } catch (e) {
      debugPrint('Update platform fee in DB error: $e');
    }
  }

  Future<void> updateBaseCurrency(String value) async {
    state = state.copyWith(baseCurrency: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currencyKey, value);
  }

  Future<void> updateSupabaseConfig(String url, String anonKey) async {
    state = state.copyWith(supabaseUrl: url, supabaseAnonKey: anonKey);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_supabaseUrlKey, url);
    await prefs.setString(_supabaseAnonKeyKey, anonKey);
  }
}

final systemSettingsProvider =
    StateNotifierProvider<SystemSettingsRepository, SystemSettings>((ref) {
      return SystemSettingsRepository();
    });
