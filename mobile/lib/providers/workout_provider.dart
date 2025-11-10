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
      _workouts = await _apiService.getWorkouts();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createWorkout(String name, String description, List<String> exercises) async {
    try {
      final newWorkout = await _apiService.createWorkout(name, description, exercises);
      _workouts.add(newWorkout);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateWorkout(String id, String name, String description, List<String> exercises) async {
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

  Future<bool> deleteWorkout(String id) async {
    try {
      await _apiService.deleteWorkout(id);
      _workouts.removeWhere((w) => w.id == id);
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
