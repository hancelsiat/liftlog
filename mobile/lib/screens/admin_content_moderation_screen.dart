import 'dart:async';

import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/bulk_action.dart';
import '../widgets/gym/gym.dart';
import 'video_player_screen.dart';

/// Admin: review every video and workout uploaded by trainers and remove
/// inappropriate content with a reason (the trainer is emailed the reason).
class AdminContentModerationScreen extends StatefulWidget {
  /// 0 = Videos tab, 1 = Workouts tab.
  final int initialTab;

  const AdminContentModerationScreen({super.key, this.initialTab = 0});

  @override
  State<AdminContentModerationScreen> createState() =>
      _AdminContentModerationScreenState();
}

class _AdminContentModerationScreenState
    extends State<AdminContentModerationScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 1),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GymScaffold(
      eyebrow: 'Admin / Moderation',
      title: 'Content',
      bottom: GymTabBar(
        controller: _tabController,
        tabs: const ['Videos', 'Workouts'],
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _ModerationList(kind: _ContentKind.video),
          _ModerationList(kind: _ContentKind.workout),
        ],
      ),
    );
  }
}

enum _ContentKind { video, workout }

String _formatDate(dynamic value) {
  final d = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
  if (d == null) return '';
  final mm = d.minute.toString().padLeft(2, '0');
  return '${d.day}/${d.month}/${d.year} ${d.hour}:$mm';
}

/// True when the trainer deleted the item themselves (not an admin removal).
/// Older removals have no `deletedByRole` and were made by an admin.
bool _deletedByTrainer(Map<String, dynamic> item) =>
    item['isDeleted'] == true && item['deletedByRole'] == 'trainer';

/// True for a workout a trainer assigned to a member (a copy of a template),
/// as opposed to the trainer's own template.
bool _isAssignedCopy(Map<String, dynamic> item) =>
    item['isTemplate'] != true && item['assignedTo'] != null;

/// True when the trainer deleted it permanently (only the record is left).
bool _purged(Map<String, dynamic> item) => item['purgedAt'] != null;

String _nameOf(dynamic userField, {String fallback = 'Unknown trainer'}) {
  if (userField is Map) {
    final name = userField['username']?.toString();
    if (name != null && name.isNotEmpty) return name;
  }
  return fallback;
}

const List<String> _presetReasons = [
  'Inappropriate or offensive content.',
  'Nudity or sexually explicit content.',
  'Unsafe exercise technique that could cause injury.',
  'Spam, advertising or unrelated content.',
  'Copyrighted content uploaded without permission.',
  'Misleading or false health information.',
  'Other',
];

/// Shows the deletion dialog. Returns the reason, or null if cancelled.
/// [message] replaces the default '"title" by owner will be removed' text
/// (used for bulk removal).
Future<String?> _askDeletionReason(
  BuildContext context, {
  required String itemLabel,
  String title = '',
  String ownerName = '',
  String? message,
  String? extraWarning,
}) {
  final customController = TextEditingController();
  String selected = _presetReasons.first;

  return showGymDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) {
        final isOther = selected == 'Other';
        final reason = isOther ? customController.text.trim() : selected;
        final valid = reason.length >= 10;

        return GymFormDialog(
          eyebrow: 'Admin / Report',
          title: 'Remove $itemLabel',
          confirmLabel: 'Remove',
          onConfirm: valid ? () => Navigator.pop(ctx, reason) : null,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                message ??
                    '"$title" by $ownerName will be removed. '
                        '$ownerName will get an email with the reason.',
                style: AuthType.body(),
              ),
              if (extraWarning != null) ...[
                const SizedBox(height: 12),
                GymStatusStrip(
                  color: GymColors.warn,
                  icon: Icons.warning_amber_rounded,
                  title: 'Heads up',
                  lines: [extraWarning],
                ),
              ],
              const SizedBox(height: AuthSpace.m),
              const GymSectionLabel(label: 'Reason for removal'),
              const SizedBox(height: 12),
              GymRadioList<String>(
                options: _presetReasons,
                selected: selected,
                onChanged: (v) => setDialogState(() => selected = v),
              ),
              if (isOther) ...[
                const SizedBox(height: 4),
                TextField(
                  controller: customController,
                  maxLength: 500,
                  maxLines: 3,
                  autofocus: true,
                  style: AuthType.input(),
                  onChanged: (_) => setDialogState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Describe why this is inappropriate',
                    errorText: customController.text.isNotEmpty && !valid
                        ? 'Minimum 10 characters'
                        : null,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    ),
  );
  // The controller is not disposed here on purpose: the dialog's TextField
  // can still be in its closing animation when the future completes.
}

class _ModerationList extends StatefulWidget {
  final _ContentKind kind;

  const _ModerationList({required this.kind});

  @override
  State<_ModerationList> createState() => _ModerationListState();
}

class _ModerationListState extends State<_ModerationList>
    with AutomaticKeepAliveClientMixin {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();

  /// 'trainer' = removed by the trainer themselves (for monitoring).
  static const List<String> _filters = ['active', 'deleted', 'trainer', 'all'];

  Timer? _debounce;
  String _status = 'active';
  List<Map<String, dynamic>> _items = [];
  int _activeCount = 0;
  int _deletedCount = 0;
  int _trainerDeletedCount = 0;
  bool _loading = true;
  String? _error;
  final Set<String> _busyIds = {};

  // Multi-select (bulk remove). Only content that is not removed yet can be
  // picked.
  bool _selecting = false;
  final Set<String> _selected = {};
  String? _bulkProgress;

  bool get _isVideo => widget.kind == _ContentKind.video;

  String _idOf(Map<String, dynamic> item) => item['_id']?.toString() ?? '';

  List<Map<String, dynamic>> get _selectableItems => _items
      .where((i) => i['isDeleted'] != true && _idOf(i).isNotEmpty)
      .toList();

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

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final search = _searchController.text;
      final data = _isVideo
          ? await _apiService.getAdminVideos(status: _status, search: search)
          : await _apiService.getAdminWorkouts(status: _status, search: search);
      if (!mounted) return;
      final key = _isVideo ? 'videos' : 'workouts';
      setState(() {
        _items = (data[key] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _activeCount = (data['activeCount'] as num?)?.toInt() ?? 0;
        _deletedCount = (data['deletedCount'] as num?)?.toInt() ?? 0;
        _trainerDeletedCount =
            (data['trainerDeletedCount'] as num?)?.toInt() ?? 0;
        _loading = false;
        // Drop selections that are gone or already removed.
        final ids = _selectableItems.map(_idOf).toSet();
        _selected.retainWhere(ids.contains);
        if (ids.isEmpty) _selecting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), _load);
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final id = item['_id']?.toString() ?? '';
    if (id.isEmpty || _busyIds.contains(id)) return;

    final title = item['title']?.toString() ?? 'Untitled';
    final owner = _nameOf(item['trainer']);
    final assigned = (item['assignedCount'] as num?)?.toInt() ?? 0;

    final reason = await _askDeletionReason(
      context,
      itemLabel: _isVideo ? 'Video' : 'Workout',
      title: title,
      ownerName: owner,
      extraWarning: !_isVideo && assigned > 0
          ? 'This workout is assigned to $assigned member(s). '
                'It will also be removed from their plans.'
          : null,
    );
    if (reason == null || !mounted) return;

    setState(() => _busyIds.add(id));
    try {
      final res = _isVideo
          ? await _apiService.adminDeleteVideo(id, reason: reason)
          : await _apiService.adminDeleteWorkout(id, reason: reason);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message']?.toString() ?? 'Content removed.'),
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AuthColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _busyIds.remove(id));
    }
  }

  /// Admin restore: only for moderation removals (trainer deletions can only
  /// be restored by the trainer).
  Future<void> _restore(Map<String, dynamic> item) async {
    final id = _idOf(item);
    if (id.isEmpty || _busyIds.contains(id)) return;
    final title = item['title']?.toString() ?? 'Untitled';

    final ok = await showAuthDialog<bool>(
      context: context,
      eyebrow: 'Admin / Moderation',
      title: 'Restore ${_isVideo ? 'Video' : 'Workout'}',
      message:
          'Restore "$title" by ${_nameOf(item['trainer'])}? It becomes '
          'visible again${_isVideo ? '' : ', including member plans it was removed from'}. '
          'The trainer gets an email.',
      actions: (dialogContext) => [
        AuthDialogAction(
          label: 'Cancel',
          onPressed: () => Navigator.of(dialogContext).pop(false),
        ),
        AuthDialogAction(
          label: 'Restore',
          primary: true,
          onPressed: () => Navigator.of(dialogContext).pop(true),
        ),
      ],
    );
    if (ok != true || !mounted) return;

    setState(() => _busyIds.add(id));
    try {
      final res = _isVideo
          ? await _apiService.adminRestoreVideo(id)
          : await _apiService.adminRestoreWorkout(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message']?.toString() ?? 'Restored.')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AuthColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _busyIds.remove(id));
    }
  }

  /// Remove every selected item with one shared reason.
  Future<void> _deleteSelected() async {
    final targets = _selectableItems
        .where((i) => _selected.contains(_idOf(i)))
        .toList();
    if (targets.isEmpty) return;
    final count = targets.length;
    final noun = _isVideo ? 'video' : 'workout';
    final owners = targets.map((i) => _nameOf(i['trainer'])).toSet();
    final assigned = targets.fold<int>(
      0,
      (sum, i) => sum + ((i['assignedCount'] as num?)?.toInt() ?? 0),
    );

    final reason = await _askDeletionReason(
      context,
      itemLabel: '$count ${count == 1 ? noun : '${noun}s'}',
      message:
          '$count $noun(s) from ${owners.length} trainer(s) will be removed. '
          'Each trainer gets an email with the reason.',
      extraWarning: !_isVideo && assigned > 0
          ? 'These workouts are assigned to $assigned member plan(s). '
                'They will also be removed from those plans.'
          : null,
    );
    if (reason == null || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _bulkProgress = 'Removing 0/$count…');
    final result = await runBulk<Map<String, dynamic>>(
      targets,
      (i) async {
        final id = _idOf(i);
        if (_isVideo) {
          await _apiService.adminDeleteVideo(id, reason: reason);
        } else {
          await _apiService.adminDeleteWorkout(id, reason: reason);
        }
      },
      onProgress: (done, total) {
        if (mounted) setState(() => _bulkProgress = 'Removing $done/$total…');
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
        content: Text(result.message(verb: 'Removed', noun: noun)),
        backgroundColor: result.failed > 0 ? AuthColors.danger : null,
      ),
    );
    await _load();
  }

  /// Check box shown in the top-left of a card while selecting.
  Widget _selectionCheckbox(Map<String, dynamic> item) {
    final id = _idOf(item);
    return GymCheckbox(
      value: _selected.contains(id),
      semanticLabel: 'Select ${item['title'] ?? 'item'}',
      onChanged: (_) => _toggle(id),
    );
  }

  /// Makes a card tappable / long-pressable for selection.
  Widget _selectable(Map<String, dynamic> item, Widget card) {
    final id = _idOf(item);
    final canPick = item['isDeleted'] != true && id.isNotEmpty;
    if (!canPick) {
      // Removed items stay visible in selection mode, just dimmed.
      return _selecting ? Opacity(opacity: 0.45, child: card) : card;
    }
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: _selecting ? () => _toggle(id) : null,
      onLongPress: !_selecting && _bulkProgress == null
          ? () => _startSelecting(id)
          : null,
      child: _selecting
          // Block the card's own taps (play video, expand workout).
          ? AbsorbPointer(child: card)
          : card,
    );
  }

  void _openVideo(Map<String, dynamic> item) {
    final url = item['videoUrl']?.toString() ?? '';
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Video file is not available.')),
      );
      return;
    }
    Navigator.push(
      context,
      GymPageRoute(
        builder: (_) => VideoPlayerScreen(
          videoUrl: url,
          title: item['title']?.toString() ?? 'Video',
        ),
      ),
    );
  }

  Widget _buildDeletedBanner(Map<String, dynamic> item) {
    if (_deletedByTrainer(item)) {
      // Remark for monitoring: the trainer removed it, not moderation.
      final trainer = _nameOf(
        item['deletedBy'],
        fallback: _nameOf(item['trainer'], fallback: 'the trainer'),
      );
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: GymStatusStrip(
          color: AuthColors.textMuted,
          icon: Icons.person_remove_outlined,
          title:
              'Deleted by trainer $trainer · ${_formatDate(item['deletedAt'])}',
          lines: [
            if (_isAssignedCopy(item))
              'Remark: the trainer removed this from '
                  '${_nameOf(item['assignedTo'], fallback: 'the member')}\'s plan. '
                  'It is hidden from the member and kept here for monitoring.'
            else
              'Remark: the trainer deleted this from their own library. '
                  'It is hidden from members and kept here for monitoring.',
            if (_isAssignedCopy(item))
              'The trainer can assign the workout again if needed.'
            else if (_purged(item))
              'The trainer deleted it permanently '
                  '(${_formatDate(item['purgedAt'])}). It cannot be restored.'
            else
              'The trainer can still restore it. Admins cannot restore '
                  'trainer deletions.',
          ],
        ),
      );
    }
    final by = _nameOf(item['deletedBy'], fallback: 'admin');
    final id = _idOf(item);
    final busy = _busyIds.contains(id);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GymStatusStrip(
            color: AuthColors.danger,
            icon: Icons.block,
            title: 'Removed by $by · ${_formatDate(item['deletedAt'])}',
            lines: [
              'Reason: ${item['deletionReason'] ?? '-'}',
              if (_purged(item))
                'The trainer deleted it permanently. It cannot be restored.',
            ],
          ),
          if (!_selecting && !_purged(item)) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: busy
                  ? const SizedBox(width: 44, height: 44, child: GymLoader())
                  : GymSmallButton(
                      label: 'Restore',
                      icon: Icons.restore,
                      onTap: () => _restore(item),
                    ),
            ),
          ],
        ],
      ),
    );
  }

  /// "Restored by admin / trainer" note on active items that came back.
  Widget? _restoredTag(Map<String, dynamic> item) {
    if (item['isDeleted'] == true || item['restoredAt'] == null) return null;
    final role = item['restoredByRole'] == 'admin' ? 'admin' : 'trainer';
    return GymTag(
      label: 'Restored by $role',
      icon: Icons.restore,
      color: AuthColors.accent,
    );
  }

  Widget _buildRemoveButton(Map<String, dynamic> item) {
    // In selection mode the bulk bar replaces the per-card button.
    if (_selecting) return const SizedBox.shrink();
    final id = item['_id']?.toString() ?? '';
    final busy = _busyIds.contains(id);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (busy)
            const SizedBox(width: 44, height: 44, child: GymLoader())
          else
            GymIconButton(
              icon: Icons.delete_outline,
              tooltip: 'Remove',
              danger: true,
              onTap: () => _delete(item),
            ),
        ],
      ),
    );
  }

  Widget _buildVideoCard(Map<String, dynamic> v) {
    final deleted = v['isDeleted'] == true;
    final thumb = v['thumbnailUrl']?.toString() ?? '';
    final isPublic = v['isPublic'] == true;
    final title = v['title']?.toString() ?? 'Untitled';
    final showBox = _selecting && !deleted;
    final canPlay = (v['videoUrl']?.toString() ?? '').isNotEmpty;
    return PressableSurface(
      padding: EdgeInsets.zero,
      highlighted: showBox && _selected.contains(_idOf(v)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Removed videos keep their files (unless deleted permanently),
          // so admins can still play them for review.
          Semantics(
            button: canPlay,
            label: canPlay ? 'Play $title' : null,
            child: GestureDetector(
              onTap: canPlay ? () => _openVideo(v) : null,
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (thumb.isNotEmpty)
                      Image.network(
                        thumb,
                        fit: BoxFit.cover,
                        color: deleted ? AuthColors.bg : null,
                        colorBlendMode: deleted ? BlendMode.saturation : null,
                        errorBuilder: (_, _, _) =>
                            const ColoredBox(color: AuthColors.surfaceHi),
                      )
                    else
                      const ColoredBox(color: AuthColors.surfaceHi),
                    Center(
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: deleted
                              ? AuthColors.danger.withValues(alpha: 0.9)
                              : AuthColors.accent,
                          borderRadius: BorderRadius.circular(
                            AuthRadius.dialog,
                          ),
                        ),
                        child: Icon(
                          deleted ? Icons.block : Icons.play_arrow_rounded,
                          size: 30,
                          color: deleted
                              ? AuthColors.textPrimary
                              : AuthColors.onAccent,
                        ),
                      ),
                    ),
                    if (showBox)
                      Positioned(
                        top: 4,
                        left: 4,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: AuthColors.bg.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(
                              AuthRadius.field,
                            ),
                          ),
                          child: _selectionCheckbox(v),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AuthSpace.s),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AuthType.display(24).copyWith(height: 1),
                ),
                const SizedBox(height: 8),
                Text(
                  'BY ${_nameOf(v['trainer']).toUpperCase()} · '
                  '${_formatDate(v['createdAt'])}',
                  style: AuthType.mono(),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    GymTag(
                      label: isPublic ? 'Public' : 'Private',
                      icon: isPublic ? Icons.public : Icons.lock_outline,
                      color: isPublic
                          ? AuthColors.accent
                          : AuthColors.textMuted,
                    ),
                    if (v['exerciseType'] != null)
                      GymTag(label: v['exerciseType'].toString()),
                    if (v['difficulty'] != null)
                      GymTag(label: v['difficulty'].toString()),
                    if (_deletedByTrainer(v))
                      GymTag(
                        label: _purged(v)
                            ? 'Permanently deleted by trainer'
                            : 'Deleted by trainer',
                        icon: Icons.person_remove_outlined,
                        color: AuthColors.danger,
                      ),
                    ?_restoredTag(v),
                  ],
                ),
                if ((v['description']?.toString() ?? '').isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    v['description'].toString(),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: AuthType.body(size: 13),
                  ),
                ],
                if (deleted) _buildDeletedBanner(v) else _buildRemoveButton(v),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkoutCard(Map<String, dynamic> w) {
    final deleted = w['isDeleted'] == true;
    final exercises = (w['exercises'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final assigned = (w['assignedCount'] as num?)?.toInt() ?? 0;
    final copy = _isAssignedCopy(w);
    final assignedLine = copy
        ? ' · assigned to ${_nameOf(w['assignedTo'], fallback: 'a member')}'
        : (assigned > 0 ? ' · assigned to $assigned' : '');
    final deletedLine = !_deletedByTrainer(w)
        ? ''
        : copy
        ? '\nREMOVED FROM PLAN BY TRAINER'
        : (_purged(w)
              ? '\nPERMANENTLY DELETED BY TRAINER'
              : '\nDELETED BY TRAINER');

    final showBox = _selecting && !deleted;
    return PressableSurface(
      padding: EdgeInsets.zero,
      highlighted: showBox && _selected.contains(_idOf(w)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.fromLTRB(14, 6, 10, 6),
          iconColor: AuthColors.textPrimary,
          collapsedIconColor: AuthColors.textMuted,
          leading: showBox
              ? _selectionCheckbox(w)
              : GymAvatar(
                  icon: deleted ? Icons.block : Icons.fitness_center,
                  size: 40,
                ),
          title: Text(
            (w['title']?.toString() ?? 'Untitled').toUpperCase(),
            style: AuthType.display(20).copyWith(
              height: 1,
              color: deleted ? AuthColors.textMuted : AuthColors.textPrimary,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'By ${_nameOf(w['trainer'])} · ${exercises.length} exercise(s)'
              '$assignedLine\n'
              '${copy ? 'ASSIGNED COPY · ' : ''}${_formatDate(w['createdAt'])}'
              '$deletedLine'
              '${w['isDeleted'] != true && w['restoredAt'] != null ? '\nRESTORED BY ${w['restoredByRole'] == 'admin' ? 'ADMIN' : 'TRAINER'}' : ''}',
              style: AuthType.body(size: 12),
            ),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if ((w['description']?.toString() ?? '').isNotEmpty) ...[
              Text(w['description'].toString(), style: AuthType.body(size: 14)),
              const SizedBox(height: 12),
            ],
            if (exercises.isEmpty)
              Text(
                'No exercises.',
                style: AuthType.body(size: 13, color: AuthColors.textFaint),
              )
            else
              for (var i = 0; i < exercises.length; i++)
                _buildExerciseLine(i, exercises[i]),
            if (deleted) _buildDeletedBanner(w) else _buildRemoveButton(w),
          ],
        ),
      ),
    );
  }

  Widget _buildExerciseLine(int index, Map<String, dynamic> e) {
    final weight = e['weight'];
    final weightText = (weight is num && weight > 0) ? ' @ $weight kg' : '';
    final notes = e['notes']?.toString() ?? '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 28,
            child: Text(
              (index + 1).toString().padLeft(2, '0'),
              style: AuthType.mono(color: AuthColors.accent),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${e['name'] ?? 'Exercise'} — '
                  '${e['sets'] ?? '-'} x ${e['reps'] ?? '-'}$weightText',
                  style: AuthType.body(size: 14, color: AuthColors.textPrimary),
                ),
                if (notes.isNotEmpty)
                  Text(notes, style: AuthType.body(size: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _scrollableMessage(Widget child) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.sizeOf(context).height * 0.08),
        child,
      ],
    );
  }

  Widget _buildBody() {
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
      final what = _isVideo ? 'videos' : 'workouts';
      return _scrollableMessage(
        GymEmptyState(
          icon: Icons.inbox_outlined,
          message: _status == 'deleted'
              ? 'No removed $what.'
              : _status == 'trainer'
              ? 'No $what deleted by trainers.'
              : 'No $what found.',
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
      itemCount: _items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, i) => StaggeredReveal(
        index: i,
        child: _selectable(
          _items[i],
          _isVideo ? _buildVideoCard(_items[i]) : _buildWorkoutCard(_items[i]),
        ),
      ),
    );
  }

  String _filterLabel(String f) {
    switch (f) {
      case 'active':
        return 'Active ($_activeCount)';
      case 'deleted':
        return 'Removed ($_deletedCount)';
      case 'trainer':
        return 'By trainer ($_trainerDeletedCount)';
      default:
        return 'All';
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            GymScaffold.side,
            AuthSpace.s,
            GymScaffold.side,
            0,
          ),
          child: TextField(
            controller: _searchController,
            onChanged: (v) {
              setState(() {}); // refresh clear button visibility
              _onSearchChanged(v);
            },
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _load(),
            style: AuthType.input(),
            decoration: InputDecoration(
              hintText: _isVideo
                  ? 'Search video title or trainer'
                  : 'Search workout, exercise or trainer',
              prefixIcon: const Icon(Icons.search, size: 20),
              isDense: true,
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      icon: const Icon(Icons.close, size: 18),
                      color: AuthColors.textMuted,
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                        _load();
                      },
                    ),
            ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(
            horizontal: GymScaffold.side,
            vertical: 12,
          ),
          child: Row(
            children: [
              for (final f in _filters) ...[
                GymChoiceChip(
                  label: _filterLabel(f),
                  selected: _status == f,
                  onTap: _bulkProgress != null
                      ? null
                      : () {
                          if (_status == f) return;
                          setState(() => _status = f);
                          _load();
                        },
                ),
                const SizedBox(width: 8),
              ],
              Container(width: 1, height: 24, color: AuthColors.line),
              const SizedBox(width: 8),
              GymChoiceChip(
                label: _selecting ? 'Done' : 'Select',
                selected: _selecting,
                onTap: _bulkProgress != null
                    ? null
                    : _selecting
                    ? _stopSelecting
                    : (!_loading && _selectableItems.isNotEmpty
                          ? _startSelecting
                          : null),
              ),
            ],
          ),
        ),
        Expanded(
          child: GymRefresh(onRefresh: _load, child: _buildBody()),
        ),
        if (_selecting) _buildSelectionBar(),
      ],
    );
  }

  Widget _buildSelectionBar() {
    final selectable = _selectableItems;
    return SafeArea(
      top: false,
      child: GymSelectionBar(
        selectedCount: _selected.length,
        selectableCount: selectable.length,
        busyLabel: _bulkProgress,
        onSelectAll: () =>
            setState(() => _selected.addAll(selectable.map(_idOf))),
        onClear: () => setState(_selected.clear),
        onClose: _stopSelecting,
        actions: [
          GymSmallButton(
            label: _selected.isEmpty ? 'Remove' : 'Remove ${_selected.length}',
            icon: Icons.delete_outline,
            primary: true,
            onTap: _selected.isEmpty ? null : _deleteSelected,
          ),
        ],
      ),
    );
  }
}
