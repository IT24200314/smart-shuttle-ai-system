import 'package:flutter/foundation.dart';

class ApiConfig {
  // If running on Flutter Web (localhost:5000), use 127.0.0.1.
  // If running on Android Emulator, use the loopback bridge 10.0.2.2
  static const String baseUrl = kIsWeb ? 'http://localhost:8000' : 'http://10.0.2.2:8000';
}
