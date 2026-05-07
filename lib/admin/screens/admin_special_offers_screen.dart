import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io' as io;
import 'package:image_picker/image_picker.dart';
import '../../shared/services/special_offer_repository.dart';
import '../../shared/models/special_offer_model.dart';
import '../../shared/services/service_repository.dart';
import '../../shared/models/service_model.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/storage_service.dart';
import '../../shared/widgets/app_network_image.dart';

class AdminSpecialOffersScreen extends ConsumerStatefulWidget {
  const AdminSpecialOffersScreen({super.key});

  @override
  ConsumerState<AdminSpecialOffersScreen> createState() =>
      _AdminSpecialOffersScreenState();
}

class _AdminSpecialOffersScreenState
    extends ConsumerState<AdminSpecialOffersScreen> {
  final _titleController = TextEditingController();
  final _discountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _imageUrlController = TextEditingController();
  final _discountPercentController = TextEditingController();
  XFile? _selectedFile;
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;
  String? _selectedServiceId;

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedFile = image;
        _imageUrlController.text = image.name;
      });
    }
  }

  Future<void> _addOffer() async {
    final title = _titleController.text;
    final discount = _discountController.text;
    final description = _descriptionController.text;

    if (title.isEmpty ||
        discount.isEmpty ||
        description.isEmpty ||
        (_selectedFile == null && _imageUrlController.text.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      String imageUrl = _imageUrlController.text;

      if (_selectedFile != null) {
        final uploadedUrl = await StorageService.uploadImage(
          _selectedFile!,
          folder: 'offers',
        );
        if (uploadedUrl == null) throw Exception('Upload failed');
        imageUrl = uploadedUrl;
      }

      final double? discountPercent =
          double.tryParse(_discountPercentController.text.trim());

      final error = await ref
          .read(specialOfferProvider.notifier)
          .addOffer(
            title: title,
            discount: discount,
            description: description,
            imageUrl: imageUrl,
            linkedServiceId: _selectedServiceId,
            discountPercent: discountPercent,
          );

      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: Colors.red),
        );
      } else {
        _titleController.clear();
        _discountController.clear();
        _descriptionController.clear();
        _imageUrlController.clear();
        _discountPercentController.clear();
        setState(() {
          _selectedFile = null;
          _selectedServiceId = null;
        });
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showAddDialog() {
    final allServices = ref.read(serviceProvider)
        .where((s) => s.status == ServiceStatus.active)
        .toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(32),
              topRight: Radius.circular(32),
            ),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 32,
            top: 32,
            left: 32,
            right: 32,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Add New Special Offer',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                Center(
                  child: GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      width: double.infinity,
                      height: 160,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: _selectedFile != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: kIsWeb
                                  ? Image.network(
                                      _selectedFile!.path,
                                      fit: BoxFit.cover,
                                    )
                                  : Image.file(
                                      io.File(_selectedFile!.path),
                                      fit: BoxFit.cover,
                                    ),
                            )
                          : const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_a_photo,
                                  size: 40,
                                  color: Colors.grey,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Tap to select banner image',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    hintText: 'e.g. Summer Special',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _discountController,
                  decoration: const InputDecoration(
                    labelText: 'Discount Label',
                    hintText: 'e.g. 30% OFF',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'e.g. Get 30% off on selected hotels',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _imageUrlController,
                  decoration: const InputDecoration(
                    labelText: 'Image URL (Auto-filled on pick)',
                    hintText: 'https://...',
                    border: OutlineInputBorder(),
                  ),
                ),

                // ─── Linked Service ──────────────────────────────────
                const SizedBox(height: 24),
                const Text(
                  'Apply Discount To Service (Optional)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 4),
                const Text(
                  'When a customer books the selected service, the discount is applied automatically.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  initialValue: _selectedServiceId,
                  decoration: InputDecoration(
                    labelText: 'Linked Service',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.link),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('— None (banner only) —'),
                    ),
                    ...allServices.map((s) => DropdownMenuItem<String?>(
                          value: s.id,
                          child: Text(
                            '${s.title} (${s.category})',
                            overflow: TextOverflow.ellipsis,
                          ),
                        )),
                  ],
                  onChanged: (val) {
                    setModalState(() => _selectedServiceId = val);
                    setState(() => _selectedServiceId = val);
                  },
                ),
                if (_selectedServiceId != null) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: _discountPercentController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Discount Percentage',
                      hintText: 'e.g. 20',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.percent),
                      suffixText: '%',
                      filled: true,
                      fillColor: Colors.green.shade50,
                    ),
                  ),
                ],
                // ────────────────────────────────────────────────────
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _addOffer,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isUploading
                        ? const Center(
                            child: CircularProgressIndicator(color: Colors.white),
                          )
                        : const Text('Add Special Offer'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final offers = ref.watch(specialOfferProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Special Offers'),
        centerTitle: true,
      ),
      body: offers.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.local_offer_outlined,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No special offers yet',
                    style: TextStyle(color: Colors.grey[600], fontSize: 18),
                  ),
                ],
              ),
            )
          : ReorderableListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: offers.length,
              onReorder: (oldIndex, newIndex) {
                if (oldIndex < newIndex) {
                  newIndex -= 1;
                }
                final items = List<SpecialOffer>.from(offers);
                final item = items.removeAt(oldIndex);
                items.insert(newIndex, item);
                ref.read(specialOfferProvider.notifier).updateOrder(items);
              },
              itemBuilder: (context, index) {
                final offer = offers[index];
                return _OfferListTile(
                  key: ValueKey(offer.id),
                  offer: offer,
                  onDelete: () => ref
                      .read(specialOfferProvider.notifier)
                      .removeOffer(offer.id),
                  onToggle: () => ref
                      .read(specialOfferProvider.notifier)
                      .toggleStatus(offer.id),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: offers.length >= 10 ? null : _showAddDialog,
        backgroundColor: offers.length >= 10 ? Colors.grey : AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text('Add Offer (${offers.length}/10)'),
      ),
    );
  }
}

class _OfferListTile extends StatelessWidget {
  final SpecialOffer offer;
  final VoidCallback onDelete;
  final VoidCallback onToggle;

  const _OfferListTile({
    super.key,
    required this.offer,
    required this.onDelete,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.drag_indicator, color: Colors.grey),
            const SizedBox(width: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: AppNetworkImage(
                imageUrl: StorageService.ensurePublicUrl(offer.imageUrl),
                width: 80,
                height: 60,
                fit: BoxFit.cover,
                borderRadius: 8,
                memCacheWidth: 160, // Small preview
                errorWidget: Container(
                  width: 80,
                  height: 60,
                  color: Colors.grey[200],
                  child: const Icon(Icons.broken_image, size: 20),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    offer.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${offer.discount} OFF',
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    offer.isActive ? 'Active' : 'Inactive',
                    style: TextStyle(
                      color: offer.isActive ? Colors.green : Colors.red,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: offer.isActive,
              onChanged: (_) => onToggle(),
              activeThumbColor: AppColors.primary,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Delete Special Offer'),
                    content: const Text(
                      'Are you sure you want to delete this offer?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () {
                          onDelete();
                          Navigator.pop(context);
                        },
                        child: const Text(
                          'Delete',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
