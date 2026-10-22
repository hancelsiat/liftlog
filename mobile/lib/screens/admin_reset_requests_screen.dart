import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/bulk_action.dart';
import '../widgets/gym/gym.dart';

/// Admin: review members' requests to reset their BMI / calorie cooldown.
class AdminResetRequestsScreen extends StatefulWidget {
  const AdminResetRequestsScreen({super.key});

  @override
  State<AdminResetRequestsScreen> createState() =>
      _AdminResetRequestsScreenState();
}

class _AdminResetRequestsScreenState extends State<AdminResetRequestsScreen> {
  final ApiService _apiService = ApiService();
  static const List<String> _filters = [
    'pending',
    'approved',
    'rejected',
    'all',
  ];

  String _status = 'pending';
  List<Map<String, dynamic>> _requests = [];
  int _pendingCount = 0;
  bool _loading = true;
  String? _error;
  final Set<String> _busyIds = {};

  // Multi-select (bulk approve / reject). Only pending requests can be picked.
  bool _selecting = false;
  final Set<String> _selected = {};
  String? _bulkProgress;

  // Client-side search over the loaded requests. Selections hidden by a
  // search are kept, but bulk actions only touch visible ones.
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _idOf(Map<String, dynamic> r) => r['_id'].toString();

  bool _isPending(Map<String, dynamic> r) => r['status'] == 'pending';

  bool _matches(Map<String, dynamic> r) {
    final user = r['user'] as Map?;
    final handledBy = r['handledBy'] as Map?;
    return matchesSearch(_query, [
      user?['username']?.toString(),
      user?['email']?.toString(),
      r['reason']?.toString(),
      r['adminNote']?.toString(),
      _typeLabel(r['type']?.toString()),
      handledBy?['username']?.toString(),
    ]);
  }

  /// Requests shown under the current status filter and search.
  List<Map<String, dynamic>> get _visibleRequests =>
      _requests.where(_matches).toList();

  /// Pending requests that are visible, i.e. the ones that can be selected.
  List<Map<String, dynamic>> get _pendingRequests =>
      _visibleRequests.where(_isPending).toList();

  int get _visibleSelectedCount =>
      _pendingRequests.where((r) => _selected.contains(_idOf(r))).length;

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

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _apiService.getCooldownResetRequests(status: _status);
      if (!mounted) return;
      setState(() {
        _requests = (data['requests'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _pendingCount = (data['pendingCount'] as num?)?.toInt() ?? 0;
        _loading = false;
        // Drop selections that are gone or no longer pending (ignoring the
        // search, so hidden selections survive a reload).
        final pendingIds = _requests.where(_isPending).map(_idOf).toSet();
        _selected.retainWhere(pendingIds.contains);
        if (pendingIds.isEmpty) _selecting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  String _typeLabel(String? type) {
    switch (type) {
      case 'bmi':
        return 'BMI';
      case 'calories':
        return 'Calories';
      default:
        return 'BMI & Calories';
    }
  }

  String _formatDate(dynamic value) {
    final d = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (d == null) return '';
    final mm = d.minute.toString().padLeft(2, '0');
    return '${d.day}/${d.month}/${d.year} ${d.hour}:$mm';
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'approved':
        return AuthColors.accent;
      case 'rejected':
        return AuthColors.danger;
      default:
        return GymColors.warn;
    }
  }

  Future<void> _handle(Map<String, dynamic> request, bool approve) async {
    final user = request['user'] as Map?;
    final username = user?['username']?.toString() ?? 'this member';
    final noteController = TextEditingController();

    final confirmed = await showGymDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final noteOk = approve || noteController.text.trim().length >= 5;
          return GymFormDialog(
            eyebrow: 'Admin / Reset request',
            title: approve ? 'Approve Reset?' : 'Reject Request?',
            confirmLabel: approve ? 'Approve' : 'Reject',
            onConfirm: noteOk ? () => Navigator.pop(ctx, true) : null,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  approve
                      ? 'This will reset the BMI & Calories cooldown for $username right away.'
                            '\n\nTheir latest BMI and calorie entries will also be deleted from their progress history, '
                            'and their update timers will start over.'
                      : 'Tell $username why the request is rejected.',
                  style: AuthType.body(),
                ),
                const SizedBox(height: AuthSpace.s),
                GymLabeledField(
                  label: approve
                      ? 'Note (optional)'
                      : 'Reason (min 5 characters)',
                  child: TextField(
                    controller: noteController,
                    maxLength: 500,
                    maxLines: 2,
                    autofocus: !approve,
                    style: AuthType.input(),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    final note = noteController.text.trim();
    noteController.dispose();
    if (confirmed != true || !mounted) return;

    final id = request['_id'].toString();
    setState(() => _busyIds.add(id));
    final messenger = ScaffoldMessenger.of(context);
    try {
      final response = await _apiService.handleCooldownResetRequest(
        id,
        approve: approve,
        note: note,
      );
      messenger.showSnackBar(
        SnackBar(
          content: Text(response['message']?.toString() ?? 'Done.'),
          backgroundColor: approve ? null : GymColors.warn,
        ),
      );
      await _load();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: AuthColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _busyIds.remove(id));
    }
  }

  /// Approve or reject every selected request with one shared note.
  Future<void> _handleSelected(bool approve) async {
    final targets = _pendingRequests
        .where((r) => _selected.contains(_idOf(r)))
        .toList();
    if (targets.isEmpty) return;
    final count = targets.length;
    final noteController = TextEditingController();

    final confirmed = await showGymDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final noteOk = approve || noteController.text.trim().length >= 5;
          return GymFormDialog(
            eyebrow: 'Admin / $count selected',
            title: approve
                ? 'Approve $count Resets?'
                : 'Reject $count Requests?',
            confirmLabel: approve ? 'Approve all' : 'Reject all',
            onConfirm: noteOk ? () => Navigator.pop(ctx, true) : null,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  approve
                      ? 'This resets the BMI & Calories cooldown for $count member(s). '
                            'Their latest BMI and calorie entries are deleted and their '
                            'update timers start over.'
                      : 'All $count member(s) will see this reason.',
                  style: AuthType.body(),
                ),
                const SizedBox(height: AuthSpace.s),
                GymLabeledField(
                  label: approve
                      ? 'Note (optional, sent to all)'
                      : 'Reason (min 5 characters)',
                  child: TextField(
                    controller: noteController,
                    maxLength: 500,
                    maxLines: 2,
                    autofocus: !approve,
                    style: AuthType.input(),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    final note = noteController.text.trim();
    noteController.dispose();
    if (confirmed != true || !mounted) return;

    final verb = approve ? 'Approving' : 'Rejecting';
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _bulkProgress = '$verb 0/$count…');
    final result = await runBulk<Map<String, dynamic>>(
      targets,
      (r) => _apiService.handleCooldownResetRequest(
        _idOf(r),
        approve: approve,
        note: note,
      ),
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
            verb: approve ? 'Approved' : 'Rejected',
            noun: 'request',
          ),
        ),
        backgroundColor: result.failed > 0
            ? AuthColors.danger
            : (approve ? null : GymColors.warn),
      ),
    );
    await _load();
  }

  Widget _buildRequestCard(Map<String, dynamic> r) {
    final user = r['user'] as Map?;
    final handledBy = r['handledBy'] as Map?;
    final status = r['status']?.toString();
    final id = r['_id'].toString();
    final busy = _busyIds.contains(id);
    final username = user?['username']?.toString() ?? 'Deleted user';
    final selectable = _selecting && status == 'pending';
    final selected = _selected.contains(id);

    return PressableSurface(
      highlighted: selectable ? selected : status == 'pending',
      padding: const EdgeInsets.all(14),
      onTap: selectable ? () => _toggle(id) : null,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onLongPress: !_selecting && status == 'pending' && _bulkProgress == null
            ? () => _startSelecting(id)
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (selectable) ...[
                  GymCheckbox(
                    value: selected,
                    semanticLabel: 'Select $username',
                    onChanged: (_) => _toggle(id),
                  ),
                  const SizedBox(width: 4),
                ],
                GymAvatar(
                  text: username,
                  icon: user == null ? Icons.person_off_outlined : null,
                  size: 44,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        username.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AuthType.display(22).copyWith(height: 1),
                      ),
                      if (user?['email'] != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          user!['email'].toString(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AuthType.body(size: 13),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                GymTag(label: status ?? 'pending', color: _statusColor(status)),
              ],
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: GymTag(
                label: 'Reset: ${_typeLabel(r['type'])}',
                icon: Icons.restart_alt,
                color: AuthColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Reason: ${r['reason'] ?? ''}',
              style: AuthType.body(size: 14, color: AuthColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'REQUESTED ${_formatDate(r['createdAt'])}',
              style: AuthType.mono(color: AuthColors.textFaint),
            ),
            if (status != 'pending') ...[
              const SizedBox(height: 4),
              Text(
                'HANDLED'
                '${handledBy?['username'] != null ? ' BY ${handledBy!['username'].toString().toUpperCase()}' : ''}'
                ' ON ${_formatDate(r['handledAt'])}',
                style: AuthType.mono(color: AuthColors.textFaint),
              ),
              if (r['adminNote'] != null) ...[
                const SizedBox(height: 8),
                Text('Note: ${r['adminNote']}', style: AuthType.body(size: 13)),
              ],
            ],
            // In selection mode the bulk bar replaces the per-card buttons.
            if (status == 'pending' && !_selecting) ...[
              const SizedBox(height: 14),
              if (busy)
                const SizedBox(height: 40, child: GymLoader())
              else
                Row(
                  children: [
                    Expanded(
                      child: GymSmallButton(
                        label: 'Reject',
                        icon: Icons.close,
                        onTap: () => _handle(r, false),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GymSmallButton(
                        label: 'Approve & Reset',
                        icon: Icons.restart_alt,
                        primary: true,
                        onTap: () => _handle(r, true),
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

  Widget _scrollableMessage(Widget child) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.sizeOf(context).height * 0.1),
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
    if (_requests.isEmpty) {
      return _scrollableMessage(
        GymEmptyState(
          icon: Icons.inbox_outlined,
          message: _status == 'pending'
              ? 'No pending reset requests.'
              : 'No $_status requests.',
        ),
      );
    }
    final visible = _visibleRequests;
    if (visible.isEmpty) {
      return _scrollableMessage(
        GymEmptyState(
          icon: Icons.search_off,
          message: 'No requests match "$_query".',
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
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, i) =>
          StaggeredReveal(index: i, child: _buildRequestCard(visible[i])),
    );
  }

  Widget? _buildSelectionBar() {
    if (!_selecting) return null;
    final count = _visibleSelectedCount;
    final none = count == 0;
    final visibleIds = _pendingRequests.map(_idOf).toList();
    return GymSelectionBar(
      selectedCount: count,
      selectableCount: visibleIds.length,
      busyLabel: _bulkProgress,
      onSelectAll: () => setState(() => _selected.addAll(visibleIds)),
      onClear: () => setState(() => _selected.removeAll(visibleIds)),
      onClose: _stopSelecting,
      actions: [
        GymSmallButton(
          label: 'Reject',
          icon: Icons.close,
          onTap: none ? null : () => _handleSelected(false),
        ),
        GymSmallButton(
          label: 'Approve',
          icon: Icons.restart_alt,
          primary: true,
          onTap: none ? null : () => _handleSelected(true),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final canSelect = !_loading && _pendingRequests.isNotEmpty;
    return GymScaffold(
      eyebrow: _pendingCount > 0
          ? 'Admin / $_pendingCount pending'
          : 'Admin / Cooldowns',
      title: 'Reset Requests',
      bottomBar: _buildSelectionBar(),
      actions: [
        GymIconButton(
          icon: _selecting ? Icons.close : Icons.checklist,
          tooltip: _selecting ? 'Exit selection' : 'Select multiple',
          onTap: _bulkProgress != null
              ? null
              : _selecting
              ? _stopSelecting
              : (canSelect ? _startSelecting : null),
        ),
      ],
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              GymScaffold.side,
              0,
              GymScaffold.side,
              AuthSpace.xs,
            ),
            child: GymSearchField(
              hint: 'Search member, email or reason',
              enabled: _bulkProgress == null,
              onChanged: (q) => setState(() => _query = q.trim()),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(
              GymScaffold.side,
              0,
              GymScaffold.side,
              AuthSpace.xs,
            ),
            child: Row(
              children: [
                for (final f in _filters) ...[
                  GymChoiceChip(
                    label: f,
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
              ],
            ),
          ),
        ],
      ),
      body: GymRefresh(onRefresh: _load, child: _buildBody()),
    );
  }
}
