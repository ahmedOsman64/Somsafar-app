import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../providers/tailor_provider.dart';
import '../../../shared/models/tailor_models.dart';
import '../../../shared/models/user_model.dart';

class TailorCustomersView extends ConsumerStatefulWidget {
  const TailorCustomersView({super.key});

  @override
  ConsumerState<TailorCustomersView> createState() => _TailorCustomersViewState();
}

class _TailorCustomersViewState extends ConsumerState<TailorCustomersView> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tailorState = ref.watch(tailorProvider);
    
    final filteredCustomers = tailorState.customers.where((c) {
      final nameMatches = c.name.toLowerCase().contains(_searchQuery.toLowerCase());
      final phoneMatches = c.phone.contains(_searchQuery);
      return nameMatches || phoneMatches;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Diiwaanka Macaamiisha (Customers)', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF0D3B66),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => const TailorCustomerFormDialog(),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                });
              },
              decoration: InputDecoration(
                hintText: 'Ku raadi magac ama taleefan...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                fillColor: Colors.white,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
          
          // Customer List
          Expanded(
            child: tailorState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredCustomers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.people_outline, size: 64, color: Colors.grey),
                            const SizedBox(height: 16),
                            const Text(
                              'Ma jiraan macaamiil la keydiyay.',
                              style: TextStyle(color: Colors.grey, fontSize: 16),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => const TailorCustomerFormDialog(),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0D3B66),
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Kudar Macmiilkii U Horeeyay'),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        itemCount: filteredCustomers.length,
                        itemBuilder: (context, index) {
                          final customer = filteredCustomers[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                            borderOnForeground: false,
                            color: Colors.white,
                            child: ExpansionTile(
                              leading: CircleAvatar(
                                backgroundColor: const Color(0xFF0D3B66).withOpacity(0.1),
                                child: Text(
                                  customer.name.substring(0, 1).toUpperCase(),
                                  style: const TextStyle(color: Color(0xFF0D3B66), fontWeight: FontWeight.bold),
                                ),
                              ),
                              title: Text(
                                customer.name,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(customer.phone),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Divider(height: 1),
                                      const SizedBox(height: 12),
                                      const Text(
                                        'Cabbiraada Macmiilka (Measurements):',
                                        style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D3B66)),
                                      ),
                                      const SizedBox(height: 12),
                                      _buildMeasurementGrid(customer),
                                      const SizedBox(height: 12),
                                      if (customer.notes.isNotEmpty) ...[
                                        Text(
                                          'Xusuusin (Notes):',
                                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700]),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          customer.notes,
                                          style: TextStyle(color: Colors.grey[600]),
                                        ),
                                        const SizedBox(height: 16),
                                      ],
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit, color: Colors.blue),
                                            onPressed: () {
                                              showDialog(
                                                context: context,
                                                builder: (context) => TailorCustomerFormDialog(customer: customer),
                                              );
                                            },
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete, color: Colors.red),
                                            onPressed: () async {
                                              final confirm = await showDialog<bool>(
                                                context: context,
                                                builder: (ctx) => AlertDialog(
                                                  title: const Text('Masixi kartaa?'),
                                                  content: Text('Ma hubtaa inaad rabto inaad tirtirto macmiilka ${customer.name}? Tani waxay sidoo kale tirtiri doontaa dalabaadkiisa.'),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () => Navigator.pop(ctx, false),
                                                      child: const Text('Maya'),
                                                    ),
                                                    TextButton(
                                                      onPressed: () => Navigator.pop(ctx, true),
                                                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                                                      child: const Text('Haa, Masax'),
                                                    ),
                                                  ],
                                                ),
                                              );
                                              if (confirm == true) {
                                                ref.read(tailorProvider.notifier).deleteCustomer(customer.id);
                                              }
                                            },
                                          ),
                                        ],
                                      )
                                    ],
                                  ),
                                )
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildMeasurementGrid(TailorCustomer customer) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 2.2,
      children: [
        _buildMeasurementCell('Garab (Shoulder)', '${customer.shoulder} cm'),
        _buildMeasurementCell('Xabad (Chest)', '${customer.chest} cm'),
        _buildMeasurementCell('Dhex (Waist)', '${customer.waist} cm'),
        _buildMeasurementCell('Miskaha (Hips)', '${customer.hips} cm'),
        _buildMeasurementCell('Gacan (Sleeve)', '${customer.sleeveLength} cm'),
        _buildMeasurementCell('Dherer (Overall)', '${customer.overallLength} cm'),
      ],
    );
  }

  Widget _buildMeasurementCell(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0C2340))),
        ],
      ),
    );
  }
}

class TailorCustomerFormDialog extends ConsumerStatefulWidget {
  final TailorCustomer? customer;
  const TailorCustomerFormDialog({this.customer, super.key});

  @override
  ConsumerState<TailorCustomerFormDialog> createState() => _TailorCustomerFormDialogState();
}

class _TailorCustomerFormDialogState extends ConsumerState<TailorCustomerFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _notesController = TextEditingController();
  
  final _shoulderController = TextEditingController(text: '0.0');
  final _chestController = TextEditingController(text: '0.0');
  final _waistController = TextEditingController(text: '0.0');
  final _hipsController = TextEditingController(text: '0.0');
  final _sleeveController = TextEditingController(text: '0.0');
  final _overallController = TextEditingController(text: '0.0');

  Gender _gender = Gender.male;

  @override
  void initState() {
    super.initState();
    if (widget.customer != null) {
      final c = widget.customer!;
      _nameController.text = c.name;
      _phoneController.text = c.phone;
      _notesController.text = c.notes;
      _shoulderController.text = c.shoulder.toString();
      _chestController.text = c.chest.toString();
      _waistController.text = c.waist.toString();
      _hipsController.text = c.hips.toString();
      _sleeveController.text = c.sleeveLength.toString();
      _overallController.text = c.overallLength.toString();
      _gender = c.gender;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
    _shoulderController.dispose();
    _chestController.dispose();
    _waistController.dispose();
    _hipsController.dispose();
    _sleeveController.dispose();
    _overallController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.customer != null;
    
    return AlertDialog(
      title: Text(isEdit ? 'Wax ka beddel Macmiilka' : 'Kudar Macmiil Cusub'),
      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Info Fields
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Magaca Macmiilka *'),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Fadlan geli magaca' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(labelText: 'Taleefanka (e.g. +25261...) *'),
                  keyboardType: TextInputType.phone,
                  validator: (v) => v == null || v.trim().isEmpty ? 'Fadlan geli taleefanka' : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Jinsiga: '),
                    Radio<Gender>(
                      value: Gender.male,
                      groupValue: _gender,
                      onChanged: (val) {
                        if (val != null) setState(() => _gender = val);
                      },
                    ),
                    const Text('Rag (Male)'),
                    Radio<Gender>(
                      value: Gender.female,
                      groupValue: _gender,
                      onChanged: (val) {
                        if (val != null) setState(() => _gender = val);
                      },
                    ),
                    const Text('Dumar (Female)'),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 8),
                const Text(
                  'Cabbiraada (cm / inches):',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                // Measurements Grid
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _shoulderController,
                        decoration: const InputDecoration(labelText: 'Garab (Shoulder)'),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _chestController,
                        decoration: const InputDecoration(labelText: 'Xabad (Chest)'),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _waistController,
                        decoration: const InputDecoration(labelText: 'Dhex (Waist)'),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _hipsController,
                        decoration: const InputDecoration(labelText: 'Miskaha (Hips)'),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _sleeveController,
                        decoration: const InputDecoration(labelText: 'Gacan (Sleeve)'),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _overallController,
                        decoration: const InputDecoration(labelText: 'Dherer (Overall)'),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(labelText: 'Xusuusin dheeraad ah (Notes)'),
                  maxLines: 2,
                ),
              ],
            ),
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
              final shoulder = double.tryParse(_shoulderController.text) ?? 0.0;
              final chest = double.tryParse(_chestController.text) ?? 0.0;
              final waist = double.tryParse(_waistController.text) ?? 0.0;
              final hips = double.tryParse(_hipsController.text) ?? 0.0;
              final sleeve = double.tryParse(_sleeveController.text) ?? 0.0;
              final overall = double.tryParse(_overallController.text) ?? 0.0;

              final customerData = TailorCustomer(
                id: isEdit ? widget.customer!.id : const Uuid().v4(),
                name: _nameController.text.trim(),
                phone: _phoneController.text.trim(),
                gender: _gender,
                shoulder: shoulder,
                chest: chest,
                waist: waist,
                hips: hips,
                sleeveLength: sleeve,
                overallLength: overall,
                notes: _notesController.text.trim(),
                updatedAt: DateTime.now(),
              );

              if (isEdit) {
                ref.read(tailorProvider.notifier).updateCustomer(customerData);
              } else {
                ref.read(tailorProvider.notifier).addCustomer(customerData);
              }

              Navigator.pop(context);
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D3B66), foregroundColor: Colors.white),
          child: Text(isEdit ? 'Keydi' : 'Kudar'),
        ),
      ],
    );
  }
}
