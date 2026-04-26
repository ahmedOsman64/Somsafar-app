import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/services/auth_service.dart';
import '../../../shared/services/user_repository.dart';

class ProviderPricingSettingsScreen extends ConsumerStatefulWidget {
  const ProviderPricingSettingsScreen({super.key});

  @override
  ConsumerState<ProviderPricingSettingsScreen> createState() =>
      _ProviderPricingSettingsScreenState();
}

class _ProviderPricingSettingsScreenState
    extends ConsumerState<ProviderPricingSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _cleaningController;
  late TextEditingController _earlyCheckinController;
  late TextEditingController _lateCheckoutController;
  late TextEditingController _basePriceController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider);
    _cleaningController = TextEditingController(
      text: user?.metadata['cleaning_price']?.toString() ?? '',
    );
    _earlyCheckinController = TextEditingController(
      text: user?.metadata['early_checkin_price']?.toString() ?? '',
    );
    _lateCheckoutController = TextEditingController(
      text: user?.metadata['late_checkout_price']?.toString() ?? '',
    );
    _basePriceController = TextEditingController(
      text: user?.metadata['default_base_price']?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _cleaningController.dispose();
    _earlyCheckinController.dispose();
    _lateCheckoutController.dispose();
    _basePriceController.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = ref.read(authProvider);
      if (user == null) return;

      final updatedMetadata = Map<String, dynamic>.from(user.metadata);
      updatedMetadata['cleaning_price'] =
          double.tryParse(_cleaningController.text) ?? 0.0;
      updatedMetadata['early_checkin_price'] =
          double.tryParse(_earlyCheckinController.text) ?? 0.0;
      updatedMetadata['late_checkout_price'] =
          double.tryParse(_lateCheckoutController.text) ?? 0.0;
      updatedMetadata['default_base_price'] =
          double.tryParse(_basePriceController.text) ?? 0.0;

      final updatedUser = user.copyWith(metadata: updatedMetadata);
      await ref.read(userProvider.notifier).updateUser(updatedUser);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pricing settings updated successfully')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating settings: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Service Pricing'),
        actions: [
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _saveSettings,
              child: const Text('SAVE', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    Icon(Icons.info_outline, size: 48, color: Colors.blue),
                    SizedBox(height: 16),
                    Text(
                      'Default Service Prices',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'These prices will be applied to all your services if they don\'t have a specific price set. Travelers will see these fees during the booking process.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _basePriceController,
              decoration: const InputDecoration(
                labelText: 'Qiimaha Asaasiga ah (Default Base Price) (\$)',
                prefixIcon: Icon(Icons.attach_money),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              validator: (v) =>
                  v == null || v.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _cleaningController,
              decoration: const InputDecoration(
                labelText: 'Lacagta Nadaafadda (Default Cleaning Fee) (\$)',
                prefixIcon: Icon(Icons.cleaning_services),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              validator: (v) =>
                  v == null || v.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _earlyCheckinController,
              decoration: const InputDecoration(
                labelText: 'Soo Galista Hore (Default Early Check-in) (\$)',
                prefixIcon: Icon(Icons.wb_sunny_outlined),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              validator: (v) =>
                  v == null || v.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _lateCheckoutController,
              decoration: const InputDecoration(
                labelText: 'Ka Bixista Dib u Dhacday (Default Late Checkout) (\$)',
                prefixIcon: Icon(Icons.nightlight_outlined),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              validator: (v) =>
                  v == null || v.isEmpty ? 'Required' : null,
            ),
          ],
        ),
      ),
    );
  }
}
