import 'payment_account_model.dart';

enum UserRole { traveler, provider, admin, providerHelper }

enum AdminRole { superAdmin, opsAdmin, financeAdmin, supportAdmin }

enum UserStatus { active, blocked, suspended }

enum ProviderType { hotel, home, apartment, all, tour }
enum Gender { male, female }

enum TravelerType { leisure, business, family, solo, adventure }

class User {
  final String id;
  final String name;
  final String email;
  final UserRole role;
  final AdminRole? adminRole; // Only for admin users
  final ProviderType? providerType; // Only for provider users
  final TravelerType? travelerType; // Only for traveler users
  final String? providerId; // Scoping ID for providers
  final UserStatus status;
  final String? profileImage;
  final String password; // Mock password field
  final String? phone; // Phone number entered by admin
  final String? location; // Business location entered by admin
  final DateTime? createdAt; // Account creation date
  final DateTime? updatedAt; // Last update date
  final DateTime? dateOfBirth; // User's birth date

  final Gender? gender; // User's gender
  final String? publicEmail; // Business email for customers to see after booking
  final String? lastSessionId; // For concurrent session control
  final int failedAttempts; // For brute force protection

  // NEW: Business / Payment fields
  final Map<String, dynamic> metadata;
  final List<PaymentAccount> paymentAccounts;

  const User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.password,
    this.adminRole,
    this.providerType,
    this.travelerType,
    this.providerId,
    this.status = UserStatus.active,
    this.profileImage,
    this.phone,
    this.location,
    this.createdAt,
    this.updatedAt,
    this.dateOfBirth,

    this.gender,
    this.publicEmail,
    this.lastSessionId,
    this.failedAttempts = 0,
    this.metadata = const {},
    this.paymentAccounts = const [],
  });

  User copyWith({
    String? name,
    String? email,
    UserRole? role,
    AdminRole? adminRole,
    bool clearAdminRole = false,
    ProviderType? providerType,
    bool clearProviderType = false,
    TravelerType? travelerType,
    bool clearTravelerType = false,
    String? providerId,
    UserStatus? status,
    String? profileImage,
    String? password,
    String? phone,
    bool clearPhone = false,
    String? location,
    bool clearLocation = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? dateOfBirth,

    Gender? gender,
    String? publicEmail,
    bool clearPublicEmail = false,
    String? lastSessionId,
    int? failedAttempts,
    Map<String, dynamic>? metadata,
    List<PaymentAccount>? paymentAccounts,
  }) {
    return User(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      adminRole: clearAdminRole ? null : (adminRole ?? this.adminRole),
      providerType:
          clearProviderType ? null : (providerType ?? this.providerType),
      travelerType:
          clearTravelerType ? null : (travelerType ?? this.travelerType),
      providerId: providerId ?? this.providerId,
      status: status ?? this.status,
      profileImage: profileImage ?? this.profileImage,
      password: password ?? this.password,
      phone: clearPhone ? null : (phone ?? this.phone),
      location: clearLocation ? null : (location ?? this.location),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,

      gender: gender ?? this.gender,
      publicEmail: clearPublicEmail ? null : (publicEmail ?? this.publicEmail),
      lastSessionId: lastSessionId ?? this.lastSessionId,
      failedAttempts: failedAttempts ?? this.failedAttempts,
      metadata: metadata ?? this.metadata,
      paymentAccounts: paymentAccounts ?? this.paymentAccounts,
    );
  }

  String get displayName => name.replaceFirst('Verified ', '');

  bool get isProviderHelper => role == UserRole.providerHelper;

  bool get isProfileComplete =>
      name.isNotEmpty &&
      phone != null &&
      phone!.isNotEmpty &&
      location != null &&
      location!.isNotEmpty &&
      profileImage != null &&
      profileImage!.isNotEmpty &&
      gender != null &&
      dateOfBirth != null;

  bool get isVerified =>
      (metadata['is_verified'] == true) || name.startsWith('Verified');
  bool get isSuperAdmin => adminRole == AdminRole.superAdmin;
  bool get isOpsAdmin => adminRole == AdminRole.opsAdmin;
  bool get isFinanceAdmin => adminRole == AdminRole.financeAdmin;
  bool get isSupportAdmin => adminRole == AdminRole.supportAdmin;

  bool get canManageAdmins => isSuperAdmin;
  bool get canManageFinance => isSuperAdmin || isFinanceAdmin;
  bool get canManageOps => isSuperAdmin || isOpsAdmin;
  bool get canManageSupport => isSuperAdmin || isSupportAdmin;

  @override
  String toString() => name;
}
