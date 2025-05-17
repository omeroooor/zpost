import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/post.dart';
import '../models/author.dart';

class PostStandardService {
  static const supportedImageTypes = ['.jpg', '.jpeg', '.png', '.gif'];
  static const supportedVideoTypes = ['.mp4', '.mov'];
  static const maxImageSize = 5 * 1024 * 1024; // 5MB
  static const maxVideoSize = 50 * 1024 * 1024; // 50MB
  static const _uuid = Uuid();

  // Export a post to W3-S-POST-NFT format
  static Map<String, dynamic> exportPost(Post post) {
    // First get the standard data
    final standardData = post.toW3SimplePostNFT();
    
    // Create parts array for media files
    final parts = <Map<String, dynamic>>[];
    if (post.mediaPath != null && post.mediaChecksum != null) {
      final fileName = path.basename(post.originalMediaPath ?? post.mediaPath!);
      parts.add({
        'id': _uuid.v4(), // Generate a unique ID for the part
        'name': fileName, // Don't include files/ prefix in name
        'hash': post.mediaChecksum!,
        'mimeType': post.mediaType ?? 'application/octet-stream',
        'size': 0, // This will be updated when creating the archive
      });
    }
    
    // Create the metadata that matches import requirements
    return {
      'id': _uuid.v4(), // Generate a unique ID for the post
      'name': post.name ?? post.content,
      'description': post.description ?? post.content,
      'standardName': 'W3-S-POST-NFT',
      'standardVersion': '1.0.0',
      'standardData': standardData,
      'contentHash': post.computeHash(),
      'parts': parts,
      'createdAt': post.createdAt.toIso8601String(),
      'updatedAt': post.updatedAt?.toIso8601String() ?? post.createdAt.toIso8601String(),
      'owner': post.author.publicKeyHash,
      'rps': post.reputationPoints,
    };
  }

  // Import a post from W3-S-POST-NFT format
  static Future<Post> importPost(Map<String, dynamic> data, Author author) async {
    // Validate standard
    if (data['standardName'] != 'W3-S-POST-NFT') {
      throw Exception('Invalid standard name: ${data['standardName']}');
    }
    if (data['standardVersion'] != '1.0.0') {
      throw Exception('Unsupported standard version: ${data['standardVersion']}');
    }

    // Get standard data and local data
    final standardData = data['standardData'] as Map<String, dynamic>;
    final localData = data['localData'] as Map<String, dynamic>?;
    
    // Create post from standard data
    final post = Post.fromW3SimplePostNFT(
      standardData,
      author,
      localPath: localData?['mediaPath'], // Pass local path separately
    );
    
    // Validate hash
    final computedHash = post.computeHash();
    if (data['contentHash'] != null && data['contentHash'] != computedHash) {
      debugPrint('Expected hash: ${data['contentHash']}');
      debugPrint('Computed hash: $computedHash');
      debugPrint('Standard data: $standardData');
      debugPrint('Local data: $localData');
      debugPrint('Hash computation: ');
      debugPrint('- Text: ${post.content}');
      if (post.mediaPath != null) {
        debugPrint('- Original media path: ${post.originalMediaPath ?? post.mediaPath}');
        debugPrint('- Local media path: ${post.mediaPath}');
        debugPrint('- Media type: ${post.mediaType}');
        debugPrint('- Media checksum: ${post.mediaChecksum}');
      }
      throw Exception('Content hash mismatch');
    }

    // Return post with the original content hash
    return post.copyWith(contentHash: data['contentHash']);
  }

  // Validate media file
  static Future<Map<String, String>> validateMediaFile(File file) async {
    final extension = path.extension(file.path).toLowerCase();
    
    // Check file type
    if (!isValidMediaType(extension)) {
      throw Exception(
        'Invalid media file type: $extension. Supported types: ${[...supportedImageTypes, ...supportedVideoTypes].join(", ")}',
      );
    }

    // Check file size
    final bytes = await file.readAsBytes();
    final maxSize = isVideoFile(extension) ? maxVideoSize : maxImageSize;
    
    if (bytes.length > maxSize) {
      throw Exception(
        'Media file too large: ${file.path}. Maximum size: ${maxSize ~/ (1024 * 1024)}MB',
      );
    }

    // Compute checksum
    final checksum = sha256.convert(bytes).toString();

    return {
      'path': path.basename(file.path),
      'type': getMediaType(extension),
      'checksum': checksum,
    };
  }

  static bool isValidMediaType(String extension) {
    return [...supportedImageTypes, ...supportedVideoTypes].contains(extension);
  }

  static bool isVideoFile(String extension) {
    return supportedVideoTypes.contains(extension);
  }

  static String getMediaType(String extension) {
    if (supportedImageTypes.contains(extension)) {
      return 'image';
    } else if (supportedVideoTypes.contains(extension)) {
      return 'video';
    }
    throw Exception('Unsupported media type: $extension');
  }
}
