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
  bool _emailNotVerified = false;
  bool _pendingApproval = false;

  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _user != null;
  bool get emailNotVerified => _emailNotVerified;
  bool get pendingApproval => _pendingApproval;

  Future<bool> register(
    BuildContext context,
    String email,
    String password,
    String username, {
    UserRole role = UserRole.member,
    File? credentialFile,
    String? fullName,
  }) async {
    _isLoading = true;
    _error = null;
    _emailNotVerified = false;
    _pendingApproval = false;
    notifyListeners();

    try {
      await _apiService.register(
        email,
        password,
        username,
        role: role,
        credentialFile: credentialFile,
        fullName: fullName,
      );

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      if (context.mounted) showErrorSnackBar(context, _error!);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> login(
    BuildContext context,
    String email,
    String password,
  ) async {
    _isLoading = true;
    _error = null;
    _emailNotVerified = false;
    _pendingApproval = false;
    notifyListeners();

    try {
      await _apiService.login(email, password);
      final profileLoaded = await _fetchProfile();
      if (!profileLoaded && context.mounted) {
        showErrorSnackBar(context, _error!);
      }
      _isLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (apiError) {
      // Catch structured errors from the server
      _error = apiError.message;
      _emailNotVerified = apiError.emailNotVerified;
      _pendingApproval = apiError.pendingApproval;

      // Only show generic snackbar if it's a normal error (not the special cases we handle in UI)
      if (!_emailNotVerified && !_pendingApproval && context.mounted) {
        showErrorSnackBar(context, _error!);
      }

      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = e.toString();
      if (context.mounted) showErrorSnackBar(context, _error!);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> loadProfile(BuildContext context) async {
    final loaded = await _fetchProfile();
    if (!loaded && context.mounted) {
      showErrorSnackBar(context, _error!);
    }
    return loaded;
  }

  /// Fetches the profile without touching any BuildContext, so callers
  /// can decide whether it is still safe to show UI feedback.
  Future<bool> _fetchProfile() async {
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
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _apiService.removeToken();
    _user = null;
    notifyListeners();
  }

  Future<bool> resendVerificationEmail(
    BuildContext context,
    String email,
  ) async {
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
      if (context.mounted) showErrorSnackBar(context, _error!);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<User?> approveTrainer(
    BuildContext context,
    String userId,
    bool isApproved, {
    String? rejectionReason,
  }) async {
    try {
      final user = await _apiService.approveTrainer(
        userId,
        isApproved,
        rejectionReason: rejectionReason,
      );
      notifyListeners();
      return user;
    } catch (e) {
      if (context.mounted) showErrorSnackBar(context, e.toString());
      rethrow;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
