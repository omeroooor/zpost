import 'dart:io';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/post.dart';

class PostProvider with ChangeNotifier {
  List<Post> _posts = [];
  List<Post> _userPosts = [];
  List<Post> _drafts = [];
  bool _isLoading = false;

  List<Post> get posts => _posts;
  List<Post> get userPosts => _userPosts;
  List<Post> get drafts => _drafts;
  bool get isLoading => _isLoading;

  Future<void> fetchPosts() async {
    if (_isLoading) return;
    
    _isLoading = true;
    notifyListeners();

    try {
      final response = await ApiService.getPosts();
      if (response is! List) {
        throw Exception('Invalid response format');
      }
      
      _posts = response
          .map((data) {
            if (data is! Map<String, dynamic>) {
              throw Exception('Invalid post data format');
            }
            try {
              return Post.fromJson(data);
            } catch (e) {
              print('Error parsing post: $e');
              print('Post data: $data');
              rethrow;
            }
          })
          .toList();
    } catch (e) {
      print('Error fetching posts: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchUserPosts() async {
    if (_isLoading) return;
    
    _isLoading = true;
    notifyListeners();

    try {
      final response = await ApiService.getUserPosts();
      if (response is! List) {
        throw Exception('Invalid response format');
      }
      
      _userPosts = response
          .map((data) {
            if (data is! Map<String, dynamic>) {
              throw Exception('Invalid post data format');
            }
            return Post.fromJson(data);
          })
          .toList();
    } catch (e) {
      print('Error fetching user posts: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Post> createPost(String content, {dynamic mediaFile, String? mediaType, List<int>? mediaBytes, String? fileName}) async {
    try {
      final postData = await ApiService.createPost(
        content, 
        mediaFile: mediaFile, 
        mediaType: mediaType,
        mediaBytes: mediaBytes,
        fileName: fileName
      );
      if (postData is! Map<String, dynamic>) {
        throw Exception('Invalid post data format');
      }
      final post = Post.fromJson(postData);
      _userPosts.insert(0, post);
      notifyListeners();
      return post;
    } catch (e) {
      print('Error creating post: $e');
      rethrow;
    }
  }

  Future<Post> updatePost(String postId, String content) async {
    try {
      final postData = await ApiService.updatePost(postId, content);
      if (postData is! Map<String, dynamic>) {
        throw Exception('Invalid post data format');
      }
      final post = Post.fromJson(postData);
      
      // Update in userPosts
      final userPostIndex = _userPosts.indexWhere((p) => p.id == postId);
      if (userPostIndex != -1) {
        _userPosts[userPostIndex] = post;
      }

      // Update in posts if it exists there
      final postIndex = _posts.indexWhere((p) => p.id == postId);
      if (postIndex != -1) {
        _posts[postIndex] = post;
      }

      notifyListeners();
      return post;
    } catch (e) {
      print('Error updating post: $e');
      rethrow;
    }
  }

  Future<Post> confirmPost(String postId) async {
    try {
      final postData = await ApiService.confirmPost(postId);
      if (postData is! Map<String, dynamic>) {
        throw Exception('Invalid post data format');
      }
      final post = Post.fromJson(postData);
      
      // Update in userPosts
      final index = _userPosts.indexWhere((p) => p.id == postId);
      if (index != -1) {
        _userPosts[index] = post;
      }

      // Add to main posts list if not already there
      if (!_posts.any((p) => p.id == postId)) {
        _posts.insert(0, post);
      }

      notifyListeners();
      return post;
    } catch (e) {
      print('Error confirming post: $e');
      rethrow;
    }
  }

  Future<void> deletePost(String postId) async {
    try {
      await ApiService.deletePost(postId);
      _userPosts.removeWhere((p) => p.id == postId);
      _posts.removeWhere((p) => p.id == postId);
      _drafts.removeWhere((p) => p.id == postId);
      notifyListeners();
    } catch (e) {
      print('Error deleting post: $e');
      rethrow;
    }
  }

  Future<Post> createDraft(String content) async {
    try {
      final postData = await ApiService.createPost(content);
      if (postData is! Map<String, dynamic>) {
        throw Exception('Invalid post data format');
      }
      final post = Post.fromJson(postData);
      _drafts.insert(0, post);
      notifyListeners();
      return post;
    } catch (e) {
      print('Error creating draft: $e');
      rethrow;
    }
  }

  Future<Post> updateDraft(String postId, String content) async {
    try {
      final postData = await ApiService.updatePost(postId, content);
      if (postData is! Map<String, dynamic>) {
        throw Exception('Invalid post data format');
      }
      final post = Post.fromJson(postData);
      final index = _drafts.indexWhere((p) => p.id == postId);
      if (index != -1) {
        _drafts[index] = post;
        notifyListeners();
      }
      return post;
    } catch (e) {
      print('Error updating draft: $e');
      rethrow;
    }
  }

  Future<void> deleteDraft(String postId) async {
    try {
      await ApiService.deletePost(postId);
      _drafts.removeWhere((p) => p.id == postId);
      notifyListeners();
    } catch (e) {
      print('Error deleting draft: $e');
      rethrow;
    }
  }

  Future<void> publishPost(String postId) async {
    try {
      final postData = await ApiService.publishPost(postId);
      if (postData is! Map<String, dynamic>) {
        throw Exception('Invalid post data format');
      }
      final updatedPost = Post.fromJson(postData);
      final index = _drafts.indexWhere((post) => post.id == postId);
      if (index != -1) {
        _drafts.removeAt(index);
      }
      _posts = [updatedPost, ..._posts];
      notifyListeners();
    } catch (e) {
      print('Error publishing post: $e');
      rethrow;
    }
  }

  Future<void> fetchDrafts() async {
    if (_isLoading) return;
    
    _isLoading = true;
    notifyListeners();

    try {
      final response = await ApiService.getDrafts();
      if (response is! List) {
        throw Exception('Invalid response format');
      }
      
      _drafts = response
          .map((data) {
            if (data is! Map<String, dynamic>) {
              throw Exception('Invalid post data format');
            }
            return Post.fromJson(data);
          })
          .toList();
    } catch (e) {
      print('Error fetching drafts: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
