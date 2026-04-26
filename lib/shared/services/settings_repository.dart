import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserSettings {
  final bool pushNotifications;
  final bool emailNotifications;
  final bool smsNotifications;
  final bool twoFactorAuth;
  final String language;
  final String currency;
  final bool isDarkMode;
  final bool hasSeenOnboarding;
  final bool initialized;

  UserSettings({
    this.pushNotifications = true,
    this.emailNotifications = true,
    this.smsNotifications = false,
    this.twoFactorAuth = true,
    this.language = 'English (United States)',
    this.currency = r'USD ($)',
    this.isDarkMode = false,
    this.hasSeenOnboarding = false,
    this.initialized = false,
  });

  UserSettings copyWith({
    bool? pushNotifications,
    bool? emailNotifications,
    bool? smsNotifications,
    bool? twoFactorAuth,
    String? language,
    String? currency,
    bool? isDarkMode,
    bool? hasSeenOnboarding,
    bool? initialized,
  }) {
    return UserSettings(
      pushNotifications: pushNotifications ?? this.pushNotifications,
      emailNotifications: emailNotifications ?? this.emailNotifications,
      smsNotifications: smsNotifications ?? this.smsNotifications,
      twoFactorAuth: twoFactorAuth ?? this.twoFactorAuth,
      language: language ?? this.language,
      currency: currency ?? this.currency,
      isDarkMode: isDarkMode ?? this.isDarkMode,
      hasSeenOnboarding: hasSeenOnboarding ?? this.hasSeenOnboarding,
      initialized: initialized ?? this.initialized,
    );
  }
}

class SettingsRepository extends StateNotifier<UserSettings> {
  SettingsRepository() : super(UserSettings()) {
    _loadFromPrefs();
  }

  static const String _pushKey = 'settings_push';
  static const String _emailKey = 'settings_email';
  static const String _smsKey = 'settings_sms';
  static const String _twoFactorAuthKey = 'settings_2fa';
  static const String _langKey = 'settings_lang';
  static const String _currKey = 'settings_curr';
  static const String _darkModeKey = 'settings_dark_mode';
  static const String _onboardingKey = 'settings_onboarding';

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    state = UserSettings(
      pushNotifications: prefs.getBool(_pushKey) ?? true,
      emailNotifications: prefs.getBool(_emailKey) ?? true,
      smsNotifications: prefs.getBool(_smsKey) ?? false,
      twoFactorAuth: prefs.getBool(_twoFactorAuthKey) ?? true,
      language: prefs.getString(_langKey) ?? 'English (United States)',
      currency: prefs.getString(_currKey) ?? r'USD ($)',
      isDarkMode: prefs.getBool(_darkModeKey) ?? false,
      hasSeenOnboarding: prefs.getBool(_onboardingKey) ?? false,
      initialized: true,
    );
  }

  Future<void> updatePush(bool value) async {
    state = state.copyWith(pushNotifications: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_pushKey, value);
  }

  Future<void> updateEmail(bool value) async {
    state = state.copyWith(emailNotifications: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_emailKey, value);
  }

  Future<void> updateSms(bool value) async {
    state = state.copyWith(smsNotifications: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_smsKey, value);
  }

  Future<void> update2FA(bool value) async {
    state = state.copyWith(twoFactorAuth: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_twoFactorAuthKey, value);
  }

  Future<void> updateLanguage(String value) async {
    state = state.copyWith(language: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_langKey, value);
  }

  Future<void> updateCurrency(String value) async {
    state = state.copyWith(currency: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currKey, value);
  }

  Future<void> updateDarkMode(bool value) async {
    state = state.copyWith(isDarkMode: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_darkModeKey, value);
  }

  Future<void> updateOnboarding(bool value) async {
    state = state.copyWith(hasSeenOnboarding: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingKey, value);
  }

}

final settingsProvider =
    StateNotifierProvider<SettingsRepository, UserSettings>((ref) {
      return SettingsRepository();
    });
