import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class VideoThumbnail extends StatefulWidget {
  final Uint8List videoData;

  const VideoThumbnail({
    Key? key,
    required this.videoData,
  }) : super(key: key);

  @override
  State<VideoThumbnail> createState() => _VideoThumbnailState();
}

class _VideoThumbnailState extends State<VideoThumbnail> {
  VideoPlayerController? _controller;
  bool _hasError = false;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeController();
  }

  Future<void> _initializeController() async {
    try {
      // Create a temporary file to store the video
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/temp_thumb_video.mp4');
      await tempFile.writeAsBytes(widget.videoData);

      _controller = VideoPlayerController.file(tempFile);
      await _controller!.initialize();
      
      // Ensure we're on the first frame
      await _controller!.seekTo(Duration.zero);
      await _controller!.setVolume(0.0);
      
      if (mounted) {
        setState(() => _isInitialized = true);
      }
    } catch (e) {
      debugPrint('Error initializing video thumbnail: $e');
      if (mounted) {
        setState(() => _hasError = true);
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Container(
        color: Colors.black12,
        child: const Center(
          child: Icon(
            Icons.error_outline,
            size: 48,
            color: Colors.red,
          ),
        ),
      );
    }

    if (!_isInitialized || _controller == null) {
      return Container(
        color: Colors.black12,
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        AspectRatio(
          aspectRatio: _controller!.value.aspectRatio,
          child: VideoPlayer(_controller!),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
          ),
        ),
        const Icon(
          Icons.play_circle_outline,
          size: 48,
          color: Colors.white,
        ),
      ],
    );
  }
}
