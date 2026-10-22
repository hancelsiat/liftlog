import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../utils/bulk_action.dart';
import '../widgets/gym/gym.dart';
import 'client_detail_screen.dart';
import 'chat_screen.dart';

class TrainerClientsScreen extends StatefulWidget {
  const TrainerClientsScreen({super.key});

  @override
  State<TrainerClientsScreen> createState() => _TrainerClientsScreenState();
}

class _TrainerClientsScreenState extends State<TrainerClientsScreen> {
  late Future<List<User>> _clientsFuture;
  final ApiService _apiService = ApiService();

  // Last loaded roster, used by search, select all and bulk remove.
  List<User> _clients = [];

  // Search filters what is shown. Selections hidden by a search are kept,
  // but bulk remove only touches selected clients that are currently visible.
  String _query = '';

  // Multi-select (bulk remove).
  bool _selecting = false;
  final Set<String> _selected = {};
  String? _bulkProgress;

  @override
  void initState() {
    super.initState();
    _clientsFuture = _fetchClients();
  }

  Future<List<User>> _fetchClients() async {
    final response = await _apiService.getClients();
    final clients = response.map((data) => User.fromJson(data)).toList();
    // The FutureBuilder rebuilds when this completes, so no setState here.
    _clients = clients;
    final ids = clients.map((c) => c.id).toSet();
    _selected.retainWhere(ids.contains);
    if (ids.isEmpty) _selecting = false;
    return clients;
  }

  Future<void> _refreshClients() async {
    setState(() {
      _clientsFuture = _fetchClients();
    });
    try {
      await _clientsFuture;
    } catch (_) {
      // The FutureBuilder shows the error.
    }
  }

  bool _matches(User u) => matchesSearch(_query, [
    u.username,
    u.name,
    u.email,
    u.profile?.firstName,
    u.profile?.lastName,
  ]);

  List<User> get _visibleClients => _clients.where(_matches).toList();

  List<User> get _selectedClients =>
      _visibleClients.where((c) => _selected.contains(c.id)).toList();

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

  void _removeClient(String clientId) async {
    try {
      await _apiService.removeClient(clientId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Client removed successfully!')),
      );
      _refreshClients();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error removing client: $e'),
          backgroundColor: AuthColors.danger,
        ),
      );
    }
  }

  /// Removes every selected (and visible) client one by one, showing
  /// progress in the selection bar and a summary snackbar at the end.
  Future<void> _bulkRemove() async {
    final clients = _selectedClients;
    if (clients.isEmpty) return;
    final names = clients.take(3).map((c) => c.username).join(', ');
    final more = clients.length > 3 ? ' and ${clients.length - 3} more' : '';
    final confirmed = await showAuthDialog<bool>(
      context: context,
      eyebrow: 'Trainer / Roster',
      title: clients.length == 1
          ? 'Remove Client'
          : 'Remove ${clients.length} Clients',
      message:
          'Remove $names$more from your roster? They will no longer be '
          'assigned to you and can pick a new trainer.',
      actions: (dialogContext) => [
        AuthDialogAction(
          label: 'Cancel',
          onPressed: () => Navigator.of(dialogContext).pop(false),
        ),
        AuthDialogAction(
          label: clients.length == 1 ? 'Remove' : 'Remove all',
          primary: true,
          onPressed: () => Navigator.of(dialogContext).pop(true),
        ),
      ],
    );
    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _bulkProgress = 'Removing 0/${clients.length}…');
    final result = await runBulk<User>(
      clients,
      (c) => _apiService.removeClient(c.id),
      onProgress: (done, total) {
        if (mounted) setState(() => _bulkProgress = 'Removing $done/$total…');
      },
    );
    if (!mounted) return;
    setState(() {
      _bulkProgress = null;
      _selecting = false;
      _selected.clear();
      _clientsFuture = _fetchClients();
    });
    messenger.showSnackBar(
      SnackBar(
        content: Text(result.message(verb: 'Removed', noun: 'client')),
        backgroundColor: result.failed > 0 ? AuthColors.danger : null,
      ),
    );
  }

  Widget _buildSelectionBar() {
    final chosen = _selectedClients.length;
    // Select all / clear act on the clients the search currently shows.
    final visibleIds = _visibleClients.map((c) => c.id).toList();
    return GymSelectionBar(
      selectedCount: chosen,
      selectableCount: visibleIds.length,
      busyLabel: _bulkProgress,
      onSelectAll: () => setState(() => _selected.addAll(visibleIds)),
      onClear: () => setState(() => _selected.removeAll(visibleIds)),
      onClose: _stopSelecting,
      actions: [
        GymSmallButton(
          label: chosen > 0 ? 'Remove $chosen' : 'Remove',
          icon: Icons.delete_outline,
          primary: true,
          onTap: chosen > 0 ? _bulkRemove : null,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentTrainerId = Provider.of<AuthProvider>(
      context,
      listen: false,
    ).user?.id;
    final busy = _bulkProgress != null;

    return GymScaffold(
      eyebrow: 'Trainer / Roster',
      title: 'My Clients',
      actions: [
        GymIconButton(
          icon: _selecting ? Icons.close : Icons.checklist,
          tooltip: _selecting ? 'Exit selection' : 'Select multiple',
          // _clients is filled inside the FutureBuilder's future, which
          // does not rebuild this action, so the button is not gated on it.
          onTap: busy ? null : (_selecting ? _stopSelecting : _startSelecting),
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
          hint: 'Search name, username or email',
          enabled: !busy,
          onChanged: (q) => setState(() => _query = q.trim()),
        ),
      ),
      bottomBar: _selecting ? _buildSelectionBar() : null,
      body: GymRefresh(
        onRefresh: _refreshClients,
        child: FutureBuilder<List<User>>(
          future: _clientsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const GymLoader();
            }
            if (snapshot.hasError) {
              return _scrollableMessage(
                GymEmptyState(
                  icon: Icons.error_outline,
                  danger: true,
                  message: 'Error: ${snapshot.error}',
                  action: SizedBox(
                    width: 160,
                    child: PressableButton(
                      label: 'Retry',
                      height: 48,
                      showArrow: false,
                      onPressed: _refreshClients,
                    ),
                  ),
                ),
              );
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return _scrollableMessage(
                const GymEmptyState(
                  icon: Icons.group_outlined,
                  message: 'You have no clients yet.',
                ),
              );
            }

            final clients = snapshot.data!.where(_matches).toList();
            if (clients.isEmpty) {
              return _scrollableMessage(
                GymEmptyState(
                  icon: Icons.search_off,
                  message: 'No clients match "$_query".',
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
              itemCount: clients.length + 1,
              separatorBuilder: (context, index) =>
                  SizedBox(height: index == 0 ? AuthSpace.s : 10),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return GymSectionLabel(
                    index: 1,
                    label:
                        '${clients.length} '
                        '${clients.length == 1 ? 'client' : 'clients'}',
                  );
                }
                final client = clients[index - 1];
                final bool hasLeft = client.trainer != currentTrainerId;
                return StaggeredReveal(
                  index: index - 1,
                  child: _ClientCard(
                    client: client,
                    hasLeft: hasLeft,
                    selecting: _selecting,
                    selected: _selected.contains(client.id),
                    onToggle: busy ? null : () => _toggle(client.id),
                    onLongPress: busy ? null : () => _startSelecting(client.id),
                    onOpen: () {
                      Navigator.push(
                        context,
                        GymPageRoute(
                          builder: (context) =>
                              ClientDetailScreen(client: client),
                        ),
                      ).then((_) => _refreshClients());
                    },
                    onChat: () {
                      Navigator.push(
                        context,
                        GymPageRoute(
                          builder: (context) => ChatScreen(partner: client),
                        ),
                      );
                    },
                    onRemove: () => _removeClient(client.id),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  /// Empty and error states still need to scroll so pull-to-refresh works.
  Widget _scrollableMessage(Widget child) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.sizeOf(context).height * 0.12),
        child,
      ],
    );
  }
}

class _ClientCard extends StatelessWidget {
  const _ClientCard({
    required this.client,
    required this.hasLeft,
    required this.onOpen,
    required this.onChat,
    required this.onRemove,
    this.selecting = false,
    this.selected = false,
    this.onToggle,
    this.onLongPress,
  });

  final User client;
  final bool hasLeft;
  final VoidCallback onOpen;
  final VoidCallback onChat;
  final VoidCallback onRemove;

  /// Shows a check box and makes the whole card toggle selection.
  final bool selecting;
  final bool selected;
  final VoidCallback? onToggle;

  /// Long press enters selection mode with this card picked.
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onLongPress: selecting ? null : onLongPress,
      child: PressableSurface(
        onTap: selecting ? onToggle : onOpen,
        highlighted: selecting && selected,
        semanticLabel: selecting
            ? '${selected ? 'Deselect' : 'Select'} ${client.username}'
            : 'Open ${client.username}',
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            if (selecting) ...[
              GymCheckbox(
                value: selected,
                semanticLabel: 'Select ${client.username}',
                onChanged: onToggle == null ? null : (_) => onToggle!(),
              ),
              const SizedBox(width: 4),
            ],
            GymAvatar(text: client.username, size: 44, highlighted: !hasLeft),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    client.username.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AuthType.display(22).copyWith(height: 1),
                  ),
                  const SizedBox(height: 6),
                  if (hasLeft)
                    const GymTag(
                      label: 'This client has left',
                      color: AuthColors.danger,
                      icon: Icons.logout,
                    )
                  else
                    Text(
                      client.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AuthType.body(size: 13),
                    ),
                ],
              ),
            ),
            if (!selecting) ...[
              const SizedBox(width: 12),
              hasLeft
                  ? GymIconButton(
                      icon: Icons.delete_outline,
                      tooltip: 'Remove client',
                      danger: true,
                      onTap: onRemove,
                    )
                  : GymIconButton(
                      icon: Icons.chat_bubble_outline,
                      tooltip: 'Message ${client.username}',
                      onTap: onChat,
                    ),
            ],
          ],
        ),
      ),
    );
  }
}
