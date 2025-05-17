import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/author.dart';
import '../providers/auth_provider.dart';
import '../services/deep_link_service.dart';
import '../services/api_service.dart';
import '../widgets/animated_copy_button.dart';
import '../widgets/custom_snackbar.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  bool _isLoading = false;
  String? _error;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    _nameController.text = auth.name ?? '';
    
    // Force profile refresh when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      auth.loadProfile();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Widget _buildProfileImage(AuthProvider auth) {
    if (auth.profileImage == null) {
      return const CircleAvatar(
        radius: 50,
        child: Icon(Icons.person, size: 50),
      );
    }

    try {
      final imageBytes = base64Decode(auth.profileImage!);
      return CircleAvatar(
        radius: 50,
        backgroundImage: MemoryImage(imageBytes),
        onBackgroundImageError: (_, __) {
          debugPrint('Error loading profile image');
          return null;
        },
      );
    } catch (e) {
      debugPrint('Error decoding profile image: $e');
      return const CircleAvatar(
        radius: 50,
        child: Icon(Icons.person, size: 50),
      );
    }
  }

  Future<void> _pickImage() async {
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 300,
        maxHeight: 300,
        imageQuality: 85,
      );
      if (image == null) return;

      setState(() => _isLoading = true);

      final imageBytes = await File(image.path).readAsBytes();
      final compressedBytes = await FlutterImageCompress.compressWithList(
        imageBytes,
        minHeight: 300,
        minWidth: 300,
        quality: 85,
      );

      final base64Image = base64Encode(compressedBytes);
      await context.read<AuthProvider>().updateProfile(
        _nameController.text,
        base64Image,
      );

      if (mounted) {
        CustomSnackbar.show(
          context,
          message: 'Profile image updated successfully',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
        CustomSnackbar.showError(
          context,
          message: e.toString(),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await context.read<AuthProvider>().updateProfile(
        _nameController.text.trim(),
        null,
      );
      
      if (mounted) {
        setState(() => _isEditing = false);
        CustomSnackbar.show(
          context,
          message: 'Profile updated successfully',
        );
      }
    } catch (e) {
      setState(() => _error = e.toString());
      if (mounted) {
        CustomSnackbar.showError(
          context,
          message: e.toString(),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String? _publicKeyHash;

  Future<void> _handleSendReputation(BuildContext context) async {
    if (_publicKeyHash == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot send reputation: Public key hash not available')),
      );
      return;
    }

    try {
      final cleanHash = _publicKeyHash!.replaceAll('UR:VERIFY-PROFILE/', '');
      await DeepLinkService.launchWalletForReputation(cleanHash);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error launching wallet: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _handleVerify(BuildContext context) async {
    if (_publicKeyHash == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot verify profile: Public key hash not available')),
      );
      return;
    }

    try {
      final cleanHash = _publicKeyHash!.replaceAll('UR:VERIFY-PROFILE/', '');
      await DeepLinkService.launchWalletForVerify(cleanHash);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error launching wallet: ${e.toString()}')),
        );
      }
    }
  }

  void _showQRDialog(BuildContext context) {
    final publicKeyHash = Provider.of<AuthProvider>(context, listen: false).publicKeyHash;
    if (publicKeyHash == null) return;

    setState(() {
      _publicKeyHash = publicKeyHash;
    });

    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Share Profile',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: 200,
                height: 200,
                child: QrImageView(
                  data: publicKeyHash,
                  version: QrVersions.auto,
                  size: 200.0,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    icon: const Icon(Icons.account_balance_wallet),
                    onPressed: () {
                      _handleSendReputation(context);
                      Navigator.pop(context);
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.verified_user),
                    onPressed: () {
                      _handleVerify(context);
                      Navigator.pop(context);
                    },
                  ),
                  AnimatedCopyButton(
                    textToCopy: publicKeyHash,
                    onCopied: () {
                      CustomSnackbar.show(
                        context,
                        message: 'Copied to clipboard',
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code),
            onPressed: () => _showQRDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _isEditing ? _updateProfile : () => setState(() => _isEditing = true),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                await context.read<AuthProvider>().loadProfile();
              },
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Text(
                            _error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      Center(
                        child: Stack(
                          children: [
                            _buildProfileImage(currentUser),
                            if (_isEditing)
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: CircleAvatar(
                                  backgroundColor: Theme.of(context).primaryColor,
                                  child: IconButton(
                                    icon: const Icon(Icons.camera_alt),
                                    onPressed: _pickImage,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_isEditing) ...[
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Name',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter your name';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _isEditing = false;
                                  // Restore the original name
                                  _nameController.text = context.read<AuthProvider>().name ?? '';
                                });
                              },
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              onPressed: _updateProfile,
                              child: const Text('Save'),
                            ),
                          ],
                        ),
                      ] else ...[
                        Center(
                          child: Column(
                            children: [
                              Text(
                                _nameController.text.isNotEmpty
                                    ? _nameController.text
                                    : 'Anonymous',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.star, size: 16),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${currentUser.reputationPoints ?? 0} RPs',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
