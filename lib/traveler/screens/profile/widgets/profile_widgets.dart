import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart';
import 'dart:io' as io;
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/services/auth_service.dart';
import '../../../../shared/services/system_activity_repository.dart';
import '../../../../shared/services/settings_repository.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../shared/models/user_model.dart';
import '../../../../core/providers/localization_provider.dart';


class ProfileHeader extends StatelessWidget {
  final String name;
  final String email;
  final String? profileImage;
  final DateTime memberSince;
  final bool isVerified;
  final VoidCallback onEdit;
  final VoidCallback onSettings;

  const ProfileHeader({
    super.key,
    required this.name,
    required this.email,
    this.profileImage,
    required this.memberSince,
    this.isVerified = false,
    required this.onEdit,
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isSmall = constraints.maxWidth < 600;

          return Padding(
            padding: const EdgeInsets.all(20),
            child: isSmall
                ? Column(
                    children: [
                      _buildAvatar(60),
                      const SizedBox(height: 16),
                      _buildProfileInfo(true),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildEditButton(),
                          const SizedBox(width: 12),
                          _buildSettingsIcon(),
                        ],
                      ),
                    ],
                  )
                : Row(
                    children: [
                      _buildAvatar(40),
                      const SizedBox(width: 20),
                      Expanded(child: _buildProfileInfo(false)),
                      const SizedBox(width: 20),
                      _buildActionColumn(),
                    ],
                  ),
          );
        },
      ),
    );
  }

  Widget _buildAvatar(double radius) {
    return Stack(
      children: [
        CircleAvatar(
          radius: radius,
          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
          backgroundImage: profileImage != null && profileImage!.isNotEmpty
              ? NetworkImage(StorageService.ensurePublicUrl(profileImage!))
              : null,
          child: (profileImage == null || profileImage!.isEmpty)
              ? Icon(Icons.person, size: radius, color: AppColors.primary)
              : null,
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileInfo(bool isCentered) {
    return Column(
      crossAxisAlignment: isCentered
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                name,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isVerified) ...[
              const SizedBox(width: 8),
              const Icon(Icons.verified, size: 18, color: Colors.blue),
            ],
          ],
        ),
        Text(
          email,
          style: TextStyle(color: Colors.grey.shade600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: isCentered ? TextAlign.center : TextAlign.start,
        ),
        const SizedBox(height: 4),
        Text(
          'Member since ${memberSince.year}',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          textAlign: isCentered ? TextAlign.center : TextAlign.start,
        ),
      ],
    );
  }

  Widget _buildActionColumn() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [_buildEditButton(), _buildSettingsIcon()],
    );
  }

  Widget _buildEditButton() {
    return OutlinedButton.icon(
      onPressed: onEdit,
      icon: const Icon(Icons.edit, size: 16),
      label: const Text('Edit Profile'),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.primary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildSettingsIcon() {
    return IconButton(
      onPressed: onSettings,
      icon: const Icon(Icons.settings_outlined),
      color: Colors.grey,
    );
  }
}

class OverviewCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const OverviewCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;

  const SectionTitle({super.key, required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class ProfileSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  const ProfileSection({
    super.key,
    required this.icon,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(icon: icon, title: title),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: child,
        ),
      ],
    );
  }
}

class PersonalInfoForm extends ConsumerStatefulWidget {
  final VoidCallback? onCancel;
  final VoidCallback? onSave;

  const PersonalInfoForm({super.key, this.onCancel, this.onSave});

  @override
  ConsumerState<PersonalInfoForm> createState() => _PersonalInfoFormState();
}

class _PersonalInfoFormState extends ConsumerState<PersonalInfoForm> {
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _locationController;
  late TextEditingController _dobController;
  Gender? _gender;
  bool _isSaving = false;
  XFile? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider);
    _nameController = TextEditingController(text: user?.name ?? '');

    // Gracefully handle 'ENCRYPTED' placeholder from database
    final displayPhone = (user?.phone == 'ENCRYPTED')
        ? ''
        : (user?.phone ?? '');
    _phoneController = TextEditingController(text: displayPhone);

    _locationController = TextEditingController(text: user?.location ?? '');
    _dobController = TextEditingController(
      text: user?.createdAt != null
          ? user!.createdAt.toString().split(' ').first
          : DateTime.now().toString().split(' ').first,
    );
    _gender = user?.gender;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 75,
      );
      if (image != null) {
        setState(() {
          _selectedImage = image;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error picking image: $e')));
      }
    }
  }

  Future<void> _handleSave() async {
    setState(() => _isSaving = true);

    String? imageUrl;
    if (_selectedImage != null) {
      try {
        imageUrl = await StorageService.uploadImage(
          _selectedImage!,
          folder: 'profiles',
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to upload image: $e')));
        }
      }
    }

    final error = await ref
        .read(authServiceProvider)
        .updateProfile(
          name: _nameController.text,
          phone: _phoneController.text,
          location: _locationController.text,
          dateOfBirth: DateTime.tryParse(_dobController.text),
          gender: _gender,
          profileImage: imageUrl,
        );

    if (mounted) {
      setState(() => _isSaving = false);
      if (error == null) {
        widget.onSave?.call();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $error'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    return Column(
      children: [
        Center(
          child: Stack(
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                backgroundImage: _selectedImage != null
                    ? (kIsWeb
                          ? NetworkImage(_selectedImage!.path)
                          : FileImage(io.File(_selectedImage!.path))
                                as ImageProvider)
                    : (user?.profileImage != null &&
                              user!.profileImage!.isNotEmpty
                          ? NetworkImage(
                              StorageService.ensurePublicUrl(
                                user.profileImage!,
                              ),
                            )
                          : null),
                child:
                    _selectedImage == null &&
                        (user?.profileImage == null ||
                            user!.profileImage!.isEmpty)
                    ? const Icon(
                        Icons.person,
                        size: 50,
                        color: AppColors.primary,
                      )
                    : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        _buildTextField('Full Name', _nameController),
        const SizedBox(height: 16),
        _buildTextField(
          'Email',
          TextEditingController(text: user?.email ?? ''),
          enabled: false,
        ),
        const SizedBox(height: 16),
        _buildTextField('Phone', _phoneController),
        const SizedBox(height: 16),
        _buildDropdown('Gender', _gender, (v) => setState(() => _gender = v)),
        const SizedBox(height: 16),
        _buildTextField('Location', _locationController),
        const SizedBox(height: 16),
        _buildTextField(
          'Member Since',
          _dobController,
          readOnly: true,
          enabled: false,
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _isSaving ? null : widget.onCancel,
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                onPressed: _isSaving ? null : _handleSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Save Changes'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    bool enabled = true,
    bool readOnly = false,
    VoidCallback? onTap,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      readOnly: readOnly,
      onTap: onTap,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
    );
  }

  Widget _buildDropdown(
    String label,
    Gender? value,
    Function(Gender?) onChanged,
  ) {
    return DropdownButtonFormField<Gender>(
      initialValue: value,
      onChanged: onChanged,
      items: const [
        DropdownMenuItem(value: Gender.male, child: Text('Male')),
        DropdownMenuItem(value: Gender.female, child: Text('Female')),
      ],
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Change Password Dialog
// ---------------------------------------------------------------------------
class _ChangePasswordDialog extends StatefulWidget {
  final WidgetRef ref;
  const _ChangePasswordDialog({required this.ref});

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _showCurrent = false;
  bool _showNew = false;
  bool _showConfirm = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final error = await widget.ref
        .read(authServiceProvider)
        .changePassword(
          currentPassword: _currentCtrl.text,
          newPassword: _newCtrl.text,
        );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Get current user name for the admin notification
    final currentUser = widget.ref.read(authProvider);
    final userName = currentUser?.name ?? currentUser?.email ?? 'Unknown User';

    // Log to admin activity (name only — password is NOT included)
    widget.ref.read(activityProvider.notifier).logPasswordChange(userName);

    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Password changed successfully!'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lock_reset,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'Change Password',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ],
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width > 500 ? 400 : double.infinity,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildPasswordField(
                controller: _currentCtrl,
                label: 'Current Password',
                show: _showCurrent,
                onToggle: () => setState(() => _showCurrent = !_showCurrent),
                validator: (v) => (v == null || v.isEmpty)
                    ? 'Enter your current password'
                    : null,
              ),
              const SizedBox(height: 16),
              _buildPasswordField(
                controller: _newCtrl,
                label: 'New Password',
                show: _showNew,
                onToggle: () => setState(() => _showNew = !_showNew),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Enter a new password';
                  if (v.length < 8) return 'Must be at least 8 characters';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _buildPasswordField(
                controller: _confirmCtrl,
                label: 'Confirm New Password',
                show: _showConfirm,
                onToggle: () => setState(() => _showConfirm = !_showConfirm),
                validator: (v) {
                  if (v == null || v.isEmpty) {
                    return 'Please confirm your new password';
                  }
                  if (v != _newCtrl.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Change Password'),
        ),
      ],
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool show,
    required VoidCallback onToggle,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: !show,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        suffixIcon: IconButton(
          icon: Icon(show ? Icons.visibility_off : Icons.visibility, size: 20),
          onPressed: onToggle,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
class SecuritySettings extends ConsumerWidget {
  const SecuritySettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);
    final settings = ref.watch(settingsProvider);

    String lastChangedText = 'Last changed recently';
    if (user?.metadata['last_password_change'] != null) {
      try {
        final lastChanged = DateTime.parse(
          user!.metadata['last_password_change'],
        );
        lastChangedText = _formatTimeAgo(lastChanged);
      } catch (_) {}
    } else if (user?.updatedAt != null) {
      lastChangedText = _formatTimeAgo(user!.updatedAt!);
    }

    return Column(
      children: [
        _buildSecurityItem(
          Icons.lock_outline,
          'Change Password',
          lastChangedText,
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () {
            showDialog(
              context: context,
              builder: (dialogContext) => _ChangePasswordDialog(ref: ref),
            );
          },
        ),
        const Divider(height: 32),
        _buildSecurityItem(
          Icons.vibration,
          'Two-Factor Authentication',
          'Secure your account with 2FA',
          trailing: Switch(
            value: settings.twoFactorAuth,
            onChanged: (val) {
              ref.read(settingsProvider.notifier).update2FA(val);
            },
            activeThumbColor: AppColors.secondary,
            activeTrackColor: AppColors.secondary.withValues(alpha: 0.5),
          ),
          onTap: () {
            ref
                .read(settingsProvider.notifier)
                .update2FA(!settings.twoFactorAuth);
          },
        ),
        const Divider(height: 32),
        _buildSecurityItem(
          Icons.history,
          'Login Activity',
          'View your recent login history',
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Viewing Login Activity...'),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                backgroundColor: AppColors.primary,
              ),
            );
          },
        ),
      ],
    );
  }

  String _formatTimeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 365) {
      final years = (diff.inDays / 365).floor();
      return 'Last changed $years year${years > 1 ? 's' : ''} ago';
    } else if (diff.inDays > 30) {
      final months = (diff.inDays / 30).floor();
      return 'Last changed $months month${months > 1 ? 's' : ''} ago';
    } else if (diff.inDays > 0) {
      return 'Last changed ${diff.inDays} day${diff.inDays > 1 ? 's' : ''} ago';
    } else if (diff.inHours > 0) {
      return 'Last changed ${diff.inHours} hour${diff.inHours > 1 ? 's' : ''} ago';
    } else if (diff.inMinutes > 0) {
      return 'Last changed ${diff.inMinutes} minute${diff.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Last changed just now';
    }
  }

  Widget _buildSecurityItem(
    IconData icon,
    String title,
    String subtitle, {
    required Widget trailing,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Row(
          children: [
            Icon(icon, color: Colors.grey.shade600),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
}

// Support widgets have been moved to shared widgets.

class AppPreferences extends ConsumerWidget {
  const AppPreferences({super.key});

  void _showLanguageSelector(BuildContext context, WidgetRef ref, AppLocalizations loc) {
    final settings = ref.read(settingsProvider);
    final languages = [
      {'name': 'English (United States)', 'code': 'English (United States)', 'display': 'English (US)', 'flag': '🇺🇸'},
      {'name': 'Somali (Somalia)', 'code': 'Somali (Somalia)', 'display': 'Af Soomaali', 'flag': '🇸🇴'},
      {'name': 'Arabic (Saudi Arabia)', 'code': 'Arabic (Saudi Arabia)', 'display': 'العربية', 'flag': '🇸🇦'},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    loc.translate('select_language'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.dark,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...languages.map((lang) {
                final isSelected = settings.language == lang['code'];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary.withValues(alpha: 0.08) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : Colors.grey.shade200,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: Text(
                      lang['flag']!,
                      style: const TextStyle(fontSize: 24),
                    ),
                    title: Text(
                      lang['display']!,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? AppColors.primary : AppColors.dark,
                      ),
                    ),
                    subtitle: Text(
                      lang['name']!,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle_rounded, color: AppColors.primary)
                        : null,
                    onTap: () {
                      ref.read(settingsProvider.notifier).updateLanguage(lang['code']!);
                      Navigator.pop(context);
                    },
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  void _showCurrencySelector(BuildContext context, WidgetRef ref, AppLocalizations loc) {
    final settings = ref.read(settingsProvider);
    final currencies = [
      {'name': 'USD (\$)', 'code': r'USD ($)', 'display': 'US Dollar', 'symbol': '\$'},
      {'name': 'SOS (Somali Shilling)', 'code': 'SOS (Somali Shilling)', 'display': 'Shilin Soomaali', 'symbol': 'Sh.so.'},
      {'name': 'EUR (€)', 'code': 'EUR (€)', 'display': 'Euro', 'symbol': '€'},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    loc.translate('select_currency'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.dark,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...currencies.map((curr) {
                final isSelected = settings.currency == curr['code'];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary.withValues(alpha: 0.08) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : Colors.grey.shade200,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary.withValues(alpha: 0.12) : Colors.grey.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        curr['symbol']!,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isSelected ? AppColors.primary : Colors.grey.shade700,
                        ),
                      ),
                    ),
                    title: Text(
                      curr['display']!,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? AppColors.primary : AppColors.dark,
                      ),
                    ),
                    subtitle: Text(
                      curr['name']!,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle_rounded, color: AppColors.primary)
                        : null,
                    onTap: () {
                      ref.read(settingsProvider.notifier).updateCurrency(curr['code']!);
                      Navigator.pop(context);
                    },
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final loc = ref.watch(localizationProvider);

    String displayLang = settings.language;
    if (settings.language.toLowerCase().contains('somali')) {
      displayLang = 'Af Soomaali 🇸🇴';
    } else if (settings.language.toLowerCase().contains('arabic')) {
      displayLang = 'العربية 🇸🇦';
    } else {
      displayLang = 'English (US) 🇺🇸';
    }

    return Column(
      children: [
        _buildPreferenceItem(
          Icons.language,
          loc.translate('language'),
          displayLang,
          onTap: () => _showLanguageSelector(context, ref, loc),
        ),
        const Divider(height: 32),
        _buildPreferenceItem(
          Icons.attach_money,
          loc.translate('currency'),
          settings.currency,
          onTap: () => _showCurrencySelector(context, ref, loc),
        ),
        const Divider(height: 32),
        _buildPreferenceItem(
          Icons.notifications_active_outlined,
          loc.translate('push_notifications'),
          settings.pushNotifications ? loc.translate('enabled') : loc.translate('disabled'),
          trailing: Switch(
            value: settings.pushNotifications,
            onChanged: (val) {
              ref.read(settingsProvider.notifier).updatePush(val);
            },
            activeThumbColor: AppColors.secondary,
            activeTrackColor: AppColors.secondary.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }

  Widget _buildPreferenceItem(
    IconData icon,
    String title,
    String subtitle, {
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Colors.grey.shade700, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
      ),
      trailing:
          trailing ??
          const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
      onTap: onTap,
    );
  }
}

class DangerZoneSection extends ConsumerWidget {
  const DangerZoneSection({super.key});

  void _showConfirmationDialog({
    required BuildContext context,
    required String title,
    required String content,
    required String confirmLabel,
    Color confirmColor = AppColors.error,
    required VoidCallback onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(content),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Expanded(
          child: _buildActionCard(
            context: context,
            icon: Icons.logout,
            title: 'Log Out',
            subtitle: 'Sign out securely',
            color: Colors.orange.shade800,
            bgColor: Colors.orange.shade50.withValues(alpha: 0.5),
            borderColor: Colors.orange.shade200,
            onTap: () => _showConfirmationDialog(
              context: context,
              title: 'Log Out?',
              content: 'Are you sure you want to log out of your account?',
              confirmLabel: 'Log Out',
              confirmColor: Colors.orange.shade600,
              onConfirm: () async {
                // Navigate to splash/login and clear state
                await ref.read(authServiceProvider).logout();
                if (context.mounted) context.go('/login');
              },
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildActionCard(
            context: context,
            icon: Icons.delete_outline,
            title: 'Delete Account',
            subtitle: 'Remove your data',
            color: Colors.red.shade700,
            bgColor: Colors.red.shade50.withValues(alpha: 0.5),
            borderColor: Colors.red.shade200,
            onTap: () {
              final currentUser = ref.read(authProvider);
              if (currentUser == null) return;

              _showDeleteAccountDialog(context, ref);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required Color bgColor,
    required Color borderColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: color.withValues(alpha: 0.7),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _DeleteAccountDialog(ref: ref),
    );
  }
}

class _DeleteAccountDialog extends StatefulWidget {
  final WidgetRef ref;
  const _DeleteAccountDialog({required this.ref});

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _reasonController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Delete Account',
        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This action is permanent and cannot be undone. Please read the following conditions:',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 16),
              _buildConditionItem(
                'All your profile data will be permanently deleted.',
              ),
              _buildConditionItem(
                'Your current active bookings will be cancelled.',
              ),
              _buildConditionItem(
                'You will not be able to recover this account.',
              ),
              const SizedBox(height: 20),
              const Text(
                'Please tell us why you are deleting your account:',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _reasonController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Type your reason here...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Please provide a reason'
                    : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _handleDelete,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Confirm and Delete'),
        ),
      ],
    );
  }

  Widget _buildConditionItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, size: 16, color: Colors.red),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  Future<void> _handleDelete() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final error = await widget.ref
        .read(authServiceProvider)
        .deleteAccount(_reasonController.text.trim());

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.red),
      );
    } else {
      context.go('/login');
    }
  }
}
