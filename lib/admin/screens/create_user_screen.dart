import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/user_model.dart';
import '../../shared/services/auth_service.dart';
import '../../shared/services/user_repository.dart';

class AdminCreateProviderScreen extends ConsumerStatefulWidget {
  final String? initialRole;
  const AdminCreateProviderScreen({super.key, this.initialRole});

  @override
  ConsumerState<AdminCreateProviderScreen> createState() =>
      _AdminCreateProviderScreenState();
}

class _AdminCreateProviderScreenState
    extends ConsumerState<AdminCreateProviderScreen> {
  final _formKey = GlobalKey<FormState>();

  // Role State
  late String _selectedRole;

  // Provider Info (Common)
  final _ownerNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  ProviderType? _selectedProviderType;
  TravelerType? _selectedTravelerType;
  AdminRole? _selectedAdminRole;
  final _locationController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.initialRole ?? 'Provider';
  }

  // Account & Auth State
  final _loginEmailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _statusLabel = 'Verified';

  @override
  void dispose() {
    _ownerNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _loginEmailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _generatePassword() {
    // simple mock generator
    _passwordController.text =
        "Prov${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}!";
    _confirmPasswordController.text = _passwordController.text;
  }

  bool _isCreating = false;

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isCreating = true);

      try {
        final authService = ref.read(authServiceProvider);

        // Prepare roles and types
        UserRole role = UserRole.provider;
        AdminRole? adminRole;
        ProviderType? providerType;
        TravelerType? travelerType;

        if (_selectedRole == 'Admin') {
          role = UserRole.admin;
          adminRole = _selectedAdminRole;
        } else if (_selectedRole == 'Provider') {
          role = UserRole.provider;
          providerType = _selectedProviderType;
        } else if (_selectedRole == 'Traveler') {
          role = UserRole.traveler;
          travelerType = _selectedTravelerType;
        }

        final emailToUse = _loginEmailController.text.trim().isNotEmpty
            ? _loginEmailController.text.trim()
            : _emailController.text.trim();

        // Check if email already exists
        final isRegistered = await ref.read(userProvider.notifier).isEmailRegistered(emailToUse);
        if (isRegistered) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: const [
                  Icon(Icons.error_outline, color: Colors.white),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'This email already exists.',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
          setState(() => _isCreating = false);
          return;
        }

        UserStatus status = UserStatus.active;
        if (_statusLabel == 'Suspended') {
          status = UserStatus.suspended;
        }

        final result = await authService.adminCreateUser(
          name: _ownerNameController.text.trim(),
          email: emailToUse,
          password: _passwordController.text,
          role: role,
          status: status,
          adminRole: adminRole,
          providerType: providerType,
          travelerType: travelerType,
          phone: _phoneController.text.trim(),
          location: _locationController.text.trim(),
          isVerified: _statusLabel == 'Verified',
        );

        if (result != null && result.containsKey('id')) {
          ref.invalidate(userProvider);
          _showSuccessDialog();
        } else {
          final error = result?['error'] ?? 'Unknown error';
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $error')));
        }
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Unexpected error: $e')));
      } finally {
        if (mounted) setState(() => _isCreating = false);
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle_outline,
              color: AppColors.secondary,
              size: 80,
            ),
            const SizedBox(height: 24),
            Text(
              'Successful Creation!',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'The $_selectedRole account has been successfully registered.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  // We no longer need to force login since we fixed the session jumping!
                  context.go('/admin/users');
                },
                child: const Text(
                  'Go to User List',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('New $_selectedRole Registration'),
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
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(32),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'PORTAL SETUP',
                    style: TextStyle(
                      color: AppColors.secondary,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create $_selectedRole Account',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Setup ${_selectedRole.toLowerCase()} profile and login credentials.',
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
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
                    _buildSectionHeader(
                      '1. Contact Information',
                      Icons.person_outline,
                    ),
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.grey[200]!),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            _buildTextField(
                              controller: _ownerNameController,
                              label: _selectedRole == 'Provider'
                                  ? 'Owner Full Name *'
                                  : 'Full Name *',
                              prefixIcon: Icons.person_outline,
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              controller: _emailController,
                              label: _selectedRole == 'Provider'
                                  ? 'Business Email *'
                                  : 'Email *',
                              inputType: TextInputType.emailAddress,
                              prefixIcon: Icons.email_outlined,
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              controller: _phoneController,
                              label: 'Phone Number *',
                              inputType: TextInputType.phone,
                              prefixIcon: Icons.phone_outlined,
                            ),
                            const SizedBox(height: 16),
                            if (_selectedRole == 'Provider') ...[
                              _buildTextField(
                                controller: _locationController,
                                label: 'Business Location',
                                prefixIcon: Icons.location_on_outlined,
                              ),
                              const SizedBox(height: 16),
                              DropdownButtonFormField<ProviderType>(
                                initialValue: _selectedProviderType,
                                decoration: InputDecoration(
                                  labelText:
                                      'Business Category / Provider Type *',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                ),
                                items: ProviderType.values
                                    .map(
                                      (p) => DropdownMenuItem(
                                        value: p,
                                        child: Text(p.name.toUpperCase()),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (val) =>
                                    setState(() => _selectedProviderType = val),
                                validator: (val) {
                                  if (_selectedRole == 'Provider' &&
                                      val == null) {
                                    return 'Select category';
                                  }
                                  return null;
                                },
                              ),
                            ],
                            if (_selectedRole == 'Traveler') ...[
                              const SizedBox(height: 16),
                              DropdownButtonFormField<TravelerType>(
                                initialValue: _selectedTravelerType,
                                decoration: InputDecoration(
                                  labelText: 'Traveler Profile Type',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                ),
                                items: TravelerType.values
                                    .map(
                                      (t) => DropdownMenuItem(
                                        value: t,
                                        child: Text(t.name.toUpperCase()),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (val) =>
                                    setState(() => _selectedTravelerType = val),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    _buildSectionHeader(
                      '2. System Login & Status',
                      Icons.security_outlined,
                    ),
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.grey[200]!),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            _buildTextField(
                              controller: _loginEmailController,
                              label:
                                  'Username / Portal ID (will be @somsafarbooking.com) *',
                              prefixIcon: Icons.alternate_email,
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildPasswordField(
                                    controller: _passwordController,
                                    label: 'Temporary Password *',
                                    obscure: _obscurePassword,
                                    onToggle: () => setState(
                                      () =>
                                          _obscurePassword = !_obscurePassword,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton.filled(
                                  onPressed: _generatePassword,
                                  icon: const Icon(Icons.refresh),
                                  style: IconButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                  ),
                                  tooltip: 'Generate Password',
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _buildPasswordField(
                              controller: _confirmPasswordController,
                              label: 'Confirm Password *',
                              obscure: _obscureConfirmPassword,
                              onToggle: () => setState(
                                () => _obscureConfirmPassword =
                                    !_obscureConfirmPassword,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildSectionHeader(
                      'Permission & Verification',
                      Icons.settings_suggest_outlined,
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Portal Role',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(
                                value: 'Traveler',
                                label: Text('Traveler'),
                                icon: Icon(Icons.person_outline),
                              ),
                              ButtonSegment(
                                value: 'Provider',
                                label: Text('Provider'),
                                icon: Icon(Icons.store),
                              ),
                              ButtonSegment(
                                value: 'Admin',
                                label: Text('Admin'),
                                icon: Icon(Icons.admin_panel_settings),
                              ),
                            ],
                            selected: {_selectedRole},
                            onSelectionChanged: (Set<String> newSelection) {
                              setState(() {
                                _selectedRole = newSelection.first;
                                if (_selectedRole == 'Provider') {
                                  _selectedAdminRole = null;
                                }
                              });
                            },
                            style: SegmentedButton.styleFrom(
                              selectedBackgroundColor: AppColors.primary,
                              selectedForegroundColor: Colors.white,
                              side: BorderSide(color: Colors.grey[300]!),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Initial Status',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          initialValue: _statusLabel,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                          ),
                          items: ['Pending', 'Verified', 'Suspended']
                              .map(
                                (s) =>
                                    DropdownMenuItem(value: s, child: Text(s)),
                              )
                              .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _statusLabel = val;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                    if (_selectedRole == 'Admin') ...[
                      const SizedBox(height: 16),
                      DropdownButtonFormField<AdminRole>(
                        initialValue: _selectedAdminRole,
                        decoration: const InputDecoration(
                          labelText: 'Admin Privileges',
                          border: OutlineInputBorder(),
                        ),
                        items: AdminRole.values
                            .map(
                              (ar) => DropdownMenuItem(
                                value: ar,
                                child: Text(ar.name),
                              ),
                            )
                            .toList(),
                        onChanged: (val) =>
                            setState(() => _selectedAdminRole = val),
                        validator: (val) => val == null ? 'Select level' : null,
                      ),
                    ],
                    const SizedBox(height: 48),
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
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 2,
                              ),
                              onPressed: _isCreating ? null : _submit,
                              child: _isCreating
                                  ? const CircularProgressIndicator(
                                      color: Colors.white,
                                    )
                                  : Text(
                                      'Create & Activate',
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
                    const SizedBox(height: 60),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, [IconData? icon]) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
            ],
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    TextInputType? inputType,
    int maxLines = 1,
    IconData? prefixIcon,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, color: AppColors.primary)
            : null,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
      keyboardType: inputType,
      maxLines: maxLines,
      validator: (val) {
        if (label.contains('*') && (val == null || val.isEmpty)) {
          return 'Required';
        }
        return null;
      },
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: IconButton(
          icon: Icon(obscure ? Icons.visibility : Icons.visibility_off),
          onPressed: onToggle,
        ),
      ),
      validator: (val) {
        if (val == null || val.isEmpty) {
          return 'Required';
        }
        if (val.length < 8) {
          return 'Too short';
        }
        return null;
      },
    );
  }
}
