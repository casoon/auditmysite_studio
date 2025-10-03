import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'package:puppeteer/puppeteer.dart';
import 'package:auditmysite_engine/deployment/embedded_config.dart';

/// Browser pool for managing Chrome/Chromium instances
class BrowserPool {
  Browser? _browser;
  final _availablePages = Queue<Page>();
  final _busyPages = Set<Page>();
  final _pageAcquisitionTimes = <Page, DateTime>{};
  bool _disposed = false;
  Timer? _cleanupTimer;
  
  // Compatibility properties
  Browser get browser => _browser!;
  
  BrowserPool._();
  
  /// Launch browser pool with embedded deployment support
  static Future<BrowserPool> launch({
    int size = 5,
    String? chromePath,
    bool headless = true,
    bool useEmbeddedConfig = true,
  }) async {
    final pool = BrowserPool._();
    
    // Use embedded configuration for deployment
    String? executablePath = chromePath;
    List<String> args;
    
    if (useEmbeddedConfig) {
      // Try to find bundled Chrome if no path specified
      executablePath ??= EmbeddedEngineConfig.getBundledChromePath();
      
      // Use deployment-specific browser arguments
      args = EmbeddedEngineConfig.getBrowserArgs(
        dataDir: EmbeddedEngineConfig.getDataDirectory(),
      );
      
      // Initialize required directories
      await EmbeddedEngineConfig.initializeDirectories();
      
      // Check for restricted environment
      final isRestricted = await EmbeddedEngineConfig.isRestrictedEnvironment();
      if (isRestricted) {
        print('Warning: Running in restricted network environment');
        args = EmbeddedEngineConfig.getBrowserArgs(
          offlineMode: true,
          dataDir: EmbeddedEngineConfig.getDataDirectory(),
        );
      }
    } else {
      // Fallback to basic arguments with AuditMySite user agent
      args = [
        '--no-sandbox',
        '--disable-setuid-sandbox',
        '--disable-dev-shm-usage',
        '--disable-gpu',
        '--window-size=1920,1080',
        '--disable-web-security',
        '--disable-features=site-per-process',
        '--user-agent=${EmbeddedEngineConfig.userAgent}',
      ];
    }
    
    // Add headless mode if requested
    if (headless) {
      args.add('--headless');
    }
    
    try {
      // For macOS, use a simpler approach without custom port
      if (Platform.isMacOS) {
        // Remove problematic args for macOS
        args.removeWhere((arg) => arg.startsWith('--remote-debugging-port'));
        
        // Ensure we have Chrome path on macOS
        if (executablePath == null || !File(executablePath).existsSync()) {
          // Try common Chrome locations on macOS
          final chromePaths = [
            '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
            '/Applications/Chromium.app/Contents/MacOS/Chromium',
            '/Applications/Google Chrome Canary.app/Contents/MacOS/Google Chrome Canary',
          ];
          
          for (final path in chromePaths) {
            if (File(path).existsSync()) {
              executablePath = path;
              print('Using Chrome at: $path');
              break;
            }
          }
        }
      } else {
        // Use debugging port for other platforms
        final debugPort = await _findAvailablePort();
        args.add('--remote-debugging-port=$debugPort');
      }
      
      pool._browser = await puppeteer.launch(
        executablePath: executablePath,
        headless: headless,
        args: args,
        defaultViewport: DeviceViewport(
          width: 1920,
          height: 1080,
          deviceScaleFactor: 1,
          isMobile: false,
          hasTouch: false,
          isLandscape: true,
        ),
        devTools: false,
        slowMo: Duration(milliseconds: 0),
        timeout: Duration(seconds: 30),
      );
    } catch (e) {
      print('Error launching browser: $e');
      // Try simpler approach without Puppeteer
      throw Exception('Browser launch failed. This is a known issue with Puppeteer on macOS. Please restart the app.');
    }
    
    // Start cleanup timer
    pool._startCleanupTimer();
    
    // Pre-create some pages for better performance
    for (int i = 0; i < 2; i++) {
      try {
        final page = await pool._createPage();
        pool._availablePages.add(page);
      } catch (e) {
        // Ignore pre-creation errors
      }
    }
    
    return pool;
  }
  
  /// Create a new page with AuditMySite configuration
  Future<Page> _createPage() async {
    if (_browser == null || _disposed) {
      throw StateError('Browser pool is disposed');
    }
    
    final page = await _browser!.newPage();
    
    // Set AuditMySite user agent
    await page.setUserAgent(EmbeddedEngineConfig.userAgent);
    
    // Set viewport
    await page.setViewport(DeviceViewport(
      width: 1920,
      height: 1080,
      deviceScaleFactor: 1,
      isMobile: false,
      hasTouch: false,
      isLandscape: true,
    ));
    
    // Set extra HTTP headers
    await page.setExtraHTTPHeaders(EmbeddedEngineConfig.defaultHeaders);
    
    // Configure timeouts
    page.defaultTimeout = EmbeddedEngineConfig.timeouts.pageLoad;
    
    return page;
  }
  
  /// Get a page from the pool
  Future<Page> acquire() async {
    if (_disposed) {
      throw StateError('Browser pool is disposed');
    }
    
    // Return available page if exists
    if (_availablePages.isNotEmpty) {
      final page = _availablePages.removeFirst();
      _busyPages.add(page);
      _pageAcquisitionTimes[page] = DateTime.now();
      
      // Ensure page is clean
      try {
        await page.goto('about:blank');
      } catch (_) {
        // Page might be corrupted, create new one
        _busyPages.remove(page);
        return await acquire();
      }
      
      return page;
    }
    
    // Create new page if within limits
    if (_busyPages.length < 10) {
      final page = await _createPage();
      _busyPages.add(page);
      _pageAcquisitionTimes[page] = DateTime.now();
      return page;
    }
    
    // Wait for available page
    await Future.delayed(Duration(milliseconds: 100));
    return await acquire();
  }
  
  /// Release page back to pool
  Future<void> release(Page page) async {
    if (_disposed) return;
    
    _busyPages.remove(page);
    _pageAcquisitionTimes.remove(page);
    
    try {
      // Clear page state
      await page.evaluate('() => { window.location.href = "about:blank"; }');
      await page.setContent('');
      
      // Return to pool
      _availablePages.add(page);
    } catch (e) {
      // Page is corrupted, close it
      try {
        await page.close();
      } catch (_) {}
    }
  }
  
  /// Compatibility method for simple page creation
  Future<Page> newPage() async {
    return await acquire();
  }
  
  /// Start cleanup timer
  void _startCleanupTimer() {
    _cleanupTimer = Timer.periodic(Duration(seconds: 30), (_) async {
      if (_disposed) return;
      
      // Clean up old pages
      final now = DateTime.now();
      final staleBusyPages = <Page>[];
      
      _pageAcquisitionTimes.forEach((page, time) {
        if (now.difference(time).inMinutes > 5) {
          staleBusyPages.add(page);
        }
      });
      
      for (final page in staleBusyPages) {
        _busyPages.remove(page);
        _pageAcquisitionTimes.remove(page);
        try {
          await page.close();
        } catch (_) {}
      }
      
      // Close excess available pages
      while (_availablePages.length > 3) {
        final page = _availablePages.removeLast();
        try {
          await page.close();
        } catch (_) {}
      }
    });
  }
  
  /// Close browser pool
  Future<void> close() async {
    _disposed = true;
    _cleanupTimer?.cancel();
    
    // Close all pages
    for (final page in _availablePages) {
      try {
        await page.close();
      } catch (_) {}
    }
    
    for (final page in _busyPages) {
      try {
        await page.close();
      } catch (_) {}
    }
    
    _availablePages.clear();
    _busyPages.clear();
    _pageAcquisitionTimes.clear();
    
    // Close browser
    if (_browser != null) {
      try {
        await _browser!.close();
      } catch (_) {}
      _browser = null;
    }
    
    // Clean up temporary files
    await EmbeddedEngineConfig.cleanup();
  }
  
  /// Get pool statistics
  Map<String, dynamic> getStats() {
    return {
      'available': _availablePages.length,
      'busy': _busyPages.length,
      'total': _availablePages.length + _busyPages.length,
      'disposed': _disposed,
    };
  }
  
  /// Find available port for debugging
  static Future<int> _findAvailablePort() async {
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
