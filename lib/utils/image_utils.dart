import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image/image.dart' as img;

class ImageUtils {
  /// Compresses and resizes a base64 encoded image
  /// Returns a compressed base64 string
  static Future<String> compressBase64Image(String base64Image, {
    int maxWidth = 800,
    int maxHeight = 800,
    int quality = 85,
    int maxSizeKB = 100,
  }) async {
    try {
      debugPrint('Original image size: ${base64Image.length} chars');
      
      // Decode base64 to bytes
      final Uint8List bytes = base64Decode(base64Image);
      debugPrint('Decoded image size: ${bytes.length} bytes');
      
      // Determine image format
      final img.Image? decodedImage = img.decodeImage(bytes);
      if (decodedImage == null) {
        debugPrint('Failed to decode image');
        return base64Image; // Return original if decoding fails
      }
      
      // Resize the image if needed
      img.Image resizedImage = decodedImage;
      if (decodedImage.width > maxWidth || decodedImage.height > maxHeight) {
        resizedImage = img.copyResize(
          decodedImage,
          width: decodedImage.width > maxWidth ? maxWidth : null,
          height: decodedImage.height > maxHeight ? maxHeight : null,
        );
        debugPrint('Resized image: ${resizedImage.width}x${resizedImage.height}');
      }
      
      // Re-encode to PNG for compression
      final Uint8List resizedBytes = Uint8List.fromList(img.encodePng(resizedImage));
      
      // Compress the image
      final Uint8List compressedBytes = await FlutterImageCompress.compressWithList(
        resizedBytes,
        quality: quality,
        format: CompressFormat.jpeg,
      );
      
      // Check if size is still too large
      if (compressedBytes.length > maxSizeKB * 1024) {
        // Try with lower quality
        return await compressBase64Image(
          base64Image,
          maxWidth: maxWidth - 100,
          maxHeight: maxHeight - 100,
          quality: quality - 10,
          maxSizeKB: maxSizeKB,
        );
      }
      
      // Convert back to base64
      final String compressedBase64 = base64Encode(compressedBytes);
      debugPrint('Compressed image size: ${compressedBase64.length} chars');
      
      return compressedBase64;
    } catch (e) {
      debugPrint('Error compressing image: $e');
      return base64Image; // Return original if compression fails
    }
  }
}
