import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../shared/models/payment_account_model.dart';
import '../../../shared/services/auth_service.dart';
import '../../../shared/services/user_repository.dart';
import '../../../shared/services/system_activity_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/confirmation_dialog.dart';

class PayoutAccountsScreen extends ConsumerStatefulWidget {
  const PayoutAccountsScreen({super.key});

  @override
  ConsumerState<PayoutAccountsScreen> createState() =>
      _PayoutAccountsScreenState();
}

class _PayoutAccountsScreenState extends ConsumerState<PayoutAccountsScreen> {
  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Please login')));
    }

    final accounts = user.paymentAccounts;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Receiving Accounts',
          style: TextStyle(
            color: Color(0xFF0D3B66),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF0D3B66)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Manage where you receive payments. These details will be shown to travelers to complete their bookings.',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 32),
            if (accounts.isEmpty)
              _buildEmptyState()
            else
              ...accounts.map((acc) => _buildAccountCard(acc)),
            const SizedBox(height: 24),
            _buildAddAccountButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(40),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 64,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          const Text(
            'No receiving accounts yet',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Color(0xFF0D3B66),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add a bank account, mobile wallet, or card (MasterCard) to receive bookings payments.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountCard(PaymentAccount account) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: account.type == PaymentAccountType.bank
                  ? const Color(0xFFE0F2FE)
                  : account.type == PaymentAccountType.card
                      ? const Color(0xFFFEE2E2)
                      : const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              account.type == PaymentAccountType.bank
                  ? Icons.account_balance
                  : account.type == PaymentAccountType.card
                      ? Icons.credit_card
                      : Icons.phone_android,
              color: account.type == PaymentAccountType.bank
                  ? Colors.blue[700]
                  : account.type == PaymentAccountType.card
                      ? Colors.red[700]
                      : Colors.green[700],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      account.providerName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFF0D3B66),
                      ),
                    ),
                    if (account.isDefault) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'DEFAULT',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.secondary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Acc: ${account.accountNumber}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
                Text(
                  account.holderName,
                  style: TextStyle(color: Colors.grey[400], fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.delete_outline,
              color: Colors.redAccent,
              size: 20,
            ),
            onPressed: () => _confirmDelete(account),
          ),
        ],
      ),
    );
  }

  Widget _buildAddAccountButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => _showAddAccountSheet(context),
        icon: const Icon(Icons.add, size: 20),
        label: const Text('Add New Account'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0D3B66),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
      ),
    );
  }

  void _confirmDelete(PaymentAccount account) async {
    final confirmed = await ConfirmationDialog.show(
      context: context,
      title: 'Remove Account?',
      message:
          'Are you sure you want to remove ${account.providerName} (${account.accountNumber})?',
      confirmLabel: 'Yes, Remove',
      type: ConfirmationDialogType.danger,
      icon: Icons.delete_forever_outlined,
    );

    if (confirmed == true) {
      final user = ref.read(authProvider);
      if (user != null) {
        ref
            .read(userProvider.notifier)
            .removePaymentAccount(user.id, account.id);
        // Also update local auth state for UI reload
        final updatedUser =
            ref.read(userProvider).firstWhere((u) => u.id == user.id);
        ref.read(authServiceProvider).updateUserData(updatedUser);

        // LOG ACTIVITY
        ref.read(activityProvider.notifier).logStatusUpdate(
              user.name,
              'Payout Account',
              'Removed ${account.providerName}',
            );
      }
    }
  }

  void _showAddAccountSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _AddPaymentAccountSheet(),
    );
  }
}

class _AddPaymentAccountSheet extends ConsumerStatefulWidget {
  @override
  ConsumerState<_AddPaymentAccountSheet> createState() =>
      _AddPaymentAccountSheetState();
}

class _AddPaymentAccountSheetState
    extends ConsumerState<_AddPaymentAccountSheet> {
  final _holderController = TextEditingController();
  final _numberController = TextEditingController();
  String _provider = 'Hormuud EVC Plus';
  PaymentAccountType _type = PaymentAccountType.mobileMoney;

  @override
  Widget build(BuildContext context) {
    final currentItems = _type == PaymentAccountType.mobileMoney
        ? [
            'Hormuud EVC Plus',
            'Zaad Service',
            'Sahal',
            'eDahab',
            'Golis',
            'Telesom',
          ]
        : _type == PaymentAccountType.bank
            ? [
                'Premier Bank',
                'IBS Bank',
                'Amal Bank',
                'Salaam Somali Bank',
                'Dahabshiil Bank',
                'MyBank Somalia',
              ]
            : [
                'MasterCard',
                'Visa',
                'MyBank Card',
              ];

    // Safety check: Ensure _provider is always one of the valid current items
    if (!currentItems.contains(_provider)) {
      _provider = currentItems.first;
    }

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24,
        right: 24,
        top: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Add Receiving Method',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0D3B66),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Account Type',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Text('Mobile'),
                  selected: _type == PaymentAccountType.mobileMoney,
                  onSelected: (v) {
                    if (v) {
                      setState(() {
                        _type = PaymentAccountType.mobileMoney;
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ChoiceChip(
                  label: const Text('Bank'),
                  selected: _type == PaymentAccountType.bank,
                  onSelected: (v) {
                    if (v) {
                      setState(() {
                        _type = PaymentAccountType.bank;
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ChoiceChip(
                  label: const Text('Card'),
                  selected: _type == PaymentAccountType.card,
                  onSelected: (v) {
                    if (v) {
                      setState(() {
                        _type = PaymentAccountType.card;
                      });
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _provider,
            decoration: const InputDecoration(labelText: 'Provider Name'),
            items: currentItems
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (v) => setState(() => _provider = v!),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _holderController,
            decoration: const InputDecoration(
              labelText: 'Account Holder Name',
              hintText: 'Full name on account',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _numberController,
            decoration: const InputDecoration(
              labelText: 'Account / Phone Number',
              hintText: 'Enter account digits',
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text('Save Account'),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _save() {
    if (_holderController.text.isEmpty || _numberController.text.isEmpty) {
      return;
    }

    final user = ref.read(authProvider);
    if (user != null) {
      final newAcc = PaymentAccount(
        id: const Uuid().v4(),
        providerName: _provider,
        accountNumber: _numberController.text,
        holderName: _holderController.text,
        type: _type,
        isDefault: user.paymentAccounts.isEmpty,
      );

      ref.read(userProvider.notifier).addPaymentAccount(user.id, newAcc);
      // Sync local auth state
      final updatedUser = ref
          .read(userProvider)
          .firstWhere((u) => u.id == user.id);
      ref.read(authServiceProvider).updateUserData(updatedUser);

      // LOG ACTIVITY
      ref
          .read(activityProvider.notifier)
          .logStatusUpdate(
            user.name,
            'Payout Account',
            'Added ${newAcc.providerName}',
          );

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account saved successfully')),
      );
    }
  }
}
