import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import '../providers/auth_provider.dart';
import '../models/supporter.dart';

class ApiService {
  // static const String baseUrl = 'http://10.0.2.2:3100/api';
  static const String baseUrl = 'https://zpost.kbunet.net/api';
  // static const String baseUrl = 'http://localhost:3050/api';
  static AuthProvider? _authProvider;

  static void initialize(AuthProvider authProvider) {
    _authProvider = authProvider;
  }

  static Future<void> _handleUnauthorized() async {
    if (_authProvider != null) {
      await _authProvider!.logout();
    }
  }

  static Future<dynamic> _handleResponse(http.Response response) async {
    if (response.statusCode == 401) {
      await _handleUnauthorized();
      throw Exception('Session expired. Please login again.');
    }

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception(jsonDecode(response.body)['message']);
    }
  }

  static Future<List<dynamic>> _handleListResponse(http.Response response) async {
    final dynamic data = await _handleResponse(response);
    if (data is! List) {
      throw Exception('Expected list response but got ${data.runtimeType}');
    }
    return data as List<dynamic>;
  }

  static Future<Map<String, dynamic>> _handleMapResponse(http.Response response) async {
    final dynamic data = await _handleResponse(response);
    if (data is! Map<String, dynamic>) {
      throw Exception('Expected map response but got ${data.runtimeType}');
    }
    return data as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> authenticate(
    String name,
    String publicKey,
    String signature,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/authenticate'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'publicKey': publicKey,
        'signature': signature,
      }),
    );

    return _handleMapResponse(response);
  }

  static Future<Map<String, dynamic>> requestOtp(String publicKey) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/request-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'publicKey': publicKey}),
    );

    return _handleMapResponse(response);
  }

  static Future<Map<String, dynamic>> verifyOtp(String publicKey, String otp) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/verify-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'publicKey': publicKey,
        'otp': otp,
      }),
    );

    return _handleMapResponse(response);
  }

  // Check if OTP has been authorized via notification
  static Future<Map<String, dynamic>> checkOtpStatus(String publicKey) async {
    final response = await http.get(
      Uri.parse('$baseUrl/auth/check/otp?publicKey=$publicKey'),
      headers: {'Content-Type': 'application/json'},
    );

    return _handleMapResponse(response);
  }

  // Request OTP with notification option
  static Future<Map<String, dynamic>> requestOtpWithNotification(String publicKey) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/request-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'publicKey': publicKey,
        'notification': true
      }),
    );

    return _handleMapResponse(response);
  }

  // Get current user's profile
  static Future<Map<String, dynamic>> getCurrentProfile() async {
    final response = await http.get(
      Uri.parse('$baseUrl/profiles/me'),
      headers: await _getHeaders(),
    );

    return _handleMapResponse(response);
  }

  // Get profile by public key hash
  static Future<Map<String, dynamic>> getProfileByHash(String publicKeyHash) async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/profiles/$publicKeyHash'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    return _handleMapResponse(response);
  }

  static Future<Map<String, dynamic>> getProfile(String publicKeyHash) async {
    final response = await http.get(
      Uri.parse('$baseUrl/profiles/$publicKeyHash'),
      headers: await _getHeaders(),
    );

    return _handleMapResponse(response);
  }

  static Future<Map<String, dynamic>> updateProfile(String name, String? image) async {
    print('Updating profile - Name: $name, Image provided: ${image != null}');
    if (image != null) {
      print('Image base64 length: ${image.length}');
    }

    final headers = await _getHeaders();
    print('Request headers: $headers');

    final body = jsonEncode({
      'name': name,
      'image': image,
    });
    print('Request body length: ${body.length}');

    final response = await http.put(
      Uri.parse('$baseUrl/profiles'),
      headers: headers,
      body: body,
    );

    print('Profile update response status: ${response.statusCode}');
    print('Profile update response body: ${response.body}');

    return _handleMapResponse(response);
  }

  static Future<List<dynamic>> getPosts() async {
    final response = await http.get(
      Uri.parse('$baseUrl/posts'),
      headers: await _getHeaders(),
    );
    return _handleListResponse(response);
  }

  static Future<List<dynamic>> getUserPosts() async {
    final response = await http.get(
      Uri.parse('$baseUrl/posts/my-posts'),
      headers: await _getHeaders(),
    );
    return _handleListResponse(response);
  }

  static Future<List<dynamic>> getUserPostsByHash(String publicKeyHash) async {
    final response = await http.get(
      Uri.parse('$baseUrl/posts/user/$publicKeyHash'),
      headers: await _getHeaders(),
    );
    return _handleListResponse(response);
  }

  static Future<Map<String, dynamic>> getPaginatedUserPosts({
    required int page,
    required String sortBy,
    String? filter,
    bool showDrafts = false,
  }) async {
    final queryParams = {
      'page': page.toString(),
      'sortBy': sortBy,
      if (filter != null) 'filter': filter,
      'showDrafts': showDrafts.toString(),
    };

    final uri = Uri.parse('$baseUrl/posts/user-posts').replace(
      queryParameters: queryParams,
    );

    final response = await http.get(
      uri,
      headers: await _getHeaders(),
    );

    return _handleMapResponse(response);
  }

  static Future<Map<String, dynamic>> createPost(String content) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/posts'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'content': content,
      }),
    );

    return _handleMapResponse(response);
  }

  static Future<Map<String, dynamic>> updatePost(String postId, String content) async {
    final token = await getToken();
    final response = await http.put(
      Uri.parse('$baseUrl/posts/$postId'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'content': content}),
    );

    return _handleMapResponse(response);
  }

  static Future<void> deletePost(String postId) async {
    final token = await getToken();
    final response = await http.delete(
      Uri.parse('$baseUrl/posts/$postId'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode != 200) {
      throw Exception(jsonDecode(response.body)['message']);
    }
  }

  static Future<Map<String, dynamic>> confirmPost(String postId) async {
    final token = await getToken();
    final url = '$baseUrl/posts/$postId/publish';
    print('Confirming post at URL: $url');

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('Response status code: ${response.statusCode}');
      print('Response headers: ${response.headers}');
      print('Response body: ${response.body}');

      return _handleMapResponse(response);
    } catch (e) {
      print('Error in confirmPost: $e');
      rethrow;
    }
  }

  // Get drafts
  static Future<List<dynamic>> getDrafts() async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/posts/drafts'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    return _handleListResponse(response);
  }

  // Publish a post
  static Future<Map<String, dynamic>> publishPost(String postId) async {
    final token = await getToken();
    print('$baseUrl/posts/$postId/publish');
    final response = await http.post(
      Uri.parse('$baseUrl/posts/$postId/publish'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    return _handleMapResponse(response);
  }

  // Get comments for a post
  static Future<List<dynamic>> getComments(String postId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/comments/post/$postId'),
      headers: await _getHeaders(),
    );
    return _handleListResponse(response);
  }

  // Create a comment
  static Future<Map<String, dynamic>> createComment(String postId, String content) async {
    final response = await http.post(
      Uri.parse('$baseUrl/comments/post/$postId'),
      headers: await _getHeaders(),
      body: jsonEncode({'content': content}),
    );
    return _handleMapResponse(response);
  }

  // Update a comment
  static Future<Map<String, dynamic>> updateComment(String commentId, String content) async {
    final response = await http.put(
      Uri.parse('$baseUrl/comments/$commentId'),
      headers: await _getHeaders(),
      body: jsonEncode({'content': content}),
    );
    return _handleMapResponse(response);
  }

  // Delete a comment
  static Future<void> deleteComment(String commentId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/comments/$commentId'),
      headers: await _getHeaders(),
    );
    await _handleResponse(response);
  }

  // Get feed posts
  static Future<Map<String, dynamic>> getFeedPosts({
    required int page,
    required String sortBy,
    String? filter,
    required bool followedOnly,
  }) async {
    try {
      final queryParams = {
        'page': page.toString(),
        'sortBy': sortBy,
        'followedOnly': followedOnly.toString(),
        if (filter != null) 'filter': filter,
      };

      final response = await http.get(
        Uri.parse('$baseUrl/posts/feed').replace(
          queryParameters: queryParams,
        ),
        headers: await _getHeaders(),
      );

      // print('Feed response status: ${response.statusCode}');
      // print('Feed response body: ${response.body}');
      // let's loop through the posts and print them
      final data = jsonDecode(response.body);
      // let's remove the author from each post before printing
      data['posts'].forEach((post) => {
        print(post['id']),
        print(post['content']),
        print(post['mediaPath']),
      });

      return _handleMapResponse(response);
    } catch (e) {
      print('Error in getFeedPosts: $e');
      rethrow;
    }
  }

  // Get following list
  static Future<List<dynamic>> getFollowing() async {
    try {
      print('Fetching following list...');
      final response = await http.get(
        Uri.parse('$baseUrl/social/following'),
        headers: await _getHeaders(),
      );
      print('Following response status: ${response.statusCode}');
      print('Following response body: ${response.body}');
      
      if (response.statusCode == 401) {
        print('Token expired, handling unauthorized');
        await _handleUnauthorized();
        throw Exception('Session expired. Please login again.');
      }
      
      if (response.statusCode != 200) {
        final error = jsonDecode(response.body)['message'] ?? 'Failed to fetch following list';
        print('Error fetching following: $error');
        throw Exception(error);
      }
      
      final data = jsonDecode(response.body);
      print('Successfully fetched following data');
      return data;
    } catch (e, stackTrace) {
      print('Error in getFollowing: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  // Get followers list
  static Future<List<dynamic>> getFollowers() async {
    try {
      print('Fetching followers list...');
      final response = await http.get(
        Uri.parse('$baseUrl/social/followers'),
        headers: await _getHeaders(),
      );
      print('Followers response status: ${response.statusCode}');
      print('Followers response body: ${response.body}');
      
      if (response.statusCode == 401) {
        print('Token expired, handling unauthorized');
        await _handleUnauthorized();
        throw Exception('Session expired. Please login again.');
      }
      
      if (response.statusCode != 200) {
        final error = jsonDecode(response.body)['message'] ?? 'Failed to fetch followers list';
        print('Error fetching followers: $error');
        throw Exception(error);
      }
      
      final data = jsonDecode(response.body);
      print('Successfully fetched followers data');
      return data;
    } catch (e, stackTrace) {
      print('Error in getFollowers: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  // Follow a user
  static Future<void> followUser(String targetPublicKeyHash) async {
    try {
      print('Following user: $targetPublicKeyHash');
      final response = await http.post(
        Uri.parse('$baseUrl/social/follow'),
        headers: await _getHeaders(),
        body: jsonEncode({'targetPublicKeyHash': targetPublicKeyHash}),
      );
      print('Follow response status: ${response.statusCode}');
      print('Follow response body: ${response.body}');
      
      if (response.statusCode == 401) {
        print('Token expired, handling unauthorized');
        await _handleUnauthorized();
        throw Exception('Session expired. Please login again.');
      }
      
      if (response.statusCode != 200) {
        final error = jsonDecode(response.body)['message'] ?? 'Failed to follow user';
        print('Error following user: $error');
        throw Exception(error);
      }
      
      print('Successfully followed user');
    } catch (e, stackTrace) {
      print('Error in followUser: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  // Unfollow a user
  static Future<void> unfollowUser(String targetPublicKeyHash) async {
    try {
      print('Unfollowing user: $targetPublicKeyHash');
      final response = await http.post(
        Uri.parse('$baseUrl/social/unfollow'),
        headers: await _getHeaders(),
        body: jsonEncode({'targetPublicKeyHash': targetPublicKeyHash}),
      );
      print('Unfollow response status: ${response.statusCode}');
      print('Unfollow response body: ${response.body}');
      
      if (response.statusCode == 401) {
        print('Token expired, handling unauthorized');
        await _handleUnauthorized();
        throw Exception('Session expired. Please login again.');
      }
      
      if (response.statusCode != 200) {
        final error = jsonDecode(response.body)['message'] ?? 'Failed to unfollow user';
        print('Error unfollowing user: $error');
        throw Exception(error);
      }
      
      print('Successfully unfollowed user');
    } catch (e, stackTrace) {
      print('Error in unfollowUser: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  // Toggle follow status
  static Future<bool> toggleFollow(String publicKeyHash, bool currentlyFollowing) async {
    final token = await getToken();
    final endpoint = currentlyFollowing ? 'unfollow' : 'follow';
    
    final response = await http.post(
      Uri.parse('$baseUrl/social/$endpoint'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'targetPublicKeyHash': publicKeyHash,
      }),
    );

    if (response.statusCode == 200) {
      return true;
    } else {
      throw Exception(jsonDecode(response.body)['message']);
    }
  }

  // Get following list
  static Future<List<dynamic>> getFollowingList() async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/users/following'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    return _handleListResponse(response);
  }

  static Future<Map<String, dynamic>> search({
    String? query,
    String searchIn = 'both',
    int page = 1,
    int limit = 20,
  }) async {
    final queryParams = {
      if (query != null && query.isNotEmpty) 'query': query,
      'searchIn': searchIn,
      'page': page.toString(),
      'limit': limit.toString(),
    };

    final uri = Uri.parse('$baseUrl/social/search').replace(
      queryParameters: queryParams,
    );

    final response = await http.get(
      uri,
      headers: await _getHeaders(),
    );

    return _handleMapResponse(response);
  }

  static Future<Map<String, dynamic>> searchPosts({
    String? query,
    String searchIn = 'both',
    int page = 1,
    int limit = 20,
  }) async {
    final queryParams = {
      if (query != null && query.isNotEmpty) 'query': query,
      'searchIn': searchIn,
      'page': page.toString(),
      'limit': limit.toString(),
    };

    final uri = Uri.parse('$baseUrl/posts/search').replace(
      queryParameters: queryParams,
    );

    print('Search request URL: $uri');
    final response = await http.get(
      uri,
      headers: await _getHeaders(),
    );

    print('Search response status: ${response.statusCode}');
    print('Search response body: ${response.body}');

    return _handleMapResponse(response);
  }

  static Future<Map<String, dynamic>> getReputationPoints() async {
    final response = await http.get(
      Uri.parse('$baseUrl/profiles/me/rps'),
      headers: await _getHeaders(),
    );

    return _handleMapResponse(response);
  }

  // Get post supporters details
  static Future<SupportersInfo> getPostSupporters(String postHash) async {
    try {
      debugPrint('Fetching supporters for post hash: $postHash');
      final response = await http.get(
        Uri.parse('$baseUrl/posts/support/$postHash'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('Supporters data: $data');
        return SupportersInfo.fromJson(data);
      } else {
        debugPrint('Error fetching supporters: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to fetch post supporters');
      }
    } catch (e, stackTrace) {
      debugPrint('Error in getPostSupporters: $e');
      debugPrint('Stack trace: $stackTrace');
      // Return empty supporters info in case of error
      return SupportersInfo(
        contentHash: postHash,
        supporters: [],
        totalSupporters: 0,
        totalReceivedRp: 0,
        lastUpdated: null
      );
    }
  }

  static Future<void> setToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
  }

  static Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    return {
      'Content-Type': 'application/json',
      'Authorization': token != null ? 'Bearer $token' : '',
    };
  }
}
