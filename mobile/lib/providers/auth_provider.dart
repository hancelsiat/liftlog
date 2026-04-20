import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/api_service.dart';

class AuthProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  User? _user;
  bool _isLoading = false;
  String? _error;

  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _user != null;

  Future<bool> register(
    String email,
    String password,
    String username,
    {UserRole role = UserRole.member}
  ) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.register(
        email,
        password,
        username,
        role: role
      );

      // Check if user data is returned in the registration response
      if (response.containsKey('user') && response['user'] != null) {
        _user = User.fromJson(response['user']);
      }

      // Only load profile for members (auto-approved)
      // Trainers need admin approval, so don't auto-login
      if (role == UserRole.member) {
        await loadProfile();
      } else {
        // For trainers, clear any stored token since they can't login yet
        await _apiService.removeToken();
        _user = null;
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.login(email, password);

      // Always load profile after successful login to get complete user data
      await loadProfile();

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> loadProfile() async {
    try {
      _user = await _apiService.getProfile();
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      // If token is invalid, clear user and token
      if (e.toString().contains('Authentication required')) {
        _user = null;
        await _apiService.removeToken();
      }
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _apiService.removeToken();
    _user = null;
    notifyListeners();
  }

  Future<bool> resendVerificationEmail(String email) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _apiService.resendVerificationEmail(email);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}