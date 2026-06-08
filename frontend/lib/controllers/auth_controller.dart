import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api_client.dart';
import '../core/constants.dart';
import '../models/user.dart';

class AuthController extends ChangeNotifier {
  User? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _currentUser != null;

  final ApiClient _apiClient = ApiClient.instance;

  AuthController() {
    checkExistingSession();
  }

  Future<void> checkExistingSession() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(ApiConstants.tokenKey);
      final userJson = prefs.getString(ApiConstants.userKey);

      if (token != null && userJson != null) {
        // Hydrate locally saved user
        _currentUser = User.fromJson(jsonDecode(userJson));
        
        // Asynchronously check with backend to verify token is still valid
        _verifySession();
      }
    } catch (e) {
      debugPrint('Error checking session: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _verifySession() async {
    try {
      final response = await _apiClient.get('/auth/me');
      final userData = jsonDecode(response.body);
      _currentUser = User.fromJson(userData);
      
      // Update saved user just in case
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(ApiConstants.userKey, jsonEncode(_currentUser!.toJson()));
      notifyListeners();
    } catch (e) {
      debugPrint('Session verification failed, logging out: $e');
      logout();
    }
  }

  Future<bool> login(String username, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiClient.post('/auth/login', {
        'username': username,
        'password': password,
      });

      final data = jsonDecode(response.body);
      final token = data['token'] as String;
      final userData = data['user'] as Map<String, dynamic>;

      _currentUser = User.fromJson(userData);

      // Save token in client and SharedPreferences
      await _apiClient.setToken(token);
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(ApiConstants.userKey, jsonEncode(_currentUser!.toJson()));

      _isLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Connection error. Please try again.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    try {
      await _apiClient.post('/auth/logout', {});
    } catch (e) {
      debugPrint('Failed to log out from backend: $e');
    } finally {
      _currentUser = null;
      _errorMessage = null;
      await _apiClient.setToken(null);
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(ApiConstants.userKey);
      notifyListeners();
    }
  }
}
