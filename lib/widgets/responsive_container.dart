import 'package:flutter/material.dart';

/// A responsive container that limits content width on larger screens
/// while centering the content horizontally.
class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;
  final BorderRadius? borderRadius;
  final BoxShadow? shadow;

  const ResponsiveContainer({
    Key? key,
    required this.child,
    this.maxWidth = 600, // Default max width for content
    this.padding = EdgeInsets.zero,
    this.backgroundColor,
    this.borderRadius,
    this.shadow,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: BoxConstraints(
          maxWidth: maxWidth,
        ),
        padding: padding,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: borderRadius,
          boxShadow: shadow != null ? [shadow!] : null,
        ),
        child: child,
      ),
    );
  }
}
