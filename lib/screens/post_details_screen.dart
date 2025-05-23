import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:http/http.dart' as http;
import '../models/post.dart';
import '../models/author.dart';
import '../models/comment.dart';
import '../models/supporter.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/deep_link_service.dart';
import '../services/post_service.dart';
import '../services/media_cache_service.dart';
import '../config/api_config.dart';
import '../widgets/animated_copy_button.dart';
import '../widgets/custom_snackbar.dart';
import '../widgets/qr_dialog.dart';
import '../widgets/supporters_dialog.dart';
import '../screens/user_profile_screen.dart';
import '../utils/responsive_layout.dart';
import '../widgets/responsive_container.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as path;
import 'package:permission_handler/permission_handler.dart';
import 'package:video_player/video_player.dart';

class PostDetailsScreen extends StatefulWidget {
  final Post post;

  const PostDetailsScreen({
    super.key,
    required this.post,
  });

  @override
  State<PostDetailsScreen> createState() => _PostDetailsScreenState();
}

class _PostDetailsScreenState extends State<PostDetailsScreen> {
  final _commentController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  List<Comment> _comments = [];
  String? _error;
  Uint8List? _mediaBytes;
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  SupportersInfo? _supportersInfo;
  bool _isLoadingSupporters = false;

  @override
  void initState() {
    super.initState();
    // Load media and other data immediately when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMedia();
      _loadComments();
      _loadSupporters();
    });
  }
  
  Future<void> _loadSupporters() async {
    if (widget.post.contentHash == null) return;
    
    setState(() => _isLoadingSupporters = true);
    
    try {
      final cleanHash = widget.post.contentHash!.replaceAll('UR:VERIFY-POST/', '');
      final supportersInfo = await ApiService.getPostSupporters(cleanHash);
      
      if (mounted) {
        setState(() {
          _supportersInfo = supportersInfo;
          _isLoadingSupporters = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading supporters: $e');
      if (mounted) {
        setState(() => _isLoadingSupporters = false);
      }
    }
  }

  Future<void> _loadMedia() async {
    if (widget.post.mediaPath == null) {
      debugPrint('No media path available for post ${widget.post.id}');
      return;
    }

    debugPrint('Loading media from path: ${widget.post.mediaPath}');
    debugPrint('Media type: ${widget.post.mediaType}');
    
    try {
      setState(() => _isLoading = true);
      
      // Construct the media URL
      final mediaUrl = ApiConfig.getMediaUrl(widget.post.mediaPath!);
      debugPrint('Constructed media URL: $mediaUrl');
      
      // First try to get media from cache using MediaCacheService
      final mediaCacheService = MediaCacheService();
      Uint8List? mediaBytes;
      
      // Try to get from cache first
      try {
        mediaBytes = await mediaCacheService.getMedia(mediaUrl);
        if (mediaBytes != null) {
          debugPrint('Retrieved media from cache, bytes length: ${mediaBytes.length}');
          
          if (mounted) {
            setState(() {
              _mediaBytes = mediaBytes;
              _isLoading = false;
            });

            if ((widget.post.mediaType?.contains('video') == true || widget.post.mediaType == 'video') && _mediaBytes != null) {
              await _initializeVideoPlayer();
            }
            return; // Successfully loaded from cache
          }
        }
      } catch (cacheError) {
        debugPrint('Error retrieving from cache: $cacheError');
      }
      
      // If not in cache, try PostService.downloadMedia
      try {
        final bytes = await PostService.downloadMedia(widget.post.mediaPath!);
        debugPrint('Media downloaded successfully via PostService, bytes length: ${bytes.length}');
        
        // Save to cache for future use
        await mediaCacheService.cacheMedia(mediaUrl, bytes);
        
        if (mounted) {
          setState(() {
            _mediaBytes = bytes;
            _isLoading = false;
          });

          if ((widget.post.mediaType?.contains('video') == true || widget.post.mediaType == 'video') && _mediaBytes != null) {
            await _initializeVideoPlayer();
          }
        }
      } catch (serviceError) {
        debugPrint('Error using PostService.downloadMedia: $serviceError');
        
        // Last attempt: Try direct HTTP request
        try {
          final response = await http.get(Uri.parse(mediaUrl));
          if (response.statusCode == 200) {
            debugPrint('Media downloaded successfully via direct HTTP, bytes length: ${response.bodyBytes.length}');
            
            // Save to cache for future use
            await mediaCacheService.cacheMedia(mediaUrl, response.bodyBytes);
            
            if (mounted) {
              setState(() {
                _mediaBytes = response.bodyBytes;
                _isLoading = false;
              });

              if ((widget.post.mediaType?.contains('video') == true || widget.post.mediaType == 'video') && _mediaBytes != null) {
                await _initializeVideoPlayer();
              }
            }
          } else {
            throw Exception('HTTP error: ${response.statusCode}');
          }
        } catch (httpError) {
          debugPrint('Error using direct HTTP: $httpError');
          rethrow;
        }
      }
    } catch (e) {
      debugPrint('All media loading attempts failed: $e');
      debugPrint('Stack trace: ${StackTrace.current}');
      if (mounted) {
        setState(() {
          _error = 'Failed to load media: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _initializeVideoPlayer() async {
    if (_mediaBytes == null) return;

    // Create a temporary file to store the video
    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/temp_video.mp4');
    await tempFile.writeAsBytes(_mediaBytes!);

    _videoController = VideoPlayerController.file(tempFile);
    await _videoController!.initialize();
    
    if (mounted) {
      setState(() {
        _isVideoInitialized = true;
      });
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    setState(() => _isLoading = true);
    
    try {
      final commentsData = await ApiService.getComments(widget.post.id!);
      
      if (mounted) {
        setState(() {
          _comments = commentsData
              .map((commentData) => Comment.fromJson(commentData))
              .toList();
          // Sort comments by creation date (newest first)
          _comments.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          _isLoading = false;
          _error = null;
        });
      }
    } catch (e) {
      debugPrint('Error loading comments: $e');
      if (mounted) {
        setState(() {
          _error = 'Failed to load comments: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _refreshPost() async {
    try {
      // Since there's no direct getPost method, we'll just reload comments
      // and supporters for now
      if (mounted) {
        await _loadComments();
        await _loadSupporters();
      }
    } catch (e) {
      debugPrint('Error refreshing post: $e');
      if (mounted) {
        setState(() {
          _error = 'Failed to refresh post: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _submitComment() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      final commentData = await ApiService.createComment(
        widget.post.id!,
        _commentController.text.trim(),
      );
      
      if (mounted) {
        final comment = Comment.fromJson(commentData);
        setState(() {
          // Add the new comment at the beginning of the list (since we're sorting by newest first)
          _comments.insert(0, comment);
          _isLoading = false;
          _commentController.clear();
        });
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Comment added successfully'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error creating comment: $e');
      if (mounted) {
        setState(() {
          _error = 'Failed to create comment: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteComment(Comment comment) async {
    // Show confirmation dialog
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Comment'),
        content: const Text('Are you sure you want to delete this comment? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.errorContainer,
              foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    ) ?? false;
  
    if (!shouldDelete) return;
  
    // Set the specific comment as loading instead of the whole screen
    setState(() {
      comment = Comment(
        id: comment.id,
        author: comment.author,
        content: comment.content,
        createdAt: comment.createdAt,
        postId: comment.postId,
        updatedAt: comment.updatedAt,
        isDeleting: true, // New property to track deletion state
      );
      // Update the comment in the list
      final index = _comments.indexWhere((c) => c.id == comment.id);
      if (index != -1) {
        _comments[index] = comment;
      }
    });
  
    try {
      await ApiService.deleteComment(comment.id);
    
      if (mounted) {
        setState(() {
          _comments.removeWhere((c) => c.id == comment.id);
        });
      
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Comment deleted successfully'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error deleting comment: $e');
      if (mounted) {
        setState(() {
          _error = 'Failed to delete comment: $e';
          // Reset the deleting state
          final index = _comments.indexWhere((c) => c.id == comment.id);
          if (index != -1) {
            _comments[index] = Comment(
              id: comment.id,
              author: comment.author,
              content: comment.content,
              createdAt: comment.createdAt,
              postId: comment.postId,
              updatedAt: comment.updatedAt,
              isDeleting: false,
            );
          }
        });
      
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete comment: ${e.toString().split(':').last}'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _handleSendReputation(BuildContext context) async {
    if (widget.post.contentHash == null) {
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

      final cleanHash = widget.post.contentHash!.replaceAll('UR:VERIFY-POST/', '');
      await DeepLinkService.launchWalletForReputation(cleanHash);
      
      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Support request sent successfully')),
        );
      }
    } catch (e) {
      debugPrint('Error sending reputation: $e');
      if (mounted) {
        // Close loading dialog if it's showing
        Navigator.of(context).pop();
        
        // Show error dialog with options
        _showDeepLinkErrorDialog(
          context,
          'Support Error',
          'Unable to open wallet app. Make sure you have a compatible wallet installed.',
          widget.post.contentHash!.replaceAll('UR:VERIFY-POST/', ''),
          true, // isSupport
        );
      }
    }
  }

  Future<void> _handleVerify(BuildContext context) async {
    if (widget.post.contentHash == null) {
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

      final cleanHash = widget.post.contentHash!.replaceAll('UR:VERIFY-POST/', '');
      await DeepLinkService.launchWalletForVerify(cleanHash);
      
      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verification request sent successfully')),
        );
      }
    } catch (e) {
      debugPrint('Error verifying post: $e');
      if (mounted) {
        // Close loading dialog if it's showing
        Navigator.of(context).pop();
        
        // Show error dialog with options
        _showDeepLinkErrorDialog(
          context,
          'Verification Error',
          'Unable to open wallet app. Make sure you have a compatible wallet installed.',
          widget.post.contentHash!.replaceAll('UR:VERIFY-POST/', ''),
          false, // isSupport
        );
      }
    }
  }

  void _showQRDialog(BuildContext context) {
    if (widget.post.contentHash == null) {
      _showErrorDialog(
        context,
        'QR Code Not Available',
        'This post does not have a valid content hash. QR codes are only available for posts with content hashes.',
      );
      return;
    }

    final cleanHash = widget.post.contentHash!.replaceAll('UR:VERIFY-POST/', '');
    QRDialog.show(
      context: context,
      title: 'Post Verification QR',
      data: cleanHash,
      onVerify: () => _handleVerify(context),
      onSupport: () => _handleSendReputation(context),
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
                _showQRDialog(context);
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

  // Share the post via native sharing options
  Future<void> _sharePost(BuildContext context) async {
    // Generate a post title from the content if no name is provided
    String postTitle;
    if (widget.post.name != null && widget.post.name!.isNotEmpty) {
      postTitle = widget.post.name!;
    } else {
      // Extract first few words from the post content
      final String content = widget.post.content.trim();
      final List<String> words = content.split(' ');
      
      if (words.length <= 5) {
        // If post is very short, use all of it
        postTitle = content;
      } else {
        // Otherwise use first 5 words with ellipsis
        postTitle = '${words.take(5).join(' ')}...';
      }
      
      // Limit the title length to 50 characters
      if (postTitle.length > 50) {
        postTitle = '${postTitle.substring(0, 47)}...';
      }
    }
    
    final String authorName = widget.post.author.name ?? 'Anonymous';
    final String postUrl = '${ApiConfig.serverBaseUrl}/posts/${widget.post.id}';
    
    // Create a share message with post details
    final String shareText = 'Check out "$postTitle" by $authorName on Z-Post!\n\n$postUrl';
    
    // Get the position of the share button for share sheet positioning
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    
    // Share the post
    await Share.share(
      shareText,
      subject: 'Sharing: $postTitle',
      sharePositionOrigin: box != null 
          ? box.localToGlobal(Offset.zero) & box.size
          : null,
    );
  }
  
  // Export the post as a ZIP file with all content
  Future<void> _exportPost() async {
    setState(() => _isLoading = true);
    
    try {
      final tempDir = await getTemporaryDirectory();
      final exportDir = Directory('${tempDir.path}/export_${DateTime.now().millisecondsSinceEpoch}');
      await exportDir.create();
      
      // Create the W3-S-POST-NFT standard JSON
      final postJson = widget.post.toW3SimplePostNFT();
      final jsonFile = File('${exportDir.path}/post.json');
      await jsonFile.writeAsString(jsonEncode(postJson));
      
      // If there's media, include it
      if (_mediaBytes != null && widget.post.mediaPath != null) {
        final mediaExtension = path.extension(widget.post.mediaPath!);
        final mediaFile = File('${exportDir.path}/files/media$mediaExtension');
        await mediaFile.create(recursive: true);
        await mediaFile.writeAsBytes(_mediaBytes!);
      }
      
      // Create a ZIP archive
      final archive = Archive();
      
      // Add JSON file to archive
      final jsonBytes = await jsonFile.readAsBytes();
      final jsonArchiveFile = ArchiveFile('post.json', jsonBytes.length, jsonBytes);
      archive.addFile(jsonArchiveFile);
      
      // Add media file to archive if it exists
      if (_mediaBytes != null && widget.post.mediaPath != null) {
        final mediaExtension = path.extension(widget.post.mediaPath!);
        final mediaArchiveFile = ArchiveFile(
          'files/media$mediaExtension', 
          _mediaBytes!.length, 
          _mediaBytes!
        );
        archive.addFile(mediaArchiveFile);
      }
      
      // Write the archive to a file
      final zipEncoder = ZipEncoder();
      final zipData = zipEncoder.encode(archive);
      if (zipData == null) {
        throw Exception('Failed to create ZIP archive');
      }
      
      final zipFile = File('${tempDir.path}/${widget.post.name ?? 'post'}_${DateTime.now().millisecondsSinceEpoch}.zip');
      await zipFile.writeAsBytes(zipData);
      
      // Share the file
      await Share.shareXFiles(
        [XFile(zipFile.path)],
        subject: 'Sharing Post: ${widget.post.name ?? 'Untitled Post'}',
        text: 'Here is a portable post created with ZPost',
      );
      
      // Clean up
      await exportDir.delete(recursive: true);
      
      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error exporting post: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export post: $e')),
        );
      }
    }
  }

  Widget _buildPostContent() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.post.name != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text(
                widget.post.name!,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          if (widget.post.content != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Text(
                widget.post.content!,
                style: const TextStyle(
                  fontSize: 16,
                ),
              ),
            ),
          if (widget.post.mediaPath != null)
            _buildMediaContent(),
        ],
      ),
    );
  }

  Widget _buildMediaContent() {
    // Show loading indicator when media is being loaded
    if (_isLoading && _mediaBytes == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    // Show error if there was an issue loading media
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _error = null;
                    _isLoading = true;
                  });
                  _loadMedia();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    
    // If media is still loading but we have a URL, try to display a network image while waiting
    if (_mediaBytes == null && widget.post.mediaPath != null) {
      final mediaUrl = ApiConfig.getMediaUrl(widget.post.mediaPath!);
      return Stack(
        alignment: Alignment.center,
        children: [
          // Attempt to show a network image while waiting for bytes
          if ((widget.post.mediaType?.startsWith('image') == true || widget.post.mediaType == 'image'))
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                mediaUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: double.infinity,
                    height: 200,
                    color: Theme.of(context).colorScheme.surfaceVariant,
                  );
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    width: double.infinity,
                    height: 200,
                    color: Theme.of(context).colorScheme.surfaceVariant,
                    child: const Center(child: CircularProgressIndicator()),
                  );
                },
              ),
            ),
          // Show loading indicator on top
          if (_isLoading)
            const CircularProgressIndicator(),
        ],
      );
    }
    
    // Handle different media types
    if (widget.post.mediaType?.startsWith('image') == true || 
        widget.post.mediaType == 'image') {
      return Hero(
        tag: 'post-media-${widget.post.id}',
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(
            _mediaBytes!,
            fit: BoxFit.cover,
            width: double.infinity,
            errorBuilder: (context, error, stackTrace) {
              debugPrint('Error displaying image from memory: $error');
              // Fallback to network image if memory image fails
              final mediaUrl = ApiConfig.getMediaUrl(widget.post.mediaPath!);
              return Image.network(
                mediaUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                errorBuilder: (context, error, stackTrace) {
                  debugPrint('Error displaying network image: $error');
                  return Container(
                    width: double.infinity,
                    height: 200,
                    color: Theme.of(context).colorScheme.surfaceVariant,
                    child: const Center(
                      child: Text('Could not load image'),
                    ),
                  );
                },
              );
            },
          ),
        ),
      );
    } else if ((widget.post.mediaType?.startsWith('video') == true || 
               widget.post.mediaType == 'video') && 
               _isVideoInitialized && 
               _videoController != null) {
      return Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: _videoController!.value.aspectRatio,
              child: VideoPlayer(_videoController!),
            ),
          ),
          const SizedBox(height: 8),
          _VideoControls(controller: _videoController!),
        ],
      );
    } else {
      // For unknown media types, try to display as image anyway
      return Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(
              _mediaBytes!,
              fit: BoxFit.cover,
              width: double.infinity,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: double.infinity,
                  height: 200,
                  color: Theme.of(context).colorScheme.surfaceVariant,
                  child: Center(
                    child: Text(
                      'Unsupported media type: ${widget.post.mediaType}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = Provider.of<AuthProvider>(context, listen: false);
    final bool isCurrentUser = currentUser.publicKeyHash == widget.post.author.publicKeyHash;
    final authorName = widget.post.author.name ?? 'Anonymous';
    
    // Get responsive layout information
    final isMobile = ResponsiveLayout.isMobile(context);
    final isTablet = ResponsiveLayout.isTablet(context);
    final isDesktop = ResponsiveLayout.isDesktop(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.post.name ?? 'Post Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share),
            onPressed: _isLoading ? null : _exportPost,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshPost,
        child: Center(
          child: ResponsiveContainer(
            maxWidth: isDesktop ? 800 : (isTablet ? 600 : double.infinity),
            padding: ResponsiveLayout.getScreenPadding(context),
            child: SingleChildScrollView(
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
                              publicKeyHash: widget.post.author.publicKeyHash,
                              name: widget.post.author.name,
                            ),
                          ),
                        );
                      },
                      child: CircleAvatar(
                        backgroundImage: widget.post.author.image != null
                            ? MemoryImage(base64Decode(widget.post.author.image!))
                            : null,
                        child: widget.post.author.image == null
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
                              publicKeyHash: widget.post.author.publicKeyHash,
                              name: widget.post.author.name,
                            ),
                          ),
                        );
                      },
                      child: Text(widget.post.author.name ?? 'Anonymous'),
                    ),
                    subtitle: Text(
                      timeago.format(widget.post.createdAt),
                    ),
                    trailing: widget.post.contentHash != null
                        ? IconButton(
                            icon: const Icon(Icons.qr_code),
                            onPressed: () => _showQRDialog(context),
                          )
                        : null,
                  ),
                  _buildPostContent(),
                  const SizedBox(height: 16),
                  // Action buttons
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FilledButton.icon(
                          onPressed: () => _handleSendReputation(context),
                          icon: const Icon(Icons.account_balance_wallet),
                          label: const Text('Support'),
                          style: FilledButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            foregroundColor: Theme.of(context).colorScheme.onPrimary,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: () => _handleVerify(context),
                          icon: const Icon(Icons.verified),
                          label: const Text('Verify'),
                          style: FilledButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.secondary,
                            foregroundColor: Theme.of(context).colorScheme.onSecondary,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: () => _sharePost(context),
                          icon: const Icon(Icons.share),
                          label: const Text('Share'),
                          style: FilledButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.tertiary,
                            foregroundColor: Theme.of(context).colorScheme.onTertiary,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          '${widget.post.reputationPoints} RPs',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 16),
                        InkWell(
                          onTap: () {
                            if (widget.post.contentHash != null) {
                              final cleanHash = widget.post.contentHash!.replaceAll('UR:VERIFY-POST/', '');
                              showSupportersDialog(context, cleanHash);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Cannot show supporters: Post hash not available')),
                              );
                            }
                          },
                          child: Row(
                            children: [
                              _isLoadingSupporters
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.people, size: 14, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(
                                _supportersInfo != null 
                                  ? '${_supportersInfo!.totalSupporters} Supporters'
                                  : '${widget.post.supporterCount} Supporters',
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Comments',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        // Refresh button for comments
                        IconButton(
                          icon: const Icon(Icons.refresh, size: 20),
                          onPressed: _isLoading ? null : _loadComments,
                          tooltip: 'Refresh comments',
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Form(
                      key: _formKey,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _commentController,
                              decoration: InputDecoration(
                                hintText: 'Write a comment...',
                                filled: true,
                                fillColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter a comment';
                                }
                                return null;
                              },
                              minLines: 1,
                              maxLines: 5,
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(),
                                  )
                                : Icon(
                                    Icons.send_rounded,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                            onPressed: _isLoading ? null : _submitComment,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_isLoading && _comments.isEmpty)
                    const Center(child: CircularProgressIndicator())
                  else if (_error != null)
                    Center(
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    )
                  else if (_comments.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline,
                              size: 48,
                              color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No comments yet',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Be the first to share your thoughts!',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _comments.length,
                      itemBuilder: (context, index) {
                        final comment = _comments[index];
                        final isAuthor = context
                                .read<AuthProvider>()
                                .publicKeyHash ==
                            comment.author.publicKeyHash;

                        // Format the comment creation date for tooltip
                        final formattedDate = '${comment.createdAt.day}/${comment.createdAt.month}/${comment.createdAt.year} ${comment.createdAt.hour}:${comment.createdAt.minute.toString().padLeft(2, '0')}';
                        
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: isAuthor 
                                  ? Theme.of(context).colorScheme.primaryContainer 
                                  : Theme.of(context).colorScheme.secondaryContainer,
                                foregroundColor: isAuthor
                                  ? Theme.of(context).colorScheme.onPrimaryContainer
                                  : Theme.of(context).colorScheme.onSecondaryContainer,
                                child: Text(
                                  (comment.author.name?.isNotEmpty ?? false)
                                      ? comment.author.name![0].toUpperCase()
                                      : 'A',
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isAuthor 
                                      ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3)
                                      : Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                                    borderRadius: BorderRadius.circular(16),
                                    border: isAuthor 
                                      ? Border.all(color: Theme.of(context).colorScheme.primaryContainer, width: 1)
                                      : null,
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              comment.author.name ?? 'Anonymous',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Tooltip(
                                            message: formattedDate,
                                            child: Text(
                                              timeago.format(comment.createdAt),
                                              style: TextStyle(
                                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                fontSize: 12,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const Spacer(),
                                          if (isAuthor)
                                            comment.isDeleting == true
                                              ? SizedBox(
                                                  width: 16,
                                                  height: 16,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: Theme.of(context).colorScheme.error,
                                                  ),
                                                )
                                              : IconButton(
                                                  icon: Icon(
                                                    Icons.delete_outline,
                                                    size: 18,
                                                    color: Theme.of(context).colorScheme.error,
                                                  ),
                                                  onPressed: () => _deleteComment(comment),
                                                  padding: EdgeInsets.zero,
                                                  constraints: const BoxConstraints(),
                                                  tooltip: 'Delete comment',
                                                ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        comment.content,
                                        style: TextStyle(
                                          color: Theme.of(context).colorScheme.onSurface,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _VideoControls extends StatelessWidget {
  final VideoPlayerController controller;

  const _VideoControls({Key? key, required this.controller}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          icon: Icon(
            controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
            size: 24,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          onPressed: () {
            if (controller.value.isPlaying) {
              controller.pause();
            } else {
              controller.play();
            }
          },
        ),
        Expanded(
          child: VideoProgressIndicator(
            controller,
            allowScrubbing: true,
            padding: const EdgeInsets.all(8.0),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.fullscreen, size: 24),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => Scaffold(
                  body: Center(
                    child: AspectRatio(
                      aspectRatio: controller.value.aspectRatio,
                      child: VideoPlayer(controller),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
