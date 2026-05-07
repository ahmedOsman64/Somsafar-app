import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../shared/services/highlight_repository.dart';
import '../../shared/models/highlight_model.dart';
import '../../shared/services/media_service.dart';
import '../../shared/widgets/app_network_image.dart';

class AdminHighlightsScreen extends ConsumerWidget {
  const AdminHighlightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final highlights = ref.watch(highlightProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Manage Highlights',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => _showAddHighlightDialog(context, ref),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(highlightProvider.notifier).refresh(),
        child: highlights.isEmpty
            ? SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.7,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.image_not_supported_outlined,
                            size: 80, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'No highlights found',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Pull down to refresh',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.grey[400],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: highlights.length,
                itemBuilder: (context, index) {
                  final highlight = highlights[index];
                  return _HighlightListTile(highlight: highlight);
                },
              ),
      ),
    );
  }

  void _showAddHighlightDialog(BuildContext context, WidgetRef ref) {
    final titleController = TextEditingController();
    final locationController = TextEditingController();
    final tagController = TextEditingController();
    final mediaService = MediaService();
    XFile? pickedImage;
    bool isUploading = false;

    showDialog(
      context: context,
      barrierDismissible: !isUploading,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Text('Add Highlight', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: isUploading ? null : () async {
                    final image = await mediaService.pickImage();
                    if (image != null) {
                      setModalState(() => pickedImage = image);
                    }
                  },
                  child: Container(
                    height: 150,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: pickedImage != null
                        ? kIsWeb
                            ? Image.network(pickedImage!.path, fit: BoxFit.cover)
                            : Image.file(File(pickedImage!.path), fit: BoxFit.cover)
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_photo_alternate_outlined, size: 40, color: Colors.grey[400]),
                              const SizedBox(height: 8),
                              Text('Tap to upload image', style: TextStyle(color: Colors.grey[600])),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    hintText: 'e.g., Liido Beach',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: locationController,
                  decoration: const InputDecoration(
                    labelText: 'Location',
                    hintText: 'e.g., Mogadishu',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: tagController,
                  decoration: const InputDecoration(
                    labelText: 'Tag',
                    hintText: 'e.g., Beach, History',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isUploading ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: (isUploading || pickedImage == null)
                  ? null
                  : () async {
                      if (titleController.text.isEmpty) return;

                      setModalState(() => isUploading = true);

                      // Upload image first
                      final imageUrl = await mediaService.uploadImage(pickedImage!);

                      if (imageUrl == null) {
                        setModalState(() => isUploading = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Failed to upload image')),
                          );
                        }
                        return;
                      }

                      final error = await ref.read(highlightProvider.notifier).addHighlight(
                        title: titleController.text,
                        location: locationController.text,
                        imageUrl: imageUrl,
                        tag: tagController.text,
                      );

                      if (context.mounted) {
                        if (error != null) {
                          setModalState(() => isUploading = false);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
                        } else {
                          Navigator.pop(context);
                        }
                      }
                    },
              child: isUploading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }
}

class _HighlightListTile extends ConsumerWidget {
  final TravelHighlight highlight;
  const _HighlightListTile({required this.highlight});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: AppNetworkImage(
            imageUrl: highlight.imageUrl,
            width: 60,
            height: 60,
            fit: BoxFit.cover,
            borderRadius: 8,
            memCacheWidth: 120, // Small preview
            errorWidget: Container(
              width: 60,
              height: 60,
              color: Colors.grey[200],
              child: const Icon(Icons.broken_image),
            ),
          ),
        ),
        title: Text(highlight.title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${highlight.location} • ${highlight.tag}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: highlight.isActive,
              onChanged: (_) => ref.read(highlightProvider.notifier).toggleStatus(highlight.id),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => _confirmDelete(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Highlight?'),
        content: const Text('Are you sure you want to remove this highlight?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              ref.read(highlightProvider.notifier).removeHighlight(highlight.id);
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
