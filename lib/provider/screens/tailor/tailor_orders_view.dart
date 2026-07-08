import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../providers/tailor_provider.dart';
import '../../../shared/models/tailor_models.dart';
import '../../../shared/models/user_model.dart';
import 'tailor_customers_view.dart';

class TailorOrdersView extends ConsumerStatefulWidget {
  const TailorOrdersView({super.key});

  @override
  ConsumerState<TailorOrdersView> createState() => _TailorOrdersViewState();
}

class _TailorOrdersViewState extends ConsumerState<TailorOrdersView> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tailorState = ref.watch(tailorProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Maamulka Dalabaadka (Orders)', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF0D3B66),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: () {
              if (tailorState.customers.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Fadlan marka hore kudar macmiil si aad u dalab u samayso!'),
                    backgroundColor: Colors.orange,
                  ),
                );
                showDialog(
                  context: context,
                  builder: (context) => const TailorCustomerFormDialog(),
                );
              } else {
                showDialog(
                  context: context,
                  builder: (context) => const TailorOrderFormDialog(),
                );
              }
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.greenAccent,
          tabs: const [
            Tab(text: 'La keenay'),
            Tab(text: 'Tolaayaa'),
            Tab(text: 'Diyaar'),
            Tab(text: 'La qaatay'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOrderList(TailorOrderStatus.received, tailorState),
          _buildOrderList(TailorOrderStatus.sewing, tailorState),
          _buildOrderList(TailorOrderStatus.ready, tailorState),
          _buildOrderList(TailorOrderStatus.taken, tailorState),
        ],
      ),
    );
  }

  Widget _buildOrderList(TailorOrderStatus status, TailorState state) {
    final orders = state.orders.where((o) => o.status == status).toList();

    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_bag_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Ma jiraan dalabaad qaybtan ku jira.',
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        final customer = state.customers.firstWhere(
          (c) => c.id == order.customerId,
          orElse: () => TailorCustomer(
            id: '',
            name: 'Macmiil aan la aqoon',
            phone: '',
            gender: Gender.male,
            shoulder: 0,
            chest: 0,
            waist: 0,
            hips: 0,
            sleeveLength: 0,
            overallLength: 0,
            notes: '',
            updatedAt: DateTime.now(),
          ),
        );

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      customer.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0D3B66)),
                    ),
                    Text(
                      'Due: ${DateFormat.yMMMd().format(order.dueDate)}',
                      style: TextStyle(
                        color: order.dueDate.isBefore(DateTime.now()) && status != TailorOrderStatus.taken
                            ? Colors.red
                            : Colors.grey[600],
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Nooca Tolidda: ${order.fabricType} • ${order.styleType}',
                  style: TextStyle(color: Colors.grey[800], fontSize: 14),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Qiimaha: \$${order.price.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    Text(
                      'Hormar: \$${order.deposit.toStringAsFixed(2)}',
                      style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    Text(
                      'Haraa: \$${order.balance.toStringAsFixed(2)}',
                      style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
                if (order.notes.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Xusuusin: ${order.notes}',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600], fontStyle: FontStyle.italic),
                  ),
                ],
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Change Status dropdown-like Actions menu
                    DropdownButton<TailorOrderStatus>(
                      value: order.status,
                      icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF0D3B66)),
                      underline: const SizedBox(),
                      onChanged: (newStatus) {
                        if (newStatus != null) {
                          if (newStatus == TailorOrderStatus.taken && order.balance > 0) {
                            _showPaymentCollectionDialog(context, customer, order);
                          } else {
                            final updatedOrder = order.copyWith(status: newStatus);
                            ref.read(tailorProvider.notifier).updateOrder(updatedOrder);

                            // Trigger notification if marked ready
                            if (newStatus == TailorOrderStatus.ready) {
                              _showNotificationTemplate(customer, order);
                            }
                          }
                        }
                      },
                      items: TailorOrderStatus.values.map((statusVal) {
                        return DropdownMenuItem<TailorOrderStatus>(
                          value: statusVal,
                          child: Text(_getStatusText(statusVal)),
                        );
                      }).toList(),
                    ),
                    
                    // Share Receipt / Notifications button
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.share, color: Colors.blue),
                          tooltip: 'La wadaag Rasiidka',
                          onPressed: () {
                            _showReceiptDialog(customer, order);
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          tooltip: 'Tirtir',
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Ma tirtirtaa dalabka?'),
                                content: const Text('Ma hubtaa inaad rabto inaad tirtirto dalabkan?'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Maya')),
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                                    child: const Text('Haa, Masax'),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              ref.read(tailorProvider.notifier).deleteOrder(order.id);
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showNotificationTemplate(TailorCustomer customer, TailorOrder order) {
    final message = 'Asc ${customer.name},\n'
        'Dharkii aad noo dhiibatay ee ahaa (${order.fabricType} - ${order.styleType}) waa uu diyaarsan yahay (Ready).\n'
        'Haraaga kugu dhiman waa \$${order.balance.toStringAsFixed(2)}.\n'
        'Waad u imaan kartaa hadda. Waad ku mahadsan tahay doorashadaada!';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Fariinta Ready-ga ah (WhatsApp/SMS)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Fariintan waxaa loo diri karaa macmiilka:'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
              child: Text(message, style: const TextStyle(fontSize: 13)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Xidh')),
          ElevatedButton(
            onPressed: () {
              // Copy message to clipboard
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Fariinta waa la koobiyeeyay!')),
              );
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D3B66), foregroundColor: Colors.white),
            child: const Text('Copy Message'),
          )
        ],
      ),
    );
  }

  void _showReceiptDialog(TailorCustomer customer, TailorOrder order) {
    final receiptText = '============================\n'
        '       RASIIDKA HARQAANKA       \n'
        '============================\n'
        'Macmiilka: ${customer.name}\n'
        'Taleefanka: ${customer.phone}\n'
        '----------------------------\n'
        'Nooca Marada: ${order.fabricType}\n'
        'Nooca Tolidda: ${order.styleType}\n'
        'Taariikhda Dalabka: ${DateFormat.yMd().format(order.createdAt)}\n'
        'Ballanta (Due Date): ${DateFormat.yMd().format(order.dueDate)}\n'
        '----------------------------\n'
        'Qiimaha Guud: \$${order.price.toStringAsFixed(2)}\n'
        'Hormar (Deposit): \$${order.deposit.toStringAsFixed(2)}\n'
        'Haraa (Balance): \$${order.balance.toStringAsFixed(2)}\n'
        '============================\n'
        'Waad ku mahadsan tahay adeegayada!';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rasiidka Dalabka'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  receiptText,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Xidh')),
          ElevatedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Rasiidka waa la koobiyeeyay si loogu diro WhatsApp!')),
              );
              Navigator.pop(ctx);
            },
            icon: const Icon(Icons.copy),
            label: const Text('Koobiyeey (Copy)'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D3B66), foregroundColor: Colors.white),
          )
        ],
      ),
    );
  }

  String _getStatusText(TailorOrderStatus status) {
    switch (status) {
      case TailorOrderStatus.received:
        return 'La keenay';
      case TailorOrderStatus.sewing:
        return 'La jarjaray / Tolaayaa';
      case TailorOrderStatus.ready:
        return 'Wuu Diyaar garoobay';
      case TailorOrderStatus.taken:
        return 'Waa la qaatay';
    }
  }

  void _showPaymentCollectionDialog(BuildContext context, TailorCustomer customer, TailorOrder order) {
    final amountController = TextEditingController(text: order.balance.toStringAsFixed(2));
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.payment, color: Color(0xFF0D3B66)),
              SizedBox(width: 8),
              Text(
                'Hubi Lacagta Haraaga',
                style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D3B66)),
              ),
            ],
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Macaamiilka ${customer.name} wuxuu qaadanayaa dharkiisa. Fadlan hubi lacagta haraaga ah ee kugu dhiman.',
                    style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        _buildDialogRow('Qiimaha Guud (Total):', '\$${order.price.toStringAsFixed(2)}'),
                        const SizedBox(height: 6),
                        _buildDialogRow('Hormar Hore (Deposit):', '\$${order.deposit.toStringAsFixed(2)}', valueColor: Colors.green),
                        const Divider(height: 16),
                        _buildDialogRow(
                          'Haraaga Dhiman (Balance):',
                          '\$${order.balance.toStringAsFixed(2)}',
                          valueColor: Colors.red,
                          isBold: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Lacagta uu Hadda Bixinayo (\$)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      prefixIcon: const Icon(Icons.attach_money),
                      helperText: 'Fadlan geli inta uu hadda dhiibayo',
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Fadlan geli lacag';
                      final val = double.tryParse(v);
                      if (val == null) return 'Geli lambar sax ah';
                      if (val < 0) return 'Lacagta ma noqon karto mid ka yar 0';
                      if (val > order.balance) return 'Lacagta ma dhaafi karto haraaga (\$${order.balance.toStringAsFixed(2)})';
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Ka Noqo', style: TextStyle(color: Colors.grey)),
            ),
            Row(
              children: [
                TextButton(
                  onPressed: () {
                    final updatedOrder = order.copyWith(status: TailorOrderStatus.taken);
                    ref.read(tailorProvider.notifier).updateOrder(updatedOrder);
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Dalabka waa la qaatay isagoo haraagii qaba.'),
                        backgroundColor: Colors.blue,
                      ),
                    );
                  },
                  child: const Text(
                    'Haraaga ku daa',
                    style: TextStyle(color: Colors.orange),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    if (formKey.currentState!.validate()) {
                      final paidAmount = double.parse(amountController.text);
                      final updatedOrder = order.copyWith(
                        deposit: order.deposit + paidAmount,
                        status: TailorOrderStatus.taken,
                      );
                      ref.read(tailorProvider.notifier).updateOrder(updatedOrder);
                      Navigator.pop(ctx);
                      
                      final msg = paidAmount == order.balance 
                          ? 'Dalabka waa la wada bixiyay waana la qaatay!' 
                          : 'Dalabka waa la qaatay, waxaana la bixiyay \$${paidAmount.toStringAsFixed(2)}!';
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(msg),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D3B66),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Bixi & Qaado'),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildDialogRow(String label, String value, {Color? valueColor, bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Colors.black87)),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: valueColor ?? Colors.black87,
          ),
        ),
      ],
    );
  }
}

class TailorOrderFormDialog extends ConsumerStatefulWidget {
  const TailorOrderFormDialog({super.key});

  @override
  ConsumerState<TailorOrderFormDialog> createState() => _TailorOrderFormDialogState();
}

class _TailorOrderFormDialogState extends ConsumerState<TailorOrderFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _fabricController = TextEditingController();
  final _styleController = TextEditingController();
  final _priceController = TextEditingController();
  final _depositController = TextEditingController();
  final _notesController = TextEditingController();

  String? _selectedCustomerId;
  DateTime _selectedDueDate = DateTime.now().add(const Duration(days: 3));

  @override
  void dispose() {
    _fabricController.dispose();
    _styleController.dispose();
    _priceController.dispose();
    _depositController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tailorState = ref.watch(tailorProvider);

    return AlertDialog(
      title: const Text('Dalab Cusub oo Tolis ah'),
      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Select Customer Dropdown
                DropdownButtonFormField<String>(
                  value: _selectedCustomerId,
                  decoration: const InputDecoration(labelText: 'Dooro Macmiilka *'),
                  items: tailorState.customers.map((c) {
                    return DropdownMenuItem<String>(
                      value: c.id,
                      child: Text('${c.name} (${c.phone})'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedCustomerId = val;
                    });
                  },
                  validator: (v) => v == null ? 'Fadlan dooro macmiilka' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _fabricController,
                  decoration: const InputDecoration(labelText: 'Nooca Marada (Fabric Type) *'),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Geli nooca marada' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _styleController,
                  decoration: const InputDecoration(labelText: 'Nooca Tolidda (Style Type) *'),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Geli qaabka loo tolayo' : null,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _priceController,
                        decoration: const InputDecoration(labelText: 'Qiimaha (\$)*'),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (v) => v == null || double.tryParse(v) == null ? 'Geli qiimo sax ah' : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _depositController,
                        decoration: const InputDecoration(labelText: 'Horudhaca/Deposit (\$)*'),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (v) => v == null || double.tryParse(v) == null ? 'Geli lacagta hore' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Due Date Selector
                ListTile(
                  title: const Text('Maalinta Ballanta (Due Date)'),
                  subtitle: Text(DateFormat.yMMMd().format(_selectedDueDate)),
                  trailing: const Icon(Icons.calendar_today),
                  contentPadding: EdgeInsets.zero,
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDueDate,
                      firstDate: DateTime.now().subtract(const Duration(days: 1)),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setState(() {
                        _selectedDueDate = picked;
                      });
                    }
                  },
                ),
                
                const SizedBox(height: 8),
                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(labelText: 'Faahfaahin kale (Notes)'),
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
            if (_formKey.currentState!.validate() && _selectedCustomerId != null) {
              final price = double.parse(_priceController.text);
              final deposit = double.parse(_depositController.text);

              final orderData = TailorOrder(
                id: const Uuid().v4(),
                customerId: _selectedCustomerId!,
                fabricType: _fabricController.text.trim(),
                styleType: _styleController.text.trim(),
                dueDate: _selectedDueDate,
                status: TailorOrderStatus.received,
                price: price,
                deposit: deposit,
                notes: _notesController.text.trim(),
                createdAt: DateTime.now(),
              );

              ref.read(tailorProvider.notifier).addOrder(orderData);
              Navigator.pop(context);
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D3B66), foregroundColor: Colors.white),
          child: const Text('Create Order'),
        ),
      ],
    );
  }
}
