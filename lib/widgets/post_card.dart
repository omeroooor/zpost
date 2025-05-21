import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/post.dart';
import '../models/author.dart';
import '../models/supporter.dart';
import '../providers/auth_provider.dart';
import '../screens/post_details_screen.dart';
import '../screens/user_profile_screen.dart';
import '../services/deep_link_service.dart';
import '../services/post_service.dart';
import '../services/api_service.dart';
import '../widgets/animated_copy_button.dart';
import '../widgets/qr_dialog.dart';
import '../widgets/video_thumbnail.dart';
import '../widgets/supporters_dialog.dart';
import 'package:timeago/timeago.dart' as timeago;

class PostCard extends StatelessWidget {
  final Post post;
  final bool showAuthorName;
  final bool showAuthorImage;
  final bool showActions;
  final bool isCurrentUser;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onPublish;
  final VoidCallback? onVerify;
  final VoidCallback? onSupport;

  const PostCard({
    Key? key,
    required this.post,
    this.showAuthorName = true,
    this.showAuthorImage = true,
    this.showActions = false,
    this.isCurrentUser = false,
    this.onEdit,
    this.onDelete,
    this.onPublish,
    this.onVerify,
    this.onSupport,
  }) : super(key: key);

  void _handleSendReputation(BuildContext context) async {
    if (post.contentHash == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot send reputation: Post hash not available')),
      );
      return;
    }

    try {
      final cleanHash = post.contentHash!.replaceAll('UR:VERIFY-POST/', '');
      await DeepLinkService.launchWalletForReputation(cleanHash);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error launching wallet: ${e.toString()}')),
        );
      }
    }
  }

  void _handleVerify(BuildContext context) async {
    if (post.contentHash == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot verify post: Post hash not available')),
      );
      return;
    }

    try {
      final cleanHash = post.contentHash!.replaceAll('UR:VERIFY-POST/', '');
      await DeepLinkService.launchWalletForVerify(cleanHash);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error launching wallet: ${e.toString()}')),
        );
      }
    }
  }

  void _showQRDialog(BuildContext context, String title, String contentHash) {
    bool isVerifyContext = true;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          // Get the base hash without any prefix
          final baseHash = contentHash.replaceAll('UR:VERIFY-POST/', '');
          
          // Create the full data string based on context
          final fullData = isVerifyContext 
              ? 'UR:VERIFY-PROFILE/$baseHash'
              : 'UR:SEND-RPS/$baseHash';
          
          return Dialog(
            child: Container(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isVerifyContext ? 'Verify Post' : 'Support Post',
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
                      data: fullData,
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
                            isVerifyContext = true;
                          });
                        },
                        style: TextButton.styleFrom(
                          backgroundColor: isVerifyContext ? Colors.blue.withOpacity(0.1) : null,
                        ),
                        child: const Text('Verify'),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            isVerifyContext = false;
                          });
                        },
                        style: TextButton.styleFrom(
                          backgroundColor: !isVerifyContext ? Colors.blue.withOpacity(0.1) : null,
                        ),
                        child: const Text('Support'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.account_balance_wallet),
                        onPressed: () {
                          if (isVerifyContext) {
                            _handleVerify(context);
                          } else {
                            _handleSendReputation(context);
                          }
                          Navigator.pop(context);
                        },
                      ),
                      AnimatedCopyButton(
                        textToCopy: baseHash,
                        onCopied: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Hash copied to clipboard')),
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
          );
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (post.mediaPath != null) ...[
          FutureBuilder<Uint8List>(
            future: PostService.downloadMedia(post.mediaPath!),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              
              if (snapshot.hasError) {
                debugPrint('Error loading media: ${snapshot.error}');
                return Center(child: Text('Error loading media: ${snapshot.error}'));
              }
              
              if (!snapshot.hasData) {
                return const SizedBox();
              }
              
              return Container(
                constraints: const BoxConstraints(
                  maxHeight: 300,
                ),
                width: double.infinity,
                child: post.mediaType == 'video'
                  ? VideoThumbnail(videoData: snapshot.data!)
                  : Image.memory(
                      snapshot.data!,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        debugPrint('Error displaying image: $error');
                        return const Center(
                          child: Icon(
                            Icons.error_outline,
                            size: 48,
                            color: Colors.red,
                          ),
                        );
                      },
                    ),
              );
            },
          ),
          const SizedBox(height: 12),
        ],
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            post.content,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PostDetailsScreen(post: post),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => UserProfileScreen(
                        publicKeyHash: post.author.publicKeyHash,
                        name: post.author.name,
                      ),
                    ),
                  );
                },
                child: CircleAvatar(
                  backgroundImage: post.author.image != null
                      ? MemoryImage(base64Decode(post.author.image!))
                      : null,
                  child: post.author.image == null
                      ? const Icon(Icons.person)
                      : null,
                ),
              ),
              title: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => UserProfileScreen(
                        publicKeyHash: post.author.publicKeyHash,
                        name: post.author.name,
                      ),
                    ),
                  );
                },
                child: Text(post.author.name ?? 'Anonymous'),
              ),
              subtitle: Text(
                timeago.format(post.createdAt),
              ),
              trailing: post.contentHash != null
                  ? IconButton(
                      icon: const Icon(Icons.qr_code),
                      onPressed: () => _showQRDialog(
                        context,
                        'Post Actions',
                        post.contentHash!,
                      ),
                    )
                  : null,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: _buildContent(context),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    icon: const Icon(Icons.verified_user),
                    onPressed: () => _handleVerify(context),
                  ),
                  IconButton(
                    icon: const Icon(Icons.account_balance_wallet),
                    onPressed: () => _handleSendReputation(context),
                  ),
                  Text('RPs: ${post.reputationPoints}'),
                  InkWell(
                    onTap: () {
                      if (post.contentHash != null) {
                        final cleanHash = post.contentHash!.replaceAll('UR:VERIFY-POST/', '');
                        showSupportersDialog(context, cleanHash);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Cannot show supporters: Post hash not available')),
                        );
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Row(
                        children: [
                          const Icon(Icons.people, size: 16),
                          const SizedBox(width: 4),
                          Text('${post.supporterCount}'),
                        ],
                      ),
                    ),
                  ),
                  if (post.isConfirmed)
                    const Icon(Icons.check_circle, color: Colors.green),
                  if (showActions) ...[
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: onEdit,
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: onDelete,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
