import 'package:flutter/material.dart';
import '../services/api_service.dart';

/// Shown to members on the Progress screen while BMI and/or calories are on
/// cooldown. Lets them ask an admin to reset the cooldown (e.g. misclick)
/// and shows the status of their latest request.
class CooldownResetRequestCard extends StatefulWidget {
  final bool bmiLocked;
  final bool caloriesLocked;

  /// Called after an admin-approved reset is detected so the parent can
  /// re-check update status.
  final VoidCallback? onStatusChanged;

  const CooldownResetRequestCard({
    super.key,
    required this.bmiLocked,
    required this.caloriesLocked,
    this.onStatusChanged,
  });

  @override
  State<CooldownResetRequestCard> createState() =>
      CooldownResetRequestCardState();
}

class CooldownResetRequestCardState extends State<CooldownResetRequestCard> {
  final ApiService _apiService = ApiService();
  Map<String, dynamic>? _request;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    reload();
  }

  /// Re-fetch the member's latest request.
  Future<void> reload() async {
    try {
      final request = await _apiService.getMyCooldownResetRequest();
      if (!mounted) return;
      final bool justApproved =
          _request?['status'] == 'pending' && request?['status'] == 'approved';
      if (justApproved) widget.onStatusChanged?.call();
      setState(() {
        _request = request;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  bool get _isPending => _request?['status'] == 'pending';

  /// Show the last decision only if it happened within the last 3 days.
  bool get _showRecentDecision {
    if (_request == null || _isPending) return false;
    final handled = DateTime.tryParse(_request?['handledAt']?.toString() ?? '');
    if (handled == null) return false;
    return DateTime.now().difference(handled).inDays < 3;
  }

  Future<void> _openRequestDialog() async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => const _RequestResetDialog(),
    );
    if (result == null || !mounted) return;

    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final response = await _apiService.requestCooldownReset(
        reason: result['reason']!,
      );
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            response['message']?.toString() ??
                'Your reset request was sent to the admin.',
          ),
          backgroundColor: Colors.green,
        ),
      );
      await reload();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancelRequest() async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _apiService.cancelMyCooldownResetRequest();
      messenger.showSnackBar(
        const SnackBar(content: Text('Reset request cancelled.')),
      );
      await reload();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool anyLocked = widget.bmiLocked || widget.caloriesLocked;

    // Nothing to show: no cooldown and no pending/recent request
    if (_loading || (!anyLocked && !_isPending && !_showRecentDecision)) {
      return const SizedBox.shrink();
    }

    Widget content;
    if (_isPending) {
      content = Row(
        children: [
          const Icon(Icons.hourglass_top, color: Colors.amber),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Reset request pending (BMI & Calories)',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const Text(
                  'An admin will review your request soon.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _busy ? null : _cancelRequest,
            child: const Text('Cancel'),
          ),
        ],
      );
    } else {
      final status = _request?['status'];
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_showRecentDecision)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    status == 'approved' ? Icons.check_circle : Icons.cancel,
                    color: status == 'approved' ? Colors.green : Colors.red,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      status == 'approved'
                          ? 'Your last reset request was approved.'
                          : 'Your last reset request was declined'
                                '${_request?['adminNote'] != null ? ': ${_request?['adminNote']}' : '.'}',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          if (anyLocked) ...[
            const Text(
              'Misclicked or entered the wrong value?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'Ask an admin to reset your BMI and calories. Your latest '
              'BMI and calorie entries will be removed and you can enter '
              'them again right away.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _busy ? null : _openRequestDialog,
              icon: _busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.support_agent),
              label: const Text('Request Reset'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.orange,
                side: const BorderSide(color: Colors.orange),
              ),
            ),
          ],
        ],
      );
    }

    return Card(
      elevation: 2,
      child: Padding(padding: const EdgeInsets.all(16), child: content),
    );
  }
}

/// Dialog where the member explains why they need a reset.
/// A reset always covers both BMI and calories.
/// Pops with {'reason': ...} or null.
class _RequestResetDialog extends StatefulWidget {
  const _RequestResetDialog();

  @override
  State<_RequestResetDialog> createState() => _RequestResetDialogState();
}

class _RequestResetDialogState extends State<_RequestResetDialog> {
  static const String _custom = 'Other';
  static const List<String> _presets = [
    'I misclicked the update button.',
    'I entered the wrong value by mistake.',
    _custom,
  ];

  String _reasonChoice = _presets.first;
  final TextEditingController _customController = TextEditingController();

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  String get _reason =>
      _reasonChoice == _custom ? _customController.text.trim() : _reasonChoice;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Request Cooldown Reset'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your BMI and calorie cooldowns will both be reset. Your '
              'latest BMI and calorie entries will be removed from your '
              'history so you can enter the correct values.',
              style: TextStyle(fontSize: 13, color: Colors.orange[800]),
            ),
            const SizedBox(height: 12),
            const Text('What happened?'),
            DropdownButton<String>(
              value: _reasonChoice,
              isExpanded: true,
              items: _presets
                  .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                  .toList(),
              onChanged: (v) => setState(() => _reasonChoice = v!),
            ),
            if (_reasonChoice == _custom)
              TextField(
                controller: _customController,
                maxLength: 500,
                maxLines: 2,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Describe what happened (min 5 characters)',
                ),
                onChanged: (_) => setState(() {}),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _reason.length >= 5
              ? () => Navigator.of(context).pop({'reason': _reason})
              : null,
          child: const Text('Send Request'),
        ),
      ],
    );
  }
}
