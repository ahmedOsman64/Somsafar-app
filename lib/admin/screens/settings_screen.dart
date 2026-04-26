import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/services/system_settings_repository.dart';
import '../../shared/widgets/confirmation_dialog.dart';

class AdminSettingsScreen extends ConsumerWidget {
  const AdminSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(systemSettingsProvider);
    final settingsNotifier = ref.read(systemSettingsProvider.notifier);

    return Scaffold(
      body: Column(
        children: [
          // Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            color: AppColors.primaryDark,
            alignment: Alignment.center,
            child: const Text(
              'System Configuration',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
                letterSpacing: 0.5,
              ),
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              children: [
                _buildSectionTitle('General Settings'),
                _buildSettingItem(
                  icon: Icons.warning_amber_outlined,
                  title: 'Maintenance Mode',
                  subtitle: 'Prevent users from making new bookings',
                  trailing: Switch(
                    value: settings.maintenanceMode,
                    activeThumbColor: AppColors.primary,
                    onChanged: (val) async {
                      final confirmed = await ConfirmationDialog.show(
                        context: context,
                        title: 'Confirm Operation',
                        message: val
                            ? 'Are you sure you want to ENABLE Maintenance Mode? This will prevent users from making new bookings.'
                            : 'Disable Maintenance Mode and resume normal operations?',
                        confirmLabel: val ? 'Enable' : 'Disable',
                        type: val
                            ? ConfirmationDialogType.warning
                            : ConfirmationDialogType.info,
                        icon: Icons.warning_amber_outlined,
                      );
                      if (confirmed == true) {
                        settingsNotifier.updateMaintenanceMode(val);
                      }
                    },
                  ),
                ),
                _buildSettingItem(
                  icon: Icons.notifications_none_outlined,
                  title: 'System Email Notifications',
                  subtitle: 'Send automatic emails for system events',
                  trailing: Switch(
                    value: settings.systemEmailNotifications,
                    activeThumbColor: AppColors.primary,
                    onChanged: (val) =>
                        settingsNotifier.updateSystemEmailNotifications(val),
                  ),
                ),

                _buildSectionTitle('Financial Configuration'),
                _buildSettingItem(
                  icon: Icons.percent_outlined,
                  title: 'Platform Fee (%)',
                  subtitle: 'Current fee: ${settings.platformFee}%',
                  onTap: () =>
                      _showFeeDialog(context, ref, settings.platformFee),
                ),
                _buildSettingItem(
                  icon: Icons.currency_exchange_outlined,
                  title: 'Base Currency',
                  subtitle: 'Current: ${settings.baseCurrency}',
                  backgroundColor: Colors.grey[100],
                  onTap: () =>
                      _showCurrencyDialog(context, ref, settings.baseCurrency),
                ),


                _buildSectionTitle('Security'),
                _buildSettingItem(
                  icon: Icons.lock_outline,
                  title: 'Admin Password Policy',
                  subtitle: 'Manage complexity requirements',
                  onTap: () {},
                ),

                const SizedBox(height: 40),
                const Divider(),
                const SizedBox(height: 16),
                Center(
                  child: Column(
                    children: [
                      Text(
                        'SomSafar Admin Portal',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Version 1.2.4 (Build 45) • Enterprise Edition',
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF4A6982),
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    Color? backgroundColor,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Icon(icon, color: const Color(0xFF4A6982), size: 28),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            color: Color(0xFF333333),
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        trailing:
            trailing ??
            const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
        onTap: onTap,
      ),
    );
  }

  void _showFeeDialog(BuildContext context, WidgetRef ref, double currentFee) {
    final controller = TextEditingController(text: currentFee.toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Platform Fee (%)'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(suffixText: '%'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final val = double.tryParse(controller.text);
              if (val != null) {
                final confirmed = await ConfirmationDialog.show(
                  context: context,
                  title: 'Update Platform Fee?',
                  message: 'Confirm Action: Do you want to update the platform fee to $val%?',
                  confirmLabel: 'Yes, Update',
                  type: ConfirmationDialogType.info,
                  icon: Icons.percent_outlined,
                );
                if (confirmed == true) {
                  ref
                      .read(systemSettingsProvider.notifier)
                      .updatePlatformFee(val);
                  if (context.mounted) Navigator.pop(context);
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showCurrencyDialog(
    BuildContext context,
    WidgetRef ref,
    String current,
  ) {
    final currencies = ['USD', 'EUR', 'GBP', 'AED', 'SOS'];
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Select Base Currency'),
        children: currencies
            .map(
              (c) => SimpleDialogOption(
                onPressed: () async {
                  final confirmed = await ConfirmationDialog.show(
                    context: context,
                    title: 'Change Base Currency?',
                    message: 'Confirm Action: Do you want to change the system base currency to $c?',
                    confirmLabel: 'Yes, Change',
                    type: ConfirmationDialogType.info,
                    icon: Icons.currency_exchange_outlined,
                  );
                  if (confirmed == true) {
                    ref
                        .read(systemSettingsProvider.notifier)
                        .updateBaseCurrency(c);
                    if (context.mounted) Navigator.pop(context);
                  }
                },
                child: Row(
                  children: [
                    Text(
                      c,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    if (c == current) ...[
                      const Spacer(),
                      const Icon(Icons.check, color: AppColors.primary),
                    ],
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

}
