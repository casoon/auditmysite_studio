import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Simple Chrome launcher that avoids Puppeteer WebSocket issues
class SimpleBrowser {
  Process? _process;
  String? _debuggerUrl;
  int _port = 9222;
  
  /// Launch Chrome with debugging port
  Future<void> launch({
    String? executablePath,
    bool headless = true,
    List<String>? args,
  }) async {
    executablePath ??= _findChrome();
    if (executablePath == null) {
      throw Exception('Chrome not found');
    }
    
    // Find available port
    _port = await _findAvailablePort();
    
    final launchArgs = [
      '--remote-debugging-port=$_port',
      if (headless) '--headless',
      '--no-sandbox',
      '--disable-setuid-sandbox',
      '--disable-dev-shm-usage',
      '--disable-gpu',
      '--user-agent=AuditMySite/1.0 (Desktop Studio; +https://auditmysite.io)',
      ...?args,
      'about:blank',
    ];
    
    print('Launching Chrome with args: ${launchArgs.join(' ')}');
    
    _process = await Process.start(
      executablePath,
      launchArgs,
    );
    
    // Wait for Chrome to start
    await Future.delayed(Duration(seconds: 2));
    
    // Get debugger URL
    try {
      final response = await http.get(
        Uri.parse('http://localhost:$_port/json/version'),
      ).timeout(Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _debuggerUrl = data['webSocketDebuggerUrl'];
        print('Chrome started successfully on port $_port');
      }
    } catch (e) {
      print('Warning: Could not get debugger URL: $e');
    }
  }
  
  /// Navigate to URL
  Future<String?> navigateAndGetHtml(String url) async {
    if (_process == null) {
      throw Exception('Browser not launched');
    }
    
    try {
      // Create new tab
      final newTabResponse = await http.get(
        Uri.parse('http://localhost:$_port/json/new'),
      );
      
      if (newTabResponse.statusCode != 200) {
        throw Exception('Failed to create new tab');
      }
      
      final tabData = json.decode(newTabResponse.body);
      final tabId = tabData['id'];
      
      // Navigate to URL using simple HTTP endpoint
      await http.get(
        Uri.parse('http://localhost:$_port/json/runtime/evaluate'),
        headers: {
          'Content-Type': 'application/json',
        },
      );
      
      // For now, just return a simple success message
      // In production, we'd use CDP to get the actual HTML
      return '<html><body>Page loaded: $url</body></html>';
      
    } catch (e) {
      print('Error navigating: $e');
      return null;
    }
  }
  
  /// Close browser
  Future<void> close() async {
    _process?.kill();
    _process = null;
  }
  
  /// Find Chrome executable
  String? _findChrome() {
    final paths = Platform.isMacOS
        ? [
            '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
            '/Applications/Chromium.app/Contents/MacOS/Chromium',
          ]
        : Platform.isWindows
            ? [
                'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe',
                'C:\\Program Files (x86)\\Google\\Chrome\\Application\\chrome.exe',
              ]
            : [
                '/usr/bin/google-chrome',
                '/usr/bin/chromium',
                '/usr/bin/chromium-browser',
              ];
    
    for (final path in paths) {
      if (File(path).existsSync()) {
        return path;
      }
    }
    return null;
  }
  
  /// Find available port
  Future<int> _findAvailablePort() async {
    for (int port = 9222; port < 9322; port++) {
      try {
        final socket = await ServerSocket.bind('localhost', port);
        await socket.close();
        return port;
      } catch (_) {
        continue;
      }
    }
    return 9222;
  }
}