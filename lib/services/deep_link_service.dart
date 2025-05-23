import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../screens/post_details_screen.dart';
import '../providers/post_provider.dart';
import '../services/api_service.dart';
import '../models/post.dart';

class DeepLinkService {
  // Singleton instance
  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;
  DeepLinkService._internal();
  
  // Navigation key for handling deep links when app is already running
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  static Future<void> _launchWalletUrl(String urlString) async {
    try {
      developer.log('DeepLinkService: Preparing to launch wallet with URL: $urlString',
          name: 'DeepLink_Flow');
          
      try {
        // Use Intent.ACTION_VIEW directly
        final intent = await const MethodChannel('app.channel.shared.data')
            .invokeMethod<bool>('launchUrl', {
          'url': urlString,
          'action': 'android.intent.action.VIEW'
        });
        
        developer.log(
            'DeepLinkService: Launch ${intent == true ? 'successful' : 'failed'}',
            name: 'DeepLink_Flow');
            
      } catch (e) {
        developer.log(
            'DeepLinkService: Error launching intent, falling back to URL launcher',
            name: 'DeepLink_Flow',
            error: e.toString());
            
        // Fallback to URL launcher if intent fails
        final url = Uri.parse(urlString);
        if (await canLaunchUrl(url)) {
          await launchUrl(
            url,
            mode: LaunchMode.externalNonBrowserApplication,
          );
        } else {
          throw Exception('Could not launch $urlString');
        }
      }
    } catch (e, stackTrace) {
      developer.log(
          'DeepLinkService: Error launching wallet',
          name: 'DeepLink_Flow',
          error: e.toString(),
          stackTrace: stackTrace);
      rethrow;
    }
  }

  static Future<void> launchWalletForReputation(String hash) async {
    final url = 'bluewallet:send?addresses=$hash-0.001-reputation';
    await _launchWalletUrl(url);
  }

  static Future<void> launchWalletForVerify(String hash) async {
    final url = 'bluewallet:verify?profile=$hash';
    await _launchWalletUrl(url);
  }

  static Future<bool> launchWalletForDecryption(String encryptedOtp) async {
    try {
      developer.log('DeepLinkService: Preparing to launch wallet',
          name: 'OTP_Flow');
      developer.log('DeepLinkService: Encrypted OTP: $encryptedOtp',
          name: 'OTP_Flow');
      
      // Create the deep link URL with new structure
      final urlString = 'otp://web3posts?otp=$encryptedOtp&callback_scheme=web3posts';
      
      developer.log('DeepLinkService: Generated URL: $urlString',
          name: 'OTP_Flow');
      
      await _launchWalletUrl(urlString);
      return true;
    } catch (e, stackTrace) {
      developer.log(
          'DeepLinkService: Error launching wallet',
          name: 'OTP_Flow',
          error: e.toString(),
          stackTrace: stackTrace);
      return false;
    }
  }
  
  // Handle post deep links
  Future<void> handlePostDeepLink(Uri uri) async {
    try {
      // Log the full URI for debugging
      developer.log('DeepLinkService: Handling post deep link: ${uri.toString()}',
          name: 'DeepLink_Flow');
      
      // Extract post ID from the URL path
      final pathSegments = uri.pathSegments;
      
      // Debug log all path segments
      developer.log('DeepLinkService: Path segments: $pathSegments',
          name: 'DeepLink_Flow');
      
      if (pathSegments.length >= 2 && pathSegments[0] == 'posts') {
        // Extract the post ID (second segment in the path)
        final postId = pathSegments[1];
        developer.log('DeepLinkService: Extracted post ID: $postId',
            name: 'DeepLink_Flow');
        
        // Make sure we have a valid context
        if (navigatorKey.currentContext != null) {
          // Show loading indicator
          ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
            const SnackBar(
              content: Text('Loading post...'),
              duration: Duration(seconds: 2),
            ),
          );
          
          // Get the PostProvider from the context
          final postProvider = Provider.of<PostProvider>(navigatorKey.currentContext!, listen: false);
          
          // Fetch the post using the provider
          developer.log('DeepLinkService: Fetching post with ID: $postId',
              name: 'DeepLink_Flow');
          final post = await postProvider.fetchPostById(postId);
          
          // Navigate to post details if found
          if (post != null) {
            developer.log('DeepLinkService: Post found, navigating to details',
                name: 'DeepLink_Flow');
            
            // If we can pop, we're not on the home screen, so navigate to home first
            if (navigatorKey.currentState!.canPop()) {
              // Pop until we reach the home screen
              navigatorKey.currentState!.popUntil((route) => route.isFirst);
            }
            
            // Navigate to post details
            navigatorKey.currentState!.push(
              MaterialPageRoute(
                builder: (context) => PostDetailsScreen(post: post),
              ),
            );
          } else {
            developer.log('DeepLinkService: Post not found',
                name: 'DeepLink_Flow');
            
            // Show a simple snackbar if post not found
            ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
              const SnackBar(
                content: Text('Post not found. It may have been deleted or is not available.'),
                duration: Duration(seconds: 3),
              ),
            );
          }
        }
      } else {
        developer.log('DeepLinkService: Invalid post URL format',
            name: 'DeepLink_Flow');
      }
    } catch (e, stackTrace) {
      developer.log(
          'DeepLinkService: Error handling post deep link',
          name: 'DeepLink_Flow',
          error: e.toString(),
          stackTrace: stackTrace);
      
      // Show error message if context is available
      if (navigatorKey.currentContext != null) {
        ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
          SnackBar(
            content: Text('Error loading post: ${e.toString()}'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
}
