import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;

class ApiConfig {
  // If running on Flutter Web (localhost:8000), use 127.0.0.1.
  // If running on Android Emulator, use the loopback bridge 10.0.2.2.
  // If running on Windows desktop, use localhost.
  static String get baseUrl {
    if (kIsWeb) return 'http://localhost:8000';
    try {
      if (Platform.isAndroid) return 'http://10.0.2.2:8000';
    } catch (_) {}
    return 'http://localhost:8000';
  }
}
