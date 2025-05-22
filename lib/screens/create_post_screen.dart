import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/post_provider.dart';
import '../services/post_service.dart';
import '../providers/auth_provider.dart';
import '../models/author.dart';
import '../utils/responsive_layout.dart';
import '../widgets/responsive_container.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
// import 'package:emoji_picker_flutter/emoji_picker_flutter.dart'; // Temporarily commented out
import 'package:path/path.dart' as path;

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _formKey = GlobalKey<FormState>();
  final _contentController = TextEditingController();
  bool _isLoading = false;
  String? _error;
  final String _importContent = '';
  bool _isArabicContent = false;
  bool _showEmojiPicker = false;
  
  // Media selection variables
  dynamic _selectedMedia; // Can be File or web file
  String? _mediaType;
  bool _isVideo = false;
  List<int>? _mediaBytes;
  String? _mediaFileName;

  @override
  void initState() {
    super.initState();
    // Listen for changes in the text field to detect language
    _contentController.addListener(_detectTextDirection);
  }

  @override
  void dispose() {
    _contentController.removeListener(_detectTextDirection);
    _contentController.dispose();
    super.dispose();
  }
  
  // Helper method to detect if text is Arabic
  bool _isArabic(String text) {
    // Arabic Unicode block range: U+0600 to U+06FF
    final arabicRegex = RegExp(r'[\u0600-\u06FF]');
    return arabicRegex.hasMatch(text);
  }
  
  // Detect text direction based on content
  void _detectTextDirection() {
    final isArabic = _isArabic(_contentController.text);
    if (isArabic != _isArabicContent) {
      setState(() {
        _isArabicContent = isArabic;
      });
    }
  }

  Future<void> _createPost() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await Provider.of<PostProvider>(context, listen: false)
          .createPost(
            _contentController.text,
            mediaFile: _selectedMedia,
            mediaType: _mediaType,
            mediaBytes: _mediaBytes,
            fileName: _mediaFileName,
          );
      
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      // Log the error for debugging
      print('Error in _createPost: ${e.toString()}');
      
      // Check for file size errors first
      if (e.toString().contains('FileTooLargeException') || 
          e.toString().contains('413') || 
          e.toString().toLowerCase().contains('entity too large') || 
          e.toString().toLowerCase().contains('too large')) {
        
        setState(() {
          _error = 'The image file is too large. Please use a smaller image (max 10MB) or compress this image.';
        });
        
        if (mounted) {
          _showFileTooLargeDialog();
        }
      } else {
        // Handle other errors
        String errorMessage = _getFormattedErrorMessage(e);
        setState(() {
          _error = errorMessage;
        });
        
        if (mounted && _isNetworkError(e)) {
          _showNetworkErrorDialog();
        }
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  // Helper method to check if the error is related to file size
  bool _isFileSizeError(dynamic error) {
    final errorStr = error.toString().toLowerCase();
    return errorStr.contains('filetoolargeexception') || 
           errorStr.contains('413') || 
           errorStr.contains('entity too large') || 
           errorStr.contains('request entity too large') ||
           errorStr.contains('too large') ||
           (errorStr.contains('file') && errorStr.contains('large'));
  }
  
  // Helper method to check if the error is related to network issues
  bool _isNetworkError(dynamic error) {
    // First check if it's a file size error, which takes precedence
    if (_isFileSizeError(error)) {
      return false;
    }
    
    final errorStr = error.toString().toLowerCase();
    return errorStr.contains('xmlhttprequest') || 
           errorStr.contains('network') || 
           errorStr.contains('connection') || 
           errorStr.contains('internet') || 
           errorStr.contains('timeout') ||
           errorStr.contains('unreachable');
  }
  
  // Helper method to format error messages in a user-friendly way
  String _getFormattedErrorMessage(dynamic error) {
    final errorStr = error.toString();
    
    // Handle file size errors
    if (_isFileSizeError(error)) {
      return 'The image file is too large. Please use a smaller image (max 10MB) or compress this image.';
    }
    
    // Handle network errors
    if (_isNetworkError(error)) {
      return 'Network error: Unable to connect to the server. Please check your internet connection and try again.';
    }
    
    // Handle XMLHttpRequest errors
    if (errorStr.contains('XMLHttpRequest')) {
      return 'Connection error: Unable to reach the server. Please check your internet connection and try again.';
    }
    
    // Handle other common errors
    if (errorStr.contains('timed out')) {
      return 'Request timed out. Please try again later.';
    }
    
    // Default case - clean up the error message
    String cleanError = errorStr
        .replaceAll('Exception: ', '')
        .replaceAll('Error: ', '');
        
    // If it's a long error message, truncate it
    if (cleanError.length > 150) {
      cleanError = '${cleanError.substring(0, 147)}...';
    }
    
    return cleanError;
  }
  
  // Show a helpful dialog with options when file is too large
  void _showFileTooLargeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('File Too Large'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'The selected image file exceeds the maximum allowed size (10MB). Please try one of these options:',
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.photo_size_select_large),
              title: const Text('Resize the image'),
              subtitle: const Text('Use an image editor to reduce dimensions'),
              dense: true,
            ),
            ListTile(
              leading: const Icon(Icons.compress),
              title: const Text('Compress the image'),
              subtitle: const Text('Use a compression tool to reduce file size'),
              dense: true,
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Select a different image'),
              subtitle: const Text('Choose a smaller image file'),
              dense: true,
              onTap: () {
                Navigator.of(context).pop();
                _selectMedia();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _removeMedia();
            },
            child: const Text('Remove Media'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
  
  // Show a helpful dialog for network errors
  void _showNetworkErrorDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Connection Error'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Unable to connect to the server. This could be due to:',
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.wifi_off),
              title: const Text('No internet connection'),
              subtitle: const Text('Check your Wi-Fi or mobile data'),
              dense: true,
            ),
            ListTile(
              leading: const Icon(Icons.cloud_off),
              title: const Text('Server unavailable'),
              subtitle: const Text('The server might be temporarily down'),
              dense: true,
            ),
            if (_selectedMedia != null) ...[  
              ListTile(
                leading: const Icon(Icons.image),
                title: const Text('Large media file'),
                subtitle: const Text('Your image might be too large to upload'),
                dense: true,
              ),
            ],
          ],
        ),
        actions: [
          if (_selectedMedia != null)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _removeMedia();
              },
              child: const Text('Remove Media'),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleImport() async {
    try {
      setState(() => _isLoading = true);
      
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        withData: true,
      );

      if (result != null && result.files.single.bytes != null) {
        final bytes = result.files.single.bytes!;
        final fileName = result.files.single.name.toLowerCase();
        
        // Handle different file types
        if (fileName.endsWith('.pcontent')) {
          await _importPContentFile(bytes);
        } else if (fileName.endsWith('.json')) {
          await _importW3SPostNFTFile(bytes);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Please select a .pcontent or .json file')),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  // Import a .pcontent file (portable post format)
  Future<void> _importPContentFile(List<int> bytes) async {
    try {
      // Decode the zip file
      final archive = ZipDecoder().decodeBytes(bytes);
      
      // List all files in archive for debugging
      debugPrint('Files in archive:');
      for (final file in archive.files) {
        debugPrint('- ${file.name}');
      }
      
      // Find and read metadata.json
      final metadataFile = archive.findFile('metadata.json');
      if (metadataFile == null) {
        throw Exception('Invalid .pcontent file: metadata.json not found');
      }

      final content = utf8.decode(metadataFile.content as List<int>);
      final metadata = jsonDecode(content) as Map<String, dynamic>;
      
      // Extract content - check different possible formats
      String? postContent;
      
      // Try to get content from different possible locations in the metadata
      if (metadata.containsKey('content') && metadata['content'] is String) {
        postContent = metadata['content'] as String;
      } else if (metadata.containsKey('text') && metadata['text'] is String) {
        postContent = metadata['text'] as String;
      } else if (metadata.containsKey('standardData') && 
                metadata['standardData'] is Map<String, dynamic> && 
                metadata['standardData']['text'] is String) {
        postContent = metadata['standardData']['text'] as String;
      } else if (metadata.containsKey('description') && metadata['description'] is String) {
        postContent = metadata['description'] as String;
      }
      
      if (postContent == null || postContent.isEmpty) {
        // Log the metadata content for debugging
        debugPrint('Metadata content: $metadata');
        throw Exception('Invalid .pcontent file: content is empty or not found');
      }
      
      // Set the content in the text field
      _contentController.text = postContent;
      
      // Check for media - handle different possible formats
      ArchiveFile? mediaFile;
      String? mediaFileName;
      String? mediaType;
      
      // First check for a media file in the root
      mediaFile = archive.findFile('media');
      
      // If not found, check for files in the 'files' directory
      if (mediaFile == null) {
        for (final file in archive.files) {
          if (file.name.startsWith('files/')) {
            mediaFile = file;
            mediaFileName = file.name.split('/').last;
            break;
          }
        }
      }
      
      // If we found a media file, process it
      if (mediaFile != null) {
        final mediaBytes = mediaFile.content as List<int>;
        
        // Try to determine media type from metadata or filename
        if (metadata.containsKey('mediaType')) {
          mediaType = metadata['mediaType'] as String?;
        } else if (metadata.containsKey('standardData') && 
                  metadata['standardData'] is Map<String, dynamic> && 
                  metadata['standardData']['mediaType'] is String) {
          mediaType = metadata['standardData']['mediaType'] as String?;
        } else {
          // Try to determine from file extension
          final extension = mediaFileName != null ? 
              path.extension(mediaFileName).toLowerCase() : '';
          
          // Convert to proper MIME type
          mediaType = _getMimeType(extension);
        }
        
        // Make sure we have a proper MIME type format
        if (mediaType != null && !mediaType.contains('/')) {
          // Convert simple types like 'image' to proper MIME types
          if (mediaType == 'image') {
            mediaType = 'image/jpeg';
          } else if (mediaType == 'video') {
            mediaType = 'video/mp4';
          }
        }
        
        setState(() {
          _mediaBytes = mediaBytes;
          _mediaType = mediaType;
          _mediaFileName = mediaFileName ?? 'media${mediaType == 'video' ? '.mp4' : '.jpg'}';
          _isVideo = mediaType == 'video';
        });
        
        debugPrint('Media loaded: $_mediaFileName, type: $_mediaType');
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post imported successfully')),
        );
      }
    } catch (e) {
      debugPrint('Import error details: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error importing .pcontent file: $e')),
        );
      }
    }
  }
  
  // Import a W3-S-POST-NFT format file (.json)
  Future<void> _importW3SPostNFTFile(List<int> bytes) async {
    try {
      // Parse the JSON content
      final jsonContent = utf8.decode(bytes);
      final jsonData = jsonDecode(jsonContent) as Map<String, dynamic>;
      
      // Check if it's a valid W3-S-POST-NFT format
      if (jsonData['standardName'] != 'W3-S-POST-NFT') {
        throw Exception('Invalid file format: Not a W3-S-POST-NFT standard');
      }
      
      // Show confirmation dialog
      if (!mounted) return;
      final shouldImport = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Import Post'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Name: ${jsonData['name'] ?? 'Unnamed post'}'),
              const SizedBox(height: 8),
              if (jsonData['description'] != null) ...[  
                Text('Description: ${jsonData['description']}'),
                const SizedBox(height: 8),
              ],
              Text('Created: ${jsonData['createdAt'] != null ? DateTime.parse(jsonData['createdAt']).toString() : 'Unknown'}'),
              const SizedBox(height: 16),
              const Text('Do you want to import this post?'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Import'),
            ),
          ],
        ),
      ) ?? false;
      
      if (!shouldImport) return;
      
      // Import the post using the PostProvider
      final post = await Provider.of<PostProvider>(context, listen: false)
          .importPost(jsonContent);
      
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post imported successfully')),
        );
        // Close the create post screen since we've already imported the post
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error importing W3-S-POST-NFT file: $e')),
        );
      }
    }
  }
  
  // Helper method to get the proper MIME type from a file extension or name
  String _getMimeType(String fileNameOrExtension) {
    // Default MIME types
    const defaultImageMime = 'image/jpeg';
    const defaultVideoMime = 'video/mp4';
    
    // Extract extension if a full filename is provided
    final extension = fileNameOrExtension.contains('.')
        ? path.extension(fileNameOrExtension).toLowerCase()
        : '.$fileNameOrExtension';
    
    // Map common extensions to MIME types
    switch (extension) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.gif':
        return 'image/gif';
      case '.webp':
        return 'image/webp';
      case '.mp4':
        return 'video/mp4';
      case '.mov':
        return 'video/quicktime';
      case '.avi':
        return 'video/x-msvideo';
      case '.webm':
        return 'video/webm';
      default:
        // If we can't determine the specific type, use generic types based on file extension categories
        if (['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp', '.tiff'].any(
            (e) => extension.endsWith(e))) {
          return defaultImageMime;
        } else if (['.mp4', '.mov', '.avi', '.webm', '.mkv', '.flv', '.wmv'].any(
            (e) => extension.endsWith(e))) {
          return defaultVideoMime;
        }
        // Default to jpeg if we can't determine the type
        return defaultImageMime;
    }
  }
  
  Future<void> _selectMedia() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.media,
        allowMultiple: false,
        withData: true, // Always request data to ensure it works on web
      );
      
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.single;
        final fileName = file.name.toLowerCase();
        final String mimeType = _getMimeType(fileName);
        final isVideo = mimeType.startsWith('video/');
        
        // Check if we're on web platform
        final isWeb = identical(0, 0.0); // A simple way to detect web in Dart
        
        if (isWeb) {
          // Web platform - always use bytes
          if (file.bytes != null) {
            setState(() {
              _mediaBytes = file.bytes;
              _mediaFileName = file.name;
              _mediaType = mimeType;
              _isVideo = isVideo;
              _selectedMedia = null; // No File object on web
            });
          } else {
            throw Exception('File bytes are null');
          }
        } else {
          // Mobile/desktop platform
          if (file.path != null) {
            final fileObj = File(file.path!);
            setState(() {
              _selectedMedia = fileObj;
              _mediaType = mimeType;
              _isVideo = isVideo;
              
              // For consistency, also store bytes for preview
              if (file.bytes != null) {
                _mediaBytes = file.bytes;
              }
              _mediaFileName = file.name;
            });
          } else if (file.bytes != null) {
            // Fallback to bytes if path is not available
            setState(() {
              _mediaBytes = file.bytes;
              _mediaFileName = file.name;
              _mediaType = mimeType;
              _isVideo = isVideo;
              _selectedMedia = null;
            });
          }
        }
        
        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Media selected: ${file.name}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error selecting media: $e')),
        );
      }
    }
  }
  
  void _removeMedia() {
    setState(() {
      _selectedMedia = null;
      _mediaType = null;
      _isVideo = false;
      _mediaBytes = null;
      _mediaFileName = null;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isMobile = ResponsiveLayout.isMobile(context);
    final isTablet = ResponsiveLayout.isTablet(context);
    final isDesktop = ResponsiveLayout.isDesktop(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Post'),
        actions: [
          IconButton(
            icon: _isLoading 
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Icon(Icons.file_upload),
            onPressed: _isLoading ? null : _handleImport,
            tooltip: 'Import Post',
          ),
        ],
      ),
      body: Center(
        child: ResponsiveContainer(
          maxWidth: isDesktop ? 800 : (isTablet ? 600 : double.infinity),
          padding: ResponsiveLayout.getScreenPadding(context),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Directionality(
                  textDirection: _isArabicContent ? TextDirection.rtl : TextDirection.ltr,
                  child: TextFormField(
                    controller: _contentController,
                    maxLines: 5,
                    textAlign: _isArabicContent ? TextAlign.right : TextAlign.left,
                    decoration: InputDecoration(
                      hintText: 'What\'s on your mind?',
                      border: const OutlineInputBorder(),
                      // Align hint text based on content direction
                      hintTextDirection: _isArabicContent ? TextDirection.rtl : TextDirection.ltr,
                      alignLabelWithHint: true,
                      // Emoji button removed
                      /* suffixIcon: IconButton(
                      icon: const Icon(Icons.emoji_emotions_outlined),
                      tooltip: 'Add emoji',
                      onPressed: null,
                      ), */
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter some content';
                      }
                      return null;
                    },
                  ),
                ),
              
                // Emoji picker - temporarily commented out
                /* if (_showEmojiPicker) ... {
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 250,
                    child: EmojiPicker(
                      onEmojiSelected: (category, emoji) {
                        // Insert emoji at current cursor position
                        final text = _contentController.text;
                        final selection = _contentController.selection;
                        final newText = text.replaceRange(
                          selection.start,
                          selection.end,
                          emoji.emoji,
                        );
                        _contentController.text = newText;
                        // Move cursor after the inserted emoji
                        _contentController.selection = TextSelection.fromPosition(
                          TextPosition(offset: selection.start + emoji.emoji.length),
                        );
                      },
                      config: Config(
                        columns: 7,
                        emojiSizeMax: 32,
                        verticalSpacing: 0,
                        horizontalSpacing: 0,
                        initCategory: Category.RECENT,
                        bgColor: theme.scaffoldBackgroundColor,
                        indicatorColor: colorScheme.primary,
                        iconColor: Colors.grey,
                        iconColorSelected: colorScheme.primary,
                        recentsLimit: 28,
                      ),
                    ),
                  ),
                }, */
                const SizedBox(height: 16),
                
                // Media selection section
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Row(
                    children: [
                      FilledButton.icon(
                        onPressed: _isLoading ? null : _selectMedia,
                        icon: const Icon(Icons.add_photo_alternate),
                        label: Text(isMobile ? 'Media' : 'Add Media'),
                        style: FilledButton.styleFrom(
                          backgroundColor: colorScheme.secondary,
                          foregroundColor: colorScheme.onSecondary,
                          padding: EdgeInsets.symmetric(
                            horizontal: isMobile ? 16 : 24, 
                            vertical: 12
                          ),
                        ),
                      ),
                      if (_selectedMedia != null) ...[  
                        const SizedBox(width: 12),
                        IconButton.filled(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: _removeMedia,
                          tooltip: 'Remove media',
                          style: IconButton.styleFrom(
                            backgroundColor: colorScheme.errorContainer,
                            foregroundColor: colorScheme.onErrorContainer,
                          ),
                        ),
                      ],
                      const Spacer(),
                      // Emoji picker toggle button removed
                      /*
                      IconButton.filled(
                        icon: Icon(Icons.emoji_emotions_outlined),
                        onPressed: null,
                        tooltip: 'Add emoji',
                        style: IconButton.styleFrom(
                          backgroundColor: colorScheme.surfaceVariant,
                          foregroundColor: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      */
                    ],
                  ),
                ),
                
                // Preview selected media
                if (_selectedMedia != null || _mediaBytes != null) ...[  
                  Container(
                    constraints: BoxConstraints(
                      maxHeight: isMobile ? 200 : 300,
                    ),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceVariant.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colorScheme.outline.withOpacity(0.3)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _isVideo
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.video_file,
                                size: 64,
                                color: colorScheme.primary,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Video Preview',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        )
                      : _mediaBytes != null
                        ? Image.memory(
                            Uint8List.fromList(_mediaBytes!),
                            fit: BoxFit.contain,
                          )
                        : Image.file(
                            _selectedMedia!,
                            fit: BoxFit.contain,
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Icon(Icons.attachment, size: 16, color: colorScheme.onSurfaceVariant),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${_mediaFileName ?? _selectedMedia?.path?.split('/')?.last ?? 'media file'}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                
                const SizedBox(height: 24),
                if (_error != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.errorContainer.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: colorScheme.error.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.error_outline, color: colorScheme.error),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _error!,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.error,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.close, size: 18, color: colorScheme.error),
                              onPressed: () => setState(() => _error = null),
                              constraints: const BoxConstraints(),
                              padding: const EdgeInsets.all(4),
                            ),
                          ],
                        ),
                        if (_isNetworkError(Exception(_error)) && _selectedMedia != null) ...[  
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const SizedBox(width: 28), // Align with text above
                              Expanded(
                                child: Text(
                                  'Try removing the image or using a smaller image file.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.error,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const SizedBox(width: 28),
                              TextButton.icon(
                                icon: const Icon(Icons.delete, size: 16),
                                label: const Text('Remove Media'),
                                onPressed: _removeMedia,
                                style: TextButton.styleFrom(
                                  foregroundColor: colorScheme.error,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                              const SizedBox(width: 8),
                              TextButton.icon(
                                icon: const Icon(Icons.refresh, size: 16),
                                label: const Text('Retry'),
                                onPressed: _createPost,
                                style: TextButton.styleFrom(
                                  foregroundColor: colorScheme.primary,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: _isLoading ? null : _createPost,
                    icon: _isLoading
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colorScheme.onPrimary,
                            ),
                          )
                        : const Icon(Icons.send),
                    label: Text(
                      _isLoading ? 'Posting...' : 'Post',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
