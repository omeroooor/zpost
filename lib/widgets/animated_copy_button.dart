import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AnimatedCopyButton extends StatefulWidget {
  final String textToCopy;
  final VoidCallback? onCopied;

  const AnimatedCopyButton({
    Key? key,
    required this.textToCopy,
    this.onCopied,
  }) : super(key: key);

  @override
  State<AnimatedCopyButton> createState() => _AnimatedCopyButtonState();
}

class _AnimatedCopyButtonState extends State<AnimatedCopyButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _hasCopied = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _copyToClipboard() async {
    await Clipboard.setData(ClipboardData(text: widget.textToCopy));
    if (!mounted) return;

    setState(() {
      _hasCopied = true;
    });
    _controller.forward().then((_) {
      Future.delayed(const Duration(seconds: 2), () {
        if (!mounted) return;
        setState(() {
          _hasCopied = false;
        });
        _controller.reverse();
      });
    });

    widget.onCopied?.call();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: _copyToClipboard,
      icon: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              Opacity(
                opacity: 1 - _animation.value,
                child: const Icon(Icons.copy_outlined),
              ),
              Opacity(
                opacity: _animation.value,
                child: const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
