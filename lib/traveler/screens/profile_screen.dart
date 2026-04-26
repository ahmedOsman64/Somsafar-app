import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/responsive.dart';
import '../../shared/services/auth_service.dart';
import 'profile/widgets/profile_widgets.dart';

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
                      isVerified: true,
                      onEdit: () {
                        setState(() => _isEditing = true);
                        _scrollToSection(_personalInfoKey);
                      },
                      onSettings: () => _scrollToSection(_preferencesKey),
                    ),
                    const SizedBox(height: 24),
                    if (_isEditing) ...[
                      ProfileSection(
                        key: _personalInfoKey,
                        icon: Icons.person_outline,
                        title: 'Personal Information',
                        child: PersonalInfoForm(
                          onCancel: () => setState(() => _isEditing = false),
                          onSave: () {
                            // Logic to save can go here
                            setState(() => _isEditing = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Profile updated successfully!'),
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
