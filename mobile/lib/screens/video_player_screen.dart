import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../utils/url_helpers.dart';
import '../widgets/gym/gym.dart';

class VideoPlayerScreen extends StatefulWidget {
  final String videoUrl;
  final String title;

  const VideoPlayerScreen({
    super.key,
    required this.videoUrl,
    required this.title,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
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

      debugPrint('Initializing video player with URL: $cleanedUrl');

      if (cleanedUrl.isEmpty) {
        throw Exception(
          'The video URL is invalid or empty. Please check the video source.',
        );
      }

      if (cleanedUrl.contains('drive.google.com')) {
        throw Exception(
          'This video cannot be played because it is a Google Drive link. Please use a direct video link.',
        );
      }

      // Initialize the video player controller with the network URL
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(cleanedUrl),
        httpHeaders: {'Accept': 'video/mp4,video/*'},
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
              _errorMessage =
                  'Video playback error: ${_controller!.value.errorDescription}';
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

      debugPrint('Video player initialized successfully');
    } catch (e) {
      debugPrint('Error initializing video player: $e');
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
    return GymScaffold(
      eyebrow: 'Video',
      title: widget.title,
      body: _errorMessage != null
          ? Center(
              child: SingleChildScrollView(
                child: GymEmptyState(
                  icon: Icons.error_outline,
                  danger: true,
                  message: '$_errorMessage\n\nURL: ${widget.videoUrl}',
                  action: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 130,
                        child: PressableButton(
                          label: 'Go Back',
                          height: 48,
                          showArrow: false,
                          variant: PressableVariant.ghost,
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 130,
                        child: PressableButton(
                          label: 'Retry',
                          height: 48,
                          showArrow: false,
                          onPressed: _initializePlayer,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : !_isInitialized
          ? const GymLoader()
          : _buildPlayer(),
    );
  }

  Widget _buildVideo() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AuthRadius.dialog),
      child: GestureDetector(
        onTap: () => setState(() => _showControls = !_showControls),
        child: Stack(
          alignment: Alignment.center,
          children: [
            AspectRatio(
              aspectRatio: _controller!.value.aspectRatio,
              child: VideoPlayer(_controller!),
            ),
            Positioned.fill(
              child: AnimatedOpacity(
                opacity: _showControls ? 1 : 0,
                duration: AuthMotion.reduced(context)
                    ? Duration.zero
                    : AuthMotion.fast,
                child: IgnorePointer(
                  ignoring: !_showControls,
                  child: ColoredBox(
                    color: AuthColors.bg.withValues(alpha: 0.45),
                    child: Center(
                      child: GymIconButton(
                        icon: _isPlaying
                            ? Icons.pause
                            : Icons.play_arrow_rounded,
                        tooltip: _isPlaying ? 'Pause' : 'Play',
                        filled: true,
                        onTap: _togglePlayPause,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayer() {
    final maxSeconds = _totalDuration.inSeconds.toDouble();
    final position = _currentPosition.inSeconds.toDouble().clamp(
      0.0,
      maxSeconds > 0 ? maxSeconds : 0.0,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        GymScaffold.side,
        AuthSpace.xs,
        GymScaffold.side,
        AuthSpace.m,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: Center(child: _buildVideo())),
          const SizedBox(height: AuthSpace.s),
          // Progress bar
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              activeTrackColor: AuthColors.accent,
              inactiveTrackColor: AuthColors.line,
              thumbColor: AuthColors.accent,
              overlayColor: AuthColors.accent.withValues(alpha: 0.12),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            ),
            child: Slider(
              value: position,
              min: 0.0,
              max: maxSeconds > 0 ? maxSeconds : 1.0,
              onChanged: maxSeconds > 0
                  ? (value) => _seekTo(Duration(seconds: value.toInt()))
                  : null,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                Text(
                  _formatDuration(_currentPosition),
                  style: AuthType.mono(color: AuthColors.textPrimary),
                ),
                const Spacer(),
                Text(_formatDuration(_totalDuration), style: AuthType.mono()),
              ],
            ),
          ),
          const SizedBox(height: AuthSpace.s),
          // Play/Pause and skip controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GymIconButton(
                icon: Icons.replay_10,
                tooltip: 'Back 10 seconds',
                onTap: _skipBackward,
              ),
              const SizedBox(width: AuthSpace.m),
              GymIconButton(
                icon: _isPlaying ? Icons.pause : Icons.play_arrow_rounded,
                tooltip: _isPlaying ? 'Pause' : 'Play',
                filled: true,
                onTap: _togglePlayPause,
              ),
              const SizedBox(width: AuthSpace.m),
              GymIconButton(
                icon: Icons.forward_10,
                tooltip: 'Forward 10 seconds',
                onTap: _skipForward,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
