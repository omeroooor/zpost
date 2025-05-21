import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/supporter.dart';
import '../services/api_service.dart';
import '../screens/user_profile_screen.dart';

class SupportersDialog extends StatelessWidget {
  final SupportersInfo supportersInfo;
  final String postHash;

  const SupportersDialog({
    Key? key,
    required this.supportersInfo,
    required this.postHash,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: _buildDialogContent(context),
    );
  }

  Widget _buildDialogContent(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        shape: BoxShape.rectangle,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10.0,
            offset: Offset(0.0, 10.0),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Post Supporters',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Total: ${supportersInfo.totalSupporters} supporters',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          Text(
            'Total RPs: ${supportersInfo.totalReceivedRp}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (supportersInfo.lastUpdated != null)
            Text(
              'Last updated: ${supportersInfo.lastUpdated!.toLocal().toString().substring(0, 16)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          const SizedBox(height: 16),
          Flexible(
            child: supportersInfo.supporters.isEmpty
                ? const Center(
                    child: Text('No supporters yet'),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: supportersInfo.supporters.length,
                    itemBuilder: (context, index) {
                      final supporter = supportersInfo.supporters[index];
                      final name = supporter.name ?? 'Anonymous';
                      Widget avatar = const CircleAvatar(
                        child: Icon(Icons.person),
                      );
                      
                      if (supporter.image != null) {
                        try {
                          avatar = CircleAvatar(
                            backgroundImage: MemoryImage(
                              base64Decode(supporter.image!),
                            ),
                          );
                        } catch (e) {
                          // If image decoding fails, use the default avatar
                          debugPrint('Error decoding supporter image: $e');
                        }
                      }

                      return ListTile(
                        leading: avatar,
                        title: Text(name),
                        subtitle: Text('${supporter.sentRp} RPs'),
                        onTap: () {
                          Navigator.of(context).pop();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => UserProfileScreen(
                                publicKeyHash: supporter.profileId,
                                name: supporter.name,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

// Function to show the supporters dialog
void showSupportersDialog(BuildContext context, String postHash) async {
  // Show loading dialog first
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return const Dialog(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text("Loading supporters..."),
            ],
          ),
        ),
      );
    },
  );

  try {
    // Fetch supporters data
    final supportersInfo = await ApiService.getPostSupporters(postHash);
    
    // Close loading dialog
    if (context.mounted) {
      Navigator.of(context).pop();
    
      // Show supporters dialog
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return SupportersDialog(
            supportersInfo: supportersInfo,
            postHash: postHash,
          );
        },
      );
    }
  } catch (e) {
    // Close loading dialog
    if (context.mounted) {
      Navigator.of(context).pop();
      
      // Show error dialog
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Error'),
            content: Text('Failed to load supporters: $e'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    }
  }
}
