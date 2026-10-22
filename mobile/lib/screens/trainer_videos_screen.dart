import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/exercise_video.dart';
import '../utils/bulk_action.dart';
import '../widgets/gym/gym.dart';
import 'trainer_deleted_items_screen.dart';
import 'video_player_screen.dart';
import 'video_upload_screen.dart';

class TrainerVideosScreen extends StatefulWidget {
  const TrainerVideosScreen({super.key});

  @override
  State<TrainerVideosScreen> createState() => _TrainerVideosScreenState();
}

class _TrainerVideosScreenState extends State<TrainerVideosScreen> {
  final ApiService _apiService = ApiService();
  List<ExerciseVideo> _videos = [];
  bool _isLoading = true;
  String? _errorMessage;

  // Search filters what is shown. Selections hidden by a search are kept,
  // but bulk delete only touches selected videos that are currently visible.
  String _query = '';

  // Multi-select (bulk delete).
  bool _selecting = false;
  final Set<String> _selected = {};
  String? _bulkProgress;

  @override
  void initState() {
    super.initState();
    _fetchTrainerVideos();
  }

  bool _matches(ExerciseVideo v) => matchesSearch(_query, [
    v.title,
    v.description,
    v.exerciseType,
    v.difficulty,
    ...v.tags,
  ]);

  List<ExerciseVideo> get _visibleVideos => _videos.where(_matches).toList();

  List<ExerciseVideo> get _selectedVideos =>
      _visibleVideos.where((v) => _selected.contains(v.id)).toList();

  void _startSelecting([String? firstId]) {
    setState(() {
      _selecting = true;
      if (firstId != null) _selected.add(firstId);
    });
  }

  void _stopSelecting() {
    setState(() {
      _selecting = false;
      _selected.clear();
    });
  }

  void _toggle(String id) {
    setState(() {
      if (!_selected.remove(id)) _selected.add(id);
    });
  }

  Future<void> _fetchTrainerVideos() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final videos = await _apiService.getTrainerVideos();
      if (!mounted) return;

      setState(() {
        _videos = videos;
        _isLoading = false;
        // Drop selections for videos that no longer exist.
        final ids = videos.map((v) => v.id).toSet();
        _selected.retainWhere(ids.contains);
        if (videos.isEmpty) _selecting = false;
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
            backgroundColor: AuthColors.danger,
          ),
        );
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

  Future<void> _deleteVideo(String videoId) async {
    try {
      await _apiService.deleteVideo(videoId);
      await _fetchTrainerVideos();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Video deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete video: ${e.toString()}'),
            backgroundColor: AuthColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _showDeleteDialog(ExerciseVideo video) async {
    final bool? confirmed = await showAuthDialog<bool>(
      context: context,
      eyebrow: 'Trainer / Library',
      title: 'Delete Video',
      message:
          'Delete "${video.title}"? Members will no longer see it. You can '
          'restore it or delete it permanently from Recently deleted.',
      actions: (dialogContext) => [
        AuthDialogAction(
          label: 'Cancel',
          onPressed: () => Navigator.of(dialogContext).pop(false),
        ),
        AuthDialogAction(
          label: 'Delete',
          primary: true,
          onPressed: () => Navigator.of(dialogContext).pop(true),
        ),
      ],
    );
    if (confirmed == true && mounted) _deleteVideo(video.id);
  }

  /// Deletes every selected (and visible) video one by one, showing
  /// progress in the selection bar and a summary snackbar at the end.
  Future<void> _bulkDelete() async {
    final videos = _selectedVideos;
    if (videos.isEmpty) return;
    final names = videos.take(3).map((v) => '"${v.title}"').join(', ');
    final more = videos.length > 3 ? ' and ${videos.length - 3} more' : '';
    final confirmed = await showAuthDialog<bool>(
      context: context,
      eyebrow: 'Trainer / Library',
      title: videos.length == 1
          ? 'Delete Video'
          : 'Delete ${videos.length} Videos',
      message:
          'Delete $names$more? Members will no longer see them. You can '
          'restore them from Recently deleted.',
      actions: (dialogContext) => [
        AuthDialogAction(
          label: 'Cancel',
          onPressed: () => Navigator.of(dialogContext).pop(false),
        ),
        AuthDialogAction(
          label: videos.length == 1 ? 'Delete' : 'Delete all',
          primary: true,
          onPressed: () => Navigator.of(dialogContext).pop(true),
        ),
      ],
    );
    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _bulkProgress = 'Deleting 0/${videos.length}…');
    final result = await runBulk<ExerciseVideo>(
      videos,
      (v) => _apiService.deleteVideo(v.id),
      onProgress: (done, total) {
        if (mounted) setState(() => _bulkProgress = 'Deleting $done/$total…');
      },
    );
    if (!mounted) return;
    setState(() {
      _bulkProgress = null;
      _selecting = false;
      _selected.clear();
    });
    messenger.showSnackBar(
      SnackBar(
        content: Text(result.message(verb: 'Deleted', noun: 'video')),
        backgroundColor: result.failed > 0 ? AuthColors.danger : null,
      ),
    );
    await _fetchTrainerVideos();
  }

  Widget _buildSelectionBar() {
    final chosen = _selectedVideos.length;
    // Select all / clear act on the videos the search currently shows.
    final visibleIds = _visibleVideos.map((v) => v.id).toList();
    return GymSelectionBar(
      selectedCount: chosen,
      selectableCount: visibleIds.length,
      busyLabel: _bulkProgress,
      onSelectAll: () => setState(() => _selected.addAll(visibleIds)),
      onClear: () => setState(() => _selected.removeAll(visibleIds)),
      onClose: _stopSelecting,
      actions: [
        GymSmallButton(
          label: chosen > 0 ? 'Delete $chosen' : 'Delete',
          icon: Icons.delete_outline,
          primary: true,
          onTap: chosen > 0 ? _bulkDelete : null,
        ),
      ],
    );
  }

  /// Opens "Recently deleted"; restored videos show up when coming back.
  void _openDeleted() {
    Navigator.push(
      context,
      GymPageRoute(
        builder: (context) =>
            const TrainerDeletedItemsScreen(kind: DeletedKind.video),
      ),
    ).then((_) {
      if (mounted) _fetchTrainerVideos();
    });
  }

  void _openUpload() {
    Navigator.push(
      context,
      GymPageRoute(builder: (context) => const VideoUploadScreen()),
    ).then((_) {
      if (mounted) _fetchTrainerVideos();
    });
  }

  @override
  Widget build(BuildContext context) {
    final count = _videos.length;
    final busy = _bulkProgress != null;
    return GymScaffold(
      eyebrow: _isLoading
          ? 'Trainer / Library'
          : 'Trainer / $count ${count == 1 ? 'video' : 'videos'}',
      title: 'My Videos',
      actions: [
        GymIconButton(
          icon: _selecting ? Icons.close : Icons.checklist,
          tooltip: _selecting ? 'Exit selection' : 'Select multiple',
          onTap: busy || (_videos.isEmpty && !_selecting)
              ? null
              : (_selecting ? _stopSelecting : _startSelecting),
        ),
        GymIconButton(
          icon: Icons.restore_from_trash_outlined,
          tooltip: 'Recently deleted',
          onTap: busy || _selecting ? null : _openDeleted,
        ),
      ],
      bottom: Padding(
        padding: const EdgeInsets.fromLTRB(
          GymScaffold.side,
          0,
          GymScaffold.side,
          AuthSpace.xs,
        ),
        child: GymSearchField(
          hint: 'Search title, type or difficulty',
          enabled: !busy,
          onChanged: (q) => setState(() => _query = q.trim()),
        ),
      ),
      bottomBar: _selecting
          ? _buildSelectionBar()
          : GymBottomBar(
              child: PressableButton(
                label: 'Upload Video',
                onPressed: _openUpload,
              ),
            ),
      body: GymRefresh(onRefresh: _fetchTrainerVideos, child: _buildBody()),
    );
  }

  Widget _scrollableMessage(Widget child) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.sizeOf(context).height * 0.12),
        child,
      ],
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const GymLoader();

    if (_errorMessage != null) {
      return _scrollableMessage(
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
              onPressed: _fetchTrainerVideos,
            ),
          ),
        ),
      );
    }

    if (_videos.isEmpty) {
      return _scrollableMessage(
        const GymEmptyState(
          icon: Icons.video_library_outlined,
          message:
              'No Videos Yet\nStart sharing your expertise by uploading your first training video',
        ),
      );
    }

    final visible = _visibleVideos;
    if (visible.isEmpty) {
      return _scrollableMessage(
        GymEmptyState(
          icon: Icons.search_off,
          message: 'No videos match "$_query".',
        ),
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
      itemCount: visible.length,
      separatorBuilder: (context, index) => const SizedBox(height: 14),
      itemBuilder: (context, index) => StaggeredReveal(
        index: index,
        child: _buildVideoCard(visible[index], index),
      ),
    );
  }

  IconData _getExerciseIcon(String type) {
    switch (type.toLowerCase()) {
      case 'cardio':
        return Icons.directions_run;
      case 'strength':
        return Icons.fitness_center;
      case 'flexibility':
        return Icons.self_improvement;
      case 'balance':
        return Icons.accessibility_new;
      case 'sports':
        return Icons.sports_basketball;
      default:
        return Icons.fitness_center;
    }
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

  Widget _buildThumbnailPlaceholder(ExerciseVideo video) {
    return ColoredBox(
      color: AuthColors.surfaceHi,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _getExerciseIcon(video.exerciseType),
            size: 40,
            color: AuthColors.textFaint,
          ),
          const SizedBox(height: 8),
          Text(
            video.exerciseType.toUpperCase(),
            style: AuthType.mono(color: AuthColors.textFaint),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoCard(ExerciseVideo video, int index) {
    final hasThumb = video.thumbnailUrl?.isNotEmpty ?? false;
    final selected = _selected.contains(video.id);
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      // Long press enters selection mode with this card picked.
      onLongPress: _selecting || _bulkProgress != null
          ? null
          : () => _startSelecting(video.id),
      child: PressableSurface(
        highlighted: _selecting && selected,
        onTap: _selecting
            ? (_bulkProgress != null ? null : () => _toggle(video.id))
            : () => _playVideo(video.videoUrl, video.title),
        semanticLabel: _selecting
            ? '${selected ? 'Deselect' : 'Select'} ${video.title}'
            : 'Play ${video.title}',
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (hasThumb)
                    Image.network(
                      video.thumbnailUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          _buildThumbnailPlaceholder(video),
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return _buildThumbnailPlaceholder(video);
                      },
                    )
                  else
                    _buildThumbnailPlaceholder(video),
                  // Bottom scrim so the badges stay readable on any frame.
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.center,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0xB30E0E0D)],
                      ),
                    ),
                  ),
                  Center(
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AuthColors.accent,
                        borderRadius: BorderRadius.circular(AuthRadius.dialog),
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: AuthColors.onAccent,
                        size: 32,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    left: 12,
                    child: Text(
                      (index + 1).toString().padLeft(2, '0'),
                      style: AuthType.mono(color: AuthColors.textPrimary),
                    ),
                  ),
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
            Padding(
              padding: const EdgeInsets.all(AuthSpace.s),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          video.title.toUpperCase(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AuthType.display(26).copyWith(height: 1),
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (_selecting)
                        GymCheckbox(
                          value: selected,
                          semanticLabel: 'Select ${video.title}',
                          onChanged: _bulkProgress != null
                              ? null
                              : (_) => _toggle(video.id),
                        )
                      else
                        GymIconButton(
                          icon: Icons.delete_outline,
                          tooltip: 'Delete ${video.title}',
                          danger: true,
                          onTap: () => _showDeleteDialog(video),
                        ),
                    ],
                  ),
                  if (video.description.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      video.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AuthType.body(
                        size: 13,
                        color: AuthColors.textFaint,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      GymTag(
                        label: video.exerciseType,
                        icon: _getExerciseIcon(video.exerciseType),
                      ),
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
      ),
    );
  }
}
