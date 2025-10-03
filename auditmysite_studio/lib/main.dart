import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/embedded_engine_provider.dart';
import 'screens/audit_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize embedded engine
  await EmbeddedEngineService.initialize();
  
  runApp(const ProviderScope(child: StudioApp()));
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
      home: const AuditScreen(),  // Direct engine integration
      debugShowCheckedModeBanner: false,
    );
  }
}
