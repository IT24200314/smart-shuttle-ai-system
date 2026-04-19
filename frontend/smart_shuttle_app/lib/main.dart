import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'config/firebase_project_guard.dart';
import 'firebase_options.dart';
import 'providers/app_state_provider.dart';
import 'screens/auth/login_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline,
                  color: Color(0xFFEF4444), size: 50),
              const SizedBox(height: 16),
              const Text(
                'An error occurred during startup!',
                style: TextStyle(color: Color(0xFFF8FAFC), fontSize: 18),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: SingleChildScrollView(
                  child: Text(
                    details.exceptionAsString(),
                    style:
                        const TextStyle(color: Color(0xFFEF4444), fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  };

  String? startupFailure;
  try {
    final options = DefaultFirebaseOptions.currentPlatform;
    final platformLabel = kIsWeb ? 'web' : defaultTargetPlatform.name;
    final manifest = await FirebaseProjectGuard.validate(
      options: options,
      platformKey: platformLabel,
    );
    debugPrint(
      'Firebase manifest expects project ${manifest['project_id']} for $platformLabel',
    );
    debugPrint(
      'Initializing Firebase for $platformLabel with project ${options.projectId}',
    );
    await Firebase.initializeApp(
      options: options,
    );
    debugPrint(
      'Firebase initialized successfully for project ${Firebase.app().options.projectId}',
    );
  } catch (e, stackTrace) {
    startupFailure = e.toString();
    debugPrint('Firebase startup failed: $e');
    debugPrintStack(stackTrace: stackTrace);
  }

  if (startupFailure != null) {
    runApp(_FatalStartupApp(message: startupFailure));
    return;
  }

  // Load persisted theme before building the widget tree.
  final appState = AppStateProvider();
  await appState.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: appState),
      ],
      child: const SmartShuttleApp(),
    ),
  );
}

class SmartShuttleApp extends StatelessWidget {
  const SmartShuttleApp({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppStateProvider>();
    AppTheme.applyThemeMode(appState.themeMode);

    return MaterialApp(
      title: 'Smart Shuttle AI Transport System',
      debugShowCheckedModeBanner: false,
      themeMode: appState.themeMode,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      home: const LoginScreen(),
    );
  }
}

class _FatalStartupApp extends StatelessWidget {
  final String message;

  const _FatalStartupApp({required this.message});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFF111827),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: Color(0xFFEF4444),
                        size: 44,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Firebase startup validation failed',
                        style: TextStyle(
                          color: Color(0xFFF8FAFC),
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'The app stopped before opening because the Firebase config in this repo is inconsistent or incomplete.',
                        style: TextStyle(
                          color: Color(0xFFCBD5E1),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 14),
                      SelectableText(
                        message,
                        style: const TextStyle(
                          color: Color(0xFFFCA5A5),
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
