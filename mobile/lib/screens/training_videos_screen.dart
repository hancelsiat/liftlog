import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../models/user.dart';
import '../models/exercise_video.dart';
import '../utils/url_helpers.dart';
import '../widgets/gym/gym.dart';
import 'video_player_screen.dart';

class TrainingVideosScreen extends StatefulWidget {
  const TrainingVideosScreen({super.key});

  @override
  State<TrainingVideosScreen> createState() => _TrainingVideosScreenState();
}

class _TrainingVideosScreenState extends State<TrainingVideosScreen> {
  List<ExerciseVideo> _videos = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchVideos();
  }

  Future<void> _fetchVideos() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final apiService = ApiService();
      final videos = await apiService.getExerciseVideos();
      if (!mounted) return;

      setState(() {
        _videos = videos;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load videos: ${e.toString()}';
        _isLoading = false;
      });
      if (e.toString().contains('Authentication required')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Session expired. Please log in again.'),
          ),
        );
        // Navigate back to login
        Navigator.of(context).pushReplacementNamed('/login');
      }
    }
  }

  void _playVideo(String videoUrl, String title) {
    Navigator.push(
      context,
      GymPageRoute(
        builder: (context) =>
            VideoPlayerScreen(videoUrl: videoUrl, title: title),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;

    if (user?.role != UserRole.member) {
      return const GymScaffold(
        title: 'Training Videos',
        body: GymEmptyState(
          icon: Icons.lock_outline,
          message: 'This screen is only for members',
        ),
      );
    }

    return GymScaffold(
      eyebrow: 'Member / Library',
      title: 'Training Videos',
      body: GymRefresh(onRefresh: _fetchVideos, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const GymLoader();

    if (_errorMessage != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.15),
          GymEmptyState(
            icon: Icons.error_outline,
            danger: true,
            message: _errorMessage!,
            action: SizedBox(
              width: 160,
              child: PressableButton(
                label: 'Retry',
                height: 48,
                showArrow: false,
                onPressed: _fetchVideos,
              ),
            ),
          ),
        ],
      );
    }

    if (_videos.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.15),
          const GymEmptyState(
            icon: Icons.video_library_outlined,
            message: 'No videos available',
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        GymScaffold.side,
        AuthSpace.xs,
        GymScaffold.side,
        AuthSpace.l,
      ),
      itemCount: _videos.length,
      separatorBuilder: (context, index) => const SizedBox(height: 14),
      itemBuilder: (context, index) => StaggeredReveal(
        index: index,
        child: _buildVideoCard(_videos[index], index),
      ),
    );
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'beginner':
        return AuthColors.accent;
      case 'intermediate':
        return GymColors.warn;
      case 'advanced':
        return AuthColors.danger;
      default:
        return AuthColors.textMuted;
    }
  }

  Widget _buildVideoCard(ExerciseVideo video, int index) {
    return PressableSurface(
      onTap: () => _playVideo(video.videoUrl, video.title),
      semanticLabel: 'Play ${video.title} by ${video.trainerName}',
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Video Thumbnail (16:9 aspect ratio)
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (video.thumbnailUrl?.isNotEmpty ?? false)
                  Image.network(
                    cleanSupabaseUrl(video.thumbnailUrl),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const _ThumbPlaceholder(),
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const _ThumbPlaceholder(loading: true);
                    },
                  )
                else
                  const _ThumbPlaceholder(),

                // Bottom scrim so the badges stay readable on any frame.
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0.55, 1],
                      colors: [Color(0x000E0E0D), Color(0xCC0E0E0D)],
                    ),
                  ),
                ),

                // Play button
                Center(
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: const BoxDecoration(
                      color: AuthColors.accent,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: AuthColors.onAccent,
                      size: 32,
                    ),
                  ),
                ),

                // Index (top left)
                Positioned(
                  top: 10,
                  left: 12,
                  child: Text(
                    (index + 1).toString().padLeft(2, '0'),
                    style: AuthType.mono(color: AuthColors.textPrimary),
                  ),
                ),

                // Duration badge (bottom right)
                if ((video.duration ?? 0) > 0)
                  Positioned(
                    bottom: 10,
                    right: 12,
                    child: GymTag(
                      label: video.formattedDuration,
                      color: AuthColors.textPrimary,
                    ),
                  ),
              ],
            ),
          ),

          // Video Info
          Padding(
            padding: const EdgeInsets.all(AuthSpace.s),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  video.title.toUpperCase(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AuthType.display(26).copyWith(height: 1),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    GymAvatar(text: video.trainerName, size: 28),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        video.trainerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AuthType.body(size: 14),
                      ),
                    ),
                  ],
                ),

                // Description (if available)
                if (video.description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    video.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AuthType.body(size: 13, color: AuthColors.textFaint),
                  ),
                ],

                // Tags/Badges
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    GymTag(label: video.exerciseType),
                    GymTag(
                      label: video.difficulty,
                      color: _getDifficultyColor(video.difficulty),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ThumbPlaceholder extends StatelessWidget {
  const _ThumbPlaceholder({this.loading = false});

  final bool loading;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AuthColors.surfaceHi,
      child: loading
          ? const GymLoader()
          : const Icon(
              Icons.video_library_outlined,
              size: 48,
              color: AuthColors.textFaint,
            ),
    );
  }
}
