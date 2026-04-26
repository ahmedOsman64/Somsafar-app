import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/discount_model.dart';
import '../../shared/services/discount_repository.dart';
import '../../shared/services/auth_service.dart';

class CreateDiscountScreen extends ConsumerStatefulWidget {
  final Discount? discountToEdit;

  const CreateDiscountScreen({super.key, this.discountToEdit});

  @override
  ConsumerState<CreateDiscountScreen> createState() =>
      _CreateDiscountScreenState();
}

class _CreateDiscountScreenState extends ConsumerState<CreateDiscountScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _valueController;

  bool _isPercentage = true;
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 7));
  DiscountStatus _status = DiscountStatus.active;

  @override
  void initState() {
    super.initState();
    _valueController = TextEditingController(
      text: widget.discountToEdit?.value.toString() ?? '',
    );
    if (widget.discountToEdit != null) {
      _isPercentage = widget.discountToEdit!.isPercentage;
      _startDate = widget.discountToEdit!.startDate;
      _endDate = widget.discountToEdit!.endDate;
      _status = widget.discountToEdit!.status;
    }
  }

  @override
  void dispose() {
    _valueController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_endDate.isBefore(_startDate)) {
            _endDate = _startDate.add(const Duration(days: 1));
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  void _saveDiscount() {
    if (_formKey.currentState!.validate()) {
      final user = ref.read(authProvider);
      if (user == null) return;

      final discount = Discount(
        id: widget.discountToEdit?.id ?? const Uuid().v4(),
        providerId: user.providerId ?? user.id,
        value: double.parse(_valueController.text),
        isPercentage: _isPercentage,
        startDate: _startDate,
        endDate: _endDate,
        applicableServiceIds: widget.discountToEdit?.applicableServiceIds ?? [],
        status: _status,
        createdAt: widget.discountToEdit?.createdAt ?? DateTime.now(),
      );

      if (widget.discountToEdit != null) {
        ref.read(discountRepositoryProvider.notifier).updateDiscount(discount);
      } else {
        ref.read(discountRepositoryProvider.notifier).addDiscount(discount);
      }

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.discountToEdit != null
                ? 'Discount updated successfully'
                : 'Discount created successfully',
          ),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.discountToEdit != null ? 'Edit Discount' : 'Create Discount',
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0D3B66),
        elevation: 0,
      ),
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('Discount Details'),
              _buildCard([
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: _buildTextField(
                        controller: _valueController,
                        label: 'Value',
                        hint: '0.00',
                        keyboardType: TextInputType.number,
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Type',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ToggleButtons(
                            borderRadius: BorderRadius.circular(12),
                            selectedColor: Colors.white,
                            fillColor: AppColors.secondary,
                            constraints: const BoxConstraints(
                              minHeight: 45,
                              minWidth: 80,
                            ),
                            isSelected: [_isPercentage, !_isPercentage],
                            onPressed: (index) {
                              setState(() {
                                _isPercentage = index == 0;
                              });
                            },
                            children: const [Text('%'), Text(r'$')],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ]),
              const SizedBox(height: 24),
              _buildSectionTitle('Duration & Status'),
              _buildCard([
                Row(
                  children: [
                    Expanded(
                      child: _buildDatePicker(
                        label: 'Start Date',
                        date: _startDate,
                        onTap: () => _selectDate(context, true),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildDatePicker(
                        label: 'End Date',
                        date: _endDate,
                        onTap: () => _selectDate(context, false),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Initial Status',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<DiscountStatus>(
                  initialValue: _status,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  items: DiscountStatus.values.map((s) {
                    return DropdownMenuItem(
                      value: s,
                      child: Text(s.name.toUpperCase()),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => _status = v!),
                ),
              ]),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _saveDiscount,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    widget.discountToEdit != null
                        ? 'Update Discount'
                        : 'Create Discount',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 50),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0, left: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Color(0xFF0D3B66),
        ),
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
      ],
    );
  }

  Widget _buildDatePicker({
    required String label,
    required DateTime date,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, size: 18, color: Colors.grey),
                const SizedBox(width: 10),
                Text('${date.day}/${date.month}/${date.year}'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
