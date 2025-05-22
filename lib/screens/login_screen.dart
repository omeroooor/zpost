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
import '../utils/responsive_layout.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _publicKeyController = TextEditingController();
  final _otpController = TextEditingController();
  final _otpFocusNode = FocusNode(); // Focus node for OTP input field
  bool _isLoading = false;
  bool _otpRequested = false;
  bool _isCheckingNotification = false;
  String? _error;
  String? _encryptedOtp;
  PublicKeyEntry? _selectedKey;
  static const _channel = MethodChannel('app.channel.shared.data');
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _uriLinkSubscription;
  Timer? _notificationCheckTimer;
  Timer? _notificationTimeoutTimer; // Timer for notification login timeout
  
  // Animation controller for the vault key icon
  late AnimationController _keyIconAnimationController;
  late Animation<double> _keyIconAnimation;

  @override
  void initState() {
    super.initState();
    print('=================== LOGIN SCREEN INIT ===================');
    WidgetsBinding.instance.addObserver(this);
    _resetState();
    _initDeepLinks();
    
    // Initialize animation controller for the vault key icon
    _keyIconAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    // Create a pulse animation
    _keyIconAnimation = Tween<double>(
      begin: 1.0,
      end: 1.25,
    ).animate(CurvedAnimation(
      parent: _keyIconAnimationController,
      curve: Curves.easeInOut,
    ));
    
    // Start periodic animation
    Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) {
        _keyIconAnimationController.forward().then((_) {
          _keyIconAnimationController.reverse();
        });
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    print('Disposing login screen');
    _otpController.dispose();
    _publicKeyController.dispose();
    _otpFocusNode.dispose(); // Dispose focus node
    _uriLinkSubscription?.cancel();
    _notificationCheckTimer?.cancel();
    _notificationTimeoutTimer?.cancel(); // Cancel timeout timer
    _keyIconAnimationController.dispose(); // Dispose animation controller
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
    _notificationCheckTimer?.cancel();
    _notificationTimeoutTimer?.cancel(); // Cancel timeout timer
    setState(() {
      _otpController.clear();
      _error = null;
      _encryptedOtp = null;
      _isLoading = false;
      _isCheckingNotification = false;
      _otpRequested = false;
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
    final selectedKey = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => const WalletScreen(),
      ),
    );
  
    if (selectedKey != null && mounted) {
      setState(() {
        _publicKeyController.text = selectedKey;
      });
    }
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
            _otpRequested = true;
            
            // Move focus to OTP input field
            if (mounted) {
              Future.delayed(const Duration(milliseconds: 300), () {
                _otpFocusNode.requestFocus();
              });
            }
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

  void _resetOtpRequest() async {
    _notificationCheckTimer?.cancel();
    setState(() {
      _encryptedOtp = null;
      _otpController.clear();
      _error = null;
      _isCheckingNotification = false;
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
  
  // Request OTP with notification and start polling for authorization
  Future<void> _requestOtpWithNotification() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Cancel any existing timers
    _notificationCheckTimer?.cancel();
    _notificationTimeoutTimer?.cancel();
    
    setState(() {
      _isLoading = true;
      _isCheckingNotification = true;
      _error = null;
    });
    
    try {
      // Request OTP with notification flag
      await ApiService.requestOtpWithNotification(_publicKeyController.text.trim());
      
      if (mounted) {
        setState(() {
          _isLoading = false;
          CustomSnackbar.show(
            context,
            message: 'Notification sent! Please check your device.',
          );
        });
        
        // Start polling for authorization
        _startPollingForAuthorization();
        
        // Set a timeout for notification-based login (2 minutes)
        _notificationTimeoutTimer = Timer(const Duration(minutes: 2), () {
          if (mounted && _isCheckingNotification) {
            _notificationCheckTimer?.cancel();
            setState(() {
              _isCheckingNotification = false;
              CustomSnackbar.showError(
                context,
                message: 'Login request timed out. Please try again.',
              );
            });
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
          _isCheckingNotification = false;
        });
      }
    }
  }
  
  // Start polling for authorization status
  void _startPollingForAuthorization() {
    // Check every 3 seconds
    _notificationCheckTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      try {
        print('Checking OTP authorization status...');
        final response = await ApiService.checkOtpStatus(_publicKeyController.text.trim());
        
        // If authorized, handle the login
        if (response['authorized'] == true) {
          print('OTP authorized via notification!');
          timer.cancel();
          
          if (mounted) {
            final authProvider = context.read<AuthProvider>();
            await authProvider.authenticate(
              response['token'],
              response['publicKeyHash'],
              response['name'],
            );
            
            setState(() {
              _isCheckingNotification = false;
            });
          }
        } else {
          print('OTP not yet authorized...');
        }
      } catch (e) {
        print('Error checking OTP status: $e');
        // Don't stop polling on error, just continue
      }
    });
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isWeb = ResponsiveLayout.isWeb();
    final isDesktop = ResponsiveLayout.isDesktop(context);
    final isMobile = ResponsiveLayout.isMobile(context);
    
    return Scaffold(
      body: SafeArea(
        child: isDesktop || (!isMobile && isWeb)
            ? _buildWebLayout(context, theme, colorScheme)
            : _buildMobileLayout(context, theme, colorScheme),
      ),
    );
  }
  
  Widget _buildWebLayout(BuildContext context, ThemeData theme, ColorScheme colorScheme) {
    return Row(
      children: [
        // Left side - Branding and information
        Expanded(
          flex: 5,
          child: Container(
            color: colorScheme.primary,
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 40),
                  Row(
                    children: [
                      Icon(
                        Icons.account_balance_wallet,
                        size: 48,
                        color: colorScheme.onPrimary,
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'Z-Post',
                        style: theme.textTheme.displayMedium?.copyWith(
                          color: colorScheme.onPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Web3 Social Media Platform',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: colorScheme.onPrimary.withOpacity(0.9),
                    ),
                  ),
                  const SizedBox(height: 40),
                  Text(
                    'Connect with your wallet',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: colorScheme.onPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'ZPost is a decentralized social media platform that puts you in control of your data and content.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onPrimary.withOpacity(0.8),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '• Secure authentication with your wallet\n• Own your content with blockchain verification\n• Earn reputation points for quality contributions\n• No centralized data collection',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onPrimary.withOpacity(0.8),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    ' 2023 ZPost',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onPrimary.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Right side - Login form
        Expanded(
          flex: 4,
          child: Container(
            color: theme.scaffoldBackgroundColor,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32.0),
              child: _buildLoginForm(context, theme, colorScheme, isWeb: true),
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildMobileLayout(BuildContext context, ThemeData theme, ColorScheme colorScheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 40),
          Center(
            child: Column(
              children: [
                Icon(
                  Icons.account_balance_wallet,
                  size: 48,
                  color: colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Z-Post',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Web3 Social Media Platform',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          _buildLoginForm(context, theme, colorScheme, isWeb: false),
        ],
      ),
    );
  }
  
  Widget _buildLoginForm(BuildContext context, ThemeData theme, ColorScheme colorScheme, {required bool isWeb}) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colorScheme.error.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: colorScheme.error),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _error!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
          if (_encryptedOtp == null) ...[
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              color: colorScheme.surface,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sign In',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Enter your public key hash or connect with your wallet',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _publicKeyController,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        labelText: 'Public Key Hash',
                        hintText: 'Enter your public key hash',
                        suffixIcon: ScaleTransition(
                          scale: _keyIconAnimation,
                          child: IconButton(
                            icon: const Icon(Icons.vpn_key),
                            tooltip: 'Open Vault',
                            onPressed: _openWallet,
                          ),
                        ),
                        filled: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your public key hash';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 50,
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _requestOtp,
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isLoading
                            ? SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: colorScheme.onPrimary,
                                ),
                              )
                            : Text(
                                'Request OTP',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: colorScheme.onPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 50,
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isCheckingNotification ? null : _requestOtpWithNotification,
                        icon: _isCheckingNotification 
                            ? SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: colorScheme.primary,
                                ),
                              )
                            : const Icon(Icons.notifications_active),
                        label: Text(
                          'Login with Notification',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            // Spacer
            const SizedBox(height: 16),
          ],
          if (_encryptedOtp != null) ...[
            // OTP verification UI
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              color: colorScheme.surface,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Verify OTP',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.qr_code_scanner, 
                          size: 16, 
                          color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7)
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Scan QR or enter OTP manually',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                     // QR code section
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colorScheme.primary.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Action buttons in a row at the top
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              // Wallet button
                              IconButton.filled(
                                icon: Icon(Icons.account_balance_wallet, size: 20),
                                onPressed: () => _handleOtpDecryption(),
                                tooltip: 'Open in Wallet',
                                style: IconButton.styleFrom(
                                  backgroundColor: colorScheme.primaryContainer,
                                  foregroundColor: colorScheme.onPrimaryContainer,
                                  minimumSize: const Size(40, 40),
                                  padding: EdgeInsets.zero,
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Copy button
                              IconButton.filled(
                                icon: Icon(Icons.copy, size: 20),
                                onPressed: _copyEncryptedOtp,
                                tooltip: 'Copy encrypted OTP',
                                style: IconButton.styleFrom(
                                  backgroundColor: colorScheme.primaryContainer,
                                  foregroundColor: colorScheme.onPrimaryContainer,
                                  minimumSize: const Size(40, 40),
                                  padding: EdgeInsets.zero,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Larger QR code with more space
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 10,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: QrImageView(
                              // Create a properly formatted JSON object for the wallet app
                              data: _encryptedOtp!,
                              version: QrVersions.auto,
                              size: 240.0, // Increased size for better scanning
                              backgroundColor: Colors.white,
                              errorCorrectionLevel: QrErrorCorrectLevel.H,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // OTP input field
                    TextFormField(
                      controller: _otpController,
                      focusNode: _otpFocusNode, // Assign focus node
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        hintText: 'Enter OTP',
                        labelText: 'One-Time Password',
                        prefixIcon: const Icon(Icons.lock),
                        filled: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter the OTP';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    // Action buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              _encryptedOtp = null;
                              _otpController.clear();
                              _error = null;
                            });
                          },
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('Back'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _verifyOtp,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: _isLoading
                                ? SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: colorScheme.onPrimary,
                                    ),
                                  )
                                : Text(
                                    'Verify OTP',
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      color: colorScheme.onPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildLoginOption(BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    bool isLoading = false,
    required ThemeData theme,
    required ColorScheme colorScheme,
  }) {
    return InkWell(
      onTap: isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 120,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          border: Border.all(color: colorScheme.primary.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            isLoading
                ? SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colorScheme.primary,
                    ),
                  )
                : Icon(icon, size: 32, color: colorScheme.primary),
            const SizedBox(height: 8),
            Text(
              label,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
