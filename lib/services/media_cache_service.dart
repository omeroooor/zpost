import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'dart:io';

class MediaCacheService {
  static final MediaCacheService _instance = MediaCacheService._internal();
  
  factory MediaCacheService() {
    return _instance;
  }
  
  MediaCacheService._internal();
  
  // Custom cache manager with longer cache duration
  final cacheManager = CacheManager(
    Config(
      'zpost_media_cache',
      stalePeriod: const Duration(days: 7), // Keep media in cache for 7 days
      maxNrOfCacheObjects: 100, // Limit cache size
      repo: JsonCacheInfoRepository(databaseName: 'zpost_media_cache'),
      fileService: HttpFileService(),
    ),
  );
  
  // Generate a unique key for each media URL
  String _generateCacheKey(String url) {
    final bytes = utf8.encode(url);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
  
  // Get media from cache or download it (nullable version)
  Future<Uint8List?> getMedia(String url) async {
    try {
      final cacheKey = _generateCacheKey(url);
      
      // Try to get from cache first
      final fileInfo = await cacheManager.getFileFromCache(cacheKey);
      
      if (fileInfo != null) {
        debugPrint('Retrieved media from cache: $url');
        return await fileInfo.file.readAsBytes();
      }
      
      // If not in cache, download and store
      debugPrint('Downloading media: $url');
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Accept': 'application/json, image/*, video/*, */*',
        },
      );
      
      if (response.statusCode == 200) {
        // Store in cache
        await cacheManager.putFile(
          cacheKey,
          response.bodyBytes,
          key: cacheKey,
          maxAge: const Duration(days: 7),
        );
        
        return response.bodyBytes;
      } else {
        debugPrint('Failed to download media: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('Error in media cache service: $e');
      return null;
    }
  }
  
  // Non-nullable version that throws an exception if media can't be retrieved
  // Use this for widgets that require non-nullable Uint8List
  Future<Uint8List> getMediaRequired(String url) async {
    final data = await getMedia(url);
    if (data == null) {
      throw Exception('Failed to load required media from $url');
    }
    return data;
  }
  
  // Save media bytes to cache
  Future<void> saveMediaToCache(String url, Uint8List bytes) async {
    try {
      final cacheKey = _generateCacheKey(url);
      await cacheManager.putFile(
        cacheKey,
        bytes,
        key: cacheKey,
        maxAge: const Duration(days: 7),
      );
      debugPrint('Saved media to cache: $url');
    } catch (e) {
      debugPrint('Error saving media to cache: $e');
    }
  }
  
  // Alias for saveMediaToCache for better naming consistency
  Future<void> cacheMedia(String url, Uint8List bytes) async {
    return saveMediaToCache(url, bytes);
  }
  
  // Clear the entire cache
  Future<void> clearCache() async {
    await cacheManager.emptyCache();
    debugPrint('Media cache cleared');
  }
  
  // Remove a specific item from cache
  Future<void> removeFromCache(String url) async {
    final cacheKey = _generateCacheKey(url);
    await cacheManager.removeFile(cacheKey);
    debugPrint('Removed from cache: $url');
  }
}
