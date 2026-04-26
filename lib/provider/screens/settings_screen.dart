import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/services/settings_repository.dart';
import '../../shared/services/auth_service.dart';
import 'settings/payout_accounts_screen.dart';
import '../../shared/widgets/mfa_setup_dialog.dart';
import 'settings/transaction_history_screen.dart';
import 'settings/manage_helpers_screen.dart';
import 'settings/provider_pricing_settings_screen.dart';

class ProviderSettingsScreen extends ConsumerWidget {
  const ProviderSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final user = ref.watch(authProvider);
    final isHelper = user?.isProviderHelper ?? false;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Account Settings',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0D3B66),
              ),
            ),
            const SizedBox(height: 32),
            _buildSection('Notification Settings', [
              _buildSwitchTile(
                'Push Notifications',
                'Receive alerts for new bookings',
                Icons.notifications_none_outlined,
                settings.pushNotifications,
                (v) => notifier.updatePush(v),
              ),
              _buildSwitchTile(
                'Email Notifications',
                'Daily summary of activities',
                Icons.email_outlined,
                settings.emailNotifications,
                (v) => notifier.updateEmail(v),
              ),
              _buildSwitchTile(
                'SMS Notifications',
                'Instant alerts for cancellations',
                Icons.sms_outlined,
                settings.smsNotifications,
                (v) => notifier.updateSms(v),
              ),
            ]),
            const SizedBox(height: 24),
            _buildSection('Payments & Banking', [
              _buildNavigationTile(
                context,
                'Receiving Accounts',
                'Manage where you receive payments',
                Icons.account_balance_wallet_outlined,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PayoutAccountsScreen(),
                    ),
                  );
                },
              ),
              _buildNavigationTile(
                context,
                'Transaction History',
                'View automated payouts and earnings',
                Icons.history_outlined,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const TransactionHistoryScreen(),
                    ),
                  );
                },
              ),
            ]),
            const SizedBox(height: 24),
            _buildSection('Business & Pricing', [
              _buildNavigationTile(
                context,
                'Service Pricing',
                'Manage default fees for your listings',
                Icons.attach_money,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProviderPricingSettingsScreen(),
                    ),
                  );
                },
              ),
            ]),
            const SizedBox(height: 24),
            _buildSection('Security', [
              _buildSwitchTile(
                'Two-Factor Authentication',
                'Add an extra layer of security',
                Icons.security_outlined,
                ref.watch(authServiceProvider).isMFAEnabled,
                (v) async {
                  final auth = ref.read(authServiceProvider);
                  if (v) {
                    try {
                      final enrollment = await auth.enrollTOTP();
                      if (!context.mounted) return;
                      
                      final success = await showDialog<bool>(
                        context: context,
                        barrierDismissible: false,
                        builder: (context) => MFASetupDialog(
                          qrUri: enrollment.totp!.uri,
                          secret: enrollment.totp!.secret,
                          factorId: enrollment.id,
                        ),
                      );

                      if (success == true) {
                        notifier.update2FA(true);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Two-Factor Authentication enabled successfully'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to set up 2FA: $e'), backgroundColor: Colors.red),
                      );
                    }
                  } else {
                    final error = await auth.unenrollMFA();
                    if (!context.mounted) return;
                    if (error == null) {
                      notifier.update2FA(false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Two-Factor Authentication disabled')),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to disable 2FA: $error'), backgroundColor: Colors.red),
                      );
                    }
                  }
                },
              ),
              _buildNavigationTile(
                context,
                'Change Password',
                'Update your login credentials',
                Icons.lock_outline,
                onTap: () => _showChangePasswordDialog(context, ref),
              ),
              if (!isHelper)
                _buildNavigationTile(
                  context,
                  'Manage Helpers',
                  'Create limited access accounts',
                  Icons.group_add_outlined,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ManageHelpersScreen(),
                      ),
                    );
                  },
                ),
            ]),
            const SizedBox(height: 24),
            _buildSection('Language & Display', [
              _buildNavigationTile(
                context,
                'App Language',
                settings.language,
                Icons.language,
                onTap: () => _showLanguageSelector(context, ref),
              ),
              _buildNavigationTile(
                context,
                'Currency',
                settings.currency,
                Icons.attach_money,
                onTap: () => _showCurrencySelector(context, ref),
              ),
            ]),
            const SizedBox(height: 40),
            Center(
              child: Text(
                'SomSafar v1.0.0',
                style: TextStyle(color: Colors.grey[400], fontSize: 12),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8.0, bottom: 12.0),
          child: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
              fontSize: 13,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildSwitchTile(
    String title,
    String subtitle,
    IconData icon,
    bool value,
    Function(bool) onChanged,
  ) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 20, color: const Color(0xFF0D3B66)),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 15,
          color: Color(0xFF0D3B66),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 12, color: Colors.grey),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: AppColors.secondary,
        activeTrackColor: AppColors.secondary.withValues(alpha: 0.3),
      ),
    );
  }

  Widget _buildNavigationTile(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon, {
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 20, color: const Color(0xFF0D3B66)),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 15,
          color: Color(0xFF0D3B66),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 12, color: Colors.grey),
      ),
      trailing: const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
    );
  }

  void _showChangePasswordDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => _ProviderChangePasswordDialog(ref: ref),
    );
  }

  void _showLanguageSelector(BuildContext context, WidgetRef ref) {
    final languages = [
      'English (United States)',
      'Somali (Somalia)',
      'Arabic (Egypt)',
    ];
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: languages
            .map(
              (lang) => ListTile(
                title: Text(lang),
                onTap: () {
                  ref.read(settingsProvider.notifier).updateLanguage(lang);
                  Navigator.pop(context);
                },
              ),
            )
            .toList(),
      ),
    );
  }

  void _showCurrencySelector(BuildContext context, WidgetRef ref) {
    final currencies = [r'USD ($)', 'SOS (Somali Shilling)', 'EUR (€)'];
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: currencies
            .map(
              (curr) => ListTile(
                title: Text(curr),
                onTap: () {
                  ref.read(settingsProvider.notifier).updateCurrency(curr);
                  Navigator.pop(context);
                },
              ),
            )
            .toList(),
      ),
    );
  }
}

class _ProviderChangePasswordDialog extends StatefulWidget {
  final WidgetRef ref;
  const _ProviderChangePasswordDialog({required this.ref});

  @override
  State<_ProviderChangePasswordDialog> createState() => _ProviderChangePasswordDialogState();
}

class _ProviderChangePasswordDialogState extends State<_ProviderChangePasswordDialog> {
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _showCurrent = false;
  bool _showNew = false;
  bool _showConfirm = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Change Password'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _currentPasswordController,
              obscureText: !_showCurrent,
              decoration: InputDecoration(
                labelText: 'Current Password',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                suffixIcon: IconButton(
                  icon: Icon(_showCurrent ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _showCurrent = !_showCurrent),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _newPasswordController,
              obscureText: !_showNew,
              decoration: InputDecoration(
                labelText: 'New Password',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                suffixIcon: IconButton(
                  icon: Icon(_showNew ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _showNew = !_showNew),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _confirmPasswordController,
              obscureText: !_showConfirm,
              decoration: InputDecoration(
                labelText: 'Confirm New Password',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                suffixIcon: IconButton(
                  icon: Icon(_showConfirm ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _showConfirm = !_showConfirm),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading
              ? null
              : () async {
                  if (_newPasswordController.text != _confirmPasswordController.text) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Passwords do not match'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  setState(() => _isLoading = true);
                  final error = await widget.ref.read(authServiceProvider).changePassword(
                    currentPassword: _currentPasswordController.text,
                    newPassword: _newPasswordController.text,
                  );

                  if (!mounted) return;

                  if (error != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(error),
                        backgroundColor: Colors.red,
                      ),
                    );
                    setState(() => _isLoading = false);
                  } else {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Password updated successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.secondary,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Text('Update', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
