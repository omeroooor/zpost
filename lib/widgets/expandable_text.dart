import 'package:flutter/material.dart';

class ExpandableText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final TextAlign textAlign;
  final TextDirection textDirection;
  final int maxLines;
  final String expandText;
  final String collapseText;
  final Color linkColor;

  const ExpandableText({
    Key? key,
    required this.text,
    required this.style,
    this.textAlign = TextAlign.left,
    this.textDirection = TextDirection.ltr,
    this.maxLines = 3,
    this.expandText = 'Read more',
    this.collapseText = 'Show less',
    this.linkColor = Colors.blue,
  }) : super(key: key);

  @override
  State<ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<ExpandableText> {
  bool _isExpanded = false;
  bool _needsExpand = false;

  @override
  void initState() {
    super.initState();
    // We'll determine if text needs expansion in the build method
  }

  @override
  Widget build(BuildContext context) {
    final TextSpan textSpan = TextSpan(
      text: widget.text,
      style: widget.style,
    );

    final TextPainter textPainter = TextPainter(
      text: textSpan,
      textDirection: widget.textDirection,
      maxLines: widget.maxLines,
      textAlign: widget.textAlign,
    );

    textPainter.layout(maxWidth: MediaQuery.of(context).size.width - 32); // Account for padding
    _needsExpand = textPainter.didExceedMaxLines;

    return Column(
      crossAxisAlignment: widget.textAlign == TextAlign.right
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          widget.text,
          style: widget.style,
          textAlign: widget.textAlign,
          maxLines: _isExpanded ? null : widget.maxLines,
          overflow: _isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
          textDirection: widget.textDirection,
        ),
        if (_needsExpand) ...[
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            child: Text(
              _isExpanded ? widget.collapseText : widget.expandText,
              style: TextStyle(
                color: widget.linkColor,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
