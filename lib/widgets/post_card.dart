import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/post.dart';
import '../models/author.dart';
import '../models/supporter.dart';
import '../providers/auth_provider.dart';
import '../screens/post_details_screen.dart';
import '../screens/user_profile_screen.dart';
import '../services/deep_link_service.dart';
import '../services/post_service.dart';
import '../services/api_service.dart';
import '../services/media_cache_service.dart';
import '../widgets/animated_copy_button.dart';
import '../widgets/qr_dialog.dart';
import '../widgets/video_thumbnail.dart';
import '../widgets/supporters_dialog.dart';
import '../widgets/responsive_container.dart';
import '../widgets/action_button.dart';
import '../config/api_config.dart';
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
      _showErrorDialog(
        context,
        'Cannot Support Post',
        'This post does not have a valid content hash. Support is only available for verified posts.',
      );
      return;
    }

    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Opening wallet app...'),
            ],
          ),
        ),
      );

      final cleanHash = post.contentHash!.replaceAll('UR:VERIFY-POST/', '');
      await DeepLinkService.launchWalletForReputation(cleanHash);
      
      // Close loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Support request sent successfully')),
        );
      }
    } catch (e) {
      debugPrint('Error sending reputation: $e');
      if (context.mounted) {
        // Close loading dialog if it's showing
        Navigator.of(context).pop();
        
        // Show error dialog with options
        _showDeepLinkErrorDialog(
          context,
          'Support Error',
          'Unable to open wallet app. Make sure you have a compatible wallet installed.',
          post.contentHash!.replaceAll('UR:VERIFY-POST/', ''),
          true, // isSupport
        );
      }
    }
  }

  void _handleVerify(BuildContext context) async {
    if (post.contentHash == null) {
      _showErrorDialog(
        context,
        'Cannot Verify Post',
        'This post does not have a valid content hash. Verification is only available for posts with content hashes.',
      );
      return;
    }

    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Opening wallet app...'),
            ],
          ),
        ),
      );

      final cleanHash = post.contentHash!.replaceAll('UR:VERIFY-POST/', '');
      await DeepLinkService.launchWalletForVerify(cleanHash);
      
      // Close loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verification request sent successfully')),
        );
      }
    } catch (e) {
      debugPrint('Error verifying post: $e');
      if (context.mounted) {
        // Close loading dialog if it's showing
        Navigator.of(context).pop();
        
        // Show error dialog with options
        _showDeepLinkErrorDialog(
          context,
          'Verification Error',
          'Unable to open wallet app. Make sure you have a compatible wallet installed.',
          post.contentHash!.replaceAll('UR:VERIFY-POST/', ''),
          false, // isSupport
        );
      }
    }
  }

  void _showQRDialog(BuildContext context, String title, String contentHash) {
    if (contentHash.isEmpty) {
      _showErrorDialog(
        context,
        'QR Code Not Available',
        'This post does not have a valid content hash. QR codes are only available for posts with content hashes.',
      );
      return;
    }

    // Get the base hash without any prefix
    final baseHash = contentHash.replaceAll('UR:VERIFY-POST/', '');
    
    // Use the responsive QRDialog implementation
    QRDialog.show(
      context: context,
      title: title,
      data: 'UR:VERIFY-PROFILE/$baseHash',
      onVerify: () {
        Navigator.pop(context);
        _handleVerify(context);
      },
      onSupport: () {
        Navigator.pop(context);
        _handleSendReputation(context);
      },
    );
  }
  
  // Helper method to show error dialogs
  void _showErrorDialog(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
  
  // Helper method to show deep link error dialogs with options
  void _showDeepLinkErrorDialog(BuildContext context, String title, String message, String hash, bool isSupport) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            const SizedBox(height: 16),
            const Text('Options:'),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.content_copy),
              title: const Text('Copy Hash'),
              subtitle: const Text('Copy the post hash to clipboard'),
              dense: true,
              onTap: () {
                Clipboard.setData(ClipboardData(text: hash));
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Hash copied to clipboard')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.qr_code),
              title: const Text('Show QR Code'),
              subtitle: const Text('Display QR code for scanning'),
              dense: true,
              onTap: () {
                Navigator.of(context).pop();
                _showQRDialog(context, 'Post Actions', hash);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Media content (image or video)
        if (post.mediaPath != null) ...[
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(4),
            ),
            child: _buildMediaContent(context),
          ),
        ],
        
        // Post text content
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Container(
            width: double.infinity,
            alignment: _isArabic(post.content) ? Alignment.centerRight : Alignment.centerLeft,
            child: Directionality(
              // Detect if the text is Arabic and set RTL direction accordingly
              textDirection: _isArabic(post.content) ? TextDirection.rtl : TextDirection.ltr,
              child: Text(
                post.content,
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: _isArabic(post.content) ? TextAlign.right : TextAlign.left,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  @override
  // Helper method to detect if text is Arabic
  bool _isArabic(String text) {
    // Check if the text contains Arabic characters
    return RegExp(r'[\u0600-\u06FF]').hasMatch(text);
  }
  
  // Build media content with caching
  Widget _buildMediaContent(BuildContext context) {
    // Use ApiConfig to get the proper media URL
    final String mediaUrl = ApiConfig.getMediaUrl(post.mediaPath!);
    
    // For video content
    if (post.mediaType == 'video') {
      return FutureBuilder<Uint8List>(
        future: MediaCacheService().getMediaRequired(mediaUrl).catchError((error) {
          // If primary URL fails, try alternative URL
          debugPrint('Error loading video from primary URL: $error');
          return MediaCacheService().getMediaRequired(ApiConfig.getAlternativeMediaUrl(post.mediaPath!));
        }).catchError((error) {
          // Both URLs failed
          debugPrint('Error loading video from alternative URL: $error');
          // Return empty bytes to show error widget
          return Uint8List(0);
        }),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingPlaceholder();
          }
          
          if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildErrorWidget('Could not load video');
          }
          
          return Container(
            constraints: const BoxConstraints(
              minHeight: 200,
              maxHeight: 450,
            ),
            width: double.infinity,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.03),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: VideoThumbnail(videoData: snapshot.data!),
            ),
          );
        },
      );
    }
    
    // For image content
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate aspect ratio based on screen size
        // Use a more square aspect ratio on wider screens
        final aspectRatio = constraints.maxWidth > 600 ? 4/3 : 16/9;
        
        return Container(
          constraints: const BoxConstraints(
            minHeight: 200,
            maxHeight: 450,
          ),
          width: double.infinity,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: mediaUrl,
              fit: BoxFit.cover,
              placeholder: (context, url) => _buildLoadingPlaceholder(),
              errorWidget: (context, url, error) {
                debugPrint('Error loading image from $url: $error');
                // Try alternative URL if the first one fails
                return CachedNetworkImage(
                  imageUrl: ApiConfig.getAlternativeMediaUrl(post.mediaPath!),
                  fit: BoxFit.cover,
                  placeholder: (context, url) => _buildLoadingPlaceholder(),
                  errorWidget: (context, url, error) => _buildErrorWidget('Could not load image'),
                );
              },
            ),
          ),
        );
      },
    );
  }
  
  // Loading placeholder widget
  Widget _buildLoadingPlaceholder() {
    return Container(
      height: 200,
      width: double.infinity,
      color: Colors.grey[200],
      child: const Center(child: CircularProgressIndicator()),
    );
  }
  
  // Error widget
  Widget _buildErrorWidget(String message) {
    return Container(
      height: 200,
      width: double.infinity,
      color: Colors.grey[100],
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 32),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(color: Colors.grey[700]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return ResponsiveContainer(
      maxWidth: 600, // Limit width to 600px on larger screens
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
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
              // Author information section
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    if (showAuthorImage) ...[  
                      GestureDetector(
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
                        child: Hero(
                          tag: 'profile-${post.author.publicKeyHash}',
                          child: CircleAvatar(
                            radius: 24,
                            backgroundColor: colorScheme.primary.withOpacity(0.1),
                            backgroundImage: post.author.image != null
                                ? MemoryImage(base64Decode(post.author.image!))
                                : null,
                            child: post.author.image == null
                                ? Icon(Icons.person, color: colorScheme.primary)
                                : null,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
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
                            child: Text(
                              post.author.name ?? 'Anonymous',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            timeago.format(post.createdAt),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (post.contentHash != null)
                      IconButton(
                        icon: Icon(Icons.qr_code, color: colorScheme.primary),
                        tooltip: 'Show QR Code',
                        onPressed: () => _showQRDialog(
                          context,
                          'Post Actions',
                          post.contentHash!,
                        ),
                      ),
                    if (post.isConfirmed)
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Tooltip(
                          message: 'Verified Post',
                          child: Icon(
                            Icons.verified, 
                            color: colorScheme.primary,
                            size: 20,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              
              // Post content
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: _buildContent(context),
              ),
              
              // Action buttons
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ActionButton(
                      icon: Icons.verified_user,
                      label: 'Verify',
                      onTap: () => _handleVerify(context),
                      color: colorScheme.primary,
                    ),
                    ActionButton(
                      icon: Icons.thumb_up_alt_outlined,
                      label: 'Support',
                      onTap: () => _handleSendReputation(context),
                      color: colorScheme.secondary,
                    ),
                    ActionButton(
                      icon: Icons.people_outline,
                      label: '${post.supporterCount}',
                      onTap: () {
                        if (post.contentHash != null) {
                          final cleanHash = post.contentHash!.replaceAll('UR:VERIFY-POST/', '');
                          showSupportersDialog(context, cleanHash);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Cannot show supporters: Post hash not available')),
                          );
                        }
                      },
                      color: colorScheme.tertiary,
                    ),
                    ActionButton(
                      icon: Icons.star_outline,
                      label: '${post.reputationPoints}',
                      onTap: null, // Just display the count
                      color: Colors.amber,
                    ),
                    if (showActions) ...[
                      ActionButton(
                        icon: Icons.edit,
                        label: 'Edit',
                        onTap: onEdit,
                        color: colorScheme.primary,
                      ),
                      ActionButton(
                        icon: Icons.delete,
                        label: 'Delete',
                        onTap: onDelete,
                        color: colorScheme.error,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
