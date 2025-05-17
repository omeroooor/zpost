import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';
import 'package:app_links/app_links.dart';
import '../services/api_service.dart';
import '../services/otp_service.dart';
import '../providers/auth_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import './wallet_screen.dart';
import '../models/public_key_entry.dart';
import '../widgets/custom_snackbar.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  final _publicKeyController = TextEditingController();
  final _otpController = TextEditingController();
  bool _isLoading = false;
  bool _otpRequested = false;
  String? _error;
  String? _encryptedOtp;
  PublicKeyEntry? _selectedKey;
  static const _channel = MethodChannel('app.channel.shared.data');
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _uriLinkSubscription;

  @override
  void initState() {
    super.initState();
    print('=================== LOGIN SCREEN INIT ===================');
    WidgetsBinding.instance.addObserver(this);
    _resetState();
    _initDeepLinks();
  }

  @override
  void dispose() {
    print('Disposing login screen');
    _otpController.dispose();
    _publicKeyController.dispose();
    _uriLinkSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    print('App lifecycle state changed to: $state');
    if (state == AppLifecycleState.resumed) {
      print('App resumed - reinitializing deep links');
      // _resetState();
      _initDeepLinks();
    }
  }

  void _resetState() {
    print('Resetting login state');
    setState(() {
      _otpController.clear();
      _error = null;
      _encryptedOtp = null;
      _isLoading = false;
    });
  }

  Future<void> _initDeepLinks() async {
    try {
      print('=================== INIT APP LINKS ===================');
      print('Initializing deep link handling');
      
      // Cancel any existing subscription
      _uriLinkSubscription?.cancel();

      // Try to get the latest intent first
      try {
        final latestIntent = await _channel.invokeMethod<String?>('getLatestIntent');
        print('Latest intent from method channel: $latestIntent');
        if (latestIntent != null) {
          final uri = Uri.parse(latestIntent);
          print('Parsed URI from latest intent: $uri');
          _handleIncomingLink(uri);
          return; // Exit early as we have the latest intent
        }
      } catch (e) {
        print('Error getting latest intent: $e');
      }

      // If no latest intent, fall back to app_links
      print('No latest intent, falling back to app_links');

      // Handle links while the app is already started
      print('Setting up URI stream listener');
      _uriLinkSubscription = _appLinks.uriLinkStream.listen(
        (uri) {
          print('=================== NEW DEEP LINK ===================');
          print('Got uri from stream: $uri');
          _handleIncomingLink(uri);
        },
        onError: (err) {
          print('Error in URI stream: $err');
        },
        cancelOnError: false,
      );

      // Check initial URI
      final initialUri = await _appLinks.getInitialAppLink();
      print('Initial URI check completed: ${initialUri?.toString() ?? 'null'}');
      
      if (initialUri != null && _otpController.text.isEmpty) {
        print('Got initial uri: $initialUri');
        _handleIncomingLink(initialUri);
      } else {
        print('Skipping initial URI: ${_otpController.text.isEmpty ? 'no initial URI' : 'OTP already set'}');
      }

      print('Deep link initialization complete');
    } catch (e, stack) {
      print('Error initializing deep links: $e');
      print('Stack trace: $stack');
    }
  }

  void _handleIncomingLink(Uri uri) async {
    if (!mounted) {
      print('Widget not mounted, cannot handle deep link');
      return;
    }

    try {
      print('=================== HANDLING DEEP LINK ===================');
      print('Incoming link: ${uri.toString()}');
      
      if (uri.queryParameters.containsKey('otp')) {
        final otp = uri.queryParameters['otp'];
        if (otp != null && otp.isNotEmpty) {
          setState(() {
            _otpController.text = otp;
            _error = null;
          });
          await _verifyOtp();
        }
      }
    } catch (e) {
      print('Error handling deep link: $e');
      setState(() {
        _error = 'Error handling wallet response';
      });
    }
  }

  Future<void> _copyEncryptedOtp() async {
    if (_encryptedOtp != null && _error == null) {
      await Clipboard.setData(ClipboardData(text: _encryptedOtp!));
      if (mounted) {
        CustomSnackbar.showCopiedToClipboard(context, itemName: 'Encrypted OTP');
      }
    }
  }

  Future<void> _openWallet() async {
    final result = await Navigator.push<PublicKeyEntry>(
      context,
      MaterialPageRoute(
        builder: (context) => WalletScreen(
          isSelectMode: true,
          onKeySelected: _onKeySelected,
        ),
      ),
    );
  }

  void _onKeySelected(PublicKeyEntry key) {
    setState(() {
      _selectedKey = key;
      _publicKeyController.text = key.publicKey;
    });
  }

  Future<void> _requestOtp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await ApiService.requestOtp(_publicKeyController.text);
      if (mounted) {
        setState(() {
          final encryptedOtp = response['encryptedOtp'];
          if (encryptedOtp != null && encryptedOtp is Map<String, dynamic>) {
            // Format the encrypted OTP data with all required fields
            final formattedJson = {
              'ephemeralPublicKey': encryptedOtp['ephemeralPublicKey'],
              'iv': encryptedOtp['iv'],
              'encryptedMessage': encryptedOtp['encryptedMessage'],
              'publicKey': encryptedOtp['publicKey'],
              'authTag': encryptedOtp['authTag'],
              'appName': 'Z-Post',
            };

            final encoder = JsonEncoder.withIndent('  ');
            _encryptedOtp = encoder.convert(formattedJson);
            _error = null;
            _isLoading = false;
          } else {
            _error = 'Invalid encrypted OTP format from server';
            _isLoading = false;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _resetOtpRequest() {
    setState(() {
      _otpRequested = false;
      _otpController.clear();
      _encryptedOtp = null;
      _error = null;
    });
  }

  Future<void> _verifyOtp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await ApiService.verifyOtp(
        _publicKeyController.text.trim(),
        _otpController.text.trim(),
      );

      if (mounted) {
        final authProvider = context.read<AuthProvider>();
        await authProvider.authenticate(
          response['token'],
          response['publicKeyHash'],
          response['name'],
        );
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleOtpDecryption() async {
    if (_encryptedOtp == null) return;
    
    try {
      await OTPService.handleEncryptedOTP(_encryptedOtp!);
    } catch (e) {
      setState(() {
        _error = 'Failed to launch wallet: ${e.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 48),
                const Text(
                  'Welcome Back',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ),

                if (_encryptedOtp == null) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Public Key',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _publicKeyController,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              hintText: 'Enter your public key',
                              prefixIcon: Icon(Icons.key),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your public key';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _requestOtp,
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.all(16),
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : const Text('Request OTP'),
                                ),
                              ),
                              const SizedBox(width: 16),
                              ElevatedButton.icon(
                                onPressed: _openWallet,
                                icon: const Icon(Icons.account_balance_wallet),
                                label: const Text('Use Wallet'),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.all(16),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Encrypted OTP',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.account_balance_wallet),
                                    onPressed: () => _handleOtpDecryption(),
                                    tooltip: 'Open in Wallet',
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.copy),
                                    onPressed: _copyEncryptedOtp,
                                    tooltip: 'Copy encrypted OTP',
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Center(
                            child: QrImageView(
                              data: 'otp://web3posts?otp=$_encryptedOtp&callback_scheme=web3posts',
                              version: QrVersions.auto,
                              size: 200.0,
                              backgroundColor: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _otpController,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              hintText: 'Enter OTP',
                              prefixIcon: Icon(Icons.lock),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter the OTP';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              TextButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _encryptedOtp = null;
                                    _otpController.clear();
                                    _error = null;
                                  });
                                },
                                icon: const Icon(Icons.arrow_back),
                                label: const Text('Back'),
                              ),
                              ElevatedButton(
                                onPressed: _isLoading ? null : _verifyOtp,
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Text('Verify OTP'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
