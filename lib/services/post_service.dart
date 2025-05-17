import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:flutter/foundation.dart';
import '../models/post.dart';
import '../models/author.dart';
import 'post_standard_service.dart';
import 'api_service.dart';

class PostService {
  // static const String baseUrl = 'http://10.0.2.2:3100/api';
  static const String baseUrl = 'https://zpost.kbunet.net/api';
  
  // Get auth headers
  static Future<Map<String, String>> _getHeaders() async {
    final token = await ApiService.getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': token != null ? 'Bearer $token' : '',
    };
  }

  // Check if post with hash exists
  static Future<bool> _postWithHashExists(String hash) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/posts/by-hash/$hash'),
        headers: await _getHeaders(),
      );
      
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error checking post hash: $e');
      return false;
    }
  }

  // Create a new post with optional media
  static Future<Post> createPost(String content, Author author, {File? mediaFile}) async {
    try {
      Map<String, String>? mediaInfo;
      if (mediaFile != null) {
        mediaInfo = await PostStandardService.validateMediaFile(mediaFile);
      }

      final post = Post(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        author: author,
        content: content,
        mediaPath: mediaInfo?['path'],
        mediaType: mediaInfo?['type'],
        mediaChecksum: mediaInfo?['checksum'],
        createdAt: DateTime.now(),
      );

      final contentHash = post.computeHash();
      final postWithHash = post.copyWith(contentHash: contentHash);

      // Check if post with same hash exists
      if (await _postWithHashExists(contentHash)) {
        throw Exception('A post with identical content already exists');
      }

      // Create post data with hash
      final postData = postWithHash.toJson();
      final requestData = {
        ...postData,
        'contentHash': contentHash,
      };

      // Create post on server with media
      final uri = Uri.parse('$baseUrl/posts');
      final request = http.MultipartRequest('POST', uri);
      
      // Add post data
      request.fields['content'] = post.content;
      request.fields['contentHash'] = contentHash;
      request.fields['mediaPath'] = mediaInfo?['path'] ?? '';
      request.fields['mediaType'] = mediaInfo?['type'] ?? '';
      request.fields['mediaChecksum'] = mediaInfo?['checksum'] ?? '';
      
      // Add media file if present
      if (mediaFile != null) {
        request.files.add(await http.MultipartFile.fromPath(
          'media',
          mediaFile.path,
          filename: mediaInfo!['path']!,
        ));
      }

      // Add headers
      final headers = await _getHeaders();
      request.headers.addAll(headers);

      // Send request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      // Check if response is HTML instead of JSON
      if (response.headers['content-type']?.contains('text/html') == true ||
          response.body.trim().startsWith('<!DOCTYPE') ||
          response.body.trim().startsWith('<html')) {
        debugPrint('Received HTML response from server: ${response.body.substring(0, min(100, response.body.length))}...');
        throw Exception('Server returned HTML instead of JSON. Please check your network connection and authentication status.');
      }

      if (response.statusCode != 201) {
        throw Exception('Failed to create post: ${response.body}');
      }

      return postWithHash;
    } catch (e) {
      throw Exception('Error creating post: $e');
    }
  }

  // Import a post from W3-S-POST-NFT format
  static Future<Post> importPost(String jsonContent, Author author) async {
    try {
      // Check if the content looks like HTML instead of JSON
      if (jsonContent.trim().startsWith('<!DOCTYPE') || jsonContent.trim().startsWith('<html')) {
        debugPrint('Received HTML instead of JSON: ${jsonContent.substring(0, min(100, jsonContent.length))}...');
        throw Exception('Received HTML instead of JSON. Please check your network connection and authentication status.');
      }
      
      final data = json.decode(jsonContent) as Map<String, dynamic>;
      
      // Check if post with same hash exists
      if (data['contentHash'] != null && await _postWithHashExists(data['contentHash'])) {
        throw Exception('This post has already been imported');
      }
      
      // Prepare metadata for import
      final metadata = {
        'standardName': data['standardName'],
        'standardVersion': data['standardVersion'],
        'standardData': data['standardData'] ?? data['data'] ?? {},
        'localData': data['localData'],
        'contentHash': data['contentHash'],
        'createdAt': data['createdAt'],
        'updatedAt': data['updatedAt'],
        'owner': data['owner'],
        'rps': data['rps'],
      };
      
      final post = await PostStandardService.importPost(metadata, author);
      
      // Create post data with hash
      final postData = post.toJson();
      final requestData = {
        ...postData,
        'contentHash': data['contentHash'], // Original hash from metadata
        'mediaPath': post.originalMediaPath, // Use original media path for hash computation
      };

      // Create post on server with media
      final uri = Uri.parse('$baseUrl/posts');
      final request = http.MultipartRequest('POST', uri);
      
      // Add post data
      request.fields['content'] = post.content;
      request.fields['contentHash'] = data['contentHash'];
      request.fields['mediaPath'] = post.originalMediaPath ?? '';
      request.fields['mediaType'] = post.mediaType ?? '';
      request.fields['mediaChecksum'] = post.mediaChecksum ?? '';
      
      // Add media file if present
      if (post.mediaPath != null) {
        request.files.add(await http.MultipartFile.fromPath(
          'media',
          post.mediaPath!,
          filename: post.originalMediaPath!,
        ));
      }

      // Add headers
      final headers = await _getHeaders();
      request.headers.addAll(headers);

      // Send request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      // Check if response is HTML instead of JSON
      if (response.headers['content-type']?.contains('text/html') == true ||
          response.body.trim().startsWith('<!DOCTYPE') ||
          response.body.trim().startsWith('<html')) {
        debugPrint('Received HTML response from server: ${response.body.substring(0, min(100, response.body.length))}...');
        throw Exception('Server returned HTML instead of JSON. Please check your network connection and authentication status.');
      }

      if (response.statusCode != 201) {
        final error = json.decode(response.body);
        debugPrint('Server error details:');
        debugPrint('Message: ${error['message']}');
        debugPrint('Computed hash: ${error['computedHash']}');
        debugPrint('Provided hash: ${error['providedHash']}');
        debugPrint('Hash input: ${error['hashInput']}');
        debugPrint('Content: ${error['content']}');
        debugPrint('Media path: ${error['mediaPath']}');
        debugPrint('Media type: ${error['mediaType']}');
        debugPrint('Media checksum: ${error['mediaChecksum']}');
        throw Exception('Failed to import post: ${response.body}');
      }

      return post;
    } catch (e) {
      throw Exception('Error importing post: $e');
    }
  }

  // Export a post to W3-S-POST-NFT format
  static String exportPost(Post post) {
    try {
      final exportData = PostStandardService.exportPost(post);
      return json.encode(exportData);
    } catch (e) {
      throw Exception('Error exporting post: $e');
    }
  }

  // Upload media file
  static Future<void> _uploadMedia(File file, String filename) async {
    try {
      final uri = Uri.parse('$baseUrl/media');
      final request = http.MultipartRequest('POST', uri)
        ..files.add(await http.MultipartFile.fromPath(
          'media',
          file.path,
          filename: filename,
        ));

      // Add auth headers
      final headers = await _getHeaders();
      request.headers.addAll(headers);

      final response = await request.send();
      if (response.statusCode != 201) {
        throw Exception('Failed to upload media file');
      }
    } catch (e) {
      throw Exception('Error uploading media: $e');
    }
  }

  // Download media file
  static Future<Uint8List> downloadMedia(String mediaPath) async {
    try {
      debugPrint('Downloading media from: $baseUrl/posts/media/$mediaPath');
      final response = await http.get(
        Uri.parse('$baseUrl/posts/media/$mediaPath'),
        headers: await _getHeaders(),
      );

      if (response.statusCode != 200) {
        debugPrint('Failed to download media: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to download media file');
      }

      return response.bodyBytes;
    } catch (e) {
      debugPrint('Error downloading media: $e');
      throw Exception('Error downloading media: $e');
    }
  }
}
