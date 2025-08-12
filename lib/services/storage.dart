import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase/supabase_client.dart';

class StorageService {
  static Future<String> uploadAudioFile({
    required File file,
    required String userId,
    required String sessionId,
  }) async {
    print('[StorageService] Starting upload...');
    print('[StorageService] File path: ${file.path}');
    print('[StorageService] File exists: ${await file.exists()}');
    if (await file.exists()) {
      final fileSize = await file.length();
      print('[StorageService] File size: $fileSize bytes');
    }
    print('[StorageService] User ID: $userId');
    print('[StorageService] Session ID: $sessionId');

    final ext = p.extension(file.path).replaceAll('.', '').toLowerCase();
    print('[StorageService] File extension: $ext');

    // Object key must start with <userId>/ to satisfy storage RLS policies
    final path = '$userId/$sessionId.$ext'; // Corrected path
    print('[StorageService] Storage path: $path');

    final storage = SupabaseService.client.storage;
    print('[StorageService] Got storage client');

    try {
      print('[StorageService] Starting upload to audio bucket...');
      await storage
          .from('audio')
          .upload(path, file, fileOptions: const FileOptions(upsert: true));
      print('[StorageService] Upload completed successfully');
    } catch (e, stackTrace) {
      print('[StorageService] Upload failed: $e');
      print('[StorageService] Stack trace: $stackTrace');
      rethrow;
    }

    print('[StorageService] Getting public URL...');
    final publicUrl = storage.from('audio').getPublicUrl(path);
    print('[StorageService] Public URL: $publicUrl');
    return publicUrl;
  }
}
