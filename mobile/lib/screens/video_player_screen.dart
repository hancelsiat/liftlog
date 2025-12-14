import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../utils/url_helpers.dart';

class VideoPlayerScreen extends StatefulWidget {
  final String videoUrl;
  final String title;

  const VideoPlayerScreen({
    super.key,
    required this.videoUrl,
    required this.title,
  });

  @override
  _VideoPlayerScreenState createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isPlaying = false;
  String? _errorMessage;
  bool _showControls = true;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      setState(() {
        _errorMessage = null;
        _isInitialized = false;
      });

      // Clean the video URL to ensure it's properly formatted
      final cleanedUrl = cleanSupabaseUrl(widget.videoUrl);
      
      print('Initializing video player with URL: $cleanedUrl');

      if (cleanedUrl.isEmpty) {
        throw Exception('Invalid video URL');
      }

      // Initialize the video player controller with the network URL
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(cleanedUrl),
        httpHeaders: {
          'Accept': 'video/mp4,video/*',
        },
      );

      // Add listener for player state changes
      _controller!.addListener(() {
        if (mounted) {
          setState(() {
            _isPlaying = _controller!.value.isPlaying;
            _currentPosition = _controller!.value.position;
            _totalDuration = _controller!.value.duration;
          });

          // Check for errors
          if (_controller!.value.hasError) {
            setState(() {
              _errorMessage = 'Video playback error: ${_controller!.value.errorDescription}';
              _isInitialized = false;
            });
          }
        }
      });

      // Initialize the controller
      await _controller!.initialize();

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _totalDuration = _controller!.value.duration;
        });

        // Auto-play the video
        _controller!.play();
      }

      print('Video player initialized successfully');
    } catch (e) {
      print('Error initializing video player: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load video: ${e.toString()}';
          _isInitialized = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    if (_controller != null && _controller!.value.isInitialized) {
      setState(() {
        if (_controller!.value.isPlaying) {
          _controller!.pause();
        } else {
          _controller!.play();
        }
      });
    }
  }

  void _seekTo(Duration position) {
    if (_controller != null && _controller!.value.isInitialized) {
      _controller!.seekTo(position);
    }
  }

  void _skipForward() {
    if (_controller != null && _controller!.value.isInitialized) {
      final newPosition = _currentPosition + const Duration(seconds: 10);
      _seekTo(newPosition > _totalDuration ? _totalDuration : newPosition);
    }
  }

  void _skipBackward() {
    if (_controller != null && _controller!.value.isInitialized) {
      final newPosition = _currentPosition - const Duration(seconds: 10);
      _seekTo(newPosition < Duration.zero ? Duration.zero : newPosition);
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    
    if (hours > 0) {
      return '$hours:${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.black87,
      ),
      body: Center(
        child: _errorMessage != null
            ? Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'URL: ${widget.videoUrl}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: const Text('Go Back'),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _initializePlayer,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              )
            : !_isInitialized
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(
                        color: Colors.white,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Loading video...',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  )
                : GestureDetector(
                    onTap: () {
                      setState(() {
                        _showControls = !_showControls;
                      });
                    },
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Video player
                        Center(
                          child: AspectRatio(
                            aspectRatio: _controller!.value.aspectRatio,
                            child: VideoPlayer(_controller!),
                          ),
                        ),
                        
                        // Controls overlay
                        if (_showControls)
                          Container(
                            color: Colors.black45,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                // Play/Pause and skip controls
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.replay_10,
                                        size: 36,
                                        color: Colors.white,
                                      ),
                                      onPressed: _skipBackward,
                                    ),
                                    const SizedBox(width: 20),
                                    IconButton(
                                      icon: Icon(
                                        _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                                        size: 64,
                                        color: Colors.white,
                                      ),
                                      onPressed: _togglePlayPause,
                                    ),
                                    const SizedBox(width: 20),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.forward_10,
                                        size: 36,
                                        color: Colors.white,
                                      ),
                                      onPressed: _skipForward,
                                    ),
                                  ],
                                ),
                                
                                // Progress bar
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                  child: Row(
                                    children: [
                                      Text(
                                        _formatDuration(_currentPosition),
                                        style: const TextStyle(color: Colors.white, fontSize: 12),
                                      ),
                                      Expanded(
                                        child: Slider(
                                          value: _currentPosition.inSeconds.toDouble(),
                                          min: 0.0,
                                          max: _totalDuration.inSeconds.toDouble(),
                                          onChanged: (value) {
                                            _seekTo(Duration(seconds: value.toInt()));
                                          },
                                          activeColor: Colors.red,
                                          inactiveColor: Colors.white30,
                                        ),
                                      ),
                                      Text(
                                        _formatDuration(_totalDuration),
                                        style: const TextStyle(color: Colors.white, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
      ),
    );
  }
}
