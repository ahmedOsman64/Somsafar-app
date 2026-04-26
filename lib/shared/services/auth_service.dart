import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import '../models/payment_account_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../../core/services/supabase_service.dart';

class NoopAuthStorage extends sb.GotrueAsyncStorage {
  @override
  Future<String?> getItem({required String key}) async => null;
  @override
  Future<void> setItem({required String key, required String value}) async {}
  @override
  Future<void> removeItem({required String key}) async {}
}

final authServiceProvider = ChangeNotifierProvider<AuthService>((ref) {
  return AuthService();
});

final authProvider = Provider<User?>((ref) {
  return ref.watch(authServiceProvider).state;
});

class AuthService extends ChangeNotifier {
  User? _state;
  User? get state => _state;
  set state(User? value) {
    if (_state == value) return;
    _state = value;
    notifyListeners();
  }

  sb.RealtimeChannel? _sessionChannel;

  bool _initialized = false;
  bool get initialized => _initialized;

  bool _mounted = true;
  bool get mounted => _mounted;

  AuthService({bool listen = true}) {
    debugPrint('AuthService: Initializing...');
    if (listen) {
      _initInitialState();
      _initAuthStateListener();
    }
  }

  Future<void> _initInitialState() async {
    // A slight delay to ensure everything is ready
    await Future.delayed(Duration.zero);
    final session = SupabaseConfig.client.auth.currentSession;
    debugPrint('AuthService: Current session: ${session?.user.id}');

    if (session == null) {
      if (!_initialized) {
        _initialized = true;
        debugPrint('AuthService: Initialized (No session)');
        notifyListeners();
      }
    }
    // If session != null, the listener will handle it and set _initialized = true
  }

  @override
  void dispose() {
    _mounted = false;
    super.dispose();
  }

  void _initAuthStateListener() {
    SupabaseConfig.client.auth.onAuthStateChange.listen((data) async {
      final sb.Session? session = data.session;
      final event = data.event;

      debugPrint('DEBUG: AUTH EVENT: $event, User: ${session?.user.id}');

      if (session != null) {
        await _fetchAndSetProfile(session);
        // Force logout if the user is suspended or blocked
        if (_state != null &&
            (_state!.status == UserStatus.blocked ||
                _state!.status == UserStatus.suspended)) {
          debugPrint(
            'DEBUG: Account is not active (status: ${_state!.status.name}), forcing logout.',
          );
          await SupabaseConfig.client.auth.signOut();
          if (mounted) state = null;
        } else {
          // Start monitoring for concurrent sessions
          _startSessionMonitoring(session.user.id, session.accessToken);
        }
      } else {
        _stopSessionMonitoring();
        if (mounted) state = null;
      }

      if (!_initialized) {
        _initialized = true;
        notifyListeners();
      }
    });
  }

  Future<void> _fetchAndSetProfile(sb.Session session) async {
    int retries = 0;
    const maxRetries = 3;

    while (retries < maxRetries) {
      try {
        debugPrint(
          'DEBUG: Fetching profile for user ${session.user.id} from "users" table (Attempt ${retries + 1})...',
        );
        final res = await SupabaseConfig.client
            .from('users')
            .select()
            .eq('id', session.user.id)
            .maybeSingle();

        if (res != null) {
          debugPrint('DEBUG: Profile found: ${res['role']}');
          final user = _mapResToUser(res, session);
          if (mounted) state = user;
          return; // Success
        }

        debugPrint('DEBUG: Profile missing for ${session.user.id}.');

        // Wait before retrying (exponential backoff or simple delay)
        retries++;
        if (retries < maxRetries) {
          await Future.delayed(Duration(milliseconds: 500 * retries));
        }
      } on sb.PostgrestException catch (e) {
        debugPrint('ERROR: Database error querying "users": ${e.message}');
        // Don't retry on certain DB errors if appropriate, but generally retry
        retries++;
        await Future.delayed(Duration(milliseconds: 500 * retries));
      } catch (e) {
        debugPrint('ERROR: Failed to fetch profile: $e');
        retries++;
        await Future.delayed(Duration(milliseconds: 500 * retries));
      }
    }

    // If we reach here, retries failed
    debugPrint('DEBUG: Retries exhausted. Creating default profile as fallback.');
    final newUser = await _createDefaultProfile(session);
    if (mounted && newUser != null) {
      state = newUser;
    }
  }

  User _mapResToUser(Map<String, dynamic> res, sb.Session session) {
    final roleStr = res['role'] as String? ?? 'traveler';
    final statusStr = res['status'] as String? ?? 'active';

    UserRole role = UserRole.traveler;
    if (roleStr == 'admin') {
      role = UserRole.admin;
    } else if (roleStr == 'provider') {
      role = UserRole.provider;
    } else if (roleStr == 'provider_helper') {
      role = UserRole.providerHelper;
    }

    AdminRole? adminRole;
    if (role == UserRole.admin) {
      final adminRoleStr = res['admin_role'] as String?;
      adminRole = AdminRole.values.firstWhere(
        (e) => e.name == adminRoleStr,
        orElse: () => AdminRole.superAdmin,
      );
    }

    ProviderType? providerType;
    if (role == UserRole.provider) {
      final typeStr = res['provider_type'] as String?;
      providerType = ProviderType.values.firstWhere(
        (e) => e.name == typeStr,
        orElse: () => ProviderType.hotel,
      );
    }

    TravelerType? travelerType;
    if (role == UserRole.traveler) {
      final typeStr = res['traveler_type'] as String?;
      travelerType = TravelerType.values.firstWhere(
        (e) => e.name == typeStr,
        orElse: () => TravelerType.leisure,
      );
    }

    final metadata = res['metadata'] as Map<String, dynamic>? ?? {};
    final List<PaymentAccount> paymentAccounts = [];
    if (metadata.containsKey('payment_accounts')) {
      final accountsData = metadata['payment_accounts'] as List<dynamic>;
      for (var item in accountsData) {
        paymentAccounts.add(PaymentAccount.fromJson(item));
      }
    }

    return User(
      id: res['id'],
      name: res['name'] ?? '',
      email: res['email'] ?? session.user.email ?? '',
      password: '',
      role: role,
      adminRole: adminRole,
      providerType: providerType,
      travelerType: travelerType,
      providerId: res['provider_id'], // Map the provider_id if it exists
      status: statusStr == 'blocked'
          ? UserStatus.blocked
          : (statusStr == 'suspended'
                ? UserStatus.suspended
                : UserStatus.active),
      phone: res['phone'],
      location: res['location'],
      profileImage: res['profile_image'],
      metadata: metadata,
      paymentAccounts: paymentAccounts,
      createdAt: res['created_at'] != null
          ? DateTime.parse(res['created_at'])
          : null,
      updatedAt: res['updated_at'] != null
          ? DateTime.parse(res['updated_at'])
          : null,
      dateOfBirth: res['date_of_birth'] != null
          ? DateTime.parse(res['date_of_birth'])
          : null,

      gender: () {
        // Try top-level gender column first, then fall back to metadata
        final topLevelGender = res['gender'] as String?;
        if (topLevelGender != null) {
          return Gender.values.firstWhere(
            (e) => e.name == topLevelGender,
            orElse: () => Gender.male,
          );
        }
        // Safely access metadata map for gender
        final metaMap = res['metadata'];
        if (metaMap is Map) {
          final metaGender = metaMap['gender'] as String?;
          if (metaGender != null) {
            return Gender.values.firstWhere(
              (e) => e.name == metaGender,
              orElse: () => Gender.male,
            );
          }
        }
        return null;
      }(),
      lastSessionId: res['last_session_id'],
      failedAttempts: res['failed_attempts'] ?? 0,
    );
  }

  void _startSessionMonitoring(String userId, String currentSessionId) {
    _stopSessionMonitoring();

    debugPrint('DEBUG: Starting session monitoring for $userId');
    _sessionChannel = SupabaseConfig.client
        .channel('public:users:id=eq.$userId')
        .onPostgresChanges(
          event: sb.PostgresChangeEvent.update,
          schema: 'public',
          table: 'users',
          filter: sb.PostgresChangeFilter(
            type: sb.PostgresChangeFilterType.eq,
            column: 'id',
            value: userId,
          ),
          callback: (payload) async {
            final newSessionId = payload.newRecord['last_session_id'];
            debugPrint(
              'DEBUG: Session change detected. DB: $newSessionId, Local: $currentSessionId',
            );

            if (newSessionId != null && newSessionId != currentSessionId) {
              debugPrint('DEBUG: Concurrent login detected. Forced logout.');
              await logout();
              // Optionally show a message to the user
            }
          },
        )
        .subscribe();
  }

  void _stopSessionMonitoring() {
    if (_sessionChannel != null) {
      debugPrint('DEBUG: Stopping session monitoring.');
      SupabaseConfig.client.removeChannel(_sessionChannel!);
      _sessionChannel = null;
    }
  }

  Future<User?> _createDefaultProfile(sb.Session session) async {
    final meta = session.user.userMetadata ?? {};
    final name = meta['name'] ?? 'New User';
    final email = session.user.email ?? '';
    final role = meta['role'] ?? 'traveler';
    final adminRole = meta['admin_role'];
    final providerType = meta['provider_type'];
    final travelerType = meta['traveler_type'];
    final phone = meta['phone'];
    final location = meta['location'];
    final gender = meta['gender'];

    try {
      final data = {
        'id': session.user.id,
        'name': name,
        'email': email,
        'role': role,
        if (adminRole != null) 'admin_role': adminRole,
        if (providerType != null) 'provider_type': providerType,
        if (travelerType != null) 'traveler_type': travelerType,
        if (phone != null) 'phone': phone,
        if (location != null) 'location': location,
        if (gender != null) 'gender': gender,
        'status': 'active',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'date_of_birth': DateTime.now()
            .toIso8601String(), // As requested: "automatic u qad waqtiga la abuuRAY"
      };

      await SupabaseConfig.client.from('users').upsert(data);
      debugPrint('DEBUG: Default profile created/upserted for ${session.user.id}');

      return _mapResToUser(data, session);
    } catch (e) {
      debugPrint('ERROR: Could not create default profile: $e');
      return null;
    }
  }

  Future<String?> login(String email, String password) async {
    try {
      final loginEmail = email.contains('@')
          ? email
          : '$email@somsafarbooking.com';
      _isLoading = true;
      if (mounted) notifyListeners();

      sb.AuthResponse? response;
      int retries = 3;
      
      while (retries > 0) {
        try {
          response = await SupabaseConfig.client.auth.signInWithPassword(
            email: loginEmail,
            password: password,
          ).timeout(const Duration(seconds: 30), onTimeout: () {
            debugPrint('DEBUG: AuthService login timed out after 30 seconds.');
            throw TimeoutException('Connection timed out. Please try again.');
          });
          break; // Success
        } catch (e) {
          final errStr = e.toString().toLowerCase();
          final isNetworkError = e is TimeoutException || 
            errStr.contains('socketexception') || 
            errStr.contains('failed host lookup') || 
            errStr.contains('connection failed') || 
            errStr.contains('errno = 7') ||
            errStr.contains('pending response rejected') ||
            errStr.contains('os error');
          
          if (!isNetworkError) {
            rethrow; // Don't retry auth errors like invalid password
          }
          
          retries--;
          debugPrint('DEBUG: Network error on login, retries left: $retries. Error: $errStr');
          if (retries == 0) rethrow;
          await Future.delayed(const Duration(seconds: 2));
        }
      }

      if (!mounted) return null; // prevent disposed widget error

      if (response!.session == null) {
        return 'Please verify your email address.';
      }

      await _fetchAndSetProfile(response.session!);

      if (_state == null) {
        return 'Unable to load profile. Please try again.';
      }

      if (_state!.status == UserStatus.blocked ||
          _state!.status == UserStatus.suspended) {
        final status = _state!.status.name;
        await SupabaseConfig.client.auth.signOut();
        return 'Account is $status. Please contact support.';
      }

      // Record successful login details
      try {
        await SupabaseConfig.client
            .from('users')
            .update({
              'last_session_id': response.session!.accessToken,
              'failed_attempts': 0,
              'last_login_attempt': DateTime.now().toIso8601String(),
            })
            .eq('id', response.user!.id);
      } catch (e) {
        debugPrint('Non-fatal error updating login metadata: $e');
      }

      return null;
    } on sb.AuthException catch (e) {
      if (e.message.contains('MFA') || e.message.contains('mfa_required')) {
        debugPrint('DEBUG: AuthService: MFA Required.');
        return 'MFA_REQUIRED';
      }
      if (e.message.toLowerCase().contains('invalid login credentials')) {
        await _handleFailedLogin(email);
        return 'Invalid email or password';
      }
      final errStr = e.message.toLowerCase();
      if (errStr.contains('socketexception') || 
          errStr.contains('failed host lookup') || 
          errStr.contains('connection failed') ||
          errStr.contains('errno = 7') ||
          errStr.contains('os error')) {
        return 'Please check your internet connection';
      }
      return e.message;
    } on TimeoutException catch (e) {
      return e.message;
    } catch (e) {
      debugPrint('DEBUG: Unexpected login error: $e');
      final err = e.toString().toLowerCase();
      
      // Detailed detection for connection errors across platforms
      if (err.contains('socketexception') || 
          err.contains('failed host lookup') || 
          err.contains('connection failed') ||
          err.contains('errno = 7') || // Common linux/android connection error
          err.contains('pending response rejected') ||
          err.contains('os error')) {
        return 'Please check your internet connection';
      }
      
      if (err.contains('http_exception') || 
          err.contains('502') || 
          err.contains('503') || 
          err.contains('server unreachable')) {
        return 'Server unreachable. Please try again later.';
      }

      return 'An unexpected error occurred. Please try again.';
    } finally {
      if (mounted) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Future<String?> signup({
    required String name,
    required String email,
    required String password,
    required UserRole role,
    String? phone,
    String? businessName,
    Gender? gender,
  }) async {
    try {
      final res = await SupabaseConfig.client.auth.signUp(
        email: email,
        password: password,
        data: {
          'name': name,
          'role': role.name,
          if (phone != null) 'phone': phone,
          if (businessName != null) 'businessName': businessName,
          'metadata': {if (gender != null) 'gender': gender.name},
        },
      );

      if (res.session != null) {
        await _fetchAndSetProfile(res.session!);
        return 'AUTO_LOGIN';
      }

      return null; // success, confirmation required
    } on sb.AuthException catch (e) {
      if (e.message.contains('rate limit') ||
          e.message.toLowerCase().contains('email rate limit exceeded')) {
        return 'Email rate limit exceeded. Please try using a new email address, or adjust the Rate Limits in your Supabase Dashboard.';
      }
      return e.message;
    } catch (e) {
      return 'Signup failed. Please try again.';
    }
  }

  Future<String?> verifyOTP(String email, String otp) async {
    try {
      final res = await SupabaseConfig.client.auth.verifyOTP(
        type: sb.OtpType.signup,
        token: otp,
        email: email,
      );

      if (res.user != null) {
        // Auth success, now ensure the public user record is created
        final meta = res.user!.userMetadata;
        final name = meta?['name'] ?? 'Unknown User';
        final roleStr = meta?['role'] ?? 'traveler';

        await SupabaseConfig.client.from('users').upsert({
          'id': res.user!.id,
          'name': name,
          'email': res.user!.email!,
          'role': roleStr,
          'status': 'active',
          'metadata': {'gender': res.user!.userMetadata?['gender']},
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
          'date_of_birth': DateTime.now().toIso8601String(),
        });

        return null; // success
      }
      return 'Verification failed.';
    } on sb.AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'Invalid or expired OTP.';
    }
  }

  Future<String?> resetPassword(String email) async {
    try {
      await SupabaseConfig.client.auth.resetPasswordForEmail(email);
      return null;
    } on sb.AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'Password reset failed.';
    }
  }

  Future<void> updatePassword(String newPassword) async {
    await SupabaseConfig.client.auth.updateUser(
      sb.UserAttributes(password: newPassword),
    );
  }

  /// Securely changes the user's password after verifying the current one.
  Future<String?> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (state == null) return 'No user logged in';

    try {
      _isLoading = true;
      if (mounted) notifyListeners();

      // Verify current password by attempting a re-authentication
      final loginEmail = state!.email.contains('@')
          ? state!.email
          : '${state!.id}@somsafarbooking.com';

      // Use a temporary client to avoid side effects on the main session
      final tempClient = sb.SupabaseClient(
        SupabaseConfig.url,
        SupabaseConfig.anonKey,
        authOptions: sb.AuthClientOptions(
          authFlowType: sb.AuthFlowType.implicit,
          pkceAsyncStorage: NoopAuthStorage(),
        ),
      );

      try {
        await tempClient.auth.signInWithPassword(
          email: loginEmail,
          password: currentPassword,
        );
      } on sb.AuthException {
        return 'Incorrect current password';
      }

      // If we reach here, re-authentication succeeded
      await SupabaseConfig.client.auth.updateUser(
        sb.UserAttributes(password: newPassword),
      );

      return null; // Success
    } on sb.AuthException catch (e) {
      return e.message;
    } catch (e) {
      print('ERROR in changePassword: $e');
      return 'An unexpected error occurred: $e';
    } finally {
      if (mounted) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  void updateUserData(User user) {
    state = user;
  }

  Future<String?> updateProfile({
    String? name,
    String? phone,

    DateTime? dateOfBirth,
    String? profileImage,
    TravelerType? travelerType,
    String? location,
    Gender? gender,
    Map<String, dynamic>? metadata,
  }) async {
    if (state == null) return 'No user logged in';

    try {
      // Always merge with existing metadata to avoid wiping data
      final existingMeta = Map<String, dynamic>.from(state!.metadata);
      final updatedMeta = {
        ...existingMeta,
        if (metadata != null) ...metadata,
        if (gender != null) 'gender': gender.name,
      };

      final updates = {
        if (name != null) 'name': name,
        if (phone != null) 'phone': phone,
        if (location != null) 'location': location,

        if (dateOfBirth != null) 'date_of_birth': dateOfBirth.toIso8601String(),
        if (profileImage != null) 'profile_image': profileImage,
        if (travelerType != null) 'traveler_type': travelerType.name,
        // Only include metadata in the update if there's something to update
        if (gender != null || metadata != null) 'metadata': updatedMeta,
        'updated_at': DateTime.now().toIso8601String(),
      };

      await SupabaseConfig.client
          .from('users')
          .update(updates)
          .eq('id', state!.id);

      // Local state update
      state = state!.copyWith(
        name: name,
        phone: phone,
        location: location,

        dateOfBirth: dateOfBirth,
        profileImage: profileImage,
        travelerType: travelerType,
        gender: gender ?? state!.gender,
        metadata: updatedMeta,
        updatedAt: DateTime.now(),
      );

      if (mounted) {
        state = state; // Trigger listeners
      }

      return null; // success
    } catch (e) {
      debugPrint('ERROR: Failed to update profile: $e');
      return e.toString();
    }
  }

  Future<void> logout() async {
    if (SupabaseConfig.client.auth.currentSession == null) {
      debugPrint('AuthService: logout called but no session exists. Skipping.');
      return;
    }
    await SupabaseConfig.client.auth.signOut();
  }

  // --- Multi-Factor Authentication (MFA) ---

  /// Returns true if the current user has at least one verified MFA factor enabled.
  bool get isMFAEnabled {
    final session = SupabaseConfig.client.auth.currentSession;
    if (session == null) return false;
    final factors = session.user.factors;
    if (factors == null) return false;
    return factors.any((f) => f.status == sb.FactorStatus.verified);
  }

  /// Initiates TOTP MFA enrollment.
  /// Returns the factor details (including QR URI and secret).
  Future<sb.AuthMFAEnrollResponse> enrollTOTP() async {
    try {
      // Add a unique suffix to the friendly name to avoid "mfa_factor_name_conflict" 
      // if the user has a previous unverified factor with the same name.
      final timestamp = DateTime.now().millisecondsSinceEpoch % 10000;
      final friendlyName = '${state?.name ?? 'User'} ($timestamp)';
      
      final res = await SupabaseConfig.client.auth.mfa.enroll(
        factorType: sb.FactorType.totp,
        issuer: 'SomSafar',
        friendlyName: friendlyName,
      );
      return res;
    } catch (e) {
      debugPrint('ERROR: MFA Enroll failed: $e');
      rethrow;
    }
  }

  /// Completes TOTP MFA enrollment by verifying the first code.
  Future<String?> verifyTOTPSetup({
    required String factorId,
    required String code,
  }) async {
    try {
      final challenge = await SupabaseConfig.client.auth.mfa.challenge(
        factorId: factorId,
      );
      
      await SupabaseConfig.client.auth.mfa.verify(
        factorId: factorId,
        challengeId: challenge.id,
        code: code,
      );
      
      notifyListeners();
      return null;
    } on sb.AuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  /// Verifies an MFA challenge during login.
  Future<String?> verifyMFAChallenge({
    required String code,
  }) async {
    try {
      final factors = await SupabaseConfig.client.auth.mfa.listFactors();
      final totpFactor = factors.all.firstWhere(
        (f) => f.factorType == sb.FactorType.totp && f.status == sb.FactorStatus.verified,
      );

      final challenge = await SupabaseConfig.client.auth.mfa.challenge(
        factorId: totpFactor.id,
      );
      
      await SupabaseConfig.client.auth.mfa.verify(
        factorId: totpFactor.id,
        challengeId: challenge.id,
        code: code,
      );
      
      // Successfully verified challenge, now fetch profile
      final session = SupabaseConfig.client.auth.currentSession;
      if (session != null) {
        await _fetchAndSetProfile(session);
      }
      
      notifyListeners();
      return null;
    } on sb.AuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  /// Unenrolls all MFA factors for the user.
  Future<String?> unenrollMFA() async {
    try {
      final factors = await SupabaseConfig.client.auth.mfa.listFactors();
      for (final factor in factors.all) {
        await SupabaseConfig.client.auth.mfa.unenroll(factor.id);
      }
      notifyListeners();
      return null;
    } on sb.AuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  /// Permanently deletes the current user's account and logs it.
  Future<String?> deleteAccount(String? reason) async {
    try {
      _isLoading = true;
      if (mounted) notifyListeners();

      // Call the RPC function that handles logging and auth deletion
      await SupabaseConfig.client.rpc('delete_user_self', params: {
        'reason': reason,
      });

      // Logout and clear state (client-side)
      await logout();

      return null; // Success
    } on sb.AuthException catch (e) {
      return e.message;
    } on sb.PostgrestException catch (e) {
      return e.message;
    } catch (e) {
      return 'Failed to delete account. Please try again later.';
    } finally {
      if (mounted) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Method for providers to create limited helper accounts (max 3)
  Future<Map<String, dynamic>?> providerCreateHelper({
    required String fullName,
    required String username,
    required String password,
    required String providerId,
    required String helperRole,
    required List<String> permissions,
    required String providerEmail,
    String? email,
  }) async {
    try {
      final signUpEmail = email ?? '$username@somsafarbooking.com';

      // Temporary client to avoid logging out the current provider
      final tempClient = sb.SupabaseClient(
        SupabaseConfig.url,
        SupabaseConfig.anonKey,
        authOptions: sb.AuthClientOptions(
          authFlowType: sb.AuthFlowType.implicit,
          pkceAsyncStorage: NoopAuthStorage(),
        ),
      );

      final res = await tempClient.auth.signUp(
        email: signUpEmail,
        password: password,
        data: {
          'name': fullName,
          'username': username,
          'role': 'provider_helper',
          'provider_id': providerId,
          'helper_role': helperRole,
          'permissions': permissions,
          'provider_email': providerEmail,
        },
      );

      if (res.user != null) {
        // Explicitly create the public profile using the PRIMARY client
        try {
          await SupabaseConfig.client.from('users').insert({
            'id': res.user!.id,
            'name': fullName,
            'email': signUpEmail,
            'role': 'provider_helper',
            'provider_id': providerId,
            'status': 'active',
            'metadata': {
              'helper_role': helperRole,
              'permissions': permissions,
              'username': username,
              'provider_email': providerEmail,
            },
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
            'date_of_birth': DateTime.now().toIso8601String(),
          });
        } on sb.PostgrestException catch (pe) {
          // If the profile already exists (e.g. via trigger), we can ignore the error
          if (pe.code != '23505') {
            // Unique violation
            debugPrint('Helper DB Insert Error: ${pe.message}');
            return {
              'error': 'Profile creation failed: ${pe.message}',
              'id': res.user!.id,
            };
          }
        }
        return {'id': res.user!.id};
      }
      return {'error': 'Failed to create helper account (Auth).'};
    } on sb.AuthException catch (e) {
      return {'error': e.message};
    } catch (e) {
      debugPrint('Unexpected error in providerCreateHelper: $e');
      return {'error': e.toString()};
    }
  }

  /// Special admin-only method to create other users.
  /// This version uses a temporary client to avoid switching the main application's session.
  Future<Map<String, dynamic>?> adminCreateUser({
    required String name,
    required String email,
    required String password,
    required UserRole role,
    required UserStatus status,
    AdminRole? adminRole,
    ProviderType? providerType,
    TravelerType? travelerType,
    String? phone,
    String? location,
    Gender? gender,
    bool isVerified = false,
  }) async {
    try {
      // Use a temporary client to perform the signUp
      // This prevents the main application from switching sessions to the new user
      final tempClient = sb.SupabaseClient(
        SupabaseConfig.url,
        SupabaseConfig.anonKey,
        authOptions: sb.AuthClientOptions(
          authFlowType: sb.AuthFlowType.implicit,
          pkceAsyncStorage: NoopAuthStorage(),
        ),
      );

      final signUpEmail = email.contains('@')
          ? email
          : '$email@somsafarbooking.com';

      final res = await tempClient.auth.signUp(
        email: signUpEmail,
        password: password,
        data: {
          'name': name,
          'role': role.name,
          'status': status.name,
          'is_verified': isVerified,
          if (adminRole != null) 'admin_role': adminRole.name,
          if (providerType != null) 'provider_type': providerType.name,
          if (travelerType != null) 'traveler_type': travelerType.name,
          if (phone != null) 'phone': phone,
          if (location != null) 'location': location,
          'metadata': {
            'is_verified': isVerified,
            if (gender != null) 'gender': gender.name,
          },
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
          'date_of_birth': DateTime.now().toIso8601String(),
        },
      );

      if (res.user != null) {
        // Explicitly create the public profile using the PRIMARY client
        // This ensures the current admin's session is used for the DB operation
        try {
          final signUpEmail = email.contains('@')
              ? email
              : '$email@somsafarbooking.com';
          await SupabaseConfig.client.from('users').insert({
            'id': res.user!.id,
            'name': name,
            'email': signUpEmail,
            'role': role.name,
            'status': status.name,
            'metadata': {
              'is_verified': isVerified,
              if (gender != null) 'gender': gender.name,
            },
            'phone': phone,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
            'date_of_birth': DateTime.now().toIso8601String(),
          });
        } on sb.PostgrestException catch (pe) {
          // If the profile already exists (e.g. via trigger), we can ignore the error
          // or log it if it's something else.
          if (pe.code != '23505') {
            // Unique violation
            debugPrint('DB Insert Error: ${pe.message}');
            return {
              'error': 'Profile creation failed: ${pe.message}',
              'id': res.user!.id,
            };
          }
        }

        return {'id': res.user!.id};
      }
      return {'error': 'Failed to create user account (Auth).'};
    } on sb.AuthException catch (e) {
      if (e.message.contains('rate limit') ||
          e.message.toLowerCase().contains('email rate limit exceeded') ||
          e.message.toLowerCase().contains('6 seconds')) {
        return {
          'error':
              'For security purposes, please wait a few seconds before trying again, or use a different email.',
        };
      }
      return {'error': e.message};
    } catch (e) {
      print('Unexpected error in adminCreateUser: $e');
      return {'error': e.toString()};
    } finally {
      // No need to explicitly dispose tempClient as it's not a service
    }
  }

  Future<void> _handleFailedLogin(String email) async {
    try {
      // Find the user by email
      final res = await SupabaseConfig.client
          .from('users')
          .select('id, failed_attempts, role, name')
          .eq('email', email)
          .maybeSingle();

      if (res != null) {
        final userId = res['id'];
        final currentAttempts = (res['failed_attempts'] as int? ?? 0) + 1;
        final role = res['role'];
        final name = res['name'];

        final updates = {
          'failed_attempts': currentAttempts,
          'last_login_attempt': DateTime.now().toIso8601String(),
        };

        if (currentAttempts >= 5 && (role == 'admin' || role == 'provider')) {
          updates['status'] = 'blocked';

          // Log security alert
          await SupabaseConfig.client.from('system_activities').insert({
            'title': 'Account Blocked: $name',
            'subtitle':
                'Brute force detected (5 failed attempts). Account has been paused.',
            'type': 'securityAlert',
            'user_id': userId,
            'user_name': name,
            'metadata': {'failed_attempts': currentAttempts, 'email': email},
          });

          // Create notification for admin
          // We find an admin to notify (or just insert without user_id if it's a system-wide alert)
        }

        await SupabaseConfig.client
            .from('users')
            .update(updates)
            .eq('id', userId);
      }
    } catch (e) {
      print('ERROR: Failed to handle failed login: $e');
    }
  }
}
