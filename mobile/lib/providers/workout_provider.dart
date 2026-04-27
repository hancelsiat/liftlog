import 'package:flutter/material.dart';
import '../models/workout.dart';
import '../services/api_service.dart';

class WorkoutProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  List<Workout> _workouts = [];
  bool _isLoading = false;
  String? _error;

  List<Workout> get workouts => _workouts;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadWorkouts() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _workouts = await _apiService.getTrainerWorkouts();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createWorkout(String name, String description, List<Map<String, dynamic>> exercises, String category, String intensity, String trainerId) async {
    try {
      final newWorkout = await _apiService.createWorkoutTemplate(
        title: name,
        description: description,
        exercises: exercises,
        category: category,
        intensity: intensity,
        trainerId: trainerId,
      );
      _workouts.add(newWorkout);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateWorkout(String id, String name, String description, List<Map<String, dynamic>> exercises) async {
    try {
      final updatedWorkout = await _apiService.updateWorkout(id, name, description, exercises);
      final index = _workouts.indexWhere((w) => w.id == id);
      if (index != -1) {
        _workouts[index] = updatedWorkout;
        notifyListeners();
      }
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteWorkouts(List<String> ids) async {
    try {
      await _apiService.deleteWorkouts(ids);
      _workouts.removeWhere((w) => ids.contains(w.id));
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
