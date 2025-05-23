import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/post.dart';
import '../models/author.dart';
import '../services/api_service.dart';
import '../services/deep_link_service.dart';
import '../widgets/post_card.dart';
import '../widgets/custom_snackbar.dart';
import '../widgets/animated_copy_button.dart';
import '../providers/auth_provider.dart';

class UserProfileScreen extends StatefulWidget {
  final String publicKeyHash;
  final String? name;

  const UserProfileScreen({
    Key? key,
    required this.publicKeyHash,
    this.name,
  }) : super(key: key);

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  bool _isFollowing = false;
  bool _isLoading = false;
  List<dynamic> _posts = [];
  String _trustLevel = 'Loading...';
  int _rps = 0;
  late String _displayName;
  String? _profileImage;

  @override
  void initState() {
    super.initState();
    _displayName = widget.name ?? 'Anonymous';
    _loadPosts();
    _loadUserProfile();
  }

  Future<void> _loadPosts() async {
    try {
      final posts = await ApiService.getUserPostsByHash(widget.publicKeyHash);
      if (mounted) {
        setState(() {
          _posts = posts;
        });
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.showError(
          context,
          message: 'Error loading posts',
        );
      }
    }
  }

  Future<void> _loadUserProfile() async {
    try {
      debugPrint('Loading profile for user: ${widget.publicKeyHash}');
      final profile = await ApiService.getProfile(widget.publicKeyHash);
      debugPrint('Loaded profile: $profile');
      
      if (mounted) {
        setState(() {
          _rps = profile['reputationPoints'] ?? 0;
          _trustLevel = profile['trustLevel'] ?? 'New';
          _displayName = profile['name'] ?? widget.name ?? 'Anonymous';
          _isFollowing = profile['isFollowing'] ?? false;
          _profileImage = profile['image'];
        });
        debugPrint('Updated profile state: RPs: $_rps, Trust Level: $_trustLevel, Following: $_isFollowing');
      }
    } catch (e) {
      debugPrint('Error loading user profile: $e');
      if (mounted) {
        CustomSnackbar.showError(
          context,
          message: 'Error loading user profile',
        );
      }
    }
  }

  Future<void> _toggleFollow() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final success = await ApiService.toggleFollow(widget.publicKeyHash, _isFollowing);
      if (success) {
        setState(() {
          _isFollowing = !_isFollowing;
        });
        CustomSnackbar.show(
          context,
          message: '${_isFollowing ? 'Following' : 'Unfollowed'} $_displayName',
        );
      }
    } catch (e) {
      CustomSnackbar.showError(
        context,
        message: 'Failed to ${_isFollowing ? 'unfollow' : 'follow'} user',
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Color _getTrustLevelColor(String trustLevel) {
    switch (trustLevel.toLowerCase()) {
      case 'expert':
        return Colors.purple;
      case 'advanced':
        return Colors.blue;
      case 'intermediate':
        return Colors.green;
      case 'beginner':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Widget _buildProfileImage(String? profileImage) {
    if (profileImage == null || profileImage.isEmpty) {
      return const CircleAvatar(
        radius: 50,
        backgroundColor: Colors.grey,
        child: Icon(Icons.person, size: 50, color: Colors.white),
      );
    }

    // Check if the image is a URL
    if (profileImage.startsWith('http://') || profileImage.startsWith('https://')) {
      debugPrint('Using NetworkImage for profile: $profileImage');
      return CircleAvatar(
        radius: 50,
        backgroundColor: Colors.grey.withOpacity(0.3),
        backgroundImage: NetworkImage(profileImage),
        onBackgroundImageError: (_, __) {
          debugPrint('Error loading profile image URL');
          return null;
        },
      );
    }
    
    // Try to decode as base64
    try {
      debugPrint('Trying to decode base64 image, length: ${profileImage.length}');
      final imageBytes = base64Decode(profileImage);
      return CircleAvatar(
        radius: 50,
        backgroundColor: Colors.grey.withOpacity(0.3),
        backgroundImage: MemoryImage(imageBytes),
        onBackgroundImageError: (_, __) {
          debugPrint('Error loading profile image');
          return null;
        },
      );
    } catch (e) {
      debugPrint('Error decoding profile image: $e');
      return CircleAvatar(
        radius: 50,
        backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
        child: Icon(Icons.person, size: 50, color: Theme.of(context).colorScheme.primary),
      );
    }
  }

  Widget _buildStatColumn(String title, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 24),
        ),
        Text(
          title,
          style: const TextStyle(color: Colors.grey),
        ),
      ],
    );
  }

  void _handleWalletAction(BuildContext context, String hash, String action) async {
    try {
      // Remove prefixes if present
      final cleanHash = hash
          .replaceAll('UR:VERIFY-PROFILE/', '')
          .replaceAll('UR:SEND-RPS/', '');

      switch (action) {
        case 'verify':
          await DeepLinkService.launchWalletForVerify(cleanHash);
          break;
        case 'reputation':
          await DeepLinkService.launchWalletForReputation(cleanHash);
          break;
        default:
          throw Exception('Unknown wallet action: $action');
      }
    } catch (e) {
      if (context.mounted) {
        CustomSnackbar.showError(
          context,
          message: e.toString(),
        );
      }
    }
  }

  void _showQrDialog() {
    int qrMode = 0; // 0: plain hash, 1: verify profile, 2: send RPs
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          String displayHash;
          String title;
          String walletAction;
          
          switch (qrMode) {
            case 1:
              displayHash = 'UR:VERIFY-PROFILE/${widget.publicKeyHash}';
              title = 'Verify Profile';
              walletAction = 'verify';
              break;
            case 2:
              displayHash = 'UR:SEND-RPS/${widget.publicKeyHash}';
              title = 'Support User';
              walletAction = 'reputation';
              break;
            default:
              displayHash = widget.publicKeyHash;
              title = 'Public Key Hash';
              walletAction = 'reputation';
          }
              
          return Dialog(
            child: Container(
              padding: const EdgeInsets.all(16.0),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: 200,
                      height: 200,
                      child: QrImageView(
                        data: displayHash,
                        version: QrVersions.auto,
                        size: 200.0,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton(
                          onPressed: () {
                            setState(() {
                              qrMode = 0;
                            });
                          },
                          style: TextButton.styleFrom(
                            backgroundColor: qrMode == 0 ? Colors.blue.withOpacity(0.1) : null,
                          ),
                          child: const Text('Hash'),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              qrMode = 1;
                            });
                          },
                          style: TextButton.styleFrom(
                            backgroundColor: qrMode == 1 ? Colors.blue.withOpacity(0.1) : null,
                          ),
                          child: const Text('Verify'),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              qrMode = 2;
                            });
                          },
                          style: TextButton.styleFrom(
                            backgroundColor: qrMode == 2 ? Colors.blue.withOpacity(0.1) : null,
                          ),
                          child: const Text('Support'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.account_balance_wallet),
                          onPressed: () {
                            _handleWalletAction(context, displayHash, walletAction);
                            Navigator.pop(context);
                          },
                        ),
                        AnimatedCopyButton(
                          textToCopy: displayHash,
                          onCopied: () {
                            CustomSnackbar.show(
                              context,
                              message: 'Copied to clipboard',
                            );
                          },
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.close),
                              SizedBox(width: 8),
                              Text('Close'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final isCurrentUser = authProvider.publicKeyHash == widget.publicKeyHash;

    return Scaffold(
      appBar: AppBar(
        title: Text(_displayName),
        actions: [
          if (!isCurrentUser)
            _isLoading
                ? const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(),
                  )
                : TextButton.icon(
                    onPressed: _toggleFollow,
                    icon: Icon(
                      _isFollowing ? Icons.person_remove : Icons.person_add,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                    label: Text(
                      _isFollowing ? 'Unfollow' : 'Follow',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                  ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: TextButton.icon(
              onPressed: _showQrDialog,
              icon: Icon(
                Icons.qr_code,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
              label: Text(
                'Share',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16.0),
              color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.1),
              child: Column(
                children: [
                  Stack(
                    children: [
                      _buildProfileImage(_profileImage),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            _trustLevel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _displayName,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.publicKeyHash,
                    style: const TextStyle(
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (!isCurrentUser) // Only show follow button for other users
                        ElevatedButton.icon(
                          onPressed: _isLoading ? null : _toggleFollow,
                          icon: Icon(_isFollowing ? Icons.person_remove : Icons.person_add),
                          label: Text(_isFollowing ? 'Unfollow' : 'Follow'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isFollowing
                                ? Theme.of(context).colorScheme.error
                                : Theme.of(context).colorScheme.primary,
                            foregroundColor: Theme.of(context).colorScheme.onPrimary,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                        ),
                      if (!isCurrentUser)
                        const SizedBox(width: 16),
                      ElevatedButton.icon(
                        onPressed: _showQrDialog,
                        icon: const Icon(Icons.qr_code),
                        label: const Text('Share Profile'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.secondary,
                          foregroundColor: Theme.of(context).colorScheme.onSecondary,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStatColumn('Posts', _posts.length.toString()),
                      Container(
                        height: 40,
                        width: 1,
                        color: Colors.grey.withOpacity(0.3),
                      ),
                      _buildStatColumn('Reputation', _rps.toString()),
                      Container(
                        height: 40,
                        width: 1,
                        color: Colors.grey.withOpacity(0.3),
                      ),
                      Column(
                        children: [
                          Text(
                            _trustLevel,
                            style: TextStyle(
                              fontSize: 24,
                              color: _getTrustLevelColor(_trustLevel),
                            ),
                          ),
                          const Text(
                            'Trust Level',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Posts',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _posts.isEmpty
                      ? const Center(
                          child: Text(
                            'No posts yet',
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _posts.length,
                          itemBuilder: (context, index) {
                            return PostCard(
                              post: Post.fromJson(_posts[index]),
                              showAuthorName: false,
                              showAuthorImage: false,
                            );
                          },
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
