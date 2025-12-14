import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../models/progress.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  final _formKey = GlobalKey<FormState>();
  final _bmiController = TextEditingController();
  final _caloriesIntakeController = TextEditingController();
  final _calorieDeficitController = TextEditingController();

  List<Progress> _progressHistory = [];
  bool _isLoading = false;
  bool _canUpdate = true;
  int _daysUntilNextUpdate = 0;
  DateTime? _nextAllowedDate;
  String _updateMessage = '';

  @override
  void initState() {
    super.initState();
    _checkUpdateStatus();
    _fetchProgressHistory();
  }

  Future<void> _checkUpdateStatus() async {
    try {
      final apiService = ApiService();
      final status = await apiService.canUpdateProgress();
      
      setState(() {
        _canUpdate = status['canUpdate'] ?? true;
        _daysUntilNextUpdate = status['daysUntilNextUpdate'] ?? 0;
        _updateMessage = status['message'] ?? '';
        if (status['nextAllowedDate'] != null) {
          _nextAllowedDate = DateTime.parse(status['nextAllowedDate']);
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
        // Navigate back to login
        Navigator.of(context).pushReplacementNamed('/login');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load progress history: $e')),
        );
      }
    }
  }

  void _saveProgress() async {
    if (!_canUpdate) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_updateMessage),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    if (_formKey.currentState!.validate()) {
      try {
        final apiService = ApiService();
        final progress = await apiService.createProgress(
          bmi: double.parse(_bmiController.text),
          caloriesIntake: double.parse(_caloriesIntakeController.text),
          calorieDeficit: double.parse(_calorieDeficitController.text),
        );

        // Clear input fields
        _bmiController.clear();
        _caloriesIntakeController.clear();
        _calorieDeficitController.clear();

        // Refresh status and history
        await _checkUpdateStatus();
        _fetchProgressHistory();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Progress saved successfully! Next update available in 7 days.'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        final errorMessage = e.toString().contains('once per week')
            ? 'You can only update your progress once per week'
            : 'Failed to save progress: $e';
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
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
              // Weekly Update Warning Banner
              if (!_canUpdate)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange, width: 2),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.schedule, color: Colors.orange, size: 32),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Weekly Update Limit',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.orange,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Next update available in $_daysUntilNextUpdate day(s)',
                              style: const TextStyle(fontSize: 14),
                            ),
                            if (_nextAllowedDate != null)
                              Text(
                                'Available on: ${_nextAllowedDate!.day}/${_nextAllowedDate!.month}/${_nextAllowedDate!.year}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              // Success Banner when can update
              if (_canUpdate && _progressHistory.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green, width: 2),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green, size: 32),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Ready to Update',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.green,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'You can update your weekly progress now!',
                              style: TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              // Progress Input Form
              Opacity(
                opacity: _canUpdate ? 1.0 : 0.5,
                child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _bmiController,
                      decoration: const InputDecoration(labelText: 'BMI'),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your BMI';
                        }
                        return null;
                      },
                    ),
                    TextFormField(
                      controller: _caloriesIntakeController,
                      decoration: const InputDecoration(labelText: 'Calories Intake'),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your daily calories intake';
                        }
                        return null;
                      },
                    ),
                    TextFormField(
                      controller: _calorieDeficitController,
                      decoration: const InputDecoration(labelText: 'Calorie Deficit'),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your calorie deficit';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _canUpdate ? _saveProgress : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _canUpdate ? null : Colors.grey,
                      ),
                      child: Text(_canUpdate ? 'Save Progress' : 'Update Not Available'),
                    ),
                  ],
                ),
              ),
              ),

              // Progress Charts
              const SizedBox(height: 30),
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
                    data: _progressHistory.map((p) => p.bmi).toList(),
                    color: Colors.blue,
                  ),
                ),

                // Calories Intake Chart
                _buildChartCard(
                  title: 'Calories Intake Over Time',
                  chart: _buildLineChart(
                    data: _progressHistory.map((p) => p.caloriesIntake).toList(),
                    color: Colors.green,
                  ),
                ),

                // Calorie Deficit Chart
                _buildChartCard(
                  title: 'Calorie Deficit Over Time',
                  chart: _buildLineChart(
                    data: _progressHistory.map((p) => p.calorieDeficit).toList(),
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
                                title: Text('BMI: ${progress.bmi.toStringAsFixed(1)}'),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Calories Intake: ${progress.caloriesIntake.toInt()}'),
                                    Text('Calorie Deficit: ${progress.calorieDeficit.toInt()}'),
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

  @override
  void dispose() {
    _bmiController.dispose();
    _caloriesIntakeController.dispose();
    _calorieDeficitController.dispose();
    super.dispose();
  }
}
