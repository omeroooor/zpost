import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/post_provider.dart';
import '../services/post_service.dart';
import '../providers/auth_provider.dart';
import '../models/author.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';

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
  String _importContent = '';
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
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
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
        
        // Check if it's a .pcontent file
        if (!result.files.single.name.toLowerCase().endsWith('.pcontent')) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Please select a .pcontent file')),
            );
          }
          return;
        }

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
          debugPrint('Metadata content: $content');
          
          final Map<String, dynamic> rawData = json.decode(content);
          debugPrint('Parsed raw data: $rawData');

          // Get the standard data
          final standardData = rawData['standardData'] as Map<String, dynamic>?;
          if (standardData == null) {
            throw Exception('Missing standardData section in metadata');
          }

          // Validate required fields first
          if (!standardData.containsKey('text') || standardData['text'].toString().trim().isEmpty) {
            throw Exception('Missing or empty required field: text');
          }

          // Create standard-compliant metadata structure
          Map<String, dynamic> metadata = {
            'standardName': 'W3-S-POST-NFT',
            'standardVersion': '1.0.0',
            'data': Map<String, dynamic>.from(standardData),
            'contentHash': rawData['contentHash'],
            'createdAt': rawData['createdAt'],
            'updatedAt': rawData['updatedAt'],
            'owner': rawData['owner'],
            'rps': rawData['rps'],
          };

          // Handle media file if present in the data
          if (standardData['mediaPath'] != null) {
            final mediaFileName = standardData['mediaPath'] as String;
            debugPrint('Looking for media file: $mediaFileName');
            
            // Get parts array
            final parts = rawData['parts'] as List<dynamic>?;
            if (parts == null || parts.isEmpty) {
              throw Exception('Missing parts array in metadata');
            }

            // Find the part that matches our media file name
            final mediaPart = parts.firstWhere(
              (part) => part['name'] == mediaFileName,
              orElse: () => null,
            );

            if (mediaPart == null) {
              throw Exception('Media file info not found in parts array');
            }

            // Look for the file using its ID
            final mediaFileId = mediaPart['id'] as String;
            final mediaFile = archive.findFile('files/$mediaFileId');
            
            if (mediaFile == null) {
              throw Exception('Media file referenced in metadata but not found in archive');
            }

            // Save media file to app's cache directory
            final appDir = await getApplicationDocumentsDirectory();
            final mediaPath = '${appDir.path}/media/$mediaFileName';
            await Directory('${appDir.path}/media').create(recursive: true);
            await File(mediaPath).writeAsBytes(mediaFile.content as List<int>);
            
            debugPrint('Media file saved to: $mediaPath');
            
            // Create a copy of standardData with updated media path
            final updatedStandardData = Map<String, dynamic>.from(standardData);
            updatedStandardData['mediaPath'] = mediaPath;
            
            // Keep original data for hash computation
            metadata['standardData'] = standardData;
            // Add local data for actual file access
            metadata['localData'] = updatedStandardData;

            // Validate media checksum if present
            if (standardData['mediaChecksum'] != null) {
              final bytes = mediaFile.content as List<int>;
              final checksum = sha256.convert(bytes).toString();
              if (checksum != standardData['mediaChecksum']) {
                throw Exception('Media file checksum mismatch');
              }
              debugPrint('Media checksum verified');
            }
          }

          debugPrint('Final metadata to import: ${json.encode(metadata)}');

          final authProvider = context.read<AuthProvider>();
          if (authProvider.publicKeyHash == null) {
            throw Exception('User not authenticated');
          }

          final post = await PostService.importPost(
            json.encode(metadata),
            Author(
              name: authProvider.name,
              publicKeyHash: authProvider.publicKeyHash!,
            ),
          );

          if (mounted) {
            Navigator.pop(context, post);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Post imported successfully!')),
            );
          }
        } on ArchiveException catch (e) {
          debugPrint('Archive error: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Invalid .pcontent file format: $e')),
            );
          }
        } catch (e, stack) {
          debugPrint('Import error: $e');
          debugPrint('Stack trace: $stack');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error importing post: $e')),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('File selection error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error selecting file: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Select media (image or video) from gallery
  Future<void> _selectMedia() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.media,
        allowMultiple: false,
        withData: true, // Important for web support
      );

      if (result != null && result.files.isNotEmpty) {
        final fileType = result.files.single.extension?.toLowerCase() ?? '';
        
        // Check if it's a supported file type
        final isImage = ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(fileType);
        final isVideo = ['mp4', 'mov', 'avi', 'webm'].contains(fileType);
        
        if (!isImage && !isVideo) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Please select an image or video file')),
            );
          }
          return;
        }
        
        // Handle both web and mobile platforms
        if (result.files.single.bytes != null) {
          // Web platform or mobile with withData: true
          setState(() {
            _mediaBytes = result.files.single.bytes;
            _mediaFileName = result.files.single.name;
            _isVideo = isVideo;
            _mediaType = isImage ? 'image/${fileType == 'jpg' ? 'jpeg' : fileType}' : 'video/$fileType';
          });
        } else if (result.files.single.path != null) {
          // Mobile platform
          setState(() {
            _selectedMedia = File(result.files.single.path!);
            _isVideo = isVideo;
            _mediaType = isImage ? 'image/${fileType == 'jpg' ? 'jpeg' : fileType}' : 'video/$fileType';
          });
        }
      }
    } catch (e) {
      debugPrint('Error selecting media: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error selecting media: $e')),
        );
      }
    }
  }
  
  // Remove selected media
  void _removeMedia() {
    setState(() {
      _selectedMedia = null;
      _mediaBytes = null;
      _mediaFileName = null;
      _mediaType = null;
      _isVideo = false;
    });
  }

  @override
  Widget build(BuildContext context) {
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
      body: Padding(
        padding: const EdgeInsets.all(16),
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
                  textDirection: _isArabicContent ? TextDirection.rtl : TextDirection.ltr,
                  decoration: InputDecoration(
                    hintText: 'What\'s on your mind?',
                    border: const OutlineInputBorder(),
                    // Align hint text based on content direction
                    hintTextDirection: _isArabicContent ? TextDirection.rtl : TextDirection.ltr,
                    alignLabelWithHint: true,
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.emoji_emotions_outlined),
                      tooltip: 'Add emoji',
                      onPressed: () {
                        setState(() {
                          _showEmojiPicker = !_showEmojiPicker;
                        });
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter some text';
                    }
                    return null;
                  },
                ),
              ),
              
              // Emoji picker
              if (_showEmojiPicker) ...[  
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
                      _contentController.value = TextEditingValue(
                        text: newText,
                        selection: TextSelection.collapsed(
                          offset: selection.start + emoji.emoji.length,
                        ),
                      );
                    },
                    config: Config(
                      columns: 7,
                      emojiSizeMax: 32,
                      verticalSpacing: 0,
                      horizontalSpacing: 0,
                      initCategory: Category.RECENT,
                      bgColor: Theme.of(context).scaffoldBackgroundColor,
                      indicatorColor: Theme.of(context).colorScheme.primary,
                      iconColor: Colors.grey,
                      iconColorSelected: Theme.of(context).colorScheme.primary,
                      recentsLimit: 28,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              
              // Media selection section
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _selectMedia,
                    icon: const Icon(Icons.add_photo_alternate),
                    label: const Text('Add Media'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.secondary,
                      foregroundColor: Theme.of(context).colorScheme.onSecondary,
                    ),
                  ),
                  if (_selectedMedia != null) ...[  
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: _removeMedia,
                      tooltip: 'Remove media',
                    ),
                  ],
                ],
              ),
              
              // Preview selected media
              if (_selectedMedia != null || _mediaBytes != null) ...[  
                const SizedBox(height: 16),
                Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _isVideo
                    ? Center(
                        child: Icon(
                          Icons.video_file,
                          size: 64,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      )
                    : _mediaBytes != null
                      ? Image.memory(
                          Uint8List.fromList(_mediaBytes!),
                          fit: BoxFit.cover,
                        )
                      : Image.file(
                          _selectedMedia!,
                          fit: BoxFit.cover,
                        ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Selected file: ${_mediaFileName ?? _selectedMedia?.path?.split('/')?.last ?? 'media file'}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
              
              const SizedBox(height: 16),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _createPost,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('Post'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
