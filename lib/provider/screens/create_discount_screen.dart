import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../shared/widgets/app_network_image.dart';

import '../../shared/models/discount_model.dart';
import '../../shared/services/discount_repository.dart';
import '../../shared/services/auth_service.dart';

import '../../core/theme/app_colors.dart';
import '../../core/services/storage_service.dart';

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
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  bool _isSaving = false;

  bool _isPercentage = true;
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 7));
  String? _selectedImagePath;
  bool _isActive = true;
  final ImagePicker _picker = ImagePicker();

  bool get isEdit => widget.discountToEdit != null;

  @override
  void initState() {
    super.initState();
    _valueController = TextEditingController(
      text: widget.discountToEdit?.value.toString() ?? '',
    );
    _titleController = TextEditingController(
      text: widget.discountToEdit?.title ?? '',
    );
    _descriptionController = TextEditingController(
      text: widget.discountToEdit?.description ?? '',
    );
    if (widget.discountToEdit != null) {
      _isPercentage = widget.discountToEdit!.isPercentage;
      _startDate = widget.discountToEdit!.startDate;
      _endDate = widget.discountToEdit!.endDate;
      _selectedImagePath = widget.discountToEdit!.imageUrl;
      _isActive = widget.discountToEdit!.status != DiscountStatus.inactive;
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        imageQuality: 85,
      );
      if (image != null) {
        setState(() {
          _selectedImagePath = image.path;
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  @override
  void dispose() {
    _valueController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.primary,
            ),
          ),
          child: child!,
        );
      },
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

  Future<void> _saveDiscount() async {
    if (_formKey.currentState!.validate()) {
      final user = ref.read(authProvider);
      if (user == null) return;

      setState(() => _isSaving = true);

      try {
        // ─── Image Upload Logic ──────────────────────────────────────────
        String? finalImageUrl = _selectedImagePath;
        
        // If image is a local path (newly picked), upload it to Supabase
        // Note: For web, _selectedImagePath might start with blob:
        if (_selectedImagePath != null && 
           !_selectedImagePath!.startsWith('http') && 
           !_selectedImagePath!.startsWith('assets/')) {
          
          finalImageUrl = await StorageService.uploadImage(
            XFile(_selectedImagePath!),
            folder: 'discounts',
          );
        }

        // Automatically determine status based on dates
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final start = DateTime(_startDate.year, _startDate.month, _startDate.day);
        final end = DateTime(_endDate.year, _endDate.month, _endDate.day, 23, 59, 59);

        DiscountStatus calculatedStatus;
        if (!_isActive) {
          calculatedStatus = DiscountStatus.inactive;
        } else if (now.isAfter(end)) {
          calculatedStatus = DiscountStatus.ended;
        } else if (now.isAfter(start) || now.isAtSameMomentAs(today)) {
          calculatedStatus = DiscountStatus.active;
        } else {
          calculatedStatus = DiscountStatus.scheduled;
        }

        final discount = Discount(
          id: widget.discountToEdit?.id ?? const Uuid().v4(),
          providerId: user.providerId ?? user.id,
          value: double.parse(_valueController.text),
          isPercentage: _isPercentage,
          startDate: _startDate,
          endDate: _endDate,
          applicableServiceIds: widget.discountToEdit?.applicableServiceIds ?? [],
          status: calculatedStatus,
          title: _titleController.text,
          description: _descriptionController.text,
          imageUrl: finalImageUrl,
          createdAt: widget.discountToEdit?.createdAt ?? DateTime.now(),
        );

        if (widget.discountToEdit != null) {
          await ref.read(discountRepositoryProvider.notifier).updateDiscount(discount);
        } else {
          await ref.read(discountRepositoryProvider.notifier).addDiscount(discount);
        }

        if (mounted) {
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
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          isEdit ? 'Edit Special Offer' : 'Add New Special Offer',
          style: const TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── Banner Image Picker ──────────────────────────────────
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: double.infinity,
                    height: 200,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        width: 2,
                      ),
                    ),
                    child: _selectedImagePath != null
                        ? Stack(
                            fit: StackFit.expand,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(22),
                            child: _selectedImagePath!.startsWith('http')
                                // Existing saved URL — use AppNetworkImage for
                                // proper caching and Supabase URL resolution
                                ? AppNetworkImage(
                                    imageUrl: _selectedImagePath,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: 200,
                                    borderRadius: 22,
                                  )
                                // Newly picked image — blob: on web, file path on mobile
                                : (kIsWeb || _selectedImagePath!.startsWith('blob:')
                                      ? Image.network(
                                          _selectedImagePath!,
                                          fit: BoxFit.cover,
                                        )
                                      : Image.file(
                                          File(_selectedImagePath!),
                                          fit: BoxFit.cover,
                                        )),
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(22),
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [
                                      Colors.black.withValues(alpha: 0.4),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                              Positioned(
                                right: 12,
                                bottom: 12,
                                child: CircleAvatar(
                                  backgroundColor: Colors.white,
                                  radius: 18,
                                  child: Icon(Icons.edit, size: 18, color: AppColors.primary),
                                ),
                              ),
                            ],
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.05),
                                      blurRadius: 10,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.add_photo_alternate_outlined,
                                  size: 32,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Tap to upload banner image',
                                style: TextStyle(
                                  color: AppColors.primary.withValues(alpha: 0.6),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Recommended size: 1200 x 600',
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 32),

                // ─── Input Fields ───────────────────────────────────────
                _buildModernTextField(
                  controller: _titleController,
                  hint: 'Offer Title',
                  icon: Icons.title_rounded,
                  validator: (v) => v!.isEmpty ? 'Please enter a title' : null,
                ),
                const SizedBox(height: 16),

                // Discount Row: Value & Type
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: _buildModernTextField(
                        controller: _valueController,
                        hint: 'Amount/Percent',
                        icon: Icons.local_offer_outlined,
                        keyboardType: TextInputType.number,
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: Container(
                        height: 60,
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Row(
                          children: [
                            _buildTypeOption('%', _isPercentage, () {
                              setState(() => _isPercentage = true);
                            }),
                            _buildTypeOption(r'$', !_isPercentage, () {
                              setState(() => _isPercentage = false);
                            }),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                _buildModernTextField(
                  controller: _descriptionController,
                  hint: 'Promotion Details',
                  icon: Icons.description_outlined,
                  maxLines: 4,
                ),
                const SizedBox(height: 32),

                // ─── Duration ──────────────────────────────────────────
                const Row(
                  children: [
                    Icon(Icons.event_available, size: 20, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text(
                      'Validity Period',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildModernDatePicker(
                        label: 'Start Date',
                        date: _startDate,
                        onTap: () => _selectDate(context, true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildModernDatePicker(
                        label: 'End Date',
                        date: _endDate,
                        onTap: () => _selectDate(context, false),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),
                // Activation Toggle
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: _isActive 
                        ? Colors.green.withValues(alpha: 0.05) 
                        : Colors.red.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _isActive 
                          ? Colors.green.withValues(alpha: 0.1) 
                          : Colors.red.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isActive ? Icons.check_circle_outline : Icons.pause_circle_outline,
                        color: _isActive ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isActive ? 'Promotion Active' : 'Promotion Inactive',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _isActive ? Colors.green[700] : Colors.red[700],
                              ),
                            ),
                            Text(
                              _isActive 
                                  ? 'This offer will be visible to travelers.' 
                                  : 'This offer will be hidden from everyone.',
                              style: TextStyle(
                                fontSize: 12,
                                color: _isActive ? Colors.green[600] : Colors.red[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _isActive,
                        onChanged: (v) => setState(() => _isActive = v),
                        activeColor: Colors.green,
                        activeTrackColor: Colors.green.withValues(alpha: 0.2),
                        inactiveThumbColor: Colors.red,
                        inactiveTrackColor: Colors.red.withValues(alpha: 0.2),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 48),

                // ─── Action Button ────────────────────────────────────
                Container(
                  width: double.infinity,
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.2),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: _saveDiscount,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      elevation: 0,
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 3,
                            ),
                          )
                        : Text(
                            isEdit ? 'Update Special Offer' : 'Add Special Offer',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    bool enabled = true,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      enabled: enabled,
      style: const TextStyle(fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 16, fontWeight: FontWeight.normal),
        prefixIcon: Icon(icon, color: AppColors.primary.withValues(alpha: 0.6), size: 22),
        filled: true,
        fillColor: enabled ? Colors.grey[50] : Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey[200]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey[200]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
      ),
    );
  }

  Widget _buildTypeOption(String label, bool isSelected, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isSelected ? const Color(0xFF0D3B66) : Colors.grey,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernDatePicker({
    required String label,
    required DateTime date,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  '${date.day}/${date.month}/${date.year}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
