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
            const SizedBox(height: 24),

            // --- PAY LATER TOGGLE ---
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: SwitchListTile(
                title: const Text(
                  'Allow "Pay Later"',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0D3B66),
                  ),
                ),
                subtitle: const Text(
                  'If active, customers can book and pay at arrival.',
                  style: TextStyle(fontSize: 12),
                ),
                secondary: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.schedule, color: AppColors.info, size: 20),
                ),
                value: user.metadata['pay_later_enabled'] ?? true,
                onChanged: (v) async {
                  final updatedMetadata = Map<String, dynamic>.from(user.metadata);
                  updatedMetadata['pay_later_enabled'] = v;
                  final updatedUser = user.copyWith(metadata: updatedMetadata);
                  
                  await ref.read(userProvider.notifier).updateUser(updatedUser);
                  ref.read(authServiceProvider).updateUserData(updatedUser);

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(v ? 'Pay Later enabled' : 'Pay Later disabled')),
                    );
                  }
                },
                activeColor: AppColors.secondary,
              ),
            ),
            const SizedBox(height: 24),

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
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(
                  Icons.edit_outlined,
                  color: Color(0xFF0D3B66),
                  size: 20,
                ),
                onPressed: () => _showEditAccountSheet(context, account),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(
                  Icons.delete_outline,
                  color: Colors.redAccent,
                  size: 20,
                ),
                onPressed: () => _confirmDelete(account),
              ),
            ],
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
        try {
          final updatedUser = await ref
              .read(userProvider.notifier)
              .removePaymentAccount(user.id, account.id);

          if (updatedUser != null) {
            // Update local auth state for UI reload
            ref.read(authServiceProvider).updateUserData(updatedUser);
          }

          // LOG ACTIVITY
          ref.read(activityProvider.notifier).logStatusUpdate(
                user.name,
                'Payout Account',
                'Removed ${account.providerName}',
              );

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Account removed successfully')),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error removing account: $e')),
            );
          }
        }
      }
    }
  }

  void _showEditAccountSheet(BuildContext context, PaymentAccount account) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _AddPaymentAccountSheet(initialAccount: account),
    );
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
  final PaymentAccount? initialAccount;
  const _AddPaymentAccountSheet({this.initialAccount});

  @override
  ConsumerState<_AddPaymentAccountSheet> createState() =>
      _AddPaymentAccountSheetState();
}

class _AddPaymentAccountSheetState
    extends ConsumerState<_AddPaymentAccountSheet> {
  final _holderController = TextEditingController();
  final _numberController = TextEditingController();
  late String _provider;
  late PaymentAccountType _type;

  @override
  void initState() {
    super.initState();
    if (widget.initialAccount != null) {
      _holderController.text = widget.initialAccount!.holderName;
      _numberController.text = widget.initialAccount!.accountNumber;
      _provider = widget.initialAccount!.providerName;
      _type = widget.initialAccount!.type;
    } else {
      _provider = 'Hormuud EVC Plus';
      _type = PaymentAccountType.mobileMoney;
    }
  }

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.initialAccount != null
                    ? 'Edit Receiving Method'
                    : 'Add Receiving Method',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0D3B66),
                ),
              ),
              if (widget.initialAccount != null)
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
            ],
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

  void _save() async {
    if (_holderController.text.isEmpty || _numberController.text.isEmpty) {
      return;
    }

    final user = ref.read(authProvider);
    if (user != null) {
      if (widget.initialAccount != null) {
        // EDIT MODE
        final updatedAcc = widget.initialAccount!.copyWith(
          providerName: _provider,
          accountNumber: _numberController.text,
          holderName: _holderController.text,
          type: _type,
        );

        final updatedUser = await ref
            .read(userProvider.notifier)
            .updatePaymentAccount(user.id, updatedAcc);

        if (updatedUser != null) {
          // Sync local auth state
          ref.read(authServiceProvider).updateUserData(updatedUser);
        }

        // LOG ACTIVITY
        ref.read(activityProvider.notifier).logStatusUpdate(
              user.name,
              'Payout Account',
              'Updated ${updatedAcc.providerName}',
            );
      } else {
        // ADD MODE
        final newAcc = PaymentAccount(
          id: const Uuid().v4(),
          providerName: _provider,
          accountNumber: _numberController.text,
          holderName: _holderController.text,
          type: _type,
          isDefault: user.paymentAccounts.isEmpty,
        );

        final updatedUser = await ref
            .read(userProvider.notifier)
            .addPaymentAccount(user.id, newAcc);

        if (updatedUser != null) {
          // Sync local auth state
          ref.read(authServiceProvider).updateUserData(updatedUser);
        }

        // LOG ACTIVITY
        ref.read(activityProvider.notifier).logStatusUpdate(
              user.name,
              'Payout Account',
              'Added ${newAcc.providerName}',
            );
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(widget.initialAccount != null
                  ? 'Account updated successfully'
                  : 'Account saved successfully')),
        );
      }
    }
  }
}
