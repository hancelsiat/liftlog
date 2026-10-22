import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/exercise_video.dart';
import '../models/workout.dart';
import '../services/api_service.dart';
import '../utils/bulk_action.dart';
import '../widgets/gym/gym.dart';
import 'video_player_screen.dart';

enum DeletedKind { video, workout }

/// One row in "Recently deleted" (a video or a workout template).
class DeletedItem {
  const DeletedItem({
    required this.id,
    required this.title,
    required this.details,
    required this.searchFields,
    required this.byTrainer,
    this.deletedAt,
    this.reason,
    this.videoUrl,
    this.thumbnailUrl,
  });

  factory DeletedItem.fromVideo(ExerciseVideo v) => DeletedItem(
    id: v.id,
    title: v.title,
    details: '${v.exerciseType} · ${v.difficulty}',
    searchFields: [v.title, v.description, v.exerciseType, ...v.tags],
    byTrainer: v.deletedByTrainer,
    deletedAt: v.deletedAt,
    reason: v.deletionReason,
    videoUrl: v.videoUrl,
    thumbnailUrl: v.thumbnailUrl,
  );

  factory DeletedItem.fromWorkout(Workout w) => DeletedItem(
    id: w.id,
    title: w.name,
    details: '${w.exercises.length} exercise(s)',
    searchFields: [w.name, w.description, ...w.exercises.map((e) => e.name)],
    byTrainer: w.deletedByTrainer,
    deletedAt: w.deletedAt,
    reason: w.deletionReason,
  );

  final String id;
  final String title;
  final String details;
  final List<String> searchFields;

  /// True when the trainer deleted it (they can restore it). False when an
  /// admin removed it (only an admin can restore it).
  final bool byTrainer;
  final DateTime? deletedAt;
  final String? reason;
  final String? videoUrl;
  final String? thumbnailUrl;
}

/// Trainer "Recently deleted": restore what they deleted (members see it
/// again) or delete it permanently. Items removed by an admin are listed
/// with the reason; only an admin can restore those.
class TrainerDeletedItemsScreen extends StatefulWidget {
  const TrainerDeletedItemsScreen({super.key, required this.kind});

  final DeletedKind kind;

  @override
  State<TrainerDeletedItemsScreen> createState() =>
      _TrainerDeletedItemsScreenState();
}

class _TrainerDeletedItemsScreenState extends State<TrainerDeletedItemsScreen> {
  final ApiService _api = ApiService();
  List<DeletedItem> _items = [];
  bool _loading = true;
  String? _error;
  String _query = '';

  bool _selecting = false;
  final Set<String> _selected = {};
  String? _bulkProgress;
  final Set<String> _busyIds = {};

  bool get _isVideo => widget.kind == DeletedKind.video;
  String get _noun => _isVideo ? 'video' : 'workout';
  String _plural(int n) => n == 1 ? _noun : '${_noun}s';

  List<DeletedItem> get _visible =>
      _items.where((i) => matchesSearch(_query, i.searchFields)).toList();

  List<DeletedItem> get _selectedItems =>
      _visible.where((i) => _selected.contains(i.id)).toList();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = _isVideo
          ? (await _api.getDeletedTrainerVideos()).map(DeletedItem.fromVideo)
          : (await _api.getDeletedTrainerWorkouts()).map(
              DeletedItem.fromWorkout,
            );
      if (!mounted) return;
      setState(() {
        _items = items.toList();
        _loading = false;
        final ids = _items.map((i) => i.id).toSet();
        _selected.retainWhere(ids.contains);
        if (_items.isEmpty) _selecting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _restoreOne(DeletedItem item) =>
      _isVideo ? _api.restoreVideo(item.id) : _api.restoreWorkout(item.id);

  Future<void> _purgeOne(DeletedItem item) => _isVideo
      ? _api.permanentlyDeleteVideo(item.id)
      : _api.permanentlyDeleteWorkout(item.id);

  void _snack(String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? AuthColors.danger : null,
      ),
    );
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final ok = await showAuthDialog<bool>(
      context: context,
      eyebrow: 'Trainer / Recently deleted',
      title: title,
      message: message,
      actions: (dialogContext) => [
        AuthDialogAction(
          label: 'Cancel',
          onPressed: () => Navigator.of(dialogContext).pop(false),
        ),
        AuthDialogAction(
          label: confirmLabel,
          primary: true,
          onPressed: () => Navigator.of(dialogContext).pop(true),
        ),
      ],
    );
    return ok == true && mounted;
  }

  Future<void> _runSingle(
    DeletedItem item,
    Future<void> Function(DeletedItem) action,
    String done,
  ) async {
    if (_busyIds.contains(item.id)) return;
    setState(() => _busyIds.add(item.id));
    try {
      await action(item);
      if (!mounted) return;
      _snack(done);
      await _load();
    } catch (e) {
      if (mounted) {
        _snack(e.toString().replaceFirst('Exception: ', ''), error: true);
      }
    } finally {
      if (mounted) setState(() => _busyIds.remove(item.id));
    }
  }

  Future<void> _restore(DeletedItem item) async {
    final ok = await _confirm(
      title: 'Restore ${_isVideo ? 'Video' : 'Workout'}',
      message:
          'Restore "${item.title}"? It goes back to your list and members '
          'can see it again.',
      confirmLabel: 'Restore',
    );
    if (!ok) return;
    await _runSingle(item, _restoreOne, 'Restored "${item.title}".');
  }

  Future<void> _purge(DeletedItem item) async {
    final ok = await _confirm(
      title: 'Delete Forever',
      message:
          'Permanently delete "${item.title}"? '
          '${_isVideo ? 'The video file is erased. ' : ''}'
          'This cannot be undone.',
      confirmLabel: 'Delete forever',
    );
    if (!ok) return;
    await _runSingle(item, _purgeOne, 'Deleted "${item.title}" permanently.');
  }

  Future<void> _bulk({required bool restore}) async {
    final targets = _selectedItems;
    if (targets.isEmpty) return;
    final n = targets.length;
    final messenger = ScaffoldMessenger.of(context);
    final ok = await _confirm(
      title: restore
          ? 'Restore $n ${_plural(n)}'
          : 'Delete $n ${_plural(n)} forever',
      message: restore
          ? 'Restore $n ${_plural(n)}? Members can see them again.'
          : 'Permanently delete $n ${_plural(n)}? This cannot be undone.',
      confirmLabel: restore ? 'Restore' : 'Delete forever',
    );
    if (!ok) return;

    final verb = restore ? 'Restoring' : 'Deleting';
    setState(() => _bulkProgress = '$verb 0/$n…');
    final result = await runBulk<DeletedItem>(
      targets,
      restore ? _restoreOne : _purgeOne,
      onProgress: (done, total) {
        if (mounted) setState(() => _bulkProgress = '$verb $done/$total…');
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
        content: Text(
          result.message(
            verb: restore ? 'Restored' : 'Permanently deleted',
            noun: _noun,
          ),
        ),
        backgroundColor: result.failed > 0 ? AuthColors.danger : null,
      ),
    );
    await _load();
  }

  void _toggle(String id) {
    setState(() {
      if (!_selected.remove(id)) _selected.add(id);
    });
  }

  void _stopSelecting() {
    setState(() {
      _selecting = false;
      _selected.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final busy = _bulkProgress != null;
    final visible = _visible;
    return GymScaffold(
      eyebrow: _selecting
          ? '${_selectedItems.length} selected'
          : 'Trainer / ${_isVideo ? 'Videos' : 'Templates'}',
      title: 'Recently Deleted',
      actions: [
        GymIconButton(
          icon: _selecting ? Icons.close : Icons.checklist,
          tooltip: _selecting ? 'Exit selection' : 'Select multiple',
          onTap: busy || (_items.isEmpty && !_selecting)
              ? null
              : (_selecting
                    ? _stopSelecting
                    : () => setState(() => _selecting = true)),
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
          hint: 'Search deleted ${_noun}s',
          enabled: !busy,
          onChanged: (q) => setState(() => _query = q.trim()),
        ),
      ),
      bottomBar: _selecting ? _buildSelectionBar(visible) : null,
      body: GymRefresh(onRefresh: _load, child: _buildBody(visible)),
    );
  }

  Widget _buildSelectionBar(List<DeletedItem> visible) {
    final visibleIds = visible.map((i) => i.id).toList();
    final chosen = _selectedItems;
    // Restore only works for the trainer's own deletions.
    final canRestore = chosen.isNotEmpty && chosen.every((i) => i.byTrainer);
    return GymSelectionBar(
      selectedCount: chosen.length,
      selectableCount: visibleIds.length,
      busyLabel: _bulkProgress,
      onSelectAll: () => setState(() => _selected.addAll(visibleIds)),
      onClear: () => setState(() => _selected.removeAll(visibleIds)),
      onClose: _stopSelecting,
      actions: [
        GymSmallButton(
          label: 'Restore',
          icon: Icons.restore,
          onTap: canRestore ? () => _bulk(restore: true) : null,
        ),
        GymSmallButton(
          label: 'Delete forever',
          icon: Icons.delete_forever_outlined,
          primary: true,
          onTap: chosen.isEmpty ? null : () => _bulk(restore: false),
        ),
      ],
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

  Widget _buildBody(List<DeletedItem> visible) {
    if (_loading) return const GymLoader();
    if (_error != null) {
      return _scrollableMessage(
        GymEmptyState(
          icon: Icons.error_outline,
          danger: true,
          message: _error!,
          action: SizedBox(
            width: 160,
            child: PressableButton(
              label: 'Retry',
              height: 48,
              showArrow: false,
              onPressed: _load,
            ),
          ),
        ),
      );
    }
    if (_items.isEmpty) {
      return _scrollableMessage(
        GymEmptyState(
          icon: Icons.delete_outline,
          message:
              'Nothing here.\nDeleted ${_noun}s show up here so you can '
              'restore them or delete them permanently.',
        ),
      );
    }
    if (visible.isEmpty) {
      return _scrollableMessage(
        GymEmptyState(
          icon: Icons.search_off,
          message: 'No deleted ${_noun}s match "$_query".',
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
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, i) =>
          StaggeredReveal(index: i, child: _buildCard(visible[i])),
    );
  }

  Widget _thumbnail(DeletedItem item) {
    final hasThumb = item.thumbnailUrl?.isNotEmpty ?? false;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AuthRadius.thumb),
      child: SizedBox(
        width: 96,
        height: 54,
        child: hasThumb
            ? Image.network(
                item.thumbnailUrl!,
                fit: BoxFit.cover,
                color: AuthColors.bg,
                colorBlendMode: BlendMode.saturation,
                errorBuilder: (_, _, _) =>
                    const ColoredBox(color: AuthColors.surfaceHi),
              )
            : const ColoredBox(
                color: AuthColors.surfaceHi,
                child: Icon(
                  Icons.videocam_off_outlined,
                  color: AuthColors.textFaint,
                ),
              ),
      ),
    );
  }

  void _play(DeletedItem item) {
    Navigator.push(
      context,
      GymPageRoute(
        builder: (_) =>
            VideoPlayerScreen(videoUrl: item.videoUrl!, title: item.title),
      ),
    );
  }

  Widget _buildCard(DeletedItem item) {
    final selected = _selected.contains(item.id);
    final busy = _busyIds.contains(item.id) || _bulkProgress != null;
    final when = item.deletedAt == null
        ? ''
        : ' · ${DateFormat.yMMMd().add_jm().format(item.deletedAt!.toLocal())}';
    final canPlay = _isVideo && (item.videoUrl?.isNotEmpty ?? false);

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onLongPress: _selecting || busy
          ? null
          : () => setState(() {
              _selecting = true;
              _selected.add(item.id);
            }),
      child: PressableSurface(
        highlighted: _selecting && selected,
        semanticLabel: _selecting
            ? '${selected ? 'Deselect' : 'Select'} ${item.title}'
            : item.title,
        onTap: _selecting
            ? (busy ? null : () => _toggle(item.id))
            : (canPlay ? () => _play(item) : null),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_isVideo) ...[_thumbnail(item), const SizedBox(width: 12)],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title.toUpperCase(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AuthType.display(
                          20,
                        ).copyWith(height: 1, color: AuthColors.textMuted),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.details.toUpperCase(),
                        style: AuthType.mono(color: AuthColors.textFaint),
                      ),
                    ],
                  ),
                ),
                if (_selecting)
                  GymCheckbox(
                    value: selected,
                    semanticLabel: 'Select ${item.title}',
                    onChanged: busy ? null : (_) => _toggle(item.id),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (item.byTrainer)
              GymStatusStrip(
                color: AuthColors.textMuted,
                icon: Icons.delete_outline,
                title: 'Deleted by you$when',
                lines: const ['Hidden from members until you restore it.'],
              )
            else
              GymStatusStrip(
                color: AuthColors.danger,
                icon: Icons.block,
                title: 'Removed by an admin$when',
                lines: [
                  'Reason: ${item.reason ?? '-'}',
                  'Only an admin can restore it.',
                ],
              ),
            if (!_selecting) ...[
              const SizedBox(height: 12),
              if (_busyIds.contains(item.id))
                const SizedBox(height: 40, child: GymLoader())
              else
                Row(
                  children: [
                    if (item.byTrainer) ...[
                      Expanded(
                        child: GymSmallButton(
                          label: 'Restore',
                          icon: Icons.restore,
                          onTap: busy ? null : () => _restore(item),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: GymSmallButton(
                        label: 'Delete forever',
                        icon: Icons.delete_forever_outlined,
                        primary: true,
                        onTap: busy ? null : () => _purge(item),
                      ),
                    ),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }
}
