import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/responsive.dart';
import '../../shared/models/user_model.dart';
import '../../shared/models/booking_model.dart';
import '../../shared/services/auth_service.dart';
import '../../shared/services/booking_repository.dart';
import 'profile/widgets/profile_widgets.dart';
import '../../shared/widgets/support_widgets.dart';

class TravelerProfileScreen extends ConsumerStatefulWidget {
  const TravelerProfileScreen({super.key});

  @override
  ConsumerState<TravelerProfileScreen> createState() =>
      _TravelerProfileScreenState();
}

class _TravelerProfileScreenState extends ConsumerState<TravelerProfileScreen> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _personalInfoKey = GlobalKey();
  final GlobalKey _securityKey = GlobalKey();
  final GlobalKey _supportKey = GlobalKey();
  final GlobalKey _preferencesKey = GlobalKey();
  final GlobalKey _dangerZoneKey = GlobalKey();
  bool _isEditing = false;

  void _scrollToSection(GlobalKey key) {
    final context = key.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    final isMobile = !context.isDesktop;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Traveler Profile',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.dark,
        elevation: 0,
      ),
      body: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMobile) _buildSidebar(),
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: EdgeInsets.all(isMobile ? 16 : 24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1000),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ProfileHeader(
                          name: user?.name ?? 'Ahmed Osman',
                          email: user?.email ?? 'ahmed@example.com',
                          profileImage: user?.profileImage,
                          memberSince: user?.createdAt ?? DateTime(2023, 1, 1),
                          isVerified: user?.isVerified ?? false,
                          onEdit: () {
                            setState(() => _isEditing = true);
                            _scrollToSection(_personalInfoKey);
                          },
                          onSettings: () => _scrollToSection(_preferencesKey),
                        ),
                        const SizedBox(height: 8),
                        if (user != null && !user.isProfileComplete)
                          _ProfileCompletenessCard(
                            user: user,
                            onEdit: () {
                              setState(() => _isEditing = true);
                              _scrollToSection(_personalInfoKey);
                            },
                          ),
                        const SizedBox(height: 12),
                        // Live stats row
                        _TravelerStatsRow(userId: user?.id ?? ''),
                        const SizedBox(height: 12),
                        if (_isEditing) ...[
                          ProfileSection(
                            key: _personalInfoKey,
                            icon: Icons.person_outline,
                            title: 'Personal Information',
                            child: PersonalInfoForm(
                              onCancel: () =>
                                  setState(() => _isEditing = false),
                              onSave: () {
                                // Logic to save can go here
                                setState(() => _isEditing = false);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Profile updated successfully!',
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                        ProfileSection(
                          key: _securityKey,
                          icon: Icons.security_outlined,
                          title: 'Security Settings',
                          child: const SecuritySettings(),
                        ),
                        const SizedBox(height: 24),
                        ProfileSection(
                          key: _supportKey,
                          icon: Icons.help_outline,
                          title: 'Support & Help',
                          child: const SupportSection(),
                        ),
                        const SizedBox(height: 24),
                        ProfileSection(
                          key: _preferencesKey,
                          icon: Icons.settings_suggest_outlined,
                          title: 'App Preferences',
                          child: const AppPreferences(),
                        ),
                        const SizedBox(height: 24),
                        DangerZoneSection(key: _dangerZoneKey),
                        const SizedBox(height: 100), // Space for bottom padding
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 280,
      color: Colors.white,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 24),
        children: [
          _buildSidebarItem(
            Icons.person_outline,
            'Personal Info',
            _personalInfoKey,
          ),
          _buildSidebarItem(Icons.security_outlined, 'Security', _securityKey),
          _buildSidebarItem(Icons.help_outline, 'Support', _supportKey),
          _buildSidebarItem(
            Icons.settings_suggest_outlined,
            'Preferences',
            _preferencesKey,
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(IconData icon, String title, GlobalKey key) {
    return ListTile(
      leading: Icon(icon, size: 20),
      title: Text(title, style: const TextStyle(fontSize: 14)),
      trailing: const Icon(Icons.chevron_right, size: 16),
      onTap: () => _scrollToSection(key),
    );
  }
}

// ── Traveler Stats Row ────────────────────────────────────────────────────
class _TravelerStatsRow extends ConsumerWidget {
  final String userId;
  const _TravelerStatsRow({required this.userId});

  String _memberTier(int trips) {
    if (trips >= 20) return '🥇 Gold';
    if (trips >= 10) return '🥈 Silver';
    if (trips >= 3) return '🥉 Bronze';
    return '🌱 Newbie';
  }

  Color _tierColor(int trips) {
    if (trips >= 20) return const Color(0xFFFF9800);
    if (trips >= 10) return const Color(0xFF9E9E9E);
    if (trips >= 3) return const Color(0xFF795548);
    return const Color(0xFF4CAF50);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(filteredBookingsProvider);
    final mine = all.where((b) => b.travelerId == userId).toList();
    final total = mine.length;
    final done = mine.where((b) => b.status == BookingStatus.completed).length;
    final pending = mine
        .where(
          (b) =>
              b.status == BookingStatus.pending ||
              b.status == BookingStatus.confirmed,
        )
        .length;
    final tier = _memberTier(total);
    final tierColor = _tierColor(total);

    return Row(
      children: [
        _StatCard(
          value: total.toString(),
          label: 'Total Trips',
          icon: Icons.luggage_rounded,
          color: AppColors.primary,
        ),
        const SizedBox(width: 10),
        _StatCard(
          value: done.toString(),
          label: 'Completed',
          icon: Icons.check_circle_rounded,
          color: const Color(0xFF22C55E),
        ),
        const SizedBox(width: 10),
        _StatCard(
          value: pending.toString(),
          label: 'Active',
          icon: Icons.pending_actions_rounded,
          color: const Color(0xFFF59E0B),
        ),
        const SizedBox(width: 10),
        _StatCard(
          value: tier,
          label: 'Member',
          icon: Icons.workspace_premium_rounded,
          color: tierColor,
          small: true,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;
  final bool small;
  const _StatCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withAlpha(25),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: color.withAlpha(40)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: color.withAlpha(25),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: small ? 11 : 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Profile Completeness Card ─────────────────────────────────────────────
class _ProfileCompletenessCard extends StatelessWidget {
  final User user;
  final VoidCallback onEdit;

  const _ProfileCompletenessCard({required this.user, required this.onEdit});

  int _completedFields() {
    int count = 0;
    if (user.name.isNotEmpty) count++;
    if (user.phone != null && user.phone!.isNotEmpty) count++;
    if (user.location != null && user.location!.isNotEmpty) count++;
    if (user.profileImage != null && user.profileImage!.isNotEmpty) count++;
    if (user.gender != null) count++;
    if (user.dateOfBirth != null) count++;
    return count;
  }

  @override
  Widget build(BuildContext context) {
    const total = 6;
    final completed = _completedFields();
    final percent = completed / total;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D47A1), Color(0xFF1976D2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1565C0).withAlpha(80),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(30),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.person_pin_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Complete Your Profile',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      '$completed of $total fields filled',
                      style: TextStyle(
                        color: Colors.white.withAlpha(180),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              // Percentage badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(30),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${(percent * 100).round()}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Progress bar
          Stack(
            children: [
              Container(
                height: 6,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(40),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              FractionallySizedBox(
                widthFactor: percent,
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withAlpha(120),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Missing fields chips
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (user.phone == null || user.phone!.isEmpty)
                _MissingChip(label: 'Phone'),
              if (user.location == null || user.location!.isEmpty)
                _MissingChip(label: 'Location'),
              if (user.profileImage == null || user.profileImage!.isEmpty)
                _MissingChip(label: 'Photo'),
              if (user.gender == null) _MissingChip(label: 'Gender'),
              if (user.dateOfBirth == null) _MissingChip(label: 'Birthday'),
            ],
          ),
          const SizedBox(height: 16),
          // CTA button
          GestureDetector(
            onTap: onEdit,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: const Text(
                'Complete Profile →',
                style: TextStyle(
                  color: Color(0xFF1565C0),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MissingChip extends StatelessWidget {
  final String label;
  const _MissingChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(25),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white38, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.add_circle_outline, color: Colors.white70, size: 12),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
