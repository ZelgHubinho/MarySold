import 'dart:convert';
import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../models/audit_log.dart';

class AuditLogController extends ChangeNotifier {
  List<AuditLog> _logs = [];
  List<String> _users = ['Todos'];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _errorMessage;
  int _offset = 0;
  static const int _limit = 20;

  List<AuditLog> get logs => _logs;
  List<String> get users => _users;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  String? get errorMessage => _errorMessage;

  final ApiClient _apiClient = ApiClient.instance;

  Future<void> fetchUsers() async {
    try {
      final response = await _apiClient.get('/audit-logs/users');
      final List<dynamic> data = jsonDecode(response.body);
      _users = ['Todos', ...data.map((u) => u.toString())];
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching audit log users: $e');
    }
  }

  Future<void> fetchLogs({
    bool isRefresh = false,
    DateTimeRange? dateRange,
    String? userFilter,
    String? actionFilter,
    String? searchQuery,
  }) async {
    if (isRefresh) {
      _offset = 0;
      _logs = [];
      _hasMore = true;
      _isLoading = true;
    } else {
      if (!_hasMore || _isLoadingMore || _isLoading) return;
      _isLoadingMore = true;
    }

    _errorMessage = null;
    notifyListeners();

    try {
      final queryParams = <String, String>{
        'limit': _limit.toString(),
        'offset': _offset.toString(),
      };

      if (dateRange != null) {
        // Ensure ISO Date formatting for query matching PostgreSQL Timestamps
        final startOfDay = DateTime(dateRange.start.year, dateRange.start.month, dateRange.start.day);
        final endOfDay = DateTime(dateRange.end.year, dateRange.end.month, dateRange.end.day, 23, 59, 59, 999);
        queryParams['startDate'] = startOfDay.toUtc().toIso8601String();
        queryParams['endDate'] = endOfDay.toUtc().toIso8601String();
      }

      if (userFilter != null && userFilter != 'Todos') {
        queryParams['username'] = userFilter;
      }

      if (actionFilter != null && actionFilter != 'Todos') {
        queryParams['action'] = actionFilter;
      }

      if (searchQuery != null && searchQuery.isNotEmpty) {
        queryParams['search'] = searchQuery;
      }

      final uriPath = Uri(path: '/audit-logs', queryParameters: queryParams).toString();
      final response = await _apiClient.get(uriPath);
      final List<dynamic> data = jsonDecode(response.body);
      
      final List<AuditLog> newLogs = data.map((json) => AuditLog.fromJson(json)).toList();

      if (isRefresh) {
        _logs = newLogs;
      } else {
        _logs.addAll(newLogs);
      }

      _offset += newLogs.length;

      if (newLogs.length < _limit) {
        _hasMore = false;
      }
    } on ApiException catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = 'Error al cargar la bitácora de acciones.';
      debugPrint('Error fetching audit logs: $e');
    } finally {
      _isLoading = false;
      _isLoadingMore = false;
      notifyListeners();
    }
  }
}
