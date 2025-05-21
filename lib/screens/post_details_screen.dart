import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/post.dart';
import '../models/author.dart';
import '../models/comment.dart';
import '../models/supporter.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/deep_link_service.dart';
import '../services/post_service.dart';
import '../widgets/animated_copy_button.dart';
import '../widgets/custom_snackbar.dart';
import '../widgets/qr_dialog.dart';
import '../widgets/supporters_dialog.dart';
import '../screens/user_profile_screen.dart';
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
    _loadMedia();
    _loadComments();
    _loadSupporters();
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
    if (widget.post.mediaPath == null) return;

    try {
      final bytes = await PostService.downloadMedia(widget.post.mediaPath!);
      setState(() => _mediaBytes = bytes);

      if (widget.post.mediaType == 'video' && _mediaBytes != null) {
        await _initializeVideoPlayer();
      }
    } catch (e) {
      debugPrint('Error loading media: $e');
      if (mounted) {
        setState(() => _error = 'Failed to load media: $e');
      }
    }
  }

  Future<void> _initializeVideoPlayer() async {
    if (_mediaBytes == null) return;

    // Create a temporary file to store the video
    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/temp_video.mp4');
    await tempFile.writeAsBytes(_mediaBytes!);

    // Dispose previous controller if exists
    await _videoController?.dispose();
    
    _videoController = VideoPlayerController.file(tempFile);

    try {
      await _videoController!.initialize();
      if (mounted) {
        setState(() => _isVideoInitialized = true);
      }
    } catch (e) {
      debugPrint('Error initializing video player: $e');
      if (mounted) {
        setState(() {
          _isVideoInitialized = false;
          _error = 'Failed to initialize video: $e';
        });
      }
    }
  }

  Widget _buildAuthorAvatar(Author author) {
    if (author.image == null) {
      return CircleAvatar(
        child: Text(
          (author.name?.isNotEmpty ?? false) 
              ? author.name![0].toUpperCase()
              : 'A',
        ),
      );
    }

    try {
      final imageBytes = base64Decode(author.image!);
      return CircleAvatar(
        backgroundImage: MemoryImage(imageBytes),
      );
    } catch (e) {
      debugPrint('Error decoding author image: $e');
      return CircleAvatar(
        child: Text(
          (author.name?.isNotEmpty ?? false) 
              ? author.name![0].toUpperCase()
              : 'A',
        ),
      );
    }
  }

  Widget _buildMediaPreview(String mediaPath, String? mediaType) {
    return FutureBuilder<Uint8List>(
      future: PostService.downloadMedia(mediaPath),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasError) {
          return const Center(child: Text('Error loading media'));
        }

        if (!snapshot.hasData) {
          return const SizedBox();
        }

        if (mediaType == 'image') {
          return Image.memory(
            snapshot.data!,
            fit: BoxFit.cover,
          );
        } else if (mediaType == 'video') {
          return _buildVideoPlayer(snapshot.data!);
        }

        return const SizedBox();
      },
    );
  }

  Widget _buildPostContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.post.mediaPath != null) ...[
          if (_mediaBytes != null)
            Container(
              constraints: const BoxConstraints(
                maxHeight: 400, // Larger max height for details view
              ),
              width: double.infinity,
              child: widget.post.mediaType == 'video'
                ? _buildVideoPlayer(_mediaBytes!)
                : Image.memory(
                    _mediaBytes!,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      debugPrint('Error loading image: $error');
                      return const Center(
                        child: Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Colors.red,
                        ),
                      );
                    },
                  ),
            )
          else
            const Center(child: CircularProgressIndicator()),
          const SizedBox(height: 16),
        ],
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            widget.post.content,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      ],
    );
  }

  Widget _buildVideoPlayer(Uint8List videoData) {
    if (_videoController == null || !_isVideoInitialized) {
      return Container(
        color: Colors.black12,
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return AspectRatio(
      aspectRatio: _videoController!.value.aspectRatio,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          VideoPlayer(_videoController!),
          _buildVideoControls(),
        ],
      ),
    );
  }

  Widget _buildVideoControls() {
    return ValueListenableBuilder(
      valueListenable: _videoController!,
      builder: (context, VideoPlayerValue value, child) {
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.black54],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Volume slider
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        value.volume == 0
                            ? Icons.volume_off
                            : value.volume < 0.5
                                ? Icons.volume_down
                                : Icons.volume_up,
                        color: Colors.white,
                      ),
                      onPressed: () {
                        if (value.volume > 0) {
                          _videoController!.setVolume(0);
                        } else {
                          _videoController!.setVolume(1.0);
                        }
                      },
                    ),
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: Colors.white,
                          inactiveTrackColor: Colors.white30,
                          thumbColor: Colors.white,
                          trackHeight: 2.0,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 6.0,
                          ),
                          overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 12.0,
                          ),
                        ),
                        child: Slider(
                          value: value.volume,
                          onChanged: (newVolume) {
                            _videoController!.setVolume(newVolume);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Progress bar and playback controls
              Row(
                children: [
                  IconButton(
                    icon: Icon(
                      value.isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      if (value.isPlaying) {
                        _videoController!.pause();
                      } else {
                        _videoController!.play();
                      }
                    },
                  ),
                  Expanded(
                    child: VideoProgressIndicator(
                      _videoController!,
                      allowScrubbing: true,
                      colors: const VideoProgressColors(
                        playedColor: Colors.white,
                        bufferedColor: Colors.white24,
                        backgroundColor: Colors.black45,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.fullscreen, color: Colors.white),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => Scaffold(
                            backgroundColor: Colors.black,
                            body: SafeArea(
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Center(
                                    child: AspectRatio(
                                      aspectRatio: _videoController!.value.aspectRatio,
                                      child: VideoPlayer(_videoController!),
                                    ),
                                  ),
                                  Positioned(
                                    top: 0,
                                    left: 0,
                                    child: IconButton(
                                      icon: const Icon(Icons.close, color: Colors.white),
                                      onPressed: () => Navigator.of(context).pop(),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    left: 0,
                                    right: 0,
                                    child: _buildVideoControls(),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _loadComments() async {
    try {
      setState(() => _isLoading = true);
      final comments = await ApiService.getComments(widget.post.id);
      setState(() {
        _comments = comments.map((c) => Comment.fromJson(c)).toList();
        _error = null;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _submitComment() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await ApiService.createComment(
        widget.post.id,
        _commentController.text.trim(),
      );

      setState(() {
        _comments.insert(0, Comment.fromJson(response));
        _commentController.clear();
      });

      if (mounted) {
        CustomSnackbar.show(
          context,
          message: 'Comment posted successfully',
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

  Future<void> _deleteComment(Comment comment) async {
    try {
      await ApiService.deleteComment(comment.id);
      setState(() {
        _comments.removeWhere((c) => c.id == comment.id);
      });
      if (mounted) {
        CustomSnackbar.show(
          context,
          message: 'Comment deleted successfully',
        );
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.showError(
          context,
          message: e.toString(),
        );
      }
    }
  }

  Future<void> _refreshPost() async {
    await _loadComments();
  }

  Future<void> _handleSendReputation(BuildContext context) async {
    try {
      final cleanHash = widget.post.contentHash!.replaceAll('UR:VERIFY-POST/', '');
      await DeepLinkService.launchWalletForReputation(cleanHash);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _handleVerify(BuildContext context) async {
    try {
      final cleanHash = widget.post.contentHash!.replaceAll('UR:VERIFY-POST/', '');
      await DeepLinkService.launchWalletForVerify(cleanHash);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _showQRDialog(BuildContext context) {
    bool isVerifyContext = true;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          // Get the base hash without any prefix
          final baseHash = widget.post.contentHash!.replaceAll('UR:VERIFY-POST/', '');
          
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
                        icon: const Icon(Icons.verified_user),
                        onPressed: () => _handleVerify(context),
                      ),
                      IconButton(
                        icon: const Icon(Icons.account_balance_wallet),
                        onPressed: () => _handleSendReputation(context),
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

  Future<Directory> _getExportDirectory() async {
    if (Platform.isAndroid) {
      // Request storage permissions on Android
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        throw Exception('Storage permission is required to export content');
      }
      
      // Get the Downloads directory using getExternalStorageDirectory
      final baseDir = await getExternalStorageDirectory();
      if (baseDir == null) {
        throw Exception('Could not access external storage');
      }
      
      // Navigate up to find the root external storage
      String? downloadsPath;
      List<String> paths = baseDir.path.split('/');
      int index = paths.indexOf('Android');
      if (index > 0) {
        downloadsPath = paths.sublist(0, index).join('/') + '/Download';
      } else {
        // Fallback if we can't find the Android directory
        downloadsPath = baseDir.path + '/Download';
      }
      
      final downloadsDir = Directory(downloadsPath);
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }
      return downloadsDir;
    } else {
      // Use the platform-specific documents directory for other platforms
      final directory = await getApplicationDocumentsDirectory();
      final downloadsDir = Directory('${directory.path}/Downloads');
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }
      return downloadsDir;
    }
  }

  Future<void> _exportPost() async {
    try {
      setState(() => _isLoading = true);
      
      // Request storage permission
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        throw Exception('Storage permission is required to export posts');
      }
      
      // Validate post data before export
      if (widget.post.content.isEmpty) {
        throw Exception('Post content cannot be empty');
      }
      
      // If post has media, ensure it's properly loaded
      if (widget.post.mediaPath != null && _mediaBytes == null) {
        throw Exception('Media must be loaded before exporting');
      }
      
      try {
        // Export post using PostService which follows W3-S-POST-NFT standard
        final exportData = await PostService.exportPost(widget.post);
        
        // Verify the exported data can be imported
        final exportedJson = json.decode(exportData);
        if (exportedJson['standardName'] != 'W3-S-POST-NFT' ||
            exportedJson['standardVersion'] != '1.0.0') {
          throw Exception('Invalid export format');
        }
        
        // Get the downloads directory
        final downloadsDir = await _getExportDirectory();
        if (!await downloadsDir.exists()) {
          await downloadsDir.create(recursive: true);
        }

        final fileName = 'post_${widget.post.id}_${DateTime.now().millisecondsSinceEpoch}.pcontent';
        final filePath = path.join(downloadsDir.path, fileName);
        
        // Create a ZIP archive
        final archive = Archive();
        
        // Parse metadata to get part ID before adding files
        final metadata = json.decode(exportData);
        String updatedExportData = exportData;
        
        // If there's media, add it to the files directory using the part ID
        if (widget.post.mediaPath != null && _mediaBytes != null && 
            metadata['parts'] != null && metadata['parts'].isNotEmpty) {
          // Get the part ID from metadata
          final partId = metadata['parts'][0]['id'];
          
          // Add file using part ID as filename
          archive.addFile(
            ArchiveFile('files/$partId', _mediaBytes!.length, _mediaBytes!)
          );
          
          // Update file size in metadata
          metadata['parts'][0]['size'] = _mediaBytes!.length;
          updatedExportData = json.encode(metadata);
        }

        // Add metadata.json to the archive root
        final metadataBytes = utf8.encode(updatedExportData);
        archive.addFile(
          ArchiveFile('metadata.json', metadataBytes.length, metadataBytes)
        );
        
        // Write the archive to a file
        final encoder = ZipEncoder();
        final zipData = encoder.encode(archive);
        if (zipData == null) {
          throw Exception('Failed to create ZIP archive');
        }
        
        final file = File(filePath);
        await file.writeAsBytes(zipData);
        
        if (mounted) {
          CustomSnackbar.show(
            context,
            message: 'Post exported successfully to Downloads/$fileName',
          );
        }
      } catch (e) {
        throw Exception('Export failed: $e');
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.showError(
          context,
          message: 'Failed to export post: ${e.toString()}',
        );
      }
      debugPrint('Export error: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = Provider.of<AuthProvider>(context, listen: false);
    final bool isCurrentUser = currentUser.publicKeyHash == widget.post.author.publicKeyHash;
    final authorName = widget.post.author.name ?? 'Anonymous';

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
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                    ),
                    const SizedBox(width: 16),
                    FilledButton.icon(
                      onPressed: () => _handleVerify(context),
                      icon: const Icon(Icons.verified),
                      label: const Text('Verify'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.secondary,
                        foregroundColor: Theme.of(context).colorScheme.onSecondary,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
                child: const Text(
                  'Comments',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
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
                  padding: const EdgeInsets.all(16.0),
                  child: Center(
                    child: Text(
                      'No comments yet. Be the first to comment!',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
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

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                            foregroundColor: Theme.of(context).colorScheme.onSecondaryContainer,
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
                                color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        comment.author.name ?? 'Anonymous',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        timeago.format(comment.createdAt),
                                        style: TextStyle(
                                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                                          fontSize: 12,
                                        ),
                                      ),
                                      if (isAuthor) const Spacer(),
                                      if (isAuthor)
                                        IconButton(
                                          icon: Icon(
                                            Icons.delete_outline,
                                            size: 18,
                                            color: Theme.of(context).colorScheme.error,
                                          ),
                                          onPressed: () => _deleteComment(comment),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
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
