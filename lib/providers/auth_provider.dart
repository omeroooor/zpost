import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/profile.dart';
import '../services/api_service.dart';
import '../services/key_storage_service.dart';
import '../utils/image_utils.dart';

class AuthProvider with ChangeNotifier {
  String? _token;
  String? _publicKeyHash;
  String? _name;
  String? _profileImage;
  int? _reputationPoints;
  String? _trustLevel;

  KeyStorageService? _keyStorageService;

  AuthProvider({required KeyStorageService? keyStorageService}) {
    _keyStorageService = keyStorageService;
  }

  String? get token => _token;
  String? get publicKeyHash => _publicKeyHash;
  String? get name => _name;
  String? get profileImage => _profileImage;
  int? get reputationPoints => _reputationPoints;
  String? get trustLevel => _trustLevel;

  bool get isAuthenticated => _token != null;

  Future<void> authenticate(String token, String publicKeyHash, String name) async {
    _token = token;
    _publicKeyHash = publicKeyHash;
    _name = name;
    
    // Save auth data
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
    await prefs.setString('publicKeyHash', publicKeyHash);
    await prefs.setString('name', name);
    
    await ApiService.setToken(token);
    await loadProfile();
    notifyListeners();
  }

  Future<void> loadProfile() async {
    if (_publicKeyHash == null) return;
    
    try {
      print('Loading profile for user: $_publicKeyHash');
      final profile = await ApiService.getCurrentProfile();
      print('Loaded profile: $profile');
      
      _name = profile['name'];
      _profileImage = profile['image'];
      _reputationPoints = profile['reputationPoints'] ?? 0;
      _trustLevel = profile['trustLevel'] ?? 'New';
      
      print('Updated profile state: RPs: $_reputationPoints, Trust Level: $_trustLevel');
      notifyListeners();
    } catch (e) {
      print('Error loading profile: $e');
    }
  }

  // Original method - uses base64 encoding (keeping for backward compatibility)
  Future<void> updateProfile(String name, String? image) async {
    try {
      debugPrint('AuthProvider.updateProfile - Name: $name, Image provided: ${image != null}');
      
      // Compress the image if provided
      String? processedImage = image;
      if (image != null && !image.startsWith('http')) {
        debugPrint('Original image base64 length: ${image.length}');
        
        // Only compress if image is larger than 50KB
        if (image.length > 50 * 1024) {
          processedImage = await ImageUtils.compressBase64Image(
            image,
            maxWidth: 600,
            maxHeight: 600,
            quality: 80,
            maxSizeKB: 50, // Target 50KB max size
          );
          debugPrint('Compressed image base64 length: ${processedImage.length}');
        }
      }
      
      // Call API with the compressed image
      final profile = await ApiService.updateProfile(name, processedImage);
      
      // Update local state
      _name = profile['name'];
      
      // Store the image URL or base64 string as is - no decoding
      // The UI components will handle the appropriate rendering
      _profileImage = profile['image'];
      
      _reputationPoints = profile['reputationPoints'] ?? 0;
      _trustLevel = profile['trustLevel'] ?? 'New';
      
      debugPrint('Updated profile state:');
      debugPrint('- Name: $_name');
      debugPrint('- Image updated: ${_profileImage != null}');
      debugPrint('- Image type: ${_profileImage?.startsWith('http') == true ? 'URL' : 'base64'}');
      debugPrint('- RPs: $_reputationPoints');
      debugPrint('- Trust Level: $_trustLevel');
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error updating profile: $e');
      rethrow;
    }
  }
  
  // New method - uses file upload instead of base64 encoding
  Future<void> updateProfileWithFile(String name, dynamic imageFile) async {
    try {
      debugPrint('AuthProvider.updateProfileWithFile - Name: $name, Image file provided: ${imageFile != null}');
      debugPrint('Platform: ${kIsWeb ? 'Web' : 'Native'}');
      debugPrint('Image file type: ${imageFile?.runtimeType}');
      
      // Call API with the image file (works with both File and XFile)
      final profile = await ApiService.updateProfileWithFile(name, imageFile);
      
      // Update local state
      _name = profile['name'];
      
      // Store the image URL or base64 string as is - no decoding
      // The UI components will handle the appropriate rendering
      _profileImage = profile['image'];
      
      _reputationPoints = profile['reputationPoints'] ?? 0;
      _trustLevel = profile['trustLevel'] ?? 'New';
      
      debugPrint('Updated profile state:');
      debugPrint('- Name: $_name');
      debugPrint('- Image updated: ${_profileImage != null}');
      debugPrint('- Image type: ${_profileImage?.startsWith('http') == true ? 'URL' : 'base64'}');
      debugPrint('- RPs: $_reputationPoints');
      debugPrint('- Trust Level: $_trustLevel');
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error updating profile with file: $e');
      rethrow;
    }
  }

  Future<void> logout() async {
    try {
      // Save wallet keys before clearing preferences
      if (_keyStorageService != null) {
        final allKeys = await _keyStorageService!.getAllKeys();
        
        _token = null;
        _publicKeyHash = null;
        _name = null;
        _profileImage = null;
        _reputationPoints = null;
        _trustLevel = null;
        
        await ApiService.clearToken();
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear(); // Clear all stored data
        
        // Restore wallet keys after clearing
        for (final key in allKeys) {
          await _keyStorageService!.addKey(key.publicKey, key.label);
        }
      } else {
        _token = null;
        _publicKeyHash = null;
        _name = null;
        _profileImage = null;
        _reputationPoints = null;
        _trustLevel = null;
        
        await ApiService.clearToken();
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
      }
      
      notifyListeners();
    } catch (e) {
      print('Error during logout: $e');
      rethrow;
    }
  }

  void setKeyStorageService(KeyStorageService service) {
    _keyStorageService = service;
  }

  Future<bool> tryAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final publicKeyHash = prefs.getString('publicKeyHash');
    final name = prefs.getString('name');

    if (token == null || publicKeyHash == null || name == null) {
      return false;
    }

    _token = token;
    _publicKeyHash = publicKeyHash;
    _name = name;

    await ApiService.setToken(token);
    
    try {
      await loadProfile();
      notifyListeners();
      return true;
    } catch (e) {
      print('Error in auto login: $e');
      // If loading profile fails (e.g., token expired), clear auth data
      await logout();
      return false;
    }
  }
}
