import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../utils/bulk_action.dart';
import '../utils/error_handler.dart';
import '../widgets/gym/gym.dart';
import '../widgets/reset_cooldown_dialog.dart';
import 'edit_user_screen.dart';
import 'credential_viewer_screen.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key, this.api});

  /// Injected in tests; defaults to the real [ApiService].
  final ApiService? api;

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen>
    with SingleTickerProviderStateMixin {
  late Future<Map<UserRole, List<User>>> _usersFuture;
  late final ApiService _apiService = widget.api ?? ApiService();

  // Trainers and members live on separate tabs, in this order.
  static const _tabRoles = [UserRole.trainer, UserRole.member];
  late final TabController _tabController;
  int _tab = 0;

  // Multi-select (bulk approve / reject / delete). Admin accounts are never
  // listed, so every visible user can be selected.
  List<User> _listedUsers = [];
  bool _selecting = false;
  final Set<String> _selected = {};
  String? _bulkProgress;

  // Search and the current tab filter what is shown. Selections hidden by a
  // search or on the other tab are kept, but bulk actions only touch selected
  // users that are currently visible.
  String _query = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabRoles.length, vsync: this)
      ..addListener(() {
        // Fires during the swipe too; only rebuild once the index changes.
        if (_tab != _tabController.index) {
          setState(() => _tab = _tabController.index);
        }
      });
    _usersFuture = _fetchAndGroupUsers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  UserRole get _currentRole => _tabRoles[_tab];

  bool _isPendingTrainer(User u) => u.role == UserRole.trainer && !u.isApproved;

  /// Trainer who confirmed their email and is waiting for admin approval.
  /// Unverified trainers are listed under "Unverified email" instead.
  bool _awaitsApproval(User u) =>
      u.role == UserRole.trainer && u.isEmailVerified && !u.isApproved;

  bool _matches(User u) => matchesSearch(_query, [
    u.username,
    u.name,
    u.fullName,
    u.email,
    u.profile?.firstName,
    u.profile?.lastName,
  ]);

  List<User> get _visibleUsers =>
      _listedUsers.where((u) => u.role == _currentRole && _matches(u)).toList();

  List<User> get _selectedUsers =>
      _visibleUsers.where((u) => _selected.contains(u.id)).toList();

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

  Future<Map<UserRole, List<User>>> _fetchAndGroupUsers() async {
    // The API pages 10 users by default; admins need to see everyone.
    final response = await _apiService.getUsers(limit: 1000);
    final usersData = response['users'] as List;
    final users = usersData.map((data) => User.fromJson(data)).toList();

    // The FutureBuilder rebuilds when this completes, so no setState here.
    _listedUsers = users.where((u) => u.role != UserRole.admin).toList();
    final ids = _listedUsers.map((u) => u.id).toSet();
    _selected.retainWhere(ids.contains);
    if (ids.isEmpty) _selecting = false;

    final Map<UserRole, List<User>> groupedUsers = {
      UserRole.trainer: [],
      UserRole.member: [],
      UserRole.admin: [],
    };

    for (var user in users) {
      groupedUsers[user.role]!.add(user);
    }

    return groupedUsers;
  }

  Future<void> _refresh() async {
    setState(() {
      _usersFuture = _fetchAndGroupUsers();
    });
    try {
      await _usersFuture;
    } catch (_) {
      // The FutureBuilder shows the error.
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = _bulkProgress != null;
    return GymScaffold(
      eyebrow: 'Admin / Accounts',
      title: 'Manage Users',
      bottomBar: _selecting ? _buildSelectionBar() : null,
      actions: [
        GymIconButton(
          icon: _selecting ? Icons.close : Icons.checklist,
          tooltip: _selecting ? 'Exit selection' : 'Select multiple',
          // _listedUsers is filled inside the FutureBuilder's future, which
          // does not rebuild this action, so the button is not gated on it.
          onTap: busy ? null : (_selecting ? _stopSelecting : _startSelecting),
        ),
      ],
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GymTabBar(
            controller: _tabController,
            tabs: const ['Trainers', 'Members'],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              GymScaffold.side,
              AuthSpace.xs,
              GymScaffold.side,
              AuthSpace.xs,
            ),
            child: GymSearchField(
              hint: 'Search name, username or email',
              enabled: !busy,
              onChanged: (q) => setState(() => _query = q.trim()),
            ),
          ),
        ],
      ),
      body: FutureBuilder<Map<UserRole, List<User>>>(
        future: _usersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const GymLoader();
          }
          if (snapshot.hasError) {
            return GymRefresh(
              onRefresh: _refresh,
              child: _scrollableMessage(
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
                      onPressed: _refresh,
                    ),
                  ),
                ),
              ),
            );
          }
          final grouped = snapshot.data ?? const {};
          // Each tab has its own refresh indicator: the TabBarView is a
          // scrollable too, so one placed above it would never fire.
          return TabBarView(
            controller: _tabController,
            children: [
              for (final role in _tabRoles)
                GymRefresh(
                  onRefresh: _refresh,
                  child: _buildRoleList(role, grouped[role] ?? const []),
                ),
            ],
          );
        },
      ),
    );
  }

  /// One tab: users of [role], split into sections. Unverified accounts
  /// always get their own section at the end.
  Widget _buildRoleList(UserRole role, List<User> all) {
    final isTrainer = role == UserRole.trainer;
    final noun = isTrainer ? 'trainers' : 'members';
    final users = all.where(_matches).toList();
    final searching = _query.isNotEmpty;

    if (users.isEmpty) {
      return _scrollableMessage(
        GymEmptyState(
          icon: searching ? Icons.search_off : Icons.group_outlined,
          message: searching ? 'No $noun match "$_query".' : 'No $noun yet.',
        ),
      );
    }

    final unverified = users.where((u) => !u.isEmailVerified).toList();
    final pending = isTrainer
        ? users.where(_awaitsApproval).toList()
        : <User>[];
    final active = users
        .where((u) => u.isEmailVerified && (!isTrainer || u.isApproved))
        .toList();

    var reveal = 0;
    Widget card(User u) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: StaggeredReveal(
        index: reveal++,
        child: _UserCard(
          user: u,
          // The bulk bar replaces per-card buttons while selecting.
          actions: _selecting ? const [] : _buildActionButtons(u, context),
          selecting: _selecting,
          selected: _selected.contains(u.id),
          onToggle: () => _toggle(u.id),
          onLongPress: _bulkProgress == null
              ? () => _startSelecting(u.id)
              : null,
        ),
      ),
    );

    var section = 0;
    List<Widget> group(
      String label,
      List<User> list, {
      String? note,
      String? emptyText,
    }) {
      if (list.isEmpty && emptyText == null) return const [];
      return [
        GymSectionLabel(index: ++section, label: '$label (${list.length})'),
        if (note != null) ...[
          const SizedBox(height: 6),
          Text(note, style: AuthType.body(size: 13)),
        ],
        const SizedBox(height: AuthSpace.s),
        if (list.isEmpty) _emptyLine(emptyText!) else ...list.map(card),
        const SizedBox(height: AuthSpace.m),
      ];
    }

    final activeLabel = isTrainer ? 'Approved trainers' : 'Verified members';
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        GymScaffold.side,
        AuthSpace.xs,
        GymScaffold.side,
        AuthSpace.l,
      ),
      children: [
        if (_selecting) ...[
          _buildQuickSelect([
            if (isTrainer) ('Pending', pending),
            (isTrainer ? 'Approved' : 'Verified', active),
            ('Unverified', unverified),
          ]),
          const SizedBox(height: AuthSpace.s),
        ],
        // Pending trainers first so they are easy to find.
        ...group('Pending approval', pending),
        ...group(
          activeLabel,
          active,
          emptyText: searching
              ? 'No matching $noun.'
              : (isTrainer
                    ? 'No approved trainers yet.'
                    : 'No verified members yet.'),
        ),
        ...group(
          'Unverified email',
          unverified,
          note:
              'These accounts have not confirmed their email, so they '
              'cannot log in yet.',
        ),
      ],
    );
  }

  /// Chips that select a whole group at once. Tapping a fully selected
  /// group clears it.
  Widget _buildQuickSelect(List<(String, List<User>)> groups) {
    Widget chip(String label, List<User> group) {
      final ids = group.map((u) => u.id).toSet();
      final all = ids.isNotEmpty && _selected.containsAll(ids);
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: GymChoiceChip(
          label: '$label (${group.length})',
          selected: all,
          onTap: group.isEmpty || _bulkProgress != null
              ? null
              : () => setState(() {
                  if (all) {
                    _selected.removeAll(ids);
                  } else {
                    _selected.addAll(ids);
                  }
                }),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [for (final (label, users) in groups) chip(label, users)],
      ),
    );
  }

  Widget _buildSelectionBar() {
    final chosen = _selectedUsers;
    final pending = chosen.where(_isPendingTrainer).length;
    final deletable = chosen.length - pending;
    // Select all / clear act on the users the search currently shows.
    final visibleIds = _visibleUsers.map((u) => u.id).toList();
    return GymSelectionBar(
      selectedCount: chosen.length,
      selectableCount: visibleIds.length,
      busyLabel: _bulkProgress,
      onSelectAll: () => setState(() => _selected.addAll(visibleIds)),
      onClear: () => setState(() => _selected.removeAll(visibleIds)),
      onClose: _stopSelecting,
      actions: [
        // Approve / Reject only apply to pending trainers; Delete only to
        // the rest (pending trainers are removed by rejecting them).
        if (pending > 0) ...[
          GymSmallButton(
            label: 'Reject $pending',
            icon: Icons.close,
            onTap: _bulkReject,
          ),
          GymSmallButton(
            label: 'Approve $pending',
            icon: Icons.check,
            primary: true,
            onTap: _bulkApprove,
          ),
        ],
        GymSmallButton(
          label: deletable > 0 ? 'Delete $deletable' : 'Delete',
          icon: Icons.delete_outline,
          primary: pending == 0,
          onTap: deletable > 0 ? _bulkDelete : null,
        ),
      ],
    );
  }

  /// Runs [action] for [users], shows progress in the bar and a summary
  /// snackbar, then reloads the list.
  Future<void> _runBulkOnUsers(
    List<User> users,
    Future<void> Function(User) action, {
    required String progressVerb,
    required String doneVerb,
    required String noun,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _bulkProgress = '$progressVerb 0/${users.length}…');
    final result = await runBulk<User>(
      users,
      action,
      onProgress: (done, total) {
        if (mounted) {
          setState(() => _bulkProgress = '$progressVerb $done/$total…');
        }
      },
    );
    if (!mounted) return;
    setState(() {
      _bulkProgress = null;
      _selecting = false;
      _selected.clear();
      _usersFuture = _fetchAndGroupUsers();
    });
    messenger.showSnackBar(
      SnackBar(
        content: Text(result.message(verb: doneVerb, noun: noun)),
        backgroundColor: result.failed > 0 ? AuthColors.danger : null,
      ),
    );
  }

  Future<void> _bulkApprove() async {
    final users = _selectedUsers.where(_isPendingTrainer).toList();
    if (users.isEmpty) return;
    final ok = await _confirm(
      title: 'Approve ${users.length} Trainers',
      message:
          '${users.length} trainer(s) will be approved and can log in right '
          'away. Each trainer gets an approval email.',
      confirmLabel: 'Approve all',
    );
    if (!ok || !mounted) return;
    await _runBulkOnUsers(
      users,
      (u) => _apiService.approveTrainer(u.id, true),
      progressVerb: 'Approving',
      doneVerb: 'Approved',
      noun: 'trainer',
    );
  }

  Future<void> _bulkReject() async {
    final users = _selectedUsers.where(_isPendingTrainer).toList();
    if (users.isEmpty) return;
    final reason = await _askRejectionReason(context, count: users.length);
    if (reason == null || !mounted) return;
    await _runBulkOnUsers(
      users,
      (u) => _apiService.approveTrainer(u.id, false, rejectionReason: reason),
      progressVerb: 'Rejecting',
      doneVerb: 'Rejected',
      noun: 'trainer',
    );
  }

  Future<void> _bulkDelete() async {
    final users = _selectedUsers.where((u) => !_isPendingTrainer(u)).toList();
    if (users.isEmpty) return;
    final names = users.take(3).map((u) => u.username).join(', ');
    final more = users.length > 3 ? ' and ${users.length - 3} more' : '';
    final ok = await _confirm(
      title: 'Delete ${users.length} Users',
      message: 'Permanently delete $names$more? This cannot be undone.',
      confirmLabel: 'Delete all',
    );
    if (!ok || !mounted) return;
    await _runBulkOnUsers(
      users,
      (u) => _apiService.deleteUser(u.id),
      progressVerb: 'Deleting',
      doneVerb: 'Deleted',
      noun: 'user',
    );
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final result = await showAuthDialog<bool>(
      context: context,
      eyebrow: 'Admin / Users',
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
    return result == true;
  }

  Widget _emptyLine(String text) => Padding(
    padding: const EdgeInsets.only(bottom: AuthSpace.s),
    child: Text(text, style: AuthType.body(size: 14)),
  );

  Widget _scrollableMessage(Widget child) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.sizeOf(context).height * 0.12),
        child,
      ],
    );
  }

  List<Widget> _buildActionButtons(User user, BuildContext context) {
    List<Widget> buttons = [];

    if (user.role == UserRole.trainer) {
      if (!user.isApproved) {
        if (user.credentialImageUrl.isNotEmpty) {
          buttons.add(
            GymIconButton(
              icon: Icons.badge_outlined,
              tooltip: 'View Credential',
              onTap: () => _viewCredential(context, user),
            ),
          );
        }
        buttons.add(
          Expanded(
            child: GymSmallButton(
              label: 'Reject',
              icon: Icons.close,
              onTap: () => _showRejectionDialog(context, user.id),
            ),
          ),
        );
        buttons.add(
          Expanded(
            child: GymSmallButton(
              label: 'Approve',
              icon: Icons.check,
              primary: true,
              onTap: () => _approveTrainer(user.id, true, context),
            ),
          ),
        );
      } else {
        buttons.add(
          GymIconButton(
            icon: Icons.edit_outlined,
            tooltip: 'Edit User',
            onTap: () => _editUser(context, user),
          ),
        );
        buttons.add(
          GymIconButton(
            icon: Icons.delete_outline,
            tooltip: 'Delete User',
            danger: true,
            onTap: () => _deleteUser(context, user.id),
          ),
        );
      }
    } else if (user.role != UserRole.admin) {
      buttons.add(
        GymIconButton(
          icon: Icons.restart_alt,
          tooltip: 'Reset BMI / Calorie Cooldown',
          onTap: () => _showResetCooldownDialog(context, user),
        ),
      );
      buttons.add(
        GymIconButton(
          icon: Icons.edit_outlined,
          tooltip: 'Edit User',
          onTap: () => _editUser(context, user),
        ),
      );
      buttons.add(
        GymIconButton(
          icon: Icons.delete_outline,
          tooltip: 'Delete User',
          danger: true,
          onTap: () => _deleteUser(context, user.id),
        ),
      );
    }

    return buttons;
  }

  Future<void> _showResetCooldownDialog(BuildContext context, User user) async {
    final messenger = ScaffoldMessenger.of(context);
    final String? message = await showGymDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          ResetCooldownDialog(userId: user.id, username: user.username),
    );
    if (message != null && mounted) {
      messenger.showSnackBar(SnackBar(content: Text(message)));
    }
  }

  void _viewCredential(BuildContext context, User user) {
    Navigator.push(
      context,
      GymPageRoute(
        builder: (context) => CredentialViewerScreen(
          imageUrl: user.credentialImageUrl,
          fullName: user.fullName,
          username: user.username,
        ),
      ),
    );
  }

  void _approveTrainer(
    String userId,
    bool approve,
    BuildContext context, {
    String? rejectionReason,
  }) async {
    // The rejection dialog pops its own context right after calling this,
    // so grab the messenger up front instead of using `context` after await.
    final messenger = ScaffoldMessenger.of(context);
    try {
      // Called directly (not through AuthProvider) so a failure shows a
      // single error snackbar instead of two.
      await _apiService.approveTrainer(
        userId,
        approve,
        rejectionReason: rejectionReason,
      );
      if (!mounted) return;
      setState(() {
        _usersFuture = _fetchAndGroupUsers();
      });
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Trainer ${approve ? 'approved' : 'rejected'} successfully!',
          ),
        ),
      );
    } catch (e) {
      if (mounted) showErrorSnackBar(this.context, e.toString());
    }
  }

  Future<void> _showRejectionDialog(BuildContext context, String userId) async {
    final reason = await _askRejectionReason(context);
    if (reason == null || !mounted) return;
    _approveTrainer(userId, false, this.context, rejectionReason: reason);
  }

  /// Asks for a trainer rejection reason. Returns null if cancelled.
  /// [count] > 1 words the dialog for a bulk rejection.
  Future<String?> _askRejectionReason(BuildContext context, {int count = 1}) {
    final rejectionReasonController = TextEditingController();
    String selectedReason = 'Invalid credentials provided.';
    final predefinedReasons = [
      'Invalid credentials provided.',
      'Credentials are not clear or unreadable.',
      'Does not meet minimum qualifications.',
      'Custom',
    ];

    return showGymDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final reason = selectedReason == 'Custom'
                ? rejectionReasonController.text.trim()
                : selectedReason;
            return GymFormDialog(
              eyebrow: count > 1
                  ? 'Admin / $count trainers'
                  : 'Admin / Trainer',
              title: count > 1 ? 'Reject $count Trainers' : 'Reject Trainer',
              confirmLabel: count > 1 ? 'Reject all' : 'Reject',
              onConfirm: reason.isEmpty
                  ? null
                  : () => Navigator.of(dialogContext).pop(reason),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    count > 1
                        ? 'Their accounts will be removed and each trainer '
                              'gets an email with this reason.\n\n'
                              'Select a reason for rejection:'
                        : 'Select a reason for rejection:',
                    style: AuthType.body(),
                  ),
                  const SizedBox(height: 12),
                  GymRadioList<String>(
                    options: predefinedReasons,
                    selected: selectedReason,
                    onChanged: (value) {
                      setDialogState(() {
                        selectedReason = value;
                      });
                    },
                  ),
                  if (selectedReason == 'Custom')
                    TextField(
                      controller: rejectionReasonController,
                      style: AuthType.input(),
                      decoration: const InputDecoration(
                        hintText: 'Enter custom reason',
                      ),
                      autofocus: true,
                      onChanged: (_) => setDialogState(() {}),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _editUser(BuildContext context, User user) {
    Navigator.push(
      context,
      GymPageRoute(builder: (context) => EditUserScreen(user: user)),
    ).then((_) {
      if (!mounted) return;
      setState(() {
        _usersFuture = _fetchAndGroupUsers();
      });
    });
  }

  Future<void> _deleteUser(BuildContext context, String userId) async {
    final bool? confirmed = await showAuthDialog<bool>(
      context: context,
      eyebrow: 'Admin / Users',
      title: 'Delete User',
      message: 'Are you sure you want to delete this user?',
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
    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(this.context);
    try {
      await _apiService.deleteUser(userId);
      if (!mounted) return;
      setState(() {
        _usersFuture = _fetchAndGroupUsers();
      });
      messenger.showSnackBar(
        const SnackBar(content: Text('User deleted successfully!')),
      );
    } catch (e) {
      if (mounted) showErrorSnackBar(this.context, e.toString());
    }
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({
    required this.user,
    required this.actions,
    this.selecting = false,
    this.selected = false,
    this.onToggle,
    this.onLongPress,
  });

  final User user;
  final List<Widget> actions;

  /// Shows a check box and makes the whole card toggle selection.
  final bool selecting;
  final bool selected;
  final VoidCallback? onToggle;

  /// Long press enters selection mode with this card picked.
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    // Unverified accounts are tagged as such even when they are trainers
    // awaiting approval; they are listed in the Unverified section.
    final unverified = !user.isEmailVerified;
    final pending =
        user.role == UserRole.trainer && !user.isApproved && !unverified;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onLongPress: selecting ? null : onLongPress,
      child: PressableSurface(
        highlighted: selecting ? selected : pending,
        padding: const EdgeInsets.all(14),
        onTap: selecting ? onToggle : null,
        semanticLabel: selecting
            ? '${selected ? 'Deselect' : 'Select'} ${user.username}'
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (selecting) ...[
                  GymCheckbox(
                    value: selected,
                    semanticLabel: 'Select ${user.username}',
                    onChanged: (_) => onToggle?.call(),
                  ),
                  const SizedBox(width: 4),
                ],
                GymAvatar(text: user.username, size: 44),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.username.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AuthType.display(22).copyWith(height: 1),
                      ),
                      // Legal name for trainers, shown so the admin can
                      // match it to the credential photo.
                      if (user.role == UserRole.trainer) ...[
                        const SizedBox(height: 4),
                        Text(
                          user.fullName.isNotEmpty
                              ? user.fullName
                              : 'Full name not provided',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AuthType.body(
                            size: 14,
                            color: user.fullName.isNotEmpty
                                ? AuthColors.textPrimary
                                : AuthColors.textFaint,
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        user.email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AuthType.body(size: 13),
                      ),
                    ],
                  ),
                ),
                if (unverified) ...[
                  const SizedBox(width: 8),
                  const GymTag(label: 'Unverified'),
                ] else if (pending) ...[
                  const SizedBox(width: 8),
                  const GymTag(label: 'Pending', color: GymColors.warn),
                ],
              ],
            ),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  for (var i = 0; i < actions.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    actions[i],
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
