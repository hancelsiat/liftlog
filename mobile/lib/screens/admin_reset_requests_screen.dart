import 'package:flutter/material.dart';
import '../services/api_service.dart';

/// Admin: review members' requests to reset their BMI / calorie cooldown.
class AdminResetRequestsScreen extends StatefulWidget {
  const AdminResetRequestsScreen({super.key});

  @override
  State<AdminResetRequestsScreen> createState() =>
      _AdminResetRequestsScreenState();
}

class _AdminResetRequestsScreenState extends State<AdminResetRequestsScreen> {
  final ApiService _apiService = ApiService();
  static const List<String> _filters = ['pending', 'approved', 'rejected', 'all'];

  String _status = 'pending';
  List<Map<String, dynamic>> _requests = [];
  int _pendingCount = 0;
  bool _loading = true;
  String? _error;
  final Set<String> _busyIds = {};

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
      final data = await _apiService.getCooldownResetRequests(status: _status);
      if (!mounted) return;
      setState(() {
        _requests = (data['requests'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _pendingCount = (data['pendingCount'] as num?)?.toInt() ?? 0;
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
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  Future<void> _handle(Map<String, dynamic> request, bool approve) async {
    final user = request['user'] as Map?;
    final username = user?['username']?.toString() ?? 'this member';
    final noteController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final noteOk = approve || noteController.text.trim().length >= 5;
          return AlertDialog(
            title: Text(approve ? 'Approve Reset?' : 'Reject Request?'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  approve
                      ? 'This will reset the BMI & Calories cooldown for $username right away.'
                          '\n\nTheir latest BMI and calorie entries will also be deleted from their progress history, '
                          'and their update timers will start over.'
                      : 'Tell $username why the request is rejected.',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteController,
                  maxLength: 500,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: approve
                        ? 'Note (optional)'
                        : 'Reason (min 5 characters)',
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (_) => setDialogState(() {}),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: approve ? Colors.green : Colors.red,
                  foregroundColor: Colors.white,
                ),
                onPressed: noteOk ? () => Navigator.pop(ctx, true) : null,
                child: Text(approve ? 'Approve' : 'Reject'),
              ),
            ],
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
          backgroundColor: approve ? Colors.green : Colors.orange,
        ),
      );
      await _load();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _busyIds.remove(id));
    }
  }

  Widget _buildRequestCard(Map<String, dynamic> r) {
    final user = r['user'] as Map?;
    final handledBy = r['handledBy'] as Map?;
    final status = r['status']?.toString();
    final id = r['_id'].toString();
    final busy = _busyIds.contains(id);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(child: Icon(Icons.person)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?['username']?.toString() ?? 'Deleted user',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (user?['email'] != null)
                        Text(
                          user!['email'].toString(),
                          style: const TextStyle(fontSize: 12),
                        ),
                    ],
                  ),
                ),
                Chip(
                  label: Text(
                    (status ?? 'pending').toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                  backgroundColor: _statusColor(status),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Reset: ${_typeLabel(r['type'])}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text('Reason: ${r['reason'] ?? ''}'),
            const SizedBox(height: 4),
            Text(
              'Requested: ${_formatDate(r['createdAt'])}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            if (status != 'pending') ...[
              const SizedBox(height: 4),
              Text(
                'Handled${handledBy?['username'] != null ? ' by ${handledBy!['username']}' : ''}'
                ' on ${_formatDate(r['handledAt'])}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              if (r['adminNote'] != null)
                Text(
                  'Note: ${r['adminNote']}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
            ],
            if (status == 'pending') ...[
              const SizedBox(height: 10),
              if (busy)
                const Center(child: CircularProgressIndicator())
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _handle(r, false),
                      icon: const Icon(Icons.close, color: Colors.red),
                      label: const Text(
                        'Reject',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => _handle(r, true),
                      icon: const Icon(Icons.restart_alt),
                      label: const Text('Approve & Reset'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
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

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return ListView(
        children: [
          const SizedBox(height: 80),
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 12),
          Center(child: Text(_error!, textAlign: TextAlign.center)),
          const SizedBox(height: 12),
          Center(
            child: ElevatedButton(onPressed: _load, child: const Text('Retry')),
          ),
        ],
      );
    }
    if (_requests.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 80),
          const Icon(Icons.inbox, size: 56, color: Colors.grey),
          const SizedBox(height: 12),
          Center(
            child: Text(
              _status == 'pending'
                  ? 'No pending reset requests.'
                  : 'No $_status requests.',
            ),
          ),
        ],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: _requests.length,
      itemBuilder: (_, i) => _buildRequestCard(_requests[i]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _pendingCount > 0
              ? 'Reset Requests ($_pendingCount pending)'
              : 'Reset Requests',
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: _filters
                  .map(
                    (f) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(f[0].toUpperCase() + f.substring(1)),
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
      ),
    );
  }
}
