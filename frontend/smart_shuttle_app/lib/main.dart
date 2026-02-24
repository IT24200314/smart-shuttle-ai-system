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
  await Firebase.initializeApp(); // JSON ෆයිල් එක දාපු නිසා දැන් මේක ඉබේම වැඩ කරනවා

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
