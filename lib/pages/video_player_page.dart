import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

class VideoPlayerPage extends StatefulWidget {
  final String url;
  const VideoPlayerPage({super.key, required this.url});

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  VideoPlayerController? _vp;
  ChewieController? _chewie;

  @override
  void initState() {
    super.initState();
    _vp = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _vp!.initialize().then((_) {
      _chewie = ChewieController(
        videoPlayerController: _vp!,
        autoPlay: true,
        looping: false,
        allowMuting: true,
        allowFullScreen: true,
      );
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _chewie?.dispose();
    _vp?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Video')),
      body: Center(
        child: _chewie == null ? const CircularProgressIndicator() : Chewie(controller: _chewie!),
      ),
    );
  }
}
