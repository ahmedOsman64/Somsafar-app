import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/models/tax_model.dart';
import '../../shared/services/tax_repository.dart';
import '../../shared/models/user_model.dart';
import 'package:intl/intl.dart';

class AdminTaxesScreen extends ConsumerWidget {
  const AdminTaxesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taxes = ref.watch(taxProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Manage Taxes')),
      body: taxes.isEmpty
          ? const Center(child: Text('No taxes found.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: taxes.length,
              itemBuilder: (context, index) {
                final tax = taxes[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    title: Text(
                      tax.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${tax.providerType.name.toUpperCase()} • ${tax.taxType == TaxType.percentage ? '${tax.rate}%' : '\$${tax.rate}'} \nCreated: ${DateFormat.yMd().format(tax.createdAt)}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(
                          value: tax.isActive,
                          onChanged: (val) {
                            ref
                                .read(taxProvider.notifier)
                                .toggleStatus(tax.id, tax.isActive);
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () =>
                              _showTaxDialog(context, ref, taxModel: tax),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            ref.read(taxProvider.notifier).deleteTax(tax.id);
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showTaxDialog(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showTaxDialog(
    BuildContext context,
    WidgetRef ref, {
    TaxModel? taxModel,
  }) {
    showDialog(
      context: context,
      builder: (context) => _TaxDialog(taxModel: taxModel),
    );
  }
}

class _TaxDialog extends ConsumerStatefulWidget {
  final TaxModel? taxModel;

  const _TaxDialog({this.taxModel});

  @override
  ConsumerState<_TaxDialog> createState() => _TaxDialogState();
}

class _TaxDialogState extends ConsumerState<_TaxDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _rateController;
  ProviderType _providerType = ProviderType.all;
  TaxType _taxType = TaxType.percentage;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.taxModel?.name ?? '');
    _rateController = TextEditingController(
      text: widget.taxModel?.rate.toString() ?? '',
    );
    if (widget.taxModel != null) {
      _providerType = widget.taxModel!.providerType;
      _taxType = widget.taxModel!.taxType;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _rateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.taxModel == null ? 'Add Tax' : 'Edit Tax'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Tax Name (e.g., VAT)',
                ),
                validator: (val) =>
                    val == null || val.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<ProviderType>(
                initialValue: _providerType,
                decoration: const InputDecoration(labelText: 'Applies To'),
                items: ProviderType.values.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type.name.toUpperCase()),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _providerType = val);
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<TaxType>(
                initialValue: _taxType,
                decoration: const InputDecoration(labelText: 'Tax Type'),
                items: TaxType.values.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type.name.toUpperCase()),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _taxType = val);
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _rateController,
                decoration: const InputDecoration(labelText: 'Rate'),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Required';
                  if (double.tryParse(val) == null) return 'Must be a number';
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final newTax = TaxModel(
                id: widget.taxModel?.id ?? '',
                name: _nameController.text,
                providerType: _providerType,
                taxType: _taxType,
                rate: double.parse(_rateController.text),
                isActive: widget.taxModel?.isActive ?? true,
                createdAt: widget.taxModel?.createdAt ?? DateTime.now(),
              );

              if (widget.taxModel == null) {
                ref.read(taxProvider.notifier).addTax(newTax);
              } else {
                ref.read(taxProvider.notifier).updateTax(newTax);
              }
              Navigator.pop(context);
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
