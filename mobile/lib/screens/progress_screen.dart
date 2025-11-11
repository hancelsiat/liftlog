import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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

  @override
  void initState() {
    super.initState();
    _fetchProgressHistory();
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load progress history: $e')),
      );
    }
  }

  void _saveProgress() async {
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

        // Refresh progress history
        _fetchProgressHistory();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Progress saved successfully')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save progress: $e')),
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
              // Progress Input Form
              Form(
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
                      onPressed: _saveProgress,
                      child: const Text('Save Progress'),
                    ),
                  ],
                ),
              ),

              // Progress History
              const SizedBox(height: 30),
              const Text(
                'Progress History',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
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
                            return ListTile(
                              title: Text('BMI: ${progress.bmi}'),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Calories Intake: ${progress.caloriesIntake}'),
                                  Text('Calorie Deficit: ${progress.calorieDeficit}'),
                                ],
                              ),
                              trailing: Text(
                                '${progress.date.day}/${progress.date.month}/${progress.date.year}',
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

  @override
  void dispose() {
    _bmiController.dispose();
    _caloriesIntakeController.dispose();
    _calorieDeficitController.dispose();
    super.dispose();
  }
}