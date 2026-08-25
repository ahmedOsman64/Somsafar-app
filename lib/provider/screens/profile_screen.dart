import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/services/auth_service.dart';
import '../../shared/models/user_model.dart';
import '../../shared/services/booking_repository.dart';
import '../../shared/services/review_repository.dart';
import '../../shared/services/service_repository.dart';
import '../../shared/models/booking_model.dart';
import '../../core/services/storage_service.dart';
import '../../shared/widgets/confirmation_dialog.dart';
import 'settings/payout_accounts_screen.dart';
import 'settings/manage_helpers_screen.dart';
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
  late TextEditingController _publicEmailController;
  late TextEditingController _providerIdController;
  bool _isSaving = false;
  bool _isUploading = false;
  bool _isEditMode = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider);
    _nameController = TextEditingController(text: user?.name ?? '');

    final displayPhone = (user?.phone == 'ENCRYPTED') ? '' : (user?.phone ?? '');
    _phoneController = TextEditingController(text: displayPhone);

    _locationController = TextEditingController(text: user?.location ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
    _publicEmailController = TextEditingController(text: user?.publicEmail ?? '');
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
    _publicEmailController.dispose();
    _providerIdController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    final user = ref.read(authProvider);
    if (user != null) {
      setState(() => _isSaving = true);
      try {
        final error = await ref.read(authServiceProvider).updateProfile(
              name: _nameController.text.trim(),
              phone: _phoneController.text.trim(),
              location: _locationController.text.trim(),
              publicEmail: _publicEmailController.text.trim(),
            );

        if (!mounted) return;

        if (error != null) {
          _showSnackbar('Error updating profile: $error', isError: true);
        } else {
          _showSnackbar('Profile updated successfully!', isError: false);
          setState(() => _isEditMode = false);
        }
      } finally {
        if (mounted) setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _pickProfileImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
    );

    if (image == null) return;

    setState(() => _isUploading = true);

    try {
      final String? imageUrl = await StorageService.uploadImage(
        image,
        folder: 'profiles',
      );

      if (imageUrl != null) {
        final error = await ref
            .read(authServiceProvider)
            .updateProfile(profileImage: imageUrl);

        if (!mounted) return;

        if (error != null) {
          _showSnackbar('Error updating profile image: $error', isError: true);
        } else {
          _showSnackbar('Profile image updated!', isError: false);
        }
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackbar('Upload failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _verifyIdentity() async {
    final user = ref.read(authProvider);
    if (user == null || user.isVerified) return;

    final confirmed = await ConfirmationDialog.show(
      context: context,
      title: 'Verify Business Identity?',
      message:
          'By clicking verify, you confirm your business information is legitimate and accurate. This will mark your account as a Verified Provider.',
      confirmLabel: 'Yes, Verify Account',
      type: ConfirmationDialogType.info,
      icon: Icons.verified_user_outlined,
    );

    if (confirmed != true) return;

    setState(() => _isSaving = true);
    try {
      final updatedMeta = Map<String, dynamic>.from(user.metadata);
      updatedMeta['is_verified'] = true;

      final error = await ref
          .read(authServiceProvider)
          .updateProfile(metadata: updatedMeta);

      if (!mounted) return;

      if (error != null) {
        _showSnackbar('Verification failed: $error', isError: true);
      } else {
        _showSnackbar('Account verified successfully!', isError: false);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _copyToClipboard(String label, String value) {
    if (value.isEmpty) return;
    Clipboard.setData(ClipboardData(text: value));
    _showSnackbar('$label copied to clipboard!');
  }

  void _showSnackbar(String text, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(text)),
          ],
        ),
        backgroundColor: isError ? AppColors.error : const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Please login')));
    }

    final allBookings = ref.watch(filteredBookingsProvider);
    final reviews = ref.watch(reviewProvider);
    final services = ref.watch(serviceProvider);
    final providerKey = user.providerId ?? user.id;

    final providerBookings = allBookings
        .where((b) => b.providerId == providerKey)
        .toList();

    final myServices = services
        .where((s) => s.providerId == providerKey)
        .toList();

    double acceptanceRate = 1.0;
    double speedScore = 100.0;

    final confirmedBookings = providerBookings
        .where((b) =>
            b.status == BookingStatus.confirmed ||
            b.status == BookingStatus.completed)
        .toList();

    if (providerBookings.isNotEmpty) {
      final decidedBookings = providerBookings
          .where((b) => b.status != BookingStatus.pending)
          .toList();

      if (decidedBookings.isNotEmpty) {
        acceptanceRate = confirmedBookings.length / decidedBookings.length;
      }

      if (confirmedBookings.isNotEmpty) {
        double totalSpeedPoints = 0;
        int speedCount = 0;

        for (final b in confirmedBookings) {
          if (b.confirmedAt != null) {
            final diff = b.confirmedAt!.difference(b.date).inMinutes;
            if (diff <= 5) {
              totalSpeedPoints += 100;
            } else if (diff <= 15) {
              totalSpeedPoints += 85;
            } else if (diff <= 30) {
              totalSpeedPoints += 70;
            } else if (diff <= 60) {
              totalSpeedPoints += 50;
            } else {
              totalSpeedPoints += 30;
            }
            speedCount++;
          }
        }
        if (speedCount > 0) speedScore = totalSpeedPoints / speedCount;
      }
    }

    double totalEarnings = 0;
    for (var b in confirmedBookings) {
      totalEarnings += b.totalPrice;
    }

    double avgRating = 0;
    if (reviews.isNotEmpty) {
      avgRating =
          reviews.map((r) => r.rating).reduce((a, b) => a + b) / reviews.length;
    }

    double finalPerformance;
    if (reviews.isNotEmpty) {
      finalPerformance = ((avgRating * 20) * 0.5) +
          ((acceptanceRate * 100) * 0.25) +
          (speedScore * 0.25);
    } else {
      finalPerformance = ((acceptanceRate * 100) * 0.5) + (speedScore * 0.5);
    }

    final performanceScore = '${finalPerformance.toStringAsFixed(0)}%';

    String joinedDate = '—';
    if (user.createdAt != null) {
      joinedDate = DateFormat('MMM yyyy').format(user.createdAt!);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ── Modern Gradient Header ───────────────────────────
            _buildHeader(user),

            const SizedBox(height: 20),

            // ── Responsive Performance & Metric Cards ──────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isMobile = constraints.maxWidth < 600;
                  final cardWidth = isMobile
                      ? (constraints.maxWidth - 12) / 2
                      : (constraints.maxWidth - 36) / 4;

                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _buildMetricCard(
                        width: cardWidth,
                        title: 'Performance',
                        value: performanceScore,
                        subtitle: 'Overall Reliability',
                        icon: Icons.speed_rounded,
                        color: const Color(0xFF10B981),
                      ),
                      _buildMetricCard(
                        width: cardWidth,
                        title: 'Gross Earnings',
                        value: '\$${totalEarnings.toStringAsFixed(2)}',
                        subtitle: 'Completed Revenue',
                        icon: Icons.account_balance_wallet_rounded,
                        color: AppColors.primary,
                      ),
                      _buildMetricCard(
                        width: cardWidth,
                        title: 'Active Services',
                        value: '${myServices.length}',
                        subtitle: 'Published Listings',
                        icon: Icons.grid_view_rounded,
                        color: const Color(0xFF6366F1),
                      ),
                      _buildMetricCard(
                        width: cardWidth,
                        title: 'Joined Date',
                        value: joinedDate,
                        subtitle: 'Member Since',
                        icon: Icons.calendar_month_rounded,
                        color: const Color(0xFFF59E0B),
                      ),
                    ],
                  );
                },
              ),
            ),

            const SizedBox(height: 24),

            // ── Account Details Card ─────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildAccountDetailsCard(user),
            ),

            const SizedBox(height: 24),

            // ── Business Settings & Shortcut Cards ────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildBusinessShortcuts(context, user),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(User user) {
    final providerTypeLabel =
        (user.providerType ?? ProviderType.hotel).name.toUpperCase().replaceAll('_', ' ');

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E3A8A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
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
                            color: Colors.black.withAlpha(50),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 48,
                        backgroundColor: Colors.white.withAlpha(20),
                        backgroundImage: user.profileImage != null &&
                                user.profileImage!.isNotEmpty
                            ? NetworkImage(
                                StorageService.ensurePublicUrl(user.profileImage!),
                              )
                            : null,
                        child: _isUploading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : (user.profileImage == null ||
                                    user.profileImage!.isEmpty)
                                ? const Icon(
                                    Icons.business_rounded,
                                    size: 48,
                                    color: Colors.white,
                                  )
                                : null,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.secondary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(
                        Icons.camera_alt_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Business Name
              _isEditMode
                  ? SizedBox(
                      width: 360,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: TextField(
                          controller: _nameController,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Enter Business Name',
                            hintStyle: TextStyle(color: Colors.white.withAlpha(120)),
                            filled: true,
                            fillColor: Colors.white.withAlpha(20),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                vertical: 10, horizontal: 16),
                          ),
                        ),
                      ),
                    )
                  : Text(
                      user.name,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),

              const SizedBox(height: 10),

              // Badges Row
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: user.isVerified
                          ? const Color(0xFF10B981).withAlpha(40)
                          : Colors.amber.withAlpha(40),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: user.isVerified
                            ? const Color(0xFF10B981)
                            : Colors.amber,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          user.isVerified
                              ? Icons.verified_rounded
                              : Icons.gpp_maybe_rounded,
                          color: user.isVerified
                              ? const Color(0xFF10B981)
                              : Colors.amber,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          user.isVerified ? 'VERIFIED BUSINESS' : 'UNVERIFIED',
                          style: TextStyle(
                            color: user.isVerified
                                ? const Color(0xFF10B981)
                                : Colors.amber,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(20),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withAlpha(40)),
                    ),
                    child: Text(
                      '$providerTypeLabel PROVIDER',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required double width,
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountDetailsCard(User user) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.business_center_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Account & Business Information',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () {
                  if (_isEditMode) {
                    _saveProfile();
                  } else {
                    setState(() => _isEditMode = true);
                  }
                },
                icon: Icon(
                  _isEditMode ? Icons.check_circle_rounded : Icons.edit_rounded,
                  size: 16,
                ),
                label: Text(_isEditMode ? 'Save' : 'Edit'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isEditMode
                      ? const Color(0xFF10B981)
                      : AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Fields
          _buildInfoRow(
            icon: Icons.email_rounded,
            color: const Color(0xFF6366F1),
            label: 'Primary Account Email',
            value: user.email,
            controller: _emailController,
            isEditable: false,
            onCopy: () => _copyToClipboard('Primary Email', user.email),
          ),
          _buildFieldDivider(),

          _buildInfoRow(
            icon: Icons.mark_email_read_rounded,
            color: const Color(0xFFEC4899),
            label: 'Public Business Email',
            value: user.publicEmail ?? 'Not specified',
            controller: _publicEmailController,
            isEditable: _isEditMode,
            onCopy: user.publicEmail != null
                ? () => _copyToClipboard('Business Email', user.publicEmail!)
                : null,
          ),
          _buildFieldDivider(),

          _buildInfoRow(
            icon: Icons.phone_android_rounded,
            color: const Color(0xFF3B82F6),
            label: 'Contact Phone Number',
            value: _phoneController.text.isNotEmpty
                ? _phoneController.text
                : 'Not specified',
            controller: _phoneController,
            isEditable: _isEditMode,
            onCopy: _phoneController.text.isNotEmpty
                ? () => _copyToClipboard('Phone Number', _phoneController.text)
                : null,
          ),
          _buildFieldDivider(),

          _buildInfoRow(
            icon: Icons.location_on_rounded,
            color: const Color(0xFF10B981),
            label: 'Business Location / City',
            value: _locationController.text.isNotEmpty
                ? _locationController.text
                : 'Not specified',
            controller: _locationController,
            isEditable: _isEditMode,
          ),
          _buildFieldDivider(),

          _buildInfoRow(
            icon: Icons.badge_rounded,
            color: const Color(0xFFF59E0B),
            label: 'Provider Account ID',
            value: user.providerId ?? user.id,
            controller: _providerIdController,
            isEditable: false,
            onCopy: () => _copyToClipboard(
              'Provider ID',
              user.providerId ?? user.id,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldDivider() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Divider(height: 1, color: Color(0xFFF1F5F9)),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
    required TextEditingController controller,
    required bool isEditable,
    VoidCallback? onCopy,
  }) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withAlpha(20),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 3),
              _isEditMode && isEditable
                  ? TextField(
                      controller: controller,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: AppColors.primary),
                        ),
                      ),
                    )
                  : Text(
                      value,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                      ),
                    ),
            ],
          ),
        ),
        if (onCopy != null && !_isEditMode)
          IconButton(
            onPressed: onCopy,
            icon: Icon(Icons.copy_rounded, size: 16, color: Colors.grey[400]),
            tooltip: 'Copy $label',
          ),
      ],
    );
  }

  Widget _buildBusinessShortcuts(BuildContext context, User user) {
    return Column(
      children: [
        if (!user.isVerified) ...[
          _buildShortcutTile(
            context,
            icon: Icons.verified_user_rounded,
            title: 'Verify Business Identity',
            subtitle: 'Activate verified badge & boost search ranking',
            color: const Color(0xFFF97316),
            isLoading: _isSaving,
            onTap: _verifyIdentity,
          ),
          const SizedBox(height: 12),
        ],

        _buildShortcutTile(
          context,
          icon: Icons.account_balance_rounded,
          title: 'Payout Accounts & Financial Settings',
          subtitle: 'Manage EVC Plus, Zaad, Sahal, or Bank payout details',
          color: const Color(0xFF10B981),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const PayoutAccountsScreen(),
            ),
          ),
        ),

        const SizedBox(height: 12),

        _buildShortcutTile(
          context,
          icon: Icons.group_outlined,
          title: 'Manage Staff & Helper Access',
          subtitle: 'Grant delegate permissions for booking handlers',
          color: const Color(0xFF6366F1),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ManageHelpersScreen(),
            ),
          ),
        ),

        const SizedBox(height: 12),

        _buildShortcutTile(
          context,
          icon: Icons.security_rounded,
          title: 'Security & Privacy Settings',
          subtitle: 'Change password, 2FA, & account preferences',
          color: AppColors.primary,
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

  Widget _buildShortcutTile(
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
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(8),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withAlpha(20),
                borderRadius: BorderRadius.circular(12),
              ),
              child: isLoading
                  ? Padding(
                      padding: const EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
                    )
                  : Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.grey[400],
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
