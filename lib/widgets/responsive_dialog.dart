import 'package:flutter/material.dart';
import '../utils/responsive_layout.dart';

/// A responsive dialog that adapts to different screen sizes
class ResponsiveDialog extends StatelessWidget {
  final String title;
  final Widget content;
  final List<Widget>? actions;
  final double maxWidth;
  final EdgeInsets contentPadding;
  final bool scrollable;
  final Color? backgroundColor;
  final ShapeBorder? shape;

  const ResponsiveDialog({
    Key? key,
    required this.title,
    required this.content,
    this.actions,
    this.maxWidth = 500,
    this.contentPadding = const EdgeInsets.all(24.0),
    this.scrollable = true,
    this.backgroundColor,
    this.shape,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = ResponsiveLayout.isMobile(context);
    
    return Dialog(
      backgroundColor: backgroundColor ?? theme.colorScheme.surface,
      shape: shape ?? RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth,
          maxHeight: MediaQuery.of(context).size.height * (isMobile ? 0.85 : 0.75),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Dialog header
            Padding(
              padding: EdgeInsets.fromLTRB(24.0, 24.0, 16.0, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Close',
                  ),
                ],
              ),
            ),
            
            // Dialog content
            Flexible(
              child: scrollable
                  ? SingleChildScrollView(
                      padding: contentPadding,
                      child: content,
                    )
                  : Padding(
                      padding: contentPadding,
                      child: content,
                    ),
            ),
            
            // Dialog actions
            if (actions != null && actions!.isNotEmpty)
              Padding(
                padding: EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: actions!,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Show the responsive dialog
  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    required Widget content,
    List<Widget>? actions,
    double maxWidth = 500,
    EdgeInsets contentPadding = const EdgeInsets.all(24.0),
    bool scrollable = true,
    Color? backgroundColor,
    ShapeBorder? shape,
  }) {
    return showDialog<T>(
      context: context,
      builder: (context) => ResponsiveDialog(
        title: title,
        content: content,
        actions: actions,
        maxWidth: maxWidth,
        contentPadding: contentPadding,
        scrollable: scrollable,
        backgroundColor: backgroundColor,
        shape: shape,
      ),
    );
  }
}
