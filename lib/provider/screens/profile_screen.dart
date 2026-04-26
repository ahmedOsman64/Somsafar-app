import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/services/auth_service.dart';
import '../../shared/models/user_model.dart';
import '../../shared/services/booking_repository.dart';
import '../../shared/services/review_repository.dart';
import '../../shared/models/booking_model.dart';
import '../../core/services/storage_service.dart';
import 'package:image_picker/image_picker.dart';
import '../../shared/widgets/confirmation_dialog.dart';
import 'settings_screen.dart';

class ProviderProfileScreen extends ConsumerStatefulWidget {
  const ProviderProfileScreen({super.key});

  @override
  ConsumerState<ProviderProfileScreen> createState() =>
      _ProviderProfileScreenState();
}

class _ProviderProfileScreenState extends ConsumerState<ProviderProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _locationController;
  late TextEditingController _emailController;
  late TextEditingController _providerIdController;
  bool _isSaving = false;
  bool _isUploading = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider);
    _nameController = TextEditingController(text: user?.name ?? '');
    _phoneController = TextEditingController(text: user?.phone ?? '');
    _locationController = TextEditingController(text: user?.location ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
    _providerIdController = TextEditingController(
      text: user?.providerId ?? user?.id ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    _emailController.dispose();
    _providerIdController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    final user = ref.read(authProvider);
    if (user != null) {
      setState(() => _isSaving = true);
      try {
        final error = await ref.read(authServiceProvider).updateProfile(
              name: _nameController.text,
              phone: _phoneController.text,
              location: _locationController.text,
            );

        if (!mounted) return;

        if (error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $error'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text('Profile updated successfully'),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _pickProfileImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );

    if (image == null) return;

    setState(() => _isUploading = true);

    try {
      final String? imageUrl = await StorageService.uploadImage(
        image,
        folder: 'profiles',
      );

      if (imageUrl != null) {
        final error = await ref.read(authServiceProvider).updateProfile(
              profileImage: imageUrl,
            );

        if (!mounted) return;

        if (error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error updating profile: $error')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile image updated')),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _verifyIdentity() async {
    final user = ref.read(authProvider);
    if (user == null || user.isVerified) return;

    final confirmed = await ConfirmationDialog.show(
      context: context,
      title: 'Verify Your Identity?',
      message:
          'Confirm Action: By clicking verify, you confirm that your business details are accurate. This will activate your account automatically.',
      confirmLabel: 'Yes, Verify Me',
      type: ConfirmationDialogType.info,
      icon: Icons.verified_user_outlined,
    );

    if (confirmed != true) return;

    setState(() => _isSaving = true);
    try {
      final updatedMeta = Map<String, dynamic>.from(user.metadata);
      updatedMeta['is_verified'] = true;

      final error = await ref.read(authServiceProvider).updateProfile(
            metadata: updatedMeta,
          );

      if (!mounted) return;

      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Verification failed: $error'),
            backgroundColor: Colors.red,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account verified successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Please login')));
    }

    final allBookings = ref.watch(filteredBookingsProvider);
    final reviews = ref.watch(reviewProvider);
    final providerKey = user.providerId ?? user.id;

    final providerBookings = allBookings
        .where((b) =>
            b.providerId == providerKey &&
            (b.status == BookingStatus.confirmed ||
                b.status == BookingStatus.completed))
        .toList();

    double totalEarnings = 0;
    for (var b in providerBookings) {
      totalEarnings += b.totalPrice;
    }

    double avgRating = 0;
    if (reviews.isNotEmpty) {
      avgRating =
          reviews.map((r) => r.rating).reduce((a, b) => a + b) / reviews.length;
    }
    final performanceScore =
        reviews.isEmpty ? '98%' : '${(avgRating * 20).toStringAsFixed(0)}%';

    String joinedDate = '—';
    if (user.createdAt != null) {
      joinedDate = DateFormat('MMM yyyy').format(user.createdAt!);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ── Gradient Header ──────────────────────────────────
            _buildHeader(user),

            // ── Stats Row ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                children: [
                  _buildStatChip(
                    Icons.speed_rounded,
                    'Performance',
                    performanceScore,
                    const Color(0xFF22C55E),
                  ),
                  const SizedBox(width: 12),
                  _buildStatChip(
                    Icons.account_balance_wallet_rounded,
                    'Earnings',
                    '\$${totalEarnings.toStringAsFixed(0)}',
                    const Color(0xFF3B82F6),
                  ),
                  const SizedBox(width: 12),
                  _buildStatChip(
                    Icons.calendar_month_rounded,
                    'Joined',
                    joinedDate,
                    const Color(0xFFF97316),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Profile Info Card ────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildInfoCard(user),
            ),

            const SizedBox(height: 20),

            // ── Action Cards ─────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildActionCards(context),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(User user) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0D3B66), Color(0xFF1A6B9A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(36),
          bottomRight: Radius.circular(36),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
          child: Column(
            children: [
              // Avatar
              GestureDetector(
                onTap: _isUploading ? null : _pickProfileImage,
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 52,
                        backgroundColor: Colors.white.withValues(alpha: 0.15),
                        backgroundImage: user.profileImage != null &&
                                user.profileImage!.isNotEmpty
                            ? NetworkImage(
                                StorageService.ensurePublicUrl(user.profileImage!))
                            : null,
                        child: _isUploading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : (user.profileImage == null ||
                                    user.profileImage!.isEmpty)
                                ? const Icon(Icons.person,
                                    size: 52, color: Colors.white)
                                : null,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: AppColors.secondary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.camera_alt,
                          color: Colors.white, size: 14),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              // Name field inline
              TextField(
                controller: _nameController,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  filled: true,
                  fillColor: Colors.transparent,
                  hintText: 'Enter name',
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: AppColors.secondary.withValues(alpha: 0.5)),
                ),
                child: Text(
                  user.role.name.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatChip(
      IconData icon, String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.12),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: Colors.grey),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(User user) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Account Details',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0D3B66),
            ),
          ),
          const SizedBox(height: 20),
          _buildInfoField(
            Icons.email_rounded,
            'Email Address',
            _emailController,
            readOnly: true,
            color: const Color(0xFF8B5CF6),
          ),
          _buildDivider(),
          _buildInfoField(
            Icons.phone_rounded,
            'Phone Number',
            _phoneController,
            color: const Color(0xFF3B82F6),
          ),
          _buildDivider(),
          _buildInfoField(
            Icons.location_on_rounded,
            'Business Location',
            _locationController,
            color: const Color(0xFF22C55E),
          ),
          _buildDivider(),
          _buildInfoField(
            Icons.badge_rounded,
            'Provider ID',
            _providerIdController,
            readOnly: true,
            color: const Color(0xFFF97316),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() => const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Divider(height: 1, color: Color(0xFFF1F5F9)),
      );

  Widget _buildInfoField(
    IconData icon,
    String label,
    TextEditingController controller, {
    bool readOnly = false,
    Color color = AppColors.primary,
  }) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                    fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 2),
              TextField(
                controller: controller,
                readOnly: readOnly,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: readOnly ? Colors.grey : const Color(0xFF0D3B66),
                ),
              ),
            ],
          ),
        ),
        if (!readOnly)
          Icon(Icons.edit, size: 16, color: Colors.grey.shade400),
      ],
    );
  }

  Widget _buildActionCards(BuildContext context) {
    return Column(
      children: [
        _buildActionTile(
          context,
          icon: Icons.save_rounded,
          title: 'Save Changes',
          subtitle: 'Update your profile information',
          color: const Color(0xFF0D3B66),
          isLoading: _isSaving,
          onTap: _saveProfile,
        ),
        if (ref.watch(authProvider)?.isVerified == false) ...[
          const SizedBox(height: 12),
          _buildActionTile(
            context,
            icon: Icons.verified_user_rounded,
            title: 'Verify Identity',
            subtitle: 'Get verified to start receiving bookings',
            color: Colors.orange,
            isLoading: _isSaving,
            onTap: _verifyIdentity,
          ),
        ],
        const SizedBox(height: 12),
        _buildActionTile(
          context,
          icon: Icons.notifications_rounded,
          title: 'Notifications',
          subtitle: 'Manage your alerts & preferences',
          color: const Color(0xFF8B5CF6),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ProviderSettingsScreen(),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _buildActionTile(
          context,
          icon: Icons.lock_rounded,
          title: 'Privacy & Security',
          subtitle: 'Password and security settings',
          color: const Color(0xFF22C55E),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ProviderSettingsScreen(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    bool isLoading = false,
  }) {
    return InkWell(
      onTap: isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: isLoading
                  ? Padding(
                      padding: const EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
                    )
                  : Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Color(0xFF0D3B66),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: Colors.grey.shade300, size: 22),
          ],
        ),
      ),
    );
  }
}
