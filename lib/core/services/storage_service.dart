import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import 'package:uuid/uuid.dart';

class StorageService {
  static const String bucketName = 'somsafar';

  /// Uploads a single image to Supabase Storage
  /// Returns the public URL of the uploaded image
  static Future<String?> uploadImage(
    XFile file, {
    String folder = 'services',
    List<int>? bytes,
  }) async {
    try {
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${const Uuid().v4()}.jpg';
      final path = '$folder/$fileName';

      // Use provided bytes or read from file
      final fileBytes = bytes ?? await file.readAsBytes();
      debugPrint('DEBUG: Uploading ${fileBytes.length} bytes to $path');

      await SupabaseConfig.client.storage
          .from(bucketName)
          .uploadBinary(
            path,
            fileBytes is Uint8List ? fileBytes : Uint8List.fromList(fileBytes),
            retryAttempts: 3,
          );

      final String publicUrl = SupabaseConfig.client.storage
          .from(bucketName)
          .getPublicUrl(path);

      return publicUrl;
    } catch (e) {
      debugPrint('DEBUG: Error uploading image to Supabase: $e');
      if (e is StorageException) {
        debugPrint('DEBUG: Storage error message: ${e.message}');
      }
      rethrow; // Rethrow to let the caller handle it
    }
  }

  /// Uploads multiple images and returns their public URLs
  static Future<List<String>> uploadMultipleImages(
    List<XFile> files, {
    String folder = 'services',
  }) async {
    final List<String> urls = [];
    for (final file in files) {
      final url = await uploadImage(file, folder: folder);
      if (url != null) {
        urls.add(url);
      }
    }
    return urls;
  }

  /// Ensures a string is a valid public URL.
  /// If it's already a URL (starts with http), returns it as is.
  /// Otherwise, resolves it against the Supabase storage bucket.
  static String ensurePublicUrl(String pathOrUrl) {
    if (pathOrUrl.isEmpty) return '';
    if (pathOrUrl.startsWith('http') || pathOrUrl.startsWith('blob:')) {
      return pathOrUrl;
    }

    // Resolve relative path
    return SupabaseConfig.client.storage
        .from(bucketName)
        .getPublicUrl(pathOrUrl);
  }
}
