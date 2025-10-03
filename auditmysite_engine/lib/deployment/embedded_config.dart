import 'dart:io';
import 'package:path/path.dart' as path;

/// Configuration for embedded engine deployment within desktop apps
class EmbeddedEngineConfig {
  /// User agent string for all browser requests
  static const String userAgent = 'AuditMySite/1.0 (Desktop Studio; +https://auditmysite.io)';
  
  /// Custom headers for HTTP requests
  static const Map<String, String> defaultHeaders = {
    'X-AuditMySite-Version': '1.0.0',
    'X-AuditMySite-Platform': 'desktop',
  };
  
  /// Browser launch arguments for restricted environments
  static List<String> getBrowserArgs({
    bool offlineMode = false,
    bool disableGpu = true,
    String? proxyServer,
    String? dataDir,
  }) {
    final args = <String>[
      '--no-sandbox',
      '--disable-setuid-sandbox',
      '--disable-dev-shm-usage',
      '--disable-web-security',
      '--disable-features=site-per-process',
      '--disable-blink-features=AutomationControlled',
      '--window-size=1920,1080',
      '--start-maximized',
      '--user-agent=$userAgent',
      
      // Performance optimizations
      '--disable-background-timer-throttling',
      '--disable-backgrounding-occluded-windows',
      '--disable-renderer-backgrounding',
      
      // Privacy and tracking
      '--disable-sync',
      '--disable-translate',
      '--disable-extensions',
      '--disable-default-apps',
      '--disable-component-extensions-with-background-pages',
      '--disable-background-networking',
      '--metrics-recording-only',
      '--no-first-run',
      
      // Network handling
      '--disable-features=TranslateUI',
      '--disable-ipc-flooding-protection',
      '--disable-hang-monitor',
      '--hide-scrollbars',
      '--mute-audio',
      '--disable-plugins',
    ];
    
    if (disableGpu) {
      args.addAll([
        '--disable-gpu',
        '--disable-software-rasterizer',
        '--disable-gpu-sandbox',
      ]);
    }
    
    if (offlineMode) {
      args.addAll([
        '--disable-background-networking',
        '--disable-sync',
        '--disable-features=OptimizationGuideModelDownloading',
      ]);
    }
    
    if (proxyServer != null) {
      args.add('--proxy-server=$proxyServer');
    }
    
    if (dataDir != null) {
      args.add('--user-data-dir=$dataDir');
    }
    
    return args;
  }
  
  /// Get the path to the bundled Chrome/Chromium executable
  static String? getBundledChromePath() {
    // Check if we're running from a bundled app
    final executableDir = File(Platform.resolvedExecutable).parent;
    
    if (Platform.isMacOS) {
      // macOS app bundle structure
      final candidates = [
        // Within app bundle
        path.join(executableDir.path, '..', 'Resources', 'chrome', 'Chromium.app', 'Contents', 'MacOS', 'Chromium'),
        // Development path
        path.join(executableDir.path, 'chrome', 'Chromium.app', 'Contents', 'MacOS', 'Chromium'),
        // System Chrome
        '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
        '/Applications/Chromium.app/Contents/MacOS/Chromium',
      ];
      
      for (final candidate in candidates) {
        if (File(candidate).existsSync()) {
          return candidate;
        }
      }
    } else if (Platform.isWindows) {
      // Windows exe bundle structure
      final candidates = [
        // Bundled with app
        path.join(executableDir.path, 'chrome', 'chrome.exe'),
        path.join(executableDir.path, '..', 'chrome', 'chrome.exe'),
        // System Chrome
        path.join(Platform.environment['PROGRAMFILES'] ?? 'C:\\Program Files', 'Google', 'Chrome', 'Application', 'chrome.exe'),
        path.join(Platform.environment['PROGRAMFILES(X86)'] ?? 'C:\\Program Files (x86)', 'Google', 'Chrome', 'Application', 'chrome.exe'),
      ];
      
      for (final candidate in candidates) {
        if (File(candidate).existsSync()) {
          return candidate;
        }
      }
    } else if (Platform.isLinux) {
      // Linux paths
      final candidates = [
        // Bundled
        path.join(executableDir.path, 'chrome', 'chrome'),
        // System
        '/usr/bin/chromium',
        '/usr/bin/chromium-browser',
        '/usr/bin/google-chrome',
        '/usr/bin/google-chrome-stable',
      ];
      
      for (final candidate in candidates) {
        if (File(candidate).existsSync()) {
          return candidate;
        }
      }
    }
    
    return null;
  }
  
  /// Get the data directory for browser profile
  static String getDataDirectory() {
    final appName = 'AuditMySite';
    
    if (Platform.isMacOS) {
      final home = Platform.environment['HOME'] ?? '/tmp';
      return path.join(home, 'Library', 'Application Support', appName, 'chrome_profile');
    } else if (Platform.isWindows) {
      final appData = Platform.environment['APPDATA'] ?? 'C:\\';
      return path.join(appData, appName, 'chrome_profile');
    } else {
      final home = Platform.environment['HOME'] ?? '/tmp';
      return path.join(home, '.config', appName, 'chrome_profile');
    }
  }
  
  /// Get the cache directory for temporary files
  static String getCacheDirectory() {
    final appName = 'AuditMySite';
    
    if (Platform.isMacOS) {
      final home = Platform.environment['HOME'] ?? '/tmp';
      return path.join(home, 'Library', 'Caches', appName);
    } else if (Platform.isWindows) {
      final localAppData = Platform.environment['LOCALAPPDATA'] ?? 'C:\\';
      return path.join(localAppData, appName, 'Cache');
    } else {
      final home = Platform.environment['HOME'] ?? '/tmp';
      return path.join(home, '.cache', appName);
    }
  }
  
  /// Get axe-core library path
  static String getAxeCoreLibraryPath() {
    final executableDir = File(Platform.resolvedExecutable).parent;
    
    // Try bundled path first
    final bundledPath = path.join(executableDir.path, 'third_party', 'axe', 'axe.min.js');
    if (File(bundledPath).existsSync()) {
      return bundledPath;
    }
    
    // Try resources path (macOS bundle)
    if (Platform.isMacOS) {
      final resourcesPath = path.join(executableDir.path, '..', 'Resources', 'third_party', 'axe', 'axe.min.js');
      if (File(resourcesPath).existsSync()) {
        return resourcesPath;
      }
    }
    
    // Fall back to development path
    return 'third_party/axe/axe.min.js';
  }
  
  /// Network timeout configurations
  static const NetworkTimeouts timeouts = NetworkTimeouts(
    pageLoad: Duration(seconds: 60),
    script: Duration(seconds: 30),
    resource: Duration(seconds: 30),
    idle: Duration(seconds: 10),
  );
  
  /// Check if we're running in a restricted environment
  static Future<bool> isRestrictedEnvironment() async {
    try {
      // Try to reach a known public endpoint
      final socket = await Socket.connect('8.8.8.8', 53,
        timeout: Duration(seconds: 3),
      );
      socket.destroy();
      return false;
    } catch (_) {
      return true;
    }
  }
  
  /// Initialize directories for embedded deployment
  static Future<void> initializeDirectories() async {
    final dirs = [
      getDataDirectory(),
      getCacheDirectory(),
      path.dirname(getAxeCoreLibraryPath()),
    ];
    
    for (final dir in dirs) {
      await Directory(dir).create(recursive: true);
    }
  }
  
  /// Clean up temporary files
  static Future<void> cleanup() async {
    try {
      final cacheDir = Directory(getCacheDirectory());
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
      }
    } catch (e) {
      // Ignore cleanup errors
      print('Warning: Failed to cleanup cache: $e');
    }
  }
}

/// Network timeout configurations
class NetworkTimeouts {
  final Duration pageLoad;
  final Duration script;
  final Duration resource;
  final Duration idle;
  
  const NetworkTimeouts({
    required this.pageLoad,
    required this.script,
    required this.resource,
    required this.idle,
  });
}

/// Deployment information for diagnostics
class DeploymentInfo {
  static Map<String, dynamic> getInfo() {
    final executableDir = File(Platform.resolvedExecutable).parent;
    final chromePath = EmbeddedEngineConfig.getBundledChromePath();
    
    return {
      'version': '1.0.0',
      'platform': Platform.operatingSystem,
      'executable': Platform.resolvedExecutable,
      'executableDir': executableDir.path,
      'chromePath': chromePath,
      'chromeFound': chromePath != null && File(chromePath).existsSync(),
      'dataDir': EmbeddedEngineConfig.getDataDirectory(),
      'cacheDir': EmbeddedEngineConfig.getCacheDirectory(),
      'axePath': EmbeddedEngineConfig.getAxeCoreLibraryPath(),
      'axeFound': File(EmbeddedEngineConfig.getAxeCoreLibraryPath()).existsSync(),
      'userAgent': EmbeddedEngineConfig.userAgent,
    };
  }
  
  static void printDiagnostics() {
    final info = getInfo();
    print('=== AuditMySite Engine Deployment Info ===');
    info.forEach((key, value) {
      print('$key: $value');
    });
    print('==========================================');
  }
}