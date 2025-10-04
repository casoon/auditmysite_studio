import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puppeteer/puppeteer.dart';
import 'audit_screen.dart';
import '../utils/debug_logger.dart';

/// Splash screen that ensures Chromium is ready before showing the main app
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  String _status = 'Initializing...';
  double? _progress;
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeChromium();
  }

  Future<void> _initializeChromium() async {
    try {
      setState(() {
        _status = 'Checking Chromium...';
        _progress = null;
      });

      DebugLogger.log('Starting Chromium initialization...');

      // Force Puppeteer to download Chromium if needed
      // This will happen on first run only
      await Future.delayed(const Duration(milliseconds: 500));
      
      setState(() {
        _status = 'Downloading Chromium (first run only)...';
        _progress = null; // Indeterminate progress
      });

      // Launch a browser instance to trigger download
      // Puppeteer will automatically download if needed
      final browser = await puppeteer.launch(
        headless: true,
        args: ['--no-sandbox', '--disable-setuid-sandbox'],
      );

      DebugLogger.log('Chromium browser launched successfully');

      setState(() {
        _status = 'Chromium ready!';
        _progress = 1.0;
      });

      // Close the test browser
      await browser.close();

      // Wait a moment to show success
      await Future.delayed(const Duration(milliseconds: 500));

      // Navigate to main screen
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const AuditScreen(),
          ),
        );
      }
    } catch (e, stack) {
      DebugLogger.error('Failed to initialize Chromium', e, stack);
      
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
        _status = 'Initialization failed';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App Icon/Logo
              Icon(
                Icons.assessment_outlined,
                size: 80,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 24),
              
              // App Title
              Text(
                'AuditMySite Studio',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 48),
              
              // Status Message
              if (!_hasError) ...[
                if (_progress == null)
                  const CircularProgressIndicator()
                else
                  CircularProgressIndicator(value: _progress),
                const SizedBox(height: 24),
                Text(
                  _status,
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                if (_progress == null)
                  Text(
                    'This may take a few minutes on first run...',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
              ],
              
              // Error Display
              if (_hasError) ...[
                Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  _status,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _errorMessage ?? 'Unknown error',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () {
                    setState(() {
                      _hasError = false;
                      _errorMessage = null;
                    });
                    _initializeChromium();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
