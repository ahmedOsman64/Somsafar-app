import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io' as io;
import 'package:image_picker/image_picker.dart';
import '../../shared/services/banner_repository.dart';
import '../../shared/models/banner_model.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/storage_service.dart';
import '../../shared/widgets/confirmation_dialog.dart';
import '../../shared/widgets/app_network_image.dart';

class AdminBannerManagerScreen extends ConsumerStatefulWidget {
  const AdminBannerManagerScreen({super.key});

  @override
  ConsumerState<AdminBannerManagerScreen> createState() =>
      _AdminBannerManagerScreenState();
}

class _AdminBannerManagerScreenState
    extends ConsumerState<AdminBannerManagerScreen> {
  bool _isRefreshing = false;

  Future<void> _refresh() async {
    setState(() => _isRefreshing = true);
    await ref.read(bannerProvider.notifier).refresh();
    if (mounted) setState(() => _isRefreshing = false);
  }

  void _showAddDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _BannerFormSheet(
        title: 'Add New Banner',
        onSave: (imageUrl, caption, _) async {
          return await ref
              .read(bannerProvider.notifier)
              .addBanner(imageUrl, caption);
        },
      ),
    );
  }

  void _showEditDialog(BannerImage banner) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _BannerFormSheet(
        title: 'Edit Banner',
        initialImageUrl: banner.imageUrl,
        initialCaption: banner.caption ?? '',
        onSave: (imageUrl, caption, _) async {
          return await ref
              .read(bannerProvider.notifier)
              .updateBanner(banner.id, imageUrl: imageUrl, caption: caption);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final banners = ref.watch(bannerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Banners'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: _isRefreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _isRefreshing ? null : _refresh,
          ),
        ],
      ),
      body: banners.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.image_outlined, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No banners yet',
                    style: TextStyle(color: Colors.grey[600], fontSize: 18),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh'),
                  ),
                ],
              ),
            )
          : ReorderableListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: banners.length,
              onReorder: (oldIndex, newIndex) {
                if (oldIndex < newIndex) {
                  newIndex -= 1;
                }
                final items = List<BannerImage>.from(banners);
                final item = items.removeAt(oldIndex);
                items.insert(newIndex, item);
                ref.read(bannerProvider.notifier).updateOrder(items);
              },
              itemBuilder: (context, index) {
                final banner = banners[index];
                return _BannerListTile(
                  key: ValueKey(banner.id),
                  banner: banner,
                  onEdit: () => _showEditDialog(banner),
                  onDelete: () async {
                    final confirmed = await ConfirmationDialog.show(
                      context: context,
                      title: 'Delete Banner?',
                      message: 'Are you sure you want to delete this banner?',
                      confirmLabel: 'Yes, Delete',
                      type: ConfirmationDialogType.danger,
                      icon: Icons.delete_forever_outlined,
                    );
                    if (confirmed == true) {
                      ref.read(bannerProvider.notifier).removeBanner(banner.id);
                    }
                  },
                  onToggle: () async {
                    final isActivating = !banner.isActive;
                    final actionVerb = isActivating ? 'Activate' : 'Deactivate';
                    final confirmed = await ConfirmationDialog.show(
                      context: context,
                      title: '$actionVerb Banner?',
                      message: 'Do you want to $actionVerb this banner?',
                      type: ConfirmationDialogType.info,
                      icon: isActivating ? Icons.visibility : Icons.visibility_off,
                    );
                    if (confirmed == true) {
                      ref.read(bannerProvider.notifier).toggleStatus(banner.id);
                    }
                  },
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: banners.length >= 10 ? null : _showAddDialog,
        backgroundColor: banners.length >= 10 ? Colors.grey : AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text('Add Banner (${banners.length}/10)'),
      ),
    );
  }
}

// ─── Reusable form sheet for Add & Edit ────────────────────────────────────────

class _BannerFormSheet extends StatefulWidget {
  final String title;
  final String initialImageUrl;
  final String initialCaption;

  /// Returns error string on failure, null on success.
  final Future<String?> Function(String imageUrl, String caption, XFile? file)
      onSave;

  const _BannerFormSheet({
    required this.title,
    required this.onSave,
    this.initialImageUrl = '',
    this.initialCaption = '',
  });

  @override
  State<_BannerFormSheet> createState() => _BannerFormSheetState();
}

class _BannerFormSheetState extends State<_BannerFormSheet> {
  late final TextEditingController _imageUrlController;
  late final TextEditingController _captionController;
  XFile? _selectedFile;
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _imageUrlController = TextEditingController(text: widget.initialImageUrl);
    _captionController = TextEditingController(text: widget.initialCaption);
  }

  @override
  void dispose() {
    _imageUrlController.dispose();
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedFile = image;
        _imageUrlController.text = image.name;
      });
    }
  }

  Future<void> _submit() async {
    final captionText = _captionController.text.trim();

    if (_selectedFile == null && _imageUrlController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an image or enter a URL')),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      String imageUrl = _imageUrlController.text.trim();

      // Upload local file if selected
      if (_selectedFile != null) {
        final uploadedUrl = await StorageService.uploadImage(
          _selectedFile!,
          folder: 'banners',
        );
        if (uploadedUrl == null) throw Exception('Image upload failed');
        imageUrl = uploadedUrl;
      }

      final error = await widget.onSave(imageUrl, captionText, _selectedFile);

      if (!mounted) return;

      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: Colors.red),
        );
      } else {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.title} successful!'),
            backgroundColor: Colors.green,
          ),
        );
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

  @override
  Widget build(BuildContext context) {
    return Container(
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
            Text(
              widget.title,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),

            // Image preview / picker
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                width: double.infinity,
                height: 160,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: _buildImagePreview(),
              ),
            ),

            const SizedBox(height: 16),

            // URL field
            TextField(
              controller: _imageUrlController,
              decoration: const InputDecoration(
                labelText: 'Image URL (auto-filled on pick)',
                hintText: 'https://...',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            // Caption field
            TextField(
              controller: _captionController,
              decoration: const InputDecoration(
                labelText: 'Caption (Optional)',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isUploading ? null : _submit,
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
                    : Text(widget.title),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
    if (_selectedFile != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: kIsWeb
            ? Image.network(_selectedFile!.path, fit: BoxFit.cover)
            : Image.file(io.File(_selectedFile!.path), fit: BoxFit.cover),
      );
    }

    // Show existing image for edit mode
    final existingUrl = widget.initialImageUrl;
    if (existingUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            AppNetworkImage(
              imageUrl: StorageService.ensurePublicUrl(existingUrl),
              fit: BoxFit.cover,
              borderRadius: 16,
              errorWidget: _emptyPicker(),
            ),
            Container(
              color: Colors.black26,
              child: const Center(
                child: Icon(Icons.edit, color: Colors.white, size: 36),
              ),
            ),
          ],
        ),
      );
    }

    return _emptyPicker();
  }

  Widget _emptyPicker() {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.add_a_photo, size: 40, color: Colors.grey),
        SizedBox(height: 8),
        Text('Tap to select image', style: TextStyle(color: Colors.grey)),
      ],
    );
  }
}

// ─── Banner list tile ──────────────────────────────────────────────────────────

class _BannerListTile extends StatelessWidget {
  final BannerImage banner;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggle;

  const _BannerListTile({
    super.key,
    required this.banner,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.drag_indicator, color: Colors.grey, size: 20),
            const SizedBox(width: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AppNetworkImage(
                imageUrl: StorageService.ensurePublicUrl(banner.imageUrl),
                width: 100,
                height: 70,
                fit: BoxFit.cover,
                borderRadius: 12,
                memCacheWidth: 200, // Optimize for list preview
                errorWidget: Container(
                  width: 100,
                  height: 70,
                  color: Colors.grey[100],
                  child: const Icon(Icons.broken_image, size: 24, color: Colors.grey),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    banner.caption?.isNotEmpty == true ? banner.caption! : 'No caption',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFF0A3D62),
                    ),
                  ),
                  const SizedBox(height: 6),
                  _buildStatusBadge(banner.isActive),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, color: Colors.blue, size: 20),
                      onPressed: onEdit,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                      onPressed: onDelete,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 30,
                  child: Switch(
                    value: banner.isActive,
                    onChanged: (_) => onToggle(),
                    activeThumbColor: AppColors.primary,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: (isActive ? Colors.green : Colors.red).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: (isActive ? Colors.green : Colors.red).withValues(alpha: 0.2),
        ),
      ),
      child: Text(
        isActive ? 'ACTIVE' : 'INACTIVE',
        style: TextStyle(
          color: isActive ? Colors.green[700] : Colors.red[700],
          fontSize: 9,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
