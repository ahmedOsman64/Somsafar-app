import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/user_model.dart';
import '../../shared/services/user_repository.dart';

class AdminEditUserScreen extends ConsumerStatefulWidget {
  final User user;
  const AdminEditUserScreen({super.key, required this.user});

  @override
  ConsumerState<AdminEditUserScreen> createState() =>
      _AdminEditUserScreenState();
}

class _AdminEditUserScreenState extends ConsumerState<AdminEditUserScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _locationController;
  late final TextEditingController _cleaningPriceController;
  late final TextEditingController _earlyCheckInPriceController;
  late final TextEditingController _lateCheckoutPriceController;
  late final TextEditingController _emailController;

  late UserRole _selectedRole;
  late UserStatus _selectedStatus;
  AdminRole? _selectedAdminRole;
  ProviderType? _selectedProviderType;
  TravelerType? _selectedTravelerType;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final u = widget.user;
    _nameController = TextEditingController(text: u.name);
    _phoneController = TextEditingController(text: u.phone ?? '');
    _locationController = TextEditingController(text: u.location ?? '');
    _cleaningPriceController = TextEditingController(
      text: u.metadata['cleaning_price']?.toString() ?? '0.0',
    );
    _earlyCheckInPriceController = TextEditingController(
      text: u.metadata['early_checkin_price']?.toString() ?? '0.0',
    );
    _lateCheckoutPriceController = TextEditingController(
      text: u.metadata['late_checkout_price']?.toString() ?? '0.0',
    );
    _emailController = TextEditingController(text: u.email);
    _selectedRole = u.role;
    _selectedStatus = u.status;
    _selectedAdminRole = u.adminRole;
    _selectedProviderType = u.providerType;
    _selectedTravelerType = u.travelerType;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    _cleaningPriceController.dispose();
    _earlyCheckInPriceController.dispose();
    _lateCheckoutPriceController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final newEmail = _emailController.text.trim();
    if (newEmail != widget.user.email) {
      final isRegistered = await ref.read(userProvider.notifier).isEmailRegistered(newEmail);
      if (isRegistered) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('This email has already been registered. Please use a different one.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        setState(() => _isSaving = false);
        return;
      }
    }

    try {
      final updated = widget.user.copyWith(
        name: _nameController.text.trim(),
        email: newEmail,
        phone: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        clearPhone: _phoneController.text.trim().isEmpty,
        location: _locationController.text.trim().isEmpty
            ? null
            : _locationController.text.trim(),
        clearLocation: _locationController.text.trim().isEmpty,
        role: _selectedRole,
        status: _selectedStatus,
        // Admin role: clear if not admin, set if admin
        adminRole: _selectedRole == UserRole.admin ? _selectedAdminRole : null,
        clearAdminRole: _selectedRole != UserRole.admin,
        // Provider type: clear if not provider, set if provider
        providerType: _selectedRole == UserRole.provider
            ? _selectedProviderType
            : null,
        clearProviderType: _selectedRole != UserRole.provider,
        // Traveler type: clear if switching away
        travelerType: _selectedRole == UserRole.traveler
            ? _selectedTravelerType
            : null,
        clearTravelerType: _selectedRole != UserRole.traveler,
        metadata: _selectedRole == UserRole.provider
            ? {
                ...widget.user.metadata,
                'cleaning_price':
                    double.tryParse(_cleaningPriceController.text) ?? 0.0,
                'early_checkin_price':
                    double.tryParse(_earlyCheckInPriceController.text) ?? 0.0,
                'late_checkout_price':
                    double.tryParse(_lateCheckoutPriceController.text) ?? 0.0,
              }
            : widget.user.metadata,
      );

      await ref.read(userProvider.notifier).updateUser(updated);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User updated successfully.'),
            backgroundColor: Colors.green,
          ),
        );
        context.go('/admin/users');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update user: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Edit User'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.primary,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.go('/admin/users'),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(32),
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: _selectedRole == UserRole.provider
                        ? Colors.teal
                        : _selectedRole == UserRole.admin
                        ? AppColors.primary
                        : Colors.blue,
                    child: Icon(
                      _selectedRole == UserRole.provider
                          ? Icons.store
                          : _selectedRole == UserRole.admin
                          ? Icons.admin_panel_settings
                          : Icons.person_outline,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.user.name,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                        ),
                        Text(
                          widget.user.email,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionHeader('Profile Information', Icons.person_outline),

                    _card([
                      _buildTextField(
                        controller: _nameController,
                        label: 'Full Name *',
                        icon: Icons.badge_outlined,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _emailController,
                        label: 'Email Address *',
                        icon: Icons.email_outlined,
                        inputType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _phoneController,
                        label: 'Phone Number',
                        icon: Icons.phone_outlined,
                        inputType: TextInputType.phone,
                        required: false,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _locationController,
                        label: 'Location / Address',
                        icon: Icons.location_on_outlined,
                        required: false,
                      ),
                    ]),

                    const SizedBox(height: 28),
                    _sectionHeader(
                      'Role & Permissions',
                      Icons.security_outlined,
                    ),

                    _card([
                      // Role selector
                      const Text(
                        'PORTAL ROLE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<UserRole>(
                          segments: const [
                            ButtonSegment(
                              value: UserRole.traveler,
                              label: Text('Traveler'),
                              icon: Icon(Icons.person_outline),
                            ),
                            ButtonSegment(
                              value: UserRole.provider,
                              label: Text('Provider'),
                              icon: Icon(Icons.store),
                            ),
                            ButtonSegment(
                              value: UserRole.admin,
                              label: Text('Admin'),
                              icon: Icon(Icons.admin_panel_settings),
                            ),
                          ],
                          selected: {_selectedRole},
                          onSelectionChanged: (s) => setState(() {
                            _selectedRole = s.first;
                            if (_selectedRole != UserRole.admin) {
                              _selectedAdminRole = null;
                            }
                            if (_selectedRole != UserRole.provider) {
                              _selectedProviderType = null;
                            }
                          }),
                          style: SegmentedButton.styleFrom(
                            selectedBackgroundColor: AppColors.primary,
                            selectedForegroundColor: Colors.white,
                            side: BorderSide(color: Colors.grey[300]!),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),

                      // Admin sub-role
                      if (_selectedRole == UserRole.admin) ...[
                        const SizedBox(height: 16),
                        DropdownButtonFormField<AdminRole>(
                          initialValue: _selectedAdminRole,
                          decoration: InputDecoration(
                            labelText: 'Admin Privileges',
                            prefixIcon: const Icon(Icons.shield_outlined),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          items: AdminRole.values
                              .map(
                                (ar) => DropdownMenuItem(
                                  value: ar,
                                  child: Text(_formatEnum(ar.name)),
                                ),
                              )
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _selectedAdminRole = v),
                          validator: (v) =>
                              v == null ? 'Select admin level' : null,
                        ),
                      ],

                      // Provider type
                      if (_selectedRole == UserRole.provider) ...[
                        const SizedBox(height: 16),
                        DropdownButtonFormField<ProviderType>(
                          initialValue: _selectedProviderType,
                          decoration: InputDecoration(
                            labelText: 'Provider Category',
                            prefixIcon: const Icon(Icons.category_outlined),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          items: ProviderType.values
                              .map(
                                (pt) => DropdownMenuItem(
                                  value: pt,
                                  child: Text(_formatEnum(pt.name)),
                                ),
                              )
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _selectedProviderType = v),
                        ),
                        if (_selectedRole == UserRole.provider) ...[
                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 16),
                          const Text(
                            'DEFAULT SERVICE PRICING',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                              letterSpacing: 1.1,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _buildTextField(
                                  controller: _cleaningPriceController,
                                  label: 'Cleaning Fee',
                                  icon: Icons.cleaning_services_outlined,
                                  inputType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  required: false,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _buildTextField(
                                  controller: _earlyCheckInPriceController,
                                  label: 'Early Check-in',
                                  icon: Icons.login_outlined,
                                  inputType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  required: false,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildTextField(
                                  controller: _lateCheckoutPriceController,
                                  label: 'Late Checkout',
                                  icon: Icons.logout_outlined,
                                  inputType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  required: false,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                      // Traveler type
                      if (_selectedRole == UserRole.traveler) ...[
                        const SizedBox(height: 16),
                        DropdownButtonFormField<TravelerType>(
                          initialValue: _selectedTravelerType,
                          decoration: InputDecoration(
                            labelText: 'Traveler Preference',
                            prefixIcon: const Icon(Icons.person_pin_outlined),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          items: TravelerType.values
                              .map(
                                (tt) => DropdownMenuItem(
                                  value: tt,
                                  child: Text(_formatEnum(tt.name)),
                                ),
                              )
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _selectedTravelerType = v),
                        ),
                      ],
                    ]),

                    const SizedBox(height: 28),
                    _sectionHeader('Account Status', Icons.toggle_on_outlined),

                    _card([
                      const Text(
                        'CURRENT STATUS',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<UserStatus>(
                          segments: [
                            ButtonSegment(
                              value: UserStatus.active,
                              label: const Text('Active'),
                              icon: const Icon(Icons.check_circle_outline),
                            ),
                            ButtonSegment(
                              value: UserStatus.suspended,
                              label: const Text('Suspended'),
                              icon: const Icon(Icons.pause_circle_outline),
                            ),
                            ButtonSegment(
                              value: UserStatus.blocked,
                              label: const Text('Blocked'),
                              icon: const Icon(Icons.block),
                            ),
                          ],
                          selected: {_selectedStatus},
                          onSelectionChanged: (s) =>
                              setState(() => _selectedStatus = s.first),
                          style: SegmentedButton.styleFrom(
                            selectedBackgroundColor: _statusColor(
                              _selectedStatus,
                            ),
                            selectedForegroundColor: Colors.white,
                            side: BorderSide(color: Colors.grey[300]!),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ]),

                    const SizedBox(height: 40),

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => context.go('/admin/users'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              side: BorderSide(color: Colors.grey[300]!),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: SizedBox(
                            height: 56,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 2,
                              ),
                              onPressed: _isSaving ? null : _save,
                              icon: _isSaving
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.save_outlined),
                              label: Text(
                                _isSaving ? 'Saving...' : 'Save Changes',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Divider(),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _card(List<Widget> children) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? inputType,
    bool required = true,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: inputType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.primary),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
      validator: required
          ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
          : null,
    );
  }

  Color _statusColor(UserStatus s) {
    switch (s) {
      case UserStatus.active:
        return Colors.green;
      case UserStatus.suspended:
        return Colors.orange;
      case UserStatus.blocked:
        return Colors.red;
    }
  }

  /// Converts camelCase enum name to 'Title Case'
  String _formatEnum(String name) {
    return name
        .replaceAllMapped(RegExp(r'([A-Z])'), (m) => ' ${m.group(0)}')
        .trim()
        .split(' ')
        .map((w) => w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }
}
