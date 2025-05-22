import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/supporter.dart';
import '../services/api_service.dart';
import '../screens/user_profile_screen.dart';
import '../widgets/responsive_dialog.dart';
import '../utils/responsive_layout.dart';

class SupportersDialog extends StatelessWidget {
  final SupportersInfo supportersInfo;
  final String postHash;

  const SupportersDialog({
    Key? key,
    required this.supportersInfo,
    required this.postHash,
  }) : super(key: key);
  
  // Helper method to format reputation points
  String _formatReputation(int reputation) {
    if (reputation >= 1000000) {
      final millions = (reputation / 1000000).toStringAsFixed(1);
      return '${millions}M';
    } else if (reputation >= 1000) {
      final thousands = (reputation / 1000).toStringAsFixed(1);
      return '${thousands}K';
    }
    return reputation.toString();
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveDialog(
      title: 'Post Supporters',
      content: _buildDialogContent(context),
      maxWidth: 600,
    );
  }

  Widget _buildDialogContent(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isMobile = ResponsiveLayout.isMobile(context);
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary section
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.people, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Total: ${supportersInfo.totalSupporters} supporters',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.star, color: colorScheme.secondary),
                  const SizedBox(width: 8),
                  Text(
                    'Total RPs: ${_formatReputation(supportersInfo.totalReceivedRp)}',
                    style: theme.textTheme.titleMedium,
                  ),
                ],
              ),
              if (supportersInfo.lastUpdated != null) ...[  
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.update, color: colorScheme.tertiary, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Last updated: ${supportersInfo.lastUpdated!.toLocal().toString().substring(0, 16)}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Supporters list
        supportersInfo.supporters.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      Icon(Icons.people_outline, size: 48, color: colorScheme.primary.withOpacity(0.5)),
                      const SizedBox(height: 16),
                      Text(
                        'No supporters yet',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * (isMobile ? 0.5 : 0.4),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: supportersInfo.supporters.length,
                  itemBuilder: (context, index) {
                    final supporter = supportersInfo.supporters[index];
                    final name = supporter.name ?? 'Anonymous';
                    // Format the reputation points for better readability
                    final formattedRp = _formatReputation(supporter.sentRp);
                    Widget avatar;
                    
                    if (supporter.image != null) {
                      try {
                        avatar = CircleAvatar(
                          radius: 24,
                          backgroundColor: colorScheme.primary.withOpacity(0.1),
                          backgroundImage: MemoryImage(
                            base64Decode(supporter.image!),
                          ),
                        );
                      } catch (e) {
                        // If image decoding fails, use the default avatar
                        debugPrint('Error decoding supporter image: $e');
                        avatar = CircleAvatar(
                          radius: 24,
                          backgroundColor: colorScheme.primary.withOpacity(0.1),
                          child: Icon(Icons.person, color: colorScheme.primary),
                        );
                      }
                    } else {
                      avatar = CircleAvatar(
                        radius: 24,
                        backgroundColor: colorScheme.primary.withOpacity(0.1),
                        child: Icon(Icons.person, color: colorScheme.primary),
                      );
                    }

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      elevation: 0,
                      color: theme.cardColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
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
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                    horizontal: 12.0,
                    vertical: isMobile ? 10.0 : 12.0,
                  ),
                          child: isMobile
                            // Mobile layout - stacked design for better space utilization
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      avatar,
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              name,
                                              style: theme.textTheme.titleMedium?.copyWith(
                                                fontWeight: FontWeight.w600,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 1,
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${supporter.profileId.substring(0, 6)}...${supporter.profileId.substring(supporter.profileId.length - 6)}',
                                              style: theme.textTheme.bodySmall?.copyWith(
                                                color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  // Reputation points shown below in mobile layout
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: colorScheme.secondary.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.star, size: 16, color: colorScheme.secondary),
                                          const SizedBox(width: 4),
                                          Text(
                                            formattedRp,
                                            style: theme.textTheme.bodyMedium?.copyWith(
                                              fontWeight: FontWeight.w600,
                                              color: colorScheme.secondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            // Desktop layout - horizontal layout with more space
                            : Row(
                                children: [
                                  avatar,
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          style: theme.textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Text(
                                          '${supporter.profileId.substring(0, 8)}...${supporter.profileId.substring(supporter.profileId.length - 8)}',
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: colorScheme.secondary.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.star, size: 16, color: colorScheme.secondary),
                                        const SizedBox(width: 4),
                                        Text(
                                          formattedRp,
                                          style: theme.textTheme.bodyMedium?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: colorScheme.secondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                            ],
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

/// Function to show the supporters dialog
void showSupportersDialog(BuildContext context, String postHash) async {
  final theme = Theme.of(context);
  final colorScheme = theme.colorScheme;
  
  // Show loading dialog first
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: colorScheme.primary),
              const SizedBox(width: 20),
              Text(
                "Loading supporters...",
                style: theme.textTheme.titleMedium,
              ),
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
      
      // Show error dialog using ResponsiveDialog
      ResponsiveDialog.show(
        context: context,
        title: 'Error',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colorScheme.error.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: colorScheme.error),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Failed to load supporters: $e',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      );
    }
  }
}
