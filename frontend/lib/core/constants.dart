import 'dart:io';
import 'package:flutter/foundation.dart';

class ApiConstants {
  // CAMBIA ESTA IP por la IP local de tu PC si estás probando en un dispositivo físico (ej: '192.168.1.50')
  // Mantén '10.0.2.2' si estás usando el emulador oficial de Android Studio
  static String serverIp = '10.0.2.2';

  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:3000/api';
    }
    // Android requires serverIp to connect to the host
    if (Platform.isAndroid) {
      return 'http://$serverIp:3000/api';
    }
    // Windows, iOS, macOS, etc. can use localhost directly
    return 'http://localhost:3000/api';
  }

  static String get mediaUrl {
    if (kIsWeb) {
      return 'http://localhost:3000';
    }
    if (Platform.isAndroid) {
      return 'http://$serverIp:3000';
    }
    return 'http://localhost:3000';
  }

  static const String tokenKey = 'auth_token';
  static const String userKey = 'auth_user';
}
