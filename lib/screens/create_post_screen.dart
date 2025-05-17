import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/post_provider.dart';
import '../services/post_service.dart';
import '../providers/auth_provider.dart';
import '../models/author.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';

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

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _createPost() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await Provider.of<PostProvider>(context, listen: false)
          .createPost(_contentController.text);
      
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
            children: [
              TextFormField(
                controller: _contentController,
                maxLines: 5,
                decoration: const InputDecoration(
                  hintText: 'What\'s on your mind?',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter some text';
                  }
                  return null;
                },
              ),
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
