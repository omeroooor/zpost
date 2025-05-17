import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../models/public_key_entry.dart';
import '../services/key_storage_service.dart';
import '../widgets/custom_snackbar.dart';

class WalletScreen extends StatefulWidget {
  final bool isSelectMode;
  final Function(PublicKeyEntry)? onKeySelected;

  const WalletScreen({
    super.key, 
    this.isSelectMode = false,
    this.onKeySelected,
  });

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  late final KeyStorageService _keyStorage;
  List<PublicKeyEntry> _keys = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _keyStorage = context.read<KeyStorageService>();
    _loadKeys();
  }

  Future<void> _loadKeys() async {
    try {
      setState(() => _isLoading = true);
      final keys = await _keyStorage.getAllKeys();
      if (mounted) {
        setState(() {
          _keys = keys;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading keys: $e')),
        );
      }
    }
  }

  Future<void> _pickQRCodeImage() async {
    try {
      final pickedFile = await ImagePicker().pickImage(
        source: ImageSource.gallery,
      );
      
      if (pickedFile != null) {
        if (!mounted) return;
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Processing image...')),
        );

        final controller = MobileScannerController();
        
        try {
          bool hasProcessed = false;
          controller.barcodes.listen((capture) {
            if (!hasProcessed && capture.barcodes.isNotEmpty) {
              hasProcessed = true;
              final code = capture.barcodes.first.rawValue;
              if (code != null) {
                Navigator.pop(context);
                _showAddKeyDialog(code);
              }
            }
          });

          await controller.start();
          await controller.analyzeImage(pickedFile.path);
          
          await Future.delayed(const Duration(seconds: 1));
          
          if (!hasProcessed && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No QR code found in the image')),
            );
          }
        } finally {
          controller.dispose();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error processing image: $e')),
        );
      }
    }
  }

  void _filterKeys(String query) {
    setState(() => _searchQuery = query);
  }

  Future<void> _addKey(String publicKey) async {
    final labelController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final bool? shouldAdd = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Key'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: labelController,
            decoration: const InputDecoration(
              labelText: 'Key Label',
              hintText: 'Enter a label for this key',
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a label';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(context).pop(true);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (shouldAdd == true && mounted) {
      try {
        await _keyStorage.addKey(publicKey, labelController.text);
        await _loadKeys();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Key added successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error adding key: $e')),
          );
        }
      }
    }
  }

  Future<void> _editKeyLabel(PublicKeyEntry key) async {
    final labelController = TextEditingController(text: key.label);
    final formKey = GlobalKey<FormState>();

    final bool? shouldUpdate = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Key Label'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: labelController,
            decoration: const InputDecoration(
              labelText: 'Key Label',
              hintText: 'Enter a new label for this key',
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a label';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(context).pop(true);
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );

    if (shouldUpdate == true && mounted) {
      try {
        await _keyStorage.updateKeyLabel(key.id, labelController.text);
        await _loadKeys();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Label updated successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error updating label: $e')),
          );
        }
      }
    }
  }

  Future<void> _deleteKey(PublicKeyEntry key) async {
    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Key'),
        content: Text('Are you sure you want to delete the key "${key.label}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
        ],
      ),
    );

    if (shouldDelete == true && mounted) {
      try {
        await _keyStorage.deleteKey(key.id);
        await _loadKeys();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Key deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting key: $e')),
          );
        }
      }
    }
  }

  Future<void> _startScanning() async {
    final MobileScannerController cameraController = MobileScannerController();
    String? scannedKey;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Scan QR Code'),
        content: SizedBox(
          height: 300,
          width: 300,
          child: MobileScanner(
            controller: cameraController,
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              if (barcodes.isNotEmpty) {
                scannedKey = barcodes.first.rawValue;
                Navigator.of(context).pop();
              }
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              cameraController.stop();
              Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    await cameraController.stop();
    if (scannedKey != null && mounted) {
      await _addKey(scannedKey!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredKeys = _searchQuery.isEmpty
        ? _keys
        : _keys
            .where((key) =>
                key.label.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                key.publicKey.toLowerCase().contains(_searchQuery.toLowerCase()))
            .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallet'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'Scan QR Code',
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (context) => Container(
                  height: MediaQuery.of(context).size.height * 0.8,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      AppBar(
                        title: const Text('Scan QR Code'),
                        automaticallyImplyLeading: false,
                        actions: [
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      Expanded(
                        child: MobileScanner(
                          onDetect: (capture) {
                            final List<Barcode> barcodes = capture.barcodes;
                            if (barcodes.isNotEmpty) {
                              Navigator.pop(context);
                              final code = barcodes.first.rawValue;
                              if (code != null) _showAddKeyDialog(code);
                            }
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: ElevatedButton.icon(
                          onPressed: _pickQRCodeImage,
                          icon: const Icon(Icons.image),
                          label: const Text('Select from Gallery'),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size.fromHeight(50),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Key Manually',
            onPressed: () => _showAddKeyDialog(null),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: 'Search keys...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),
          if (_isLoading)
            const Expanded(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (filteredKeys.isEmpty)
            const Expanded(
              child: Center(
                child: Text(
                  'No keys found.\nTap + to add a new key or scan a QR code.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: filteredKeys.length,
                itemBuilder: (context, index) {
                  final key = filteredKeys[index];
                  return ListTile(
                    title: Text(key.label),
                    subtitle: Text(
                      key.publicKey,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.isSelectMode)
                          IconButton(
                            icon: const Icon(Icons.check_circle_outline),
                            onPressed: () {
                              widget.onKeySelected?.call(key);
                              Navigator.pop(context);
                            },
                          )
                        else ...[
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () => _showEditKeyDialog(key),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () => _showDeleteKeyDialog(key),
                          ),
                        ],
                      ],
                    ),
                    onTap: () {
                      if (widget.isSelectMode) {
                        widget.onKeySelected?.call(key);
                        Navigator.pop(context);
                      } else {
                        Clipboard.setData(ClipboardData(text: key.publicKey));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Public key copied to clipboard'),
                          ),
                        );
                      }
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _showAddKeyDialog(String? initialPublicKey) async {
    final publicKeyController = TextEditingController(text: initialPublicKey);
    final labelController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(initialPublicKey == null ? 'Add Key Manually' : 'Add Scanned Key'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: publicKeyController,
              decoration: const InputDecoration(
                labelText: 'Public Key',
                hintText: 'Enter public key',
              ),
              maxLines: null,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: labelController,
              decoration: const InputDecoration(
                labelText: 'Label',
                hintText: 'Enter a name for this key',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (publicKeyController.text.isEmpty || labelController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please fill in all fields')),
                );
                return;
              }
              await _keyStorage.addKey(
                publicKeyController.text,
                labelController.text,
              );
              await _loadKeys();
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditKeyDialog(PublicKeyEntry key) async {
    final labelController = TextEditingController(text: key.label);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Key'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Public Key:',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              key.publicKey,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: labelController,
              decoration: const InputDecoration(
                labelText: 'Label',
                hintText: 'Enter a new name for this key',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (labelController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Label cannot be empty')),
                );
                return;
              }
              await _keyStorage.updateKeyLabel(key.id, labelController.text);
              await _loadKeys();
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _showDeleteKeyDialog(PublicKeyEntry key) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Key'),
        content: Text('Are you sure you want to delete "${key.label}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await _keyStorage.deleteKey(key.id);
              await _loadKeys();
              if (mounted) Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
