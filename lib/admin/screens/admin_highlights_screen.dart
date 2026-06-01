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
                        Icon(
                          Icons.image_not_supported_outlined,
                          size: 80,
                          color: Colors.grey[400],
                        ),
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
    final descriptionController = TextEditingController();
    final tagController = TextEditingController();
    final mediaService = MediaService();
    XFile? pickedImage;
    bool isUploading = false;

    showDialog(
      context: context,
      barrierDismissible: !isUploading,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Text(
            'Add Highlight',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: isUploading
                      ? null
                      : () async {
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
                              ? Image.network(
                                  pickedImage!.path,
                                  fit: BoxFit.cover,
                                )
                              : Image.file(
                                  File(pickedImage!.path),
                                  fit: BoxFit.cover,
                                )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_photo_alternate_outlined,
                                size: 40,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Tap to upload image',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title (Optional)',
                    hintText: 'If empty, Location will be used',
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
                  controller: descriptionController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'Enter detailed information about this highlight...',
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
              onPressed: isUploading
                  ? null
                  : () async {
                      final title = titleController.text.trim();
                      final location = locationController.text.trim();
                      final description = descriptionController.text.trim();
                      final tag = tagController.text.trim();

                      if (pickedImage == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please pick an image')),
                        );
                        return;
                      }

                      if (location.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter location')),
                        );
                        return;
                      }

                      setModalState(() => isUploading = true);

                      try {
                        // Upload image first
                        final imageUrl = await mediaService.uploadImage(
                          pickedImage!,
                        );

                        if (imageUrl == null) {
                          setModalState(() => isUploading = false);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Failed to upload image'),
                              ),
                            );
                          }
                          return;
                        }

                        final error = await ref
                            .read(highlightProvider.notifier)
                            .addHighlight(
                              title: title.isEmpty ? location : title,
                              location: location,
                              description: description,
                              imageUrl: imageUrl,
                              tag: tag,
                            );

                        if (context.mounted) {
                          if (error != null) {
                            setModalState(() => isUploading = false);
                            ScaffoldMessenger.of(
                              context,
                            ).showSnackBar(SnackBar(content: Text(error)));
                          } else {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Highlight added successfully')),
                            );
                          }
                        }
                      } catch (e) {
                        setModalState(() => isUploading = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e')),
                          );
                        }
                      }
                    },
              child: isUploading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
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
        title: Text(
          highlight.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('${highlight.location} • ${highlight.tag}'),
        trailing: Wrap(
          spacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Transform.scale(
              scale: 0.8,
              child: Switch(
                value: highlight.isActive,
                onChanged: (val) => ref
                    .read(highlightProvider.notifier)
                    .toggleStatus(highlight.id, val),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: Colors.blue, size: 22),
              onPressed: () => _showEditHighlightDialog(context, ref),
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.all(8),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 22),
              onPressed: () => _confirmDelete(context, ref),
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.all(8),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditHighlightDialog(BuildContext context, WidgetRef ref) {
    final titleController = TextEditingController(text: highlight.title);
    final locationController = TextEditingController(text: highlight.location);
    final descriptionController =
        TextEditingController(text: highlight.description);
    final tagController = TextEditingController(text: highlight.tag);
    final mediaService = MediaService();
    XFile? pickedImage;
    bool isUploading = false;

    showDialog(
      context: context,
      barrierDismissible: !isUploading,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Text(
            'Edit Highlight',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: isUploading
                      ? null
                      : () async {
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
                        : (highlight.imageUrl.isNotEmpty
                            ? AppNetworkImage(
                                imageUrl: highlight.imageUrl,
                                fit: BoxFit.cover,
                                borderRadius: 12,
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add_photo_alternate_outlined,
                                    size: 40,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Tap to change image',
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                                ],
                              )),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title (Optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: locationController,
                  decoration: const InputDecoration(
                    labelText: 'Location',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descriptionController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: tagController,
                  decoration: const InputDecoration(
                    labelText: 'Tag',
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
              onPressed: isUploading
                  ? null
                  : () async {
                      final title = titleController.text.trim();
                      final location = locationController.text.trim();
                      if (location.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter location')),
                        );
                        return;
                      }

                      setModalState(() => isUploading = true);

                      try {
                        String? finalImageUrl;
                        if (pickedImage != null) {
                          finalImageUrl =
                              await mediaService.uploadImage(pickedImage!);
                        }

                        final error = await ref
                            .read(highlightProvider.notifier)
                            .updateHighlight(
                              highlight.id,
                              title: title.isEmpty ? location : title,
                              location: location,
                              description: descriptionController.text.trim(),
                              imageUrl: finalImageUrl,
                              tag: tagController.text.trim(),
                            );

                        if (context.mounted) {
                          if (error != null) {
                            setModalState(() => isUploading = false);
                            ScaffoldMessenger.of(context)
                                .showSnackBar(SnackBar(content: Text(error)));
                          } else {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Highlight updated successfully')),
                            );
                          }
                        }
                      } catch (e) {
                        setModalState(() => isUploading = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e')),
                          );
                        }
                      }
                    },
              child: isUploading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Save'),
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
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref
                  .read(highlightProvider.notifier)
                  .removeHighlight(highlight.id);
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
