import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../utils/responsive_layout.dart';
import '../widgets/responsive_dialog.dart';

class QRDialog extends StatelessWidget {
  final String title;
  final String data;
  final VoidCallback? onVerify;
  final VoidCallback? onSupport;

  const QRDialog({
    super.key,
    required this.title,
    required this.data,
    this.onVerify,
    this.onSupport,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isMobile = ResponsiveLayout.isMobile(context);
    
    return ResponsiveDialog(
      title: title,
      maxWidth: 400,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // QR Code
          Container(
            width: isMobile ? 180 : 220,
            height: isMobile ? 180 : 220,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: QrImageView(
              data: data,
              version: QrVersions.auto,
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              size: isMobile ? 160 : 200,
              padding: const EdgeInsets.all(8),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Data text (shortened with copy option)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  data.length > 20 ? '${data.substring(0, 20)}...' : data,
                  style: theme.textTheme.bodyMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: Icon(Icons.copy, size: 16, color: colorScheme.primary),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: data));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Copied to clipboard')),
                  );
                },
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(8),
                tooltip: 'Copy to clipboard',
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Action buttons
          if (onVerify != null || onSupport != null)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                if (onVerify != null)
                  FilledButton.icon(
                    onPressed: onVerify,
                    icon: const Icon(Icons.verified_user, size: 18),
                    label: const Text('Verify'),
                    style: FilledButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                    ),
                  ),
                if (onSupport != null)
                  OutlinedButton.icon(
                    onPressed: onSupport,
                    icon: const Icon(Icons.favorite, size: 18),
                    label: const Text('Support'),
                  ),
              ],
            ),
        ],
      ),
    );
  }
  
  // Static method to show the dialog
  static Future<void> show({
    required BuildContext context,
    required String title,
    required String data,
    VoidCallback? onVerify,
    VoidCallback? onSupport,
  }) {
    return showDialog(
      context: context,
      builder: (context) => QRDialog(
        title: title,
        data: data,
        onVerify: onVerify,
        onSupport: onSupport,
      ),
    );
  }
}
