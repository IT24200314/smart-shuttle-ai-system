// ============================================================
// Smart Shuttle AI System — Integrated System Prototype
// Entry Point
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'theme/app_theme.dart';
import 'screens/auth/login_screen.dart';
import 'providers/app_state_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Custom Error Widget for the whole app
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 50),
              const SizedBox(height: 16),
              const Text('An error occurred during startup!', style: TextStyle(color: Colors.white, fontSize: 18)),
              const SizedBox(height: 8),
              Expanded(
                child: SingleChildScrollView(
                  child: Text(
                    details.exceptionAsString(),
                    style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  };

  try {
    // Try to auto-initialize. It will throw an error if google-services.json is missing on Android.
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase Initialization Warning: $e');
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppStateProvider()),
      ],
      child: const SmartShuttleApp(),
    ),
  );
}

class SmartShuttleApp extends StatelessWidget {
  const SmartShuttleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Shuttle — AI Transport System',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const LoginScreen(),
    );
  }
}
