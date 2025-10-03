import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as path;

/// Handles offline/restricted network scenarios
class OfflineHandler {
  static final Set<String> _localHostnames = {
    'localhost',
    '127.0.0.1',
    '::1',
    '0.0.0.0',
  };
  
  /// Check if URL is local
  static bool isLocalUrl(Uri url) {
    // Check for file protocol
    if (url.scheme == 'file') {
      return true;
    }
    
    // Check for localhost variations
    if (_localHostnames.contains(url.host)) {
      return true;
    }
    
    // Check for local IP ranges
    if (_isPrivateIP(url.host)) {
      return true;
    }
    
    return false;
  }
  
  /// Check if IP is in private range
  static bool _isPrivateIP(String host) {
    try {
      final parts = host.split('.');
      if (parts.length != 4) return false;
      
      final octets = parts.map(int.tryParse).toList();
      if (octets.any((o) => o == null || o < 0 || o > 255)) return false;
      
      // 10.0.0.0/8
      if (octets[0] == 10) return true;
      
      // 172.16.0.0/12
      if (octets[0] == 172 && octets[1]! >= 16 && octets[1]! <= 31) return true;
      
      // 192.168.0.0/16
      if (octets[0] == 192 && octets[1] == 168) return true;
      
      return false;
    } catch (_) {
      return false;
    }
  }
  
  /// Create offline cache directory
  static Future<Directory> getCacheDirectory() async {
    final cacheDir = Directory(path.join(
      Platform.environment['HOME'] ?? '/tmp',
      '.auditmysite',
      'offline_cache',
    ));
    
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    
    return cacheDir;
  }
  
  /// Cache resource locally
  static Future<void> cacheResource(String url, List<int> data) async {
    try {
      final cacheDir = await getCacheDirectory();
      final urlHash = url.hashCode.toRadixString(16);
      final cacheFile = File(path.join(cacheDir.path, '$urlHash.cache'));
      
      final cacheData = {
        'url': url,
        'timestamp': DateTime.now().toIso8601String(),
        'data': base64Encode(data),
      };
      
      await cacheFile.writeAsString(jsonEncode(cacheData));
    } catch (e) {
      // Silently fail caching
    }
  }
  
  /// Get cached resource
  static Future<List<int>?> getCachedResource(String url) async {
    try {
      final cacheDir = await getCacheDirectory();
      final urlHash = url.hashCode.toRadixString(16);
      final cacheFile = File(path.join(cacheDir.path, '$urlHash.cache'));
      
      if (!await cacheFile.exists()) {
        return null;
      }
      
      final cacheData = jsonDecode(await cacheFile.readAsString());
      
      // Check cache age (24 hours)
      final timestamp = DateTime.parse(cacheData['timestamp']);
      if (DateTime.now().difference(timestamp).inHours > 24) {
        await cacheFile.delete();
        return null;
      }
      
      return base64Decode(cacheData['data']);
    } catch (e) {
      return null;
    }
  }
  
  /// Clear offline cache
  static Future<void> clearCache() async {
    try {
      final cacheDir = await getCacheDirectory();
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
      }
    } catch (e) {
      // Ignore errors
    }
  }
  
  /// Get offline resources bundle
  static Future<Map<String, String>> getOfflineResources() async {
    return {
      // Essential JavaScript libraries for offline audits
      'axe-core': await _loadBundledResource('axe.min.js'),
      
      // Fallback HTML for error pages
      'error-page': '''
<!DOCTYPE html>
<html>
<head>
  <title>Offline Mode</title>
  <style>
    body { font-family: system-ui, sans-serif; padding: 40px; background: #f5f5f5; }
    .container { max-width: 600px; margin: 0 auto; background: white; padding: 30px; border-radius: 8px; }
    h1 { color: #333; }
    p { color: #666; line-height: 1.6; }
    .info { background: #e3f2fd; padding: 15px; border-radius: 4px; margin-top: 20px; }
  </style>
</head>
<body>
  <div class="container">
    <h1>AuditMySite - Offline Mode</h1>
    <p>The audit engine is running in offline/restricted mode.</p>
    <div class="info">
      <p><strong>Note:</strong> Some features may be limited when running without internet access.</p>
      <p>Local and intranet sites can still be audited normally.</p>
    </div>
  </div>
</body>
</html>
''',
    };
  }
  
  /// Load bundled resource
  static Future<String> _loadBundledResource(String filename) async {
    try {
      final executableDir = File(Platform.resolvedExecutable).parent;
      
      // Try various paths
      final paths = [
        path.join(executableDir.path, 'third_party', 'axe', filename),
        path.join(executableDir.path, '..', 'Resources', 'third_party', 'axe', filename),
        path.join('third_party', 'axe', filename),
      ];
      
      for (final p in paths) {
        final file = File(p);
        if (await file.exists()) {
          return await file.readAsString();
        }
      }
    } catch (e) {
      // Fall back to empty string
    }
    
    return '';
  }
  
  /// Validate connectivity before audit
  static Future<ConnectivityStatus> checkConnectivity() async {
    final status = ConnectivityStatus();
    
    // Check internet connectivity
    try {
      final socket = await Socket.connect('8.8.8.8', 53,
        timeout: Duration(seconds: 3));
      socket.destroy();
      status.hasInternet = true;
    } catch (_) {
      status.hasInternet = false;
    }
    
    // Check local network
    try {
      final interfaces = await NetworkInterface.list();
      status.hasLocalNetwork = interfaces.isNotEmpty;
      status.localAddresses = interfaces
        .expand((i) => i.addresses)
        .map((a) => a.address)
        .toList();
    } catch (_) {
      status.hasLocalNetwork = false;
    }
    
    return status;
  }
  
  /// Configure browser for offline mode
  static Map<String, dynamic> getOfflineBrowserConfig() {
    return {
      'args': [
        '--disable-background-networking',
        '--disable-sync',
        '--disable-translate',
        '--disable-features=OptimizationGuideModelDownloading',
        '--disable-component-update',
        '--disable-domain-reliability',
        '--disable-features=NetworkService,NetworkServiceInProcess',
        '--disable-features=ImprovedCookieControls',
        '--disable-reading-from-canvas',
        '--disable-client-side-phishing-detection',
      ],
      'prefs': {
        'profile.default_content_settings.geolocation': 2,
        'profile.default_content_settings.notifications': 2,
        'profile.default_content_settings.media_stream': 2,
        'profile.default_content_settings.popups': 2,
      },
    };
  }
}

/// Connectivity status information
class ConnectivityStatus {
  bool hasInternet = false;
  bool hasLocalNetwork = false;
  List<String> localAddresses = [];
  
  Map<String, dynamic> toJson() => {
    'hasInternet': hasInternet,
    'hasLocalNetwork': hasLocalNetwork,
    'localAddresses': localAddresses,
  };
  
  @override
  String toString() {
    if (hasInternet) {
      return 'Full connectivity';
    } else if (hasLocalNetwork) {
      return 'Local network only (offline mode)';
    } else {
      return 'No network connectivity';
    }
  }
}

/// Offline audit configuration
class OfflineAuditConfig {
  final bool allowExternalUrls;
  final bool useCachedResources;
  final Duration cacheExpiry;
  final List<String> whitelistedDomains;
  
  const OfflineAuditConfig({
    this.allowExternalUrls = false,
    this.useCachedResources = true,
    this.cacheExpiry = const Duration(days: 1),
    this.whitelistedDomains = const [],
  });
  
  /// Create config for fully offline mode
  factory OfflineAuditConfig.strict() {
    return OfflineAuditConfig(
      allowExternalUrls: false,
      useCachedResources: true,
      cacheExpiry: Duration(days: 7),
      whitelistedDomains: [],
    );
  }
  
  /// Create config for restricted network (local only)
  factory OfflineAuditConfig.localOnly() {
    return OfflineAuditConfig(
      allowExternalUrls: false,
      useCachedResources: true,
      cacheExpiry: Duration(days: 1),
      whitelistedDomains: ['localhost', '127.0.0.1', '192.168.*', '10.*'],
    );
  }
  
  bool isUrlAllowed(Uri url) {
    // Always allow local URLs
    if (OfflineHandler.isLocalUrl(url)) {
      return true;
    }
    
    // Check if external URLs are allowed
    if (!allowExternalUrls) {
      return false;
    }
    
    // Check whitelist
    if (whitelistedDomains.isNotEmpty) {
      return whitelistedDomains.any((pattern) {
        if (pattern.contains('*')) {
          final regex = RegExp(pattern.replaceAll('*', '.*'));
          return regex.hasMatch(url.host);
        }
        return url.host == pattern;
      });
    }
    
    return true;
  }
}