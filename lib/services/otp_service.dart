import 'package:flutter/services.dart';
import 'dart:async';
import 'package:app_links/app_links.dart';
import 'dart:developer' as developer;
import 'deep_link_service.dart';

class OTPService {
  static final AppLinks _appLinks = AppLinks();
  
  static void setOTPCallback(void Function(String otp) callback) {
    // Implementation can be added if needed
  }

  static void clearCallback() {
    // Implementation can be added if needed
  }
  
  static Future<bool> handleEncryptedOTP(String encryptedOtp) async {
    try {
      developer.log('OTPService: Starting OTP handling process',
          name: 'OTP_Flow');
      developer.log('OTPService: Received encrypted OTP: $encryptedOtp',
          name: 'OTP_Flow');

      // Launch the wallet for decryption
      final launched = await DeepLinkService.launchWalletForDecryption(encryptedOtp);
      
      if (!launched) {
        developer.log('OTPService: Failed to launch wallet',
            name: 'OTP_Flow',
            error: 'Wallet launch failed');
        return false;
      }

      developer.log('OTPService: Wallet launched successfully, waiting for result',
          name: 'OTP_Flow');

      // Listen for the result from the wallet
      final result = await _listenForWalletResult();
      
      developer.log('OTPService: Received result from wallet: $result',
          name: 'OTP_Flow');
          
      return result;
    } catch (e, stackTrace) {
      developer.log(
          'OTPService: Error handling encrypted OTP',
          name: 'OTP_Flow',
          error: e.toString(),
          stackTrace: stackTrace);
      return false;
    }
  }

  static Future<bool> _listenForWalletResult() async {
    try {
      developer.log('OTPService: Starting to listen for wallet result',
          name: 'OTP_Flow');

      // Wait for up to 5 minutes for the user to complete the action
      developer.log('OTPService: Setting up URI stream with 5-minute timeout',
          name: 'OTP_Flow');

      final Uri? uri = await _appLinks.uriLinkStream
          .where((uri) => uri != null)
          .map((uri) {
            developer.log('OTPService: Received URI: $uri',
                name: 'OTP_Flow');
            return uri;
          })
          .firstWhere(
            (uri) {
              final matches = uri.scheme == 'web3posts' && uri.host == 'otp-result';
              developer.log(
                  'OTPService: Checking URI match: $uri, matches=$matches',
                  name: 'OTP_Flow');
              return matches;
            },
            orElse: () {
              developer.log('OTPService: No matching URI found, using default failure URI',
                  name: 'OTP_Flow');
              return Uri.parse('web3posts://otp-result?success=false');
            },
          )
          .timeout(
            const Duration(minutes: 5),
            onTimeout: () {
              developer.log('OTPService: Timeout waiting for wallet response',
                  name: 'OTP_Flow');
              return Uri.parse('web3posts://otp-result?success=false');
            },
          );

      if (uri == null) {
        developer.log('OTPService: Received null URI',
            name: 'OTP_Flow',
            error: 'Null URI received');
        return false;
      }

      // Check the success parameter
      final success = uri.queryParameters['success'] == 'true';
      developer.log('OTPService: Final result: success=$success',
          name: 'OTP_Flow');
      return success;
    } on PlatformException catch (e, stackTrace) {
      developer.log(
          'OTPService: Platform exception while listening for result',
          name: 'OTP_Flow',
          error: e.toString(),
          stackTrace: stackTrace);
      return false;
    } catch (e, stackTrace) {
      developer.log(
          'OTPService: Error while listening for result',
          name: 'OTP_Flow',
          error: e.toString(),
          stackTrace: stackTrace);
      return false;
    }
  }

  // Initialize app links handling
  static Future<void> init() async {
    try {
      developer.log('OTPService: Initializing app links handling',
          name: 'OTP_Flow');
      // Get the initial link if the app was launched from a link
      final uri = await _appLinks.getInitialAppLink();
      if (uri != null) {
        developer.log('OTPService: App launched from link: $uri',
          name: 'OTP_Flow');
      }
    } catch (e, stackTrace) {
      developer.log(
          'OTPService: Error initializing app links',
          name: 'OTP_Flow',
          error: e.toString(),
          stackTrace: stackTrace);
    }
  }
}
