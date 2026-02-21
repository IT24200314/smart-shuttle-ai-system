// ============================================================
// Smart Shuttle AI System — Integrated System Prototype
// Entry Point
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme/app_theme.dart';
import 'screens/auth/login_screen.dart';
import 'providers/app_state_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase.initializeApp() — add after configuring google-services.json
  // await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

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
