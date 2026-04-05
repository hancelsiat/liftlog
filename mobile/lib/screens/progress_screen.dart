import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:async';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../models/progress.dart';

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

  @override
  void initState() {
    super.initState();
    _checkUpdateStatus();
    _fetchProgressHistory();
    // Update timer every minute to refresh countdown
    _updateTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _checkUpdateStatus();
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
          _caloriesNextAllowedDate = DateTime.parse(caloriesStatus!['nextAllowedDate']);
        }
      });
    } catch (e) {
      print('Error checking update status: $e');
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
      setState(() {
        _progressHistory = history;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (e.toString().contains('Authentication required')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Session expired. Please log in again.')),
        );
        Navigator.of(context).pushReplacementNamed('/login');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load progress history: $e')),
        );
      }
    }
  }

  void _saveBmi() async {
    if (!_canUpdateBmi) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_bmiUpdateMessage),
          backgroundColor: Colors.orange,
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
        _fetchProgressHistory();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('BMI updated successfully! Next update available in 7 days.'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update BMI: $e'),
            backgroundColor: Colors.red,
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
          backgroundColor: Colors.orange,
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
        _fetchProgressHistory();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Calories updated successfully! Next update available in 24 hours.'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update calories: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Progress'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // BMI Section
              _buildBmiSection(),
              const SizedBox(height: 24),
              
              // Calories Section
              _buildCaloriesSection(),
              const SizedBox(height: 30),

              // Progress Charts
              const Text(
                'Progress Charts',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              if (_progressHistory.isNotEmpty) ...[
                // BMI Chart
                _buildChartCard(
                  title: 'BMI Over Time',
                  chart: _buildLineChart(
                    data: _progressHistory.where((p) => p.bmi != null).map((p) => p.bmi!).toList(),
                    color: Colors.blue,
                  ),
                ),

                // Calories Intake Chart
                _buildChartCard(
                  title: 'Calories Intake Over Time',
                  chart: _buildLineChart(
                    data: _progressHistory.where((p) => p.caloriesIntake != null).map((p) => p.caloriesIntake!).toList(),
                    color: Colors.green,
                  ),
                ),

                // Calorie Deficit Chart
                _buildChartCard(
                  title: 'Calorie Deficit Over Time',
                  chart: _buildLineChart(
                    data: _progressHistory.where((p) => p.calorieDeficit != null).map((p) => p.calorieDeficit!).toList(),
                    color: Colors.red,
                  ),
                ),
              ],

              // Progress History
              const SizedBox(height: 30),
              const Text(
                'Progress History',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _progressHistory.isEmpty
                      ? const Center(child: Text('No progress records yet'))
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _progressHistory.length,
                          itemBuilder: (context, index) {
                            final progress = _progressHistory[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                title: Text('BMI: ${progress.bmi?.toStringAsFixed(1) ?? 'N/A'}'),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Calories Intake: ${progress.caloriesIntake?.toInt() ?? 'N/A'}'),
                                    Text('Calorie Deficit: ${progress.calorieDeficit?.toInt() ?? 'N/A'}'),
                                  ],
                                ),
                                trailing: Text(
                                  '${progress.date.day}/${progress.date.month}/${progress.date.year}',
                                ),
                              ),
                            );
                          },
                        ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBmiSection() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.monitor_weight, size: 32, color: Colors.blue),
                const SizedBox(width: 12),
                const Text(
                  'BMI Tracking',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Update once per week',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            const SizedBox(height: 16),

            // Status Banner
            if (!_canUpdateBmi)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange, width: 2),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.schedule, color: Colors.orange),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Update Locked',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text('Next update in $_daysUntilNextBmiUpdate day(s)'),
                          if (_bmiNextAllowedDate != null)
                            Text(
                              'Available: ${_bmiNextAllowedDate!.day}/${_bmiNextAllowedDate!.month}/${_bmiNextAllowedDate!.year}',
                              style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green, width: 2),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green),
                    SizedBox(width: 12),
                    Text(
                      'Ready to Update',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),

            // BMI Input Form
            Form(
              key: _bmiFormKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _bmiController,
                    enabled: _canUpdateBmi,
                    decoration: InputDecoration(
                      labelText: 'BMI',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.monitor_weight),
                      filled: !_canUpdateBmi,
                      fillColor: !_canUpdateBmi ? Colors.grey[200] : null,
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your BMI';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _canUpdateBmi ? _saveBmi : null,
                    icon: const Icon(Icons.save),
                    label: const Text('Update BMI'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      textStyle: const TextStyle(fontSize: 16),
                      backgroundColor: Colors.blue,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCaloriesSection() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.restaurant, size: 32, color: Colors.green),
                const SizedBox(width: 12),
                const Text(
                  'Calories Tracking',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Update every 24 hours',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            const SizedBox(height: 16),

            // Status Banner
            if (!_canUpdateCalories)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange, width: 2),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.schedule, color: Colors.orange),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Update Locked',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text('Next update in $_hoursUntilNextCaloriesUpdate hour(s)'),
                          if (_caloriesNextAllowedDate != null)
                            Text(
                              'Available: ${_caloriesNextAllowedDate!.day}/${_caloriesNextAllowedDate!.month} ${_caloriesNextAllowedDate!.hour}:${_caloriesNextAllowedDate!.minute.toString().padLeft(2, '0')}',
                              style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green, width: 2),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green),
                    SizedBox(width: 12),
                    Text(
                      'Ready to Update',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),

            // Calories Input Form
            Form(
              key: _caloriesFormKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _caloriesIntakeController,
                    enabled: _canUpdateCalories,
                    decoration: InputDecoration(
                      labelText: 'Calories Intake',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.restaurant),
                      filled: !_canUpdateCalories,
                      fillColor: !_canUpdateCalories ? Colors.grey[200] : null,
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your daily calories intake';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _calorieDeficitController,
                    enabled: _canUpdateCalories,
                    decoration: InputDecoration(
                      labelText: 'Calorie Deficit',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.trending_down),
                      filled: !_canUpdateCalories,
                      fillColor: !_canUpdateCalories ? Colors.grey[200] : null,
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your calorie deficit';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _canUpdateCalories ? _saveCalories : null,
                    icon: const Icon(Icons.save),
                    label: const Text('Update Calories'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      textStyle: const TextStyle(fontSize: 16),
                      backgroundColor: Colors.green,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartCard({required String title, required Widget chart}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: chart,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLineChart({required List<double> data, required Color color}) {
    if (data.isEmpty) {
      return const Center(child: Text('No data available'));
    }

    // Reverse data to show chronological order (oldest to newest)
    final reversedData = data.reversed.toList();

    return LineChart(
      LineChartData(
        gridData: FlGridData(show: true),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < reversedData.length) {
                  // Show date labels for first, middle, and last points
                  if (index == 0 ||
                      index == (reversedData.length - 1) ~/ 2 ||
                      index == reversedData.length - 1) {
                    final progress = _progressHistory[_progressHistory.length - 1 - index];
                    return Text(
                      '${progress.date.day}/${progress.date.month}',
                      style: const TextStyle(fontSize: 10),
                    );
                  }
                }
                return const Text('');
              },
            ),
          ),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: true),
        lineBarsData: [
          LineChartBarData(
            spots: List.generate(
              reversedData.length,
              (index) => FlSpot(index.toDouble(), reversedData[index]),
            ),
            isCurved: true,
            color: color,
            barWidth: 3,
            belowBarData: BarAreaData(
              show: true,
              color: color.withOpacity(0.1),
            ),
            dotData: FlDotData(show: true),
          ),
        ],
      ),
    );
  }
}
