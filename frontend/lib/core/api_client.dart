import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'constants.dart';

class ApiClient {
  String? _token;

  ApiClient._privateConstructor();
  static final ApiClient instance = ApiClient._privateConstructor();

  Future<String?> getToken() async {
    if (_token != null) return _token;
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(ApiConstants.tokenKey);
    return _token;
  }

  Future<void> setToken(String? token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    if (token == null) {
      await prefs.remove(ApiConstants.tokenKey);
    } else {
      await prefs.setString(ApiConstants.tokenKey, token);
    }
  }

  Map<String, String> _getHeaders(String? token, {bool isJson = true}) {
    final headers = <String, String>{};
    if (isJson) {
      headers['Content-Type'] = 'application/json';
    }
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<http.Response> get(String path) async {
    final token = await getToken();
    final uri = Uri.parse('${ApiConstants.baseUrl}$path');
    final response = await http.get(uri, headers: _getHeaders(token));
    return _handleResponse(response);
  }

  Future<http.Response> post(String path, Map<String, dynamic> body) async {
    final token = await getToken();
    final uri = Uri.parse('${ApiConstants.baseUrl}$path');
    final response = await http.post(
      uri,
      headers: _getHeaders(token),
      body: jsonEncode(body),
    );
    return _handleResponse(response);
  }

  Future<http.Response> put(String path, Map<String, dynamic> body) async {
    final token = await getToken();
    final uri = Uri.parse('${ApiConstants.baseUrl}$path');
    final response = await http.put(
      uri,
      headers: _getHeaders(token),
      body: jsonEncode(body),
    );
    return _handleResponse(response);
  }

  Future<http.Response> delete(String path) async {
    final token = await getToken();
    final uri = Uri.parse('${ApiConstants.baseUrl}$path');
    final response = await http.delete(uri, headers: _getHeaders(token));
    return _handleResponse(response);
  }

  // Multipart request for file uploads
  Future<http.Response> multipart(
    String method,
    String path,
    Map<String, String> fields, {
    String? fileKey,
    String? filePath,
    List<int>? fileBytes,
    String? fileName,
  }) async {
    final token = await getToken();
    final uri = Uri.parse('${ApiConstants.baseUrl}$path');
    final request = http.MultipartRequest(method, uri);

    // Add authentication headers
    request.headers.addAll(_getHeaders(token, isJson: false));

    // Add fields
    request.fields.addAll(fields);

    // Add file if provided
    if (fileKey != null) {
      if (filePath != null) {
        final extension = filePath.split('.').last.toLowerCase();
        MediaType? contentType;
        if (extension == 'jpg' || extension == 'jpeg') {
          contentType = MediaType('image', 'jpeg');
        } else if (extension == 'png') {
          contentType = MediaType('image', 'png');
        } else if (extension == 'gif') {
          contentType = MediaType('image', 'gif');
        } else if (extension == 'webp') {
          contentType = MediaType('image', 'webp');
        }
        request.files.add(await http.MultipartFile.fromPath(
          fileKey,
          filePath,
          contentType: contentType,
        ));
      } else if (fileBytes != null && fileName != null) {
        final extension = fileName.split('.').last.toLowerCase();
        MediaType? contentType;
        if (extension == 'jpg' || extension == 'jpeg') {
          contentType = MediaType('image', 'jpeg');
        } else if (extension == 'png') {
          contentType = MediaType('image', 'png');
        } else if (extension == 'gif') {
          contentType = MediaType('image', 'gif');
        } else if (extension == 'webp') {
          contentType = MediaType('image', 'webp');
        }
        request.files.add(http.MultipartFile.fromBytes(
          fileKey,
          fileBytes,
          filename: fileName,
          contentType: contentType,
        ));
      }
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    return _handleResponse(response);
  }

  // Multipart request for multiple file uploads under a single key
  Future<http.Response> multipartList(
    String method,
    String path,
    Map<String, String> fields,
    String fileKey,
    List<String> filePaths,
  ) async {
    final token = await getToken();
    final uri = Uri.parse('${ApiConstants.baseUrl}$path');
    final request = http.MultipartRequest(method, uri);

    // Add authentication headers
    request.headers.addAll(_getHeaders(token, isJson: false));

    // Add fields
    request.fields.addAll(fields);

    // Add files
    for (final filePath in filePaths) {
      if (filePath.isNotEmpty) {
        final extension = filePath.split('.').last.toLowerCase();
        MediaType? contentType;
        if (extension == 'jpg' || extension == 'jpeg') {
          contentType = MediaType('image', 'jpeg');
        } else if (extension == 'png') {
          contentType = MediaType('image', 'png');
        } else if (extension == 'gif') {
          contentType = MediaType('image', 'gif');
        } else if (extension == 'webp') {
          contentType = MediaType('image', 'webp');
        }
        request.files.add(await http.MultipartFile.fromPath(
          fileKey,
          filePath,
          contentType: contentType,
        ));
      }
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    return _handleResponse(response);
  }

  http.Response _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response;
    } else {
      String errorMessage = 'An error occurred';
      try {
        final body = jsonDecode(response.body);
        if (body is Map && body.containsKey('error')) {
          errorMessage = body['error'];
        }
      } catch (_) {}
      throw ApiException(errorMessage, response.statusCode);
    }
  }
}

class ApiException implements Exception {
  final String message;
  final int statusCode;

  ApiException(this.message, this.statusCode);

  @override
  String toString() => 'ApiException: $message (Status $statusCode)';
}
