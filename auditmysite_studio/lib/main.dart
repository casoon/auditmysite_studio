import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/splash_screen.dart';
import 'utils/debug_logger.dart';
import 'dart:async';

void main() {
  // Catch all async errors
  runZonedGuarded(
    () async {
      // Initialize Flutter
      WidgetsFlutterBinding.ensureInitialized();
      
      // Initialize debug logger
      await DebugLogger.initialize();
      DebugLogger.log('Application starting...');
      
      // Catch all Flutter errors
      FlutterError.onError = (FlutterErrorDetails details) {
        DebugLogger.error(
          'Flutter Error',
          details.exception,
          details.stack,
        );
      };
      
      runApp(const ProviderScope(child: StudioApp()));
    },
    (error, stack) {
      DebugLogger.error('Uncaught async error', error, stack);
    },
  );
}

class StudioApp extends StatelessWidget {
  const StudioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AuditMySite Studio',
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
        fontFamily: 'Inter',
      ),
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
