import 'package:flutter/material.dart';
import 'dart:async';
import '../services/api_service.dart';
import '../models/progress.dart';
import '../widgets/cooldown_reset_request_card.dart';
import '../widgets/gym/gym.dart';
import '../widgets/progress_charts.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  final _bmiFormKey = GlobalKey<FormState>();
  final _caloriesFormKey = GlobalKey<FormState>();
  final _bmiController = TextEditingController();
  final _caloriesIntakeController = TextEditingController();
  final _calorieDeficitController = TextEditingController();

  List<Progress> _progressHistory = [];
  bool _isLoading = false;

  // BMI status
  bool _canUpdateBmi = true;
  int _daysUntilNextBmiUpdate = 0;
  DateTime? _bmiNextAllowedDate;
  String _bmiUpdateMessage = '';

  // Calories status
  bool _canUpdateCalories = true;
  int _hoursUntilNextCaloriesUpdate = 0;
  DateTime? _caloriesNextAllowedDate;
  String _caloriesUpdateMessage = '';

  Timer? _updateTimer;

  final GlobalKey<CooldownResetRequestCardState> _resetRequestCardKey =
      GlobalKey<CooldownResetRequestCardState>();

  @override
  void initState() {
    super.initState();
    _checkUpdateStatus();
    _fetchProgressHistory();
    // Update timer every minute to refresh countdown
    _updateTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _checkUpdateStatus();
      _resetRequestCardKey.currentState?.reload();
    });
  }

  @override
  void dispose() {
    _bmiController.dispose();
    _caloriesIntakeController.dispose();
    _calorieDeficitController.dispose();
    _updateTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkUpdateStatus() async {
    try {
      final apiService = ApiService();
      final status = await apiService.canUpdateProgress();
      if (!mounted) return;

      setState(() {
        // BMI status
        final bmiStatus = status['bmi'] as Map<String, dynamic>?;
        _canUpdateBmi = bmiStatus?['canUpdate'] ?? true;
        _daysUntilNextBmiUpdate = bmiStatus?['daysUntilNext'] ?? 0;
        _bmiUpdateMessage = bmiStatus?['message'] ?? '';
        if (bmiStatus?['nextAllowedDate'] != null) {
          _bmiNextAllowedDate = DateTime.parse(bmiStatus!['nextAllowedDate']);
        }

        // Calories status
        final caloriesStatus = status['calories'] as Map<String, dynamic>?;
        _canUpdateCalories = caloriesStatus?['canUpdate'] ?? true;
        _hoursUntilNextCaloriesUpdate = caloriesStatus?['hoursUntilNext'] ?? 0;
        _caloriesUpdateMessage = caloriesStatus?['message'] ?? '';
        if (caloriesStatus?['nextAllowedDate'] != null) {
          _caloriesNextAllowedDate = DateTime.parse(
            caloriesStatus!['nextAllowedDate'],
          );
        }
      });
    } catch (e) {
      debugPrint('Error checking update status: $e');
    }
  }

  void _fetchProgressHistory() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final apiService = ApiService();
      final history = await apiService.getProgressHistory();
      // Sort by date descending (most recent first)
      history.sort((a, b) => b.date.compareTo(a.date));
      if (!mounted) return;
      setState(() {
        _progressHistory = history;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      if (e.toString().contains('Authentication required')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Session expired. Please log in again.'),
          ),
        );
        Navigator.of(context).pushReplacementNamed('/login');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'We could not load your progress history at this time.',
            ),
          ),
        );
      }
    }
  }

  void _saveBmi() async {
    if (!_canUpdateBmi) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_bmiUpdateMessage),
          backgroundColor: GymColors.warn,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    if (_bmiFormKey.currentState!.validate()) {
      try {
        final apiService = ApiService();
        await apiService.createProgressPartial(
          bmi: double.parse(_bmiController.text),
        );

        _bmiController.clear();
        await _checkUpdateStatus();
        if (!mounted) return;
        _fetchProgressHistory();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'BMI updated successfully! Next update available in 7 days.',
            ),
            backgroundColor: AuthColors.surfaceHi,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Failed to update BMI. Please check your connection and try again.',
            ),
            backgroundColor: AuthColors.danger,
          ),
        );
      }
    }
  }

  void _saveCalories() async {
    if (!_canUpdateCalories) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_caloriesUpdateMessage),
          backgroundColor: GymColors.warn,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    if (_caloriesFormKey.currentState!.validate()) {
      try {
        final apiService = ApiService();
        await apiService.createProgressPartial(
          caloriesIntake: double.parse(_caloriesIntakeController.text),
          calorieDeficit: double.parse(_calorieDeficitController.text),
        );

        _caloriesIntakeController.clear();
        _calorieDeficitController.clear();
        await _checkUpdateStatus();
        if (!mounted) return;
        _fetchProgressHistory();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Calories updated successfully! Next update available in 24 hours.',
            ),
            backgroundColor: AuthColors.surfaceHi,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Failed to update calories. Please check your connection and try again.',
            ),
            backgroundColor: AuthColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _refreshAll() async {
    await _checkUpdateStatus();
    await _resetRequestCardKey.currentState?.reload();
    if (!mounted) return;
    _fetchProgressHistory();
  }

  @override
  Widget build(BuildContext context) {
    return GymScaffold(
      eyebrow: 'Member / Body log',
      title: 'My Progress',
      body: GymRefresh(
        onRefresh: _refreshAll,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(
            GymScaffold.side,
            AuthSpace.xs,
            GymScaffold.side,
            AuthSpace.l,
          ),
          children: [
            // BMI Section
            EntranceRise(index: 0, child: _buildBmiSection()),
            const SizedBox(height: 12),

            // Calories Section
            EntranceRise(index: 1, child: _buildCaloriesSection()),
            const SizedBox(height: 12),

            // Ask admin to reset cooldown (misclick)
            EntranceRise(
              index: 2,
              child: CooldownResetRequestCard(
                key: _resetRequestCardKey,
                bmiLocked: !_canUpdateBmi,
                caloriesLocked: !_canUpdateCalories,
                onStatusChanged: () {
                  // An approved BMI reset also deletes the wrong entry
                  _checkUpdateStatus();
                  _fetchProgressHistory();
                },
              ),
            ),
            const SizedBox(height: AuthSpace.l),

            // Progress Charts
            const EntranceRise(
              index: 3,
              child: GymSectionLabel(index: 3, label: 'Progress Charts'),
            ),
            const SizedBox(height: AuthSpace.s),
            if (_progressHistory.isNotEmpty)
              ProgressCharts(history: _progressHistory)
            else
              const GymEmptyState(
                icon: Icons.show_chart,
                message: 'Your charts appear after the first entry',
              ),

            // Progress History
            const SizedBox(height: AuthSpace.l),
            const GymSectionLabel(index: 4, label: 'Progress History'),
            const SizedBox(height: AuthSpace.s),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AuthSpace.l),
                child: GymLoader(),
              )
            else if (_progressHistory.isEmpty)
              const GymEmptyState(
                icon: Icons.history,
                message: 'No progress records yet',
              )
            else
              ..._buildHistory(),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildHistory() {
    final rows = <Widget>[];
    for (final progress in _progressHistory) {
      // Each entry holds only what was entered at that
      // time (BMI, calories, or both).
      final hasBmi = progress.bmi != null;
      final calorieLines = <String>[
        if (progress.caloriesIntake != null)
          'Calories Intake: ${progress.caloriesIntake!.toInt()}',
        if (progress.calorieDeficit != null)
          'Calorie Deficit: ${progress.calorieDeficit!.toInt()}',
      ];
      if (!hasBmi && calorieLines.isEmpty) continue;

      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: StaggeredReveal(
            index: rows.length,
            child: PressableSurface(
              padding: const EdgeInsets.fromLTRB(AuthSpace.s, 14, 14, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hasBmi
                              ? 'BMI: ${progress.bmi!.toStringAsFixed(1)}'
                              : 'CALORIES',
                          style: AuthType.display(22).copyWith(height: 1),
                        ),
                        for (final line in calorieLines) ...[
                          const SizedBox(height: 4),
                          Text(line, style: AuthType.body(size: 13)),
                        ],
                      ],
                    ),
                  ),
                  Text(
                    '${progress.date.day}/${progress.date.month}/${progress.date.year}',
                    style: AuthType.mono(),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return rows;
  }

  /// Shared layout for the BMI and calories trackers.
  Widget _trackerCard({
    required int number,
    required IconData icon,
    required String title,
    required String cadence,
    required bool canUpdate,
    required List<String> lockedLines,
    required GlobalKey<FormState> formKey,
    required List<Widget> fields,
    required String buttonLabel,
    required VoidCallback onSave,
  }) {
    final reduced = AuthMotion.reduced(context);
    return PressableSurface(
      padding: const EdgeInsets.all(AuthSpace.s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              GymAvatar(icon: icon, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.toUpperCase(),
                      style: AuthType.display(26).copyWith(height: 1),
                    ),
                    const SizedBox(height: 4),
                    Text(cadence.toUpperCase(), style: AuthType.mono()),
                  ],
                ),
              ),
              Text(
                number.toString().padLeft(2, '0'),
                style: AuthType.mono(color: AuthColors.accent),
              ),
            ],
          ),
          const SizedBox(height: AuthSpace.s),

          // Status Banner
          AnimatedSwitcher(
            duration: reduced ? Duration.zero : AuthMotion.base,
            switchInCurve: AuthMotion.standard,
            switchOutCurve: AuthMotion.exit,
            child: canUpdate
                ? const GymStatusStrip(
                    key: ValueKey('ready'),
                    color: AuthColors.accent,
                    icon: Icons.check_circle_outline,
                    title: 'Ready to Update',
                  )
                : GymStatusStrip(
                    key: const ValueKey('locked'),
                    color: GymColors.warn,
                    icon: Icons.schedule,
                    title: 'Update Locked',
                    lines: lockedLines,
                  ),
          ),
          const SizedBox(height: AuthSpace.s),

          Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < fields.length; i++) ...[
                  if (i > 0) const SizedBox(height: 12),
                  fields[i],
                ],
                const SizedBox(height: AuthSpace.s),
                PressableButton(
                  label: buttonLabel,
                  height: 52,
                  showArrow: false,
                  onPressed: canUpdate ? onSave : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _numberField({
    required TextEditingController controller,
    required bool enabled,
    required String label,
    required IconData icon,
    required String emptyMessage,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      style: AuthType.input(
        color: enabled ? AuthColors.textPrimary : AuthColors.textFaint,
      ),
      cursorColor: AuthColors.accent,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
      ),
      keyboardType: TextInputType.number,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return emptyMessage;
        }
        return null;
      },
    );
  }

  Widget _buildBmiSection() {
    return _trackerCard(
      number: 1,
      icon: Icons.monitor_weight_outlined,
      title: 'BMI Tracking',
      cadence: 'Update once per week',
      canUpdate: _canUpdateBmi,
      lockedLines: [
        'Next update in $_daysUntilNextBmiUpdate day(s)',
        if (_bmiNextAllowedDate != null)
          'Available: ${_bmiNextAllowedDate!.day}/${_bmiNextAllowedDate!.month}/${_bmiNextAllowedDate!.year}',
      ],
      formKey: _bmiFormKey,
      fields: [
        _numberField(
          controller: _bmiController,
          enabled: _canUpdateBmi,
          label: 'BMI',
          icon: Icons.monitor_weight_outlined,
          emptyMessage: 'Please enter your BMI',
        ),
      ],
      buttonLabel: 'Update BMI',
      onSave: _saveBmi,
    );
  }

  Widget _buildCaloriesSection() {
    return _trackerCard(
      number: 2,
      icon: Icons.restaurant,
      title: 'Calories Tracking',
      cadence: 'Update every 24 hours',
      canUpdate: _canUpdateCalories,
      lockedLines: [
        'Next update in $_hoursUntilNextCaloriesUpdate hour(s)',
        if (_caloriesNextAllowedDate != null)
          'Available: ${_caloriesNextAllowedDate!.day}/${_caloriesNextAllowedDate!.month} ${_caloriesNextAllowedDate!.hour}:${_caloriesNextAllowedDate!.minute.toString().padLeft(2, '0')}',
      ],
      formKey: _caloriesFormKey,
      fields: [
        _numberField(
          controller: _caloriesIntakeController,
          enabled: _canUpdateCalories,
          label: 'Calories Intake',
          icon: Icons.restaurant,
          emptyMessage: 'Please enter your daily calories intake',
        ),
        _numberField(
          controller: _calorieDeficitController,
          enabled: _canUpdateCalories,
          label: 'Calorie Deficit',
          icon: Icons.trending_down,
          emptyMessage: 'Please enter your calorie deficit',
        ),
      ],
      buttonLabel: 'Update Calories',
      onSave: _saveCalories,
    );
  }
}
