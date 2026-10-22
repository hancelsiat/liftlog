import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import 'gym/gym.dart';

/// Admin dialog for resetting a client's BMI / calorie tracking cooldown
/// (e.g. when the client misclicked the update button).
///
/// Pops with the server's success message (String) when a reset happens,
/// or `null` if cancelled.
class ResetCooldownDialog extends StatefulWidget {
  final String userId;
  final String username;

  const ResetCooldownDialog({
    super.key,
    required this.userId,
    required this.username,
  });

  @override
  State<ResetCooldownDialog> createState() => _ResetCooldownDialogState();
}

class _ResetCooldownDialogState extends State<ResetCooldownDialog> {
  static const String _customReason = 'Custom';
  static const List<String> _presetReasons = [
    'Client misclicked the update button.',
    'Client entered incorrect values by mistake.',
    'Client requested a correction of submitted data.',
    _customReason,
  ];

  final ApiService _apiService = ApiService();
  final TextEditingController _customReasonController = TextEditingController();

  Map<String, dynamic>? _status;
  String? _loadError;
  String? _submitError;
  bool _loading = true;
  bool _submitting = false;
  String _selectedReason = _presetReasons.first;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  @override
  void dispose() {
    _customReasonController.dispose();
    super.dispose();
  }

  bool get _bmiActive => _status?['bmi']?['active'] == true;
  bool get _caloriesActive => _status?['calories']?['active'] == true;
  bool get _hasProgress => _status?['hasProgress'] == true;

  bool get _anyActive => _bmiActive || _caloriesActive;

  Future<void> _loadStatus() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final status = await _apiService.getUserCooldownStatus(widget.userId);
      if (!mounted) return;
      setState(() {
        _status = status;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.toString();
        _loading = false;
      });
    }
  }

  String get _reason => _selectedReason == _customReason
      ? _customReasonController.text.trim()
      : _selectedReason;

  bool get _canSubmit =>
      !_submitting && _hasProgress && _anyActive && _reason.length >= 5;

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() {
      _submitting = true;
      _submitError = null;
    });
    try {
      final result = await _apiService.resetUserCooldown(
        widget.userId,
        reason: _reason,
      );
      if (!mounted) return;
      Navigator.of(
        context,
      ).pop(result['message']?.toString() ?? 'Cooldown reset successfully.');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submitError = e.toString();
      });
    }
  }

  String _formatRemaining(dynamic remainingMs) {
    final ms = (remainingMs is num) ? remainingMs.toInt() : 0;
    final d = Duration(milliseconds: ms);
    if (d.inDays > 0) return '${d.inDays}d ${d.inHours % 24}h left';
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes % 60}m left';
    return '${d.inMinutes < 1 ? 1 : d.inMinutes}m left';
  }

  String _formatDate(dynamic value) {
    final date = value == null ? null : DateTime.tryParse(value.toString());
    if (date == null) return '-';
    return DateFormat('MMM d, yyyy h:mm a').format(date.toLocal());
  }

  Widget _buildStatusTile(String label, IconData icon, dynamic data) {
    final bool active = data?['active'] == true;
    final lines = <String>[
      active
          ? 'On cooldown - ${_formatRemaining(data?['remainingMs'])}'
          : 'No active cooldown',
      if (data?['lastUpdate'] != null)
        'Last update: ${_formatDate(data?['lastUpdate'])}',
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GymStatusStrip(
        color: active ? GymColors.warn : AuthColors.accent,
        icon: icon,
        title: label,
        lines: lines,
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const SizedBox(height: 120, child: GymLoader());
    }
    if (_loadError != null) {
      return GymEmptyState(
        icon: Icons.error_outline,
        danger: true,
        message: _loadError!,
        action: SizedBox(
          width: 160,
          child: PressableButton(
            label: 'Retry',
            height: 48,
            showArrow: false,
            variant: PressableVariant.ghost,
            onPressed: _loadStatus,
          ),
        ),
      );
    }
    if (!_hasProgress) {
      return Text(
        'This user has not logged any BMI or calorie data yet, '
        'so there is no cooldown to reset.',
        style: AuthType.body(),
      );
    }

    final recentResets = (_status?['recentResets'] as List?) ?? const [];
    final bool anyActive = _anyActive;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildStatusTile(
          'BMI (7-day cooldown)',
          Icons.monitor_weight_outlined,
          _status?['bmi'],
        ),
        _buildStatusTile(
          'Calories (24-hour cooldown)',
          Icons.local_fire_department_outlined,
          _status?['calories'],
        ),
        if (!anyActive)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'The client can already update BMI and calories. Nothing to reset.',
              style: AuthType.body(size: 14),
            ),
          )
        else ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              'Both BMI and calories will be reset. The client\'s latest BMI '
              'and calorie entries still on cooldown will be deleted from '
              'their history and their update timers will start over.',
              style: AuthType.body(size: 13, color: GymColors.warn),
            ),
          ),
          const SizedBox(height: AuthSpace.s),
          const GymSectionLabel(label: 'Reason'),
          const SizedBox(height: 12),
          GymRadioList<String>(
            options: _presetReasons,
            selected: _selectedReason,
            onChanged: _submitting
                ? null
                : (v) => setState(() => _selectedReason = v),
          ),
          if (_selectedReason == _customReason)
            TextField(
              controller: _customReasonController,
              maxLength: 500,
              maxLines: 2,
              enabled: !_submitting,
              autofocus: true,
              style: AuthType.input(),
              decoration: const InputDecoration(
                hintText: 'Describe the client request (min 5 characters)',
              ),
              onChanged: (_) => setState(() {}),
            ),
        ],
        if (recentResets.isNotEmpty) ...[
          const SizedBox(height: AuthSpace.s),
          const GymSectionLabel(label: 'Recent resets'),
          const SizedBox(height: 8),
          ...recentResets.map(
            (r) => Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '${_formatDate(r['resetAt'])} - ${r['type']} - '
                '${r['reason'] ?? ''}'
                '${r['admin'] != null ? ' (by ${r['admin']})' : ''}',
                style: AuthType.mono(),
              ),
            ),
          ),
        ],
        if (_submitError != null) ...[
          const SizedBox(height: AuthSpace.s),
          Semantics(
            liveRegion: true,
            child: Text(_submitError!, style: AuthType.error()),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return GymFormDialog(
      eyebrow: 'Admin / ${widget.username}',
      title: 'Reset Cooldown',
      confirmLabel: 'Reset',
      loading: _submitting,
      onConfirm: _canSubmit ? _submit : null,
      child: _buildContent(),
    );
  }
}
