import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../core/services/supabase_service.dart';

class MediaService {
  final _picker = ImagePicker();
  final _uuid = const Uuid();

  /// Picks an image from the gallery
  Future<XFile?> pickImage() async {
    try {
      return await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
    } catch (e) {
      debugPrint('Error picking image: $e');
      return null;
    }
  }

  /// Uploads an image to Supabase Storage and returns the public URL
  Future<String?> uploadImage(XFile file, {String bucket = 'somsafar'}) async {
    try {
      final fileName = '${_uuid.v4()}_${file.name}';
      final fileBytes = await file.readAsBytes();
      final path = 'highlights/$fileName';

      await SupabaseConfig.client.storage.from(bucket).uploadBinary(
            path,
            fileBytes,
            fileOptions: const FileOptions(
              cacheControl: '3600',
              upsert: false,
              contentType: 'image/jpeg',
            ),
          );

      // Get public URL
      final publicUrl = SupabaseConfig.client.storage.from(bucket).getPublicUrl(path);
      return publicUrl;
    } catch (e) {
      debugPrint('Error uploading image: $e');
      return null;
    }
  }
}
