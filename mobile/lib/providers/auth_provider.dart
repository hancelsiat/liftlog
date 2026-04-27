
import 'dart:io';
import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../utils/error_handler.dart';

class AuthProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  User? _user;
  bool _isLoading = false;
  String? _error;

  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _user != null;

  Future<bool> register(BuildContext context, String email, String password, String username, {UserRole role = UserRole.member, File? credentialFile}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.register(
        email,
        password,
        username,
        role: role,
        credentialFile: credentialFile,
      );

      if (response.containsKey('user') && response['user'] != null) {
        _user = User.fromJson(response['user']);
      }

      if (role == UserRole.member) {
        await loadProfile(context);
      } else {
        await _apiService.removeToken();
        _user = null;
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      showErrorSnackBar(context, _error!);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> login(BuildContext context, String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _apiService.login(email, password);
      await loadProfile(context);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      showErrorSnackBar(context, _error!);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> loadProfile(BuildContext context) async {
    try {
      _user = await _apiService.getProfile();
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      if (e.toString().contains('Authentication required')) {
        _user = null;
        await _apiService.removeToken();
      }
      showErrorSnackBar(context, _error!);
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _apiService.removeToken();
    _user = null;
    notifyListeners();
  }

  Future<bool> resendVerificationEmail(BuildContext context, String email) async {
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
      showErrorSnackBar(context, _error!);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
  
  Future<User> approveTrainer(BuildContext context, String userId, bool isApproved, {String? rejectionReason}) async {
    try {
      final user = await _apiService.approveTrainer(userId, isApproved, rejectionReason: rejectionReason);
      notifyListeners();
      return user;
    } catch (e) {
      showErrorSnackBar(context, e.toString());
      rethrow;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
