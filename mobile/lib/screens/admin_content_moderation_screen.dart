import 'dart:async';

import 'package:flutter/material.dart';
import '../services/api_service.dart';
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Content Moderation'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.video_library), text: 'Videos'),
            Tab(icon: Icon(Icons.fitness_center), text: 'Workouts'),
          ],
        ),
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
Future<String?> _askDeletionReason(
  BuildContext context, {
  required String itemLabel,
  required String title,
  required String ownerName,
  String? extraWarning,
}) {
  final customController = TextEditingController();
  String selected = _presetReasons.first;

  return showDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) {
        final isOther = selected == 'Other';
        final reason = isOther ? customController.text.trim() : selected;
        final valid = reason.length >= 10;

        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.report, color: Colors.red),
              const SizedBox(width: 8),
              Expanded(child: Text('Remove $itemLabel')),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '"$title" by $ownerName will be removed. '
                  '$ownerName will get an email with the reason.',
                ),
                if (extraWarning != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    extraWarning,
                    style: const TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                const Text(
                  'Reason for removal',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: selected,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: _presetReasons
                      .map(
                        (r) => DropdownMenuItem(
                          value: r,
                          child: Text(r, overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(),
                  onChanged: (v) =>
                      setDialogState(() => selected = v ?? selected),
                ),
                if (isOther) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: customController,
                    maxLength: 500,
                    maxLines: 3,
                    autofocus: true,
                    onChanged: (_) => setDialogState(() {}),
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      hintText: 'Describe why this is inappropriate',
                      errorText: customController.text.isNotEmpty && !valid
                          ? 'Minimum 10 characters'
                          : null,
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: valid ? () => Navigator.pop(ctx, reason) : null,
              icon: const Icon(Icons.delete_forever),
              label: const Text('Remove'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
          ],
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
  static const List<String> _filters = ['active', 'deleted', 'all'];

  Timer? _debounce;
  String _status = 'active';
  List<Map<String, dynamic>> _items = [];
  int _activeCount = 0;
  int _deletedCount = 0;
  bool _loading = true;
  String? _error;
  final Set<String> _busyIds = {};

  bool get _isVideo => widget.kind == _ContentKind.video;

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
        _loading = false;
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
          : (_isVideo
              ? 'The video file will be permanently deleted from storage.'
              : null),
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
          backgroundColor: Colors.green,
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _busyIds.remove(id));
    }
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
      MaterialPageRoute(
        builder: (_) => VideoPlayerScreen(
          videoUrl: url,
          title: item['title']?.toString() ?? 'Video',
        ),
      ),
    );
  }

  Widget _buildDeletedBanner(Map<String, dynamic> item) {
    final by = _nameOf(item['deletedBy'], fallback: 'admin');
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Removed by $by · ${_formatDate(item['deletedAt'])}',
            style: const TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text('Reason: ${item['deletionReason'] ?? '-'}'),
        ],
      ),
    );
  }

  Widget _buildRemoveButton(Map<String, dynamic> item) {
    final id = item['_id']?.toString() ?? '';
    final busy = _busyIds.contains(id);
    return Align(
      alignment: Alignment.centerRight,
      child: OutlinedButton.icon(
        onPressed: busy ? null : () => _delete(item),
        icon: busy
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.delete_outline, color: Colors.red),
        label: const Text('Remove', style: TextStyle(color: Colors.red)),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Colors.red),
        ),
      ),
    );
  }

  Widget _buildVideoCard(Map<String, dynamic> v) {
    final deleted = v['isDeleted'] == true;
    final thumb = v['thumbnailUrl']?.toString() ?? '';
    final isPublic = v['isPublic'] == true;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: deleted ? null : () => _openVideo(v),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (thumb.isNotEmpty)
                    Image.network(
                      thumb,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          Container(color: Colors.black26),
                    )
                  else
                    Container(color: Colors.black26),
                  Center(
                    child: Icon(
                      deleted ? Icons.block : Icons.play_circle_fill,
                      size: 56,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  v['title']?.toString() ?? 'Untitled',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'By ${_nameOf(v['trainer'])} · ${_formatDate(v['createdAt'])}',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _chip(isPublic ? 'Public' : 'Private',
                        isPublic ? Colors.green : Colors.blueGrey),
                    if (v['exerciseType'] != null)
                      _chip(v['exerciseType'].toString(), Colors.blue),
                    if (v['difficulty'] != null)
                      _chip(v['difficulty'].toString(), Colors.purple),
                  ],
                ),
                if ((v['description']?.toString() ?? '').isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    v['description'].toString(),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (deleted)
                  _buildDeletedBanner(v)
                else ...[
                  const SizedBox(height: 8),
                  _buildRemoveButton(v),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildWorkoutCard(Map<String, dynamic> w) {
    final deleted = w['isDeleted'] == true;
    final exercises = (w['exercises'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final assigned = (w['assignedCount'] as num?)?.toInt() ?? 0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: CircleAvatar(
            backgroundColor:
                (deleted ? Colors.red : Colors.blue).withValues(alpha: 0.15),
            child: Icon(
              deleted ? Icons.block : Icons.fitness_center,
              color: deleted ? Colors.red : Colors.blue,
            ),
          ),
          title: Text(
            w['title']?.toString() ?? 'Untitled',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            'By ${_nameOf(w['trainer'])} · ${exercises.length} exercise(s)'
            '${assigned > 0 ? ' · assigned to $assigned' : ''}\n'
            '${_formatDate(w['createdAt'])}',
            style: const TextStyle(fontSize: 12),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if ((w['description']?.toString() ?? '').isNotEmpty) ...[
              Text(w['description'].toString()),
              const SizedBox(height: 8),
            ],
            if (exercises.isEmpty)
              const Text(
                'No exercises.',
                style: TextStyle(color: Colors.grey),
              )
            else
              ...exercises.map(_buildExerciseLine),
            if (deleted)
              _buildDeletedBanner(w)
            else ...[
              const SizedBox(height: 8),
              _buildRemoveButton(w),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildExerciseLine(Map<String, dynamic> e) {
    final weight = e['weight'];
    final weightText =
        (weight is num && weight > 0) ? ' @ $weight kg' : '';
    final notes = e['notes']?.toString() ?? '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '• ${e['name'] ?? 'Exercise'} — '
            '${e['sets'] ?? '-'} x ${e['reps'] ?? '-'}$weightText',
          ),
          if (notes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Text(
                notes,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return ListView(
        children: [
          const SizedBox(height: 80),
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(_error!, textAlign: TextAlign.center),
          ),
          const SizedBox(height: 12),
          Center(
            child: ElevatedButton(onPressed: _load, child: const Text('Retry')),
          ),
        ],
      );
    }
    if (_items.isEmpty) {
      final what = _isVideo ? 'videos' : 'workouts';
      return ListView(
        children: [
          const SizedBox(height: 80),
          const Icon(Icons.inbox, size: 56, color: Colors.grey),
          const SizedBox(height: 12),
          Center(
            child: Text(
              _status == 'deleted' ? 'No removed $what.' : 'No $what found.',
            ),
          ),
        ],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: _items.length,
      itemBuilder: (_, i) => _isVideo
          ? _buildVideoCard(_items[i])
          : _buildWorkoutCard(_items[i]),
    );
  }

  String _filterLabel(String f) {
    switch (f) {
      case 'active':
        return 'Active ($_activeCount)';
      case 'deleted':
        return 'Removed ($_deletedCount)';
      default:
        return 'All';
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: TextField(
            controller: _searchController,
            onChanged: (v) {
              setState(() {}); // refresh clear button visibility
              _onSearchChanged(v);
            },
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _load(),
            decoration: InputDecoration(
              hintText: _isVideo
                  ? 'Search video title or trainer'
                  : 'Search workout, exercise or trainer',
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _load();
                      },
                    ),
            ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: _filters
                .map(
                  (f) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(_filterLabel(f)),
                      selected: _status == f,
                      onSelected: (_) {
                        if (_status == f) return;
                        setState(() => _status = f);
                        _load();
                      },
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        Expanded(
          child: RefreshIndicator(onRefresh: _load, child: _buildBody()),
        ),
      ],
    );
  }
}
