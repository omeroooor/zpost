import 'dart:developer' as developer;
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class DeepLinkService {
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
}
