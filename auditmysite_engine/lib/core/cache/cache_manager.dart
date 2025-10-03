import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;

/// Main cache manager for AuditMySite
class CacheManager {
  final Logger _logger = Logger('CacheManager');
  
  final Directory cacheDir;
  final Duration defaultTTL;
  final int maxSizeBytes;
  final bool persistCache;
  
  // Cache stores
  late final ResponseCache responseCache;
  late final AssetCache assetCache;
  late final BrowserCache browserCache;
  late final AuditResultCache auditCache;
  
  // Statistics
  int _hits = 0;
  int _misses = 0;
  int _evictions = 0;
  int _currentSizeBytes = 0;
  
  CacheManager({
    String? cachePath,
    this.defaultTTL = const Duration(hours: 24),
    this.maxSizeBytes = 500 * 1024 * 1024, // 500MB default
    this.persistCache = true,
  }) : cacheDir = Directory(cachePath ?? _getDefaultCachePath()) {
    _initialize();
  }
  
  void _initialize() {
    if (!cacheDir.existsSync()) {
      cacheDir.createSync(recursive: true);
    }
    
    // Initialize sub-caches
    responseCache = ResponseCache(
      baseDir: Directory(path.join(cacheDir.path, 'responses')),
      ttl: defaultTTL,
    );
    
    assetCache = AssetCache(
      baseDir: Directory(path.join(cacheDir.path, 'assets')),
      ttl: Duration(days: 7),
    );
    
    browserCache = BrowserCache(
      baseDir: Directory(path.join(cacheDir.path, 'browser')),
    );
    
    auditCache = AuditResultCache(
      baseDir: Directory(path.join(cacheDir.path, 'audits')),
      ttl: Duration(days: 30),
    );
    
    // Load cache metadata
    _loadCacheMetadata();
    
    _logger.info('Cache manager initialized at ${cacheDir.path}');
  }
  
  static String _getDefaultCachePath() {
    final homeDir = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    return path.join(homeDir!, '.auditmysite', 'cache');
  }
  
  /// Get cache statistics
  CacheStatistics getStatistics() {
    return CacheStatistics(
      hits: _hits,
      misses: _misses,
      evictions: _evictions,
      hitRate: _hits > 0 ? _hits / (_hits + _misses) : 0,
      currentSizeBytes: _currentSizeBytes,
      maxSizeBytes: maxSizeBytes,
      responsesCached: responseCache.getCount(),
      assetsCached: assetCache.getCount(),
      auditsCached: auditCache.getCount(),
    );
  }
  
  /// Clear all caches
  Future<void> clearAll() async {
    await responseCache.clear();
    await assetCache.clear();
    await browserCache.clear();
    await auditCache.clear();
    
    _hits = 0;
    _misses = 0;
    _evictions = 0;
    _currentSizeBytes = 0;
    
    _logger.info('All caches cleared');
  }
  
  /// Clear expired entries
  Future<int> clearExpired() async {
    int cleared = 0;
    
    cleared += await responseCache.clearExpired();
    cleared += await assetCache.clearExpired();
    cleared += await auditCache.clearExpired();
    
    _logger.info('Cleared $cleared expired cache entries');
    return cleared;
  }
  
  /// Prune cache to stay within size limits
  Future<void> pruneCache() async {
    if (_currentSizeBytes <= maxSizeBytes) return;
    
    _logger.info('Pruning cache (current: $_currentSizeBytes, max: $maxSizeBytes)');
    
    // Get all cache entries with metadata
    final entries = await _getAllCacheEntries();
    
    // Sort by last access time (LRU)
    entries.sort((a, b) => a.lastAccessed.compareTo(b.lastAccessed));
    
    // Remove oldest entries until under limit
    int removed = 0;
    for (final entry in entries) {
      if (_currentSizeBytes <= maxSizeBytes * 0.9) break; // Keep 10% buffer
      
      await _removeEntry(entry);
      removed++;
      _evictions++;
    }
    
    _logger.info('Pruned $removed cache entries');
  }
  
  void _loadCacheMetadata() {
    final metadataFile = File(path.join(cacheDir.path, 'metadata.json'));
    if (metadataFile.existsSync()) {
      try {
        final data = jsonDecode(metadataFile.readAsStringSync());
        _hits = data['hits'] ?? 0;
        _misses = data['misses'] ?? 0;
        _evictions = data['evictions'] ?? 0;
        _currentSizeBytes = data['currentSizeBytes'] ?? 0;
      } catch (e) {
        _logger.warning('Failed to load cache metadata: $e');
      }
    }
  }
  
  Future<void> _saveCacheMetadata() async {
    final metadataFile = File(path.join(cacheDir.path, 'metadata.json'));
    await metadataFile.writeAsString(jsonEncode({
      'hits': _hits,
      'misses': _misses,
      'evictions': _evictions,
      'currentSizeBytes': _currentSizeBytes,
      'lastUpdated': DateTime.now().toIso8601String(),
    }));
  }
  
  Future<List<CacheEntry>> _getAllCacheEntries() async {
    final entries = <CacheEntry>[];
    
    entries.addAll(await responseCache.getAllEntries());
    entries.addAll(await assetCache.getAllEntries());
    entries.addAll(await auditCache.getAllEntries());
    
    return entries;
  }
  
  Future<void> _removeEntry(CacheEntry entry) async {
    switch (entry.type) {
      case CacheType.response:
        await responseCache.remove(entry.key);
        break;
      case CacheType.asset:
        await assetCache.remove(entry.key);
        break;
      case CacheType.audit:
        await auditCache.remove(entry.key);
        break;
      case CacheType.browser:
        await browserCache.remove(entry.key);
        break;
    }
    
    _currentSizeBytes -= entry.sizeBytes;
  }
  
  void recordHit() {
    _hits++;
    _saveCacheMetadata();
  }
  
  void recordMiss() {
    _misses++;
    _saveCacheMetadata();
  }
  
  void dispose() {
    _saveCacheMetadata();
  }
}

/// Cache for HTTP responses
class ResponseCache {
  final Logger _logger = Logger('ResponseCache');
  final Directory baseDir;
  final Duration ttl;
  final Map<String, ResponseCacheEntry> _memoryCache = {};
  
  ResponseCache({
    required this.baseDir,
    required this.ttl,
  }) {
    if (!baseDir.existsSync()) {
      baseDir.createSync(recursive: true);
    }
    _loadIndex();
  }
  
  /// Get cached response
  Future<CachedResponse?> get(String url, {Map<String, String>? headers}) async {
    final key = _generateKey(url, headers);
    
    // Check memory cache first
    if (_memoryCache.containsKey(key)) {
      final entry = _memoryCache[key]!;
      if (!entry.isExpired) {
        entry.lastAccessed = DateTime.now();
        _logger.fine('Memory cache hit for $url');
        return entry.response;
      } else {
        _memoryCache.remove(key);
      }
    }
    
    // Check disk cache
    final file = File(path.join(baseDir.path, '$key.json'));
    if (await file.exists()) {
      try {
        final data = jsonDecode(await file.readAsString());
        final entry = ResponseCacheEntry.fromJson(data);
        
        if (!entry.isExpired) {
          _memoryCache[key] = entry;
          entry.lastAccessed = DateTime.now();
          await _updateLastAccessed(key);
          _logger.fine('Disk cache hit for $url');
          return entry.response;
        } else {
          await file.delete();
        }
      } catch (e) {
        _logger.warning('Failed to read cache entry: $e');
        await file.delete();
      }
    }
    
    return null;
  }
  
  /// Store response in cache
  Future<void> put(
    String url,
    CachedResponse response, {
    Map<String, String>? headers,
    Duration? customTTL,
  }) async {
    final key = _generateKey(url, headers);
    final entry = ResponseCacheEntry(
      key: key,
      url: url,
      response: response,
      created: DateTime.now(),
      lastAccessed: DateTime.now(),
      ttl: customTTL ?? ttl,
      headers: headers,
    );
    
    // Store in memory
    _memoryCache[key] = entry;
    
    // Store on disk
    final file = File(path.join(baseDir.path, '$key.json'));
    await file.writeAsString(jsonEncode(entry.toJson()));
    
    _logger.fine('Cached response for $url');
  }
  
  /// Check if URL is cached and valid
  Future<bool> has(String url, {Map<String, String>? headers}) async {
    final cached = await get(url, headers: headers);
    return cached != null;
  }
  
  /// Remove cached response
  Future<void> remove(String url, {Map<String, String>? headers}) async {
    final key = _generateKey(url, headers);
    _memoryCache.remove(key);
    
    final file = File(path.join(baseDir.path, '$key.json'));
    if (await file.exists()) {
      await file.delete();
    }
  }
  
  /// Clear all cached responses
  Future<void> clear() async {
    _memoryCache.clear();
    
    await for (final file in baseDir.list()) {
      if (file is File && file.path.endsWith('.json')) {
        await file.delete();
      }
    }
  }
  
  /// Clear expired entries
  Future<int> clearExpired() async {
    int cleared = 0;
    
    // Clear from memory
    _memoryCache.removeWhere((key, entry) {
      if (entry.isExpired) {
        cleared++;
        return true;
      }
      return false;
    });
    
    // Clear from disk
    await for (final file in baseDir.list()) {
      if (file is File && file.path.endsWith('.json')) {
        try {
          final data = jsonDecode(await file.readAsString());
          final entry = ResponseCacheEntry.fromJson(data);
          if (entry.isExpired) {
            await file.delete();
            cleared++;
          }
        } catch (e) {
          // Invalid file, delete it
          await file.delete();
        }
      }
    }
    
    return cleared;
  }
  
  int getCount() => _memoryCache.length;
  
  Future<List<CacheEntry>> getAllEntries() async {
    final entries = <CacheEntry>[];
    
    for (final entry in _memoryCache.values) {
      entries.add(CacheEntry(
        key: entry.key,
        type: CacheType.response,
        url: entry.url,
        created: entry.created,
        lastAccessed: entry.lastAccessed,
        sizeBytes: entry.response.sizeBytes,
      ));
    }
    
    return entries;
  }
  
  String _generateKey(String url, Map<String, String>? headers) {
    final parts = [url];
    if (headers != null) {
      final sortedHeaders = headers.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key));
      for (final entry in sortedHeaders) {
        parts.add('${entry.key}:${entry.value}');
      }
    }
    
    final bytes = utf8.encode(parts.join('|'));
    final hash = sha256.convert(bytes);
    return hash.toString().substring(0, 16);
  }
  
  void _loadIndex() {
    // Load cache index for quick memory cache population
    // This is a simplified version - in production, maintain a proper index
  }
  
  Future<void> _updateLastAccessed(String key) async {
    final file = File(path.join(baseDir.path, '$key.json'));
    if (await file.exists()) {
      try {
        final data = jsonDecode(await file.readAsString());
        data['lastAccessed'] = DateTime.now().toIso8601String();
        await file.writeAsString(jsonEncode(data));
      } catch (e) {
        _logger.warning('Failed to update last accessed time: $e');
      }
    }
  }
}

/// Cache for static assets (images, CSS, JS)
class AssetCache {
  final Logger _logger = Logger('AssetCache');
  final Directory baseDir;
  final Duration ttl;
  
  AssetCache({
    required this.baseDir,
    required this.ttl,
  }) {
    if (!baseDir.existsSync()) {
      baseDir.createSync(recursive: true);
    }
  }
  
  /// Get cached asset
  Future<Uint8List?> get(String url) async {
    final key = _generateKey(url);
    final file = File(path.join(baseDir.path, key));
    final metaFile = File(path.join(baseDir.path, '$key.meta'));
    
    if (await file.exists() && await metaFile.exists()) {
      try {
        final metadata = jsonDecode(await metaFile.readAsString());
        final created = DateTime.parse(metadata['created']);
        
        if (DateTime.now().difference(created) < ttl) {
          _logger.fine('Asset cache hit for $url');
          return await file.readAsBytes();
        } else {
          await file.delete();
          await metaFile.delete();
        }
      } catch (e) {
        _logger.warning('Failed to read asset cache: $e');
      }
    }
    
    return null;
  }
  
  /// Store asset in cache
  Future<void> put(String url, Uint8List data, {String? mimeType}) async {
    final key = _generateKey(url);
    final file = File(path.join(baseDir.path, key));
    final metaFile = File(path.join(baseDir.path, '$key.meta'));
    
    await file.writeAsBytes(data);
    await metaFile.writeAsString(jsonEncode({
      'url': url,
      'mimeType': mimeType,
      'created': DateTime.now().toIso8601String(),
      'sizeBytes': data.length,
    }));
    
    _logger.fine('Cached asset for $url (${data.length} bytes)');
  }
  
  /// Remove cached asset
  Future<void> remove(String url) async {
    final key = _generateKey(url);
    final file = File(path.join(baseDir.path, key));
    final metaFile = File(path.join(baseDir.path, '$key.meta'));
    
    if (await file.exists()) await file.delete();
    if (await metaFile.exists()) await metaFile.delete();
  }
  
  /// Clear all cached assets
  Future<void> clear() async {
    await for (final file in baseDir.list()) {
      if (file is File) {
        await file.delete();
      }
    }
  }
  
  /// Clear expired assets
  Future<int> clearExpired() async {
    int cleared = 0;
    
    await for (final file in baseDir.list()) {
      if (file is File && file.path.endsWith('.meta')) {
        try {
          final metadata = jsonDecode(await file.readAsString());
          final created = DateTime.parse(metadata['created']);
          
          if (DateTime.now().difference(created) > ttl) {
            final key = path.basenameWithoutExtension(file.path);
            final dataFile = File(path.join(baseDir.path, key));
            
            await file.delete();
            if (await dataFile.exists()) await dataFile.delete();
            cleared++;
          }
        } catch (e) {
          // Invalid metadata, delete it
          await file.delete();
        }
      }
    }
    
    return cleared;
  }
  
  int getCount() {
    int count = 0;
    for (final file in baseDir.listSync()) {
      if (file is File && file.path.endsWith('.meta')) {
        count++;
      }
    }
    return count;
  }
  
  Future<List<CacheEntry>> getAllEntries() async {
    final entries = <CacheEntry>[];
    
    await for (final file in baseDir.list()) {
      if (file is File && file.path.endsWith('.meta')) {
        try {
          final metadata = jsonDecode(await file.readAsString());
          entries.add(CacheEntry(
            key: path.basenameWithoutExtension(file.path),
            type: CacheType.asset,
            url: metadata['url'],
            created: DateTime.parse(metadata['created']),
            lastAccessed: DateTime.parse(metadata['created']),
            sizeBytes: metadata['sizeBytes'] ?? 0,
          ));
        } catch (e) {
          // Skip invalid entries
        }
      }
    }
    
    return entries;
  }
  
  String _generateKey(String url) {
    final bytes = utf8.encode(url);
    final hash = sha256.convert(bytes);
    
    // Include file extension if available
    final uri = Uri.tryParse(url);
    String extension = '';
    if (uri != null && uri.pathSegments.isNotEmpty) {
      final lastSegment = uri.pathSegments.last;
      final dotIndex = lastSegment.lastIndexOf('.');
      if (dotIndex != -1) {
        extension = lastSegment.substring(dotIndex);
      }
    }
    
    return '${hash.toString().substring(0, 16)}$extension';
  }
}

/// Browser cache simulation
class BrowserCache {
  final Logger _logger = Logger('BrowserCache');
  final Directory baseDir;
  final Map<String, BrowserCacheEntry> _cache = {};
  
  BrowserCache({
    required this.baseDir,
  }) {
    if (!baseDir.existsSync()) {
      baseDir.createSync(recursive: true);
    }
  }
  
  /// Simulate browser caching behavior
  Future<bool> shouldUseCached(
    String url,
    Map<String, String> responseHeaders,
  ) async {
    // Check Cache-Control header
    final cacheControl = responseHeaders['cache-control'];
    if (cacheControl != null) {
      if (cacheControl.contains('no-store')) return false;
      if (cacheControl.contains('no-cache')) return false;
      
      // Parse max-age
      final maxAgeMatch = RegExp(r'max-age=(\d+)').firstMatch(cacheControl);
      if (maxAgeMatch != null) {
        final maxAge = int.parse(maxAgeMatch.group(1)!);
        
        if (_cache.containsKey(url)) {
          final entry = _cache[url]!;
          final age = DateTime.now().difference(entry.created).inSeconds;
          
          if (age < maxAge) {
            _logger.fine('Browser cache hit for $url (age: $age, max-age: $maxAge)');
            return true;
          }
        }
      }
    }
    
    // Check Expires header
    final expires = responseHeaders['expires'];
    if (expires != null) {
      try {
        final expiresDate = HttpDate.parse(expires);
        if (DateTime.now().isBefore(expiresDate)) {
          _logger.fine('Browser cache hit for $url (expires: $expires)');
          return true;
        }
      } catch (e) {
        _logger.warning('Invalid Expires header: $expires');
      }
    }
    
    // Check ETag
    final etag = responseHeaders['etag'];
    if (etag != null && _cache.containsKey(url)) {
      final entry = _cache[url]!;
      if (entry.etag == etag) {
        _logger.fine('Browser cache hit for $url (ETag match)');
        return true;
      }
    }
    
    return false;
  }
  
  /// Store response in browser cache
  void store(String url, Map<String, String> headers) {
    _cache[url] = BrowserCacheEntry(
      url: url,
      created: DateTime.now(),
      headers: headers,
      etag: headers['etag'],
      lastModified: headers['last-modified'],
    );
  }
  
  /// Clear browser cache
  Future<void> clear() async {
    _cache.clear();
  }
  
  /// Remove specific URL from cache
  Future<void> remove(String key) async {
    _cache.remove(key);
  }
}

/// Cache for audit results
class AuditResultCache {
  final Logger _logger = Logger('AuditResultCache');
  final Directory baseDir;
  final Duration ttl;
  
  AuditResultCache({
    required this.baseDir,
    required this.ttl,
  }) {
    if (!baseDir.existsSync()) {
      baseDir.createSync(recursive: true);
    }
  }
  
  /// Get cached audit result
  Future<Map<String, dynamic>?> get(String url, {String? configHash}) async {
    final key = _generateKey(url, configHash);
    final file = File(path.join(baseDir.path, '$key.json'));
    
    if (await file.exists()) {
      try {
        final data = jsonDecode(await file.readAsString());
        final created = DateTime.parse(data['created']);
        
        if (DateTime.now().difference(created) < ttl) {
          _logger.info('Audit cache hit for $url');
          return data['result'];
        } else {
          await file.delete();
        }
      } catch (e) {
        _logger.warning('Failed to read audit cache: $e');
        await file.delete();
      }
    }
    
    return null;
  }
  
  /// Store audit result
  Future<void> put(
    String url,
    Map<String, dynamic> result, {
    String? configHash,
  }) async {
    final key = _generateKey(url, configHash);
    final file = File(path.join(baseDir.path, '$key.json'));
    
    await file.writeAsString(jsonEncode({
      'url': url,
      'created': DateTime.now().toIso8601String(),
      'configHash': configHash,
      'result': result,
    }));
    
    _logger.info('Cached audit result for $url');
  }
  
  /// Remove cached result
  Future<void> remove(String url, {String? configHash}) async {
    final key = _generateKey(url, configHash);
    final file = File(path.join(baseDir.path, '$key.json'));
    
    if (await file.exists()) {
      await file.delete();
    }
  }
  
  /// Clear all cached results
  Future<void> clear() async {
    await for (final file in baseDir.list()) {
      if (file is File && file.path.endsWith('.json')) {
        await file.delete();
      }
    }
  }
  
  /// Clear expired results
  Future<int> clearExpired() async {
    int cleared = 0;
    
    await for (final file in baseDir.list()) {
      if (file is File && file.path.endsWith('.json')) {
        try {
          final data = jsonDecode(await file.readAsString());
          final created = DateTime.parse(data['created']);
          
          if (DateTime.now().difference(created) > ttl) {
            await file.delete();
            cleared++;
          }
        } catch (e) {
          await file.delete();
        }
      }
    }
    
    return cleared;
  }
  
  int getCount() {
    int count = 0;
    for (final file in baseDir.listSync()) {
      if (file is File && file.path.endsWith('.json')) {
        count++;
      }
    }
    return count;
  }
  
  Future<List<CacheEntry>> getAllEntries() async {
    final entries = <CacheEntry>[];
    
    await for (final file in baseDir.list()) {
      if (file is File && file.path.endsWith('.json')) {
        try {
          final data = jsonDecode(await file.readAsString());
          final fileSize = await file.length();
          
          entries.add(CacheEntry(
            key: path.basenameWithoutExtension(file.path),
            type: CacheType.audit,
            url: data['url'],
            created: DateTime.parse(data['created']),
            lastAccessed: DateTime.parse(data['created']),
            sizeBytes: fileSize,
          ));
        } catch (e) {
          // Skip invalid entries
        }
      }
    }
    
    return entries;
  }
  
  String _generateKey(String url, String? configHash) {
    final input = configHash != null ? '$url|$configHash' : url;
    final bytes = utf8.encode(input);
    final hash = sha256.convert(bytes);
    return hash.toString().substring(0, 16);
  }
}

// Data models

/// Cache entry metadata
class CacheEntry {
  final String key;
  final CacheType type;
  final String url;
  final DateTime created;
  DateTime lastAccessed;
  final int sizeBytes;
  
  CacheEntry({
    required this.key,
    required this.type,
    required this.url,
    required this.created,
    required this.lastAccessed,
    required this.sizeBytes,
  });
}

/// Cache entry types
enum CacheType {
  response,
  asset,
  browser,
  audit,
}

/// Response cache entry
class ResponseCacheEntry {
  final String key;
  final String url;
  final CachedResponse response;
  final DateTime created;
  DateTime lastAccessed;
  final Duration ttl;
  final Map<String, String>? headers;
  
  ResponseCacheEntry({
    required this.key,
    required this.url,
    required this.response,
    required this.created,
    required this.lastAccessed,
    required this.ttl,
    this.headers,
  });
  
  bool get isExpired => DateTime.now().difference(created) > ttl;
  
  Map<String, dynamic> toJson() => {
    'key': key,
    'url': url,
    'response': response.toJson(),
    'created': created.toIso8601String(),
    'lastAccessed': lastAccessed.toIso8601String(),
    'ttlSeconds': ttl.inSeconds,
    'headers': headers,
  };
  
  factory ResponseCacheEntry.fromJson(Map<String, dynamic> json) {
    return ResponseCacheEntry(
      key: json['key'],
      url: json['url'],
      response: CachedResponse.fromJson(json['response']),
      created: DateTime.parse(json['created']),
      lastAccessed: DateTime.parse(json['lastAccessed']),
      ttl: Duration(seconds: json['ttlSeconds']),
      headers: json['headers']?.cast<String, String>(),
    );
  }
}

/// Cached HTTP response
class CachedResponse {
  final int statusCode;
  final Map<String, String> headers;
  final String body;
  final int sizeBytes;
  
  CachedResponse({
    required this.statusCode,
    required this.headers,
    required this.body,
    required this.sizeBytes,
  });
  
  Map<String, dynamic> toJson() => {
    'statusCode': statusCode,
    'headers': headers,
    'body': body,
    'sizeBytes': sizeBytes,
  };
  
  factory CachedResponse.fromJson(Map<String, dynamic> json) {
    return CachedResponse(
      statusCode: json['statusCode'],
      headers: json['headers'].cast<String, String>(),
      body: json['body'],
      sizeBytes: json['sizeBytes'],
    );
  }
}

/// Browser cache entry
class BrowserCacheEntry {
  final String url;
  final DateTime created;
  final Map<String, String> headers;
  final String? etag;
  final String? lastModified;
  
  BrowserCacheEntry({
    required this.url,
    required this.created,
    required this.headers,
    this.etag,
    this.lastModified,
  });
}

/// Cache statistics
class CacheStatistics {
  final int hits;
  final int misses;
  final int evictions;
  final double hitRate;
  final int currentSizeBytes;
  final int maxSizeBytes;
  final int responsesCached;
  final int assetsCached;
  final int auditsCached;
  
  CacheStatistics({
    required this.hits,
    required this.misses,
    required this.evictions,
    required this.hitRate,
    required this.currentSizeBytes,
    required this.maxSizeBytes,
    required this.responsesCached,
    required this.assetsCached,
    required this.auditsCached,
  });
  
  double get usagePercentage => currentSizeBytes / maxSizeBytes * 100;
  
  Map<String, dynamic> toJson() => {
    'hits': hits,
    'misses': misses,
    'evictions': evictions,
    'hitRate': hitRate,
    'currentSizeBytes': currentSizeBytes,
    'maxSizeBytes': maxSizeBytes,
    'usagePercentage': usagePercentage,
    'responsesCached': responsesCached,
    'assetsCached': assetsCached,
    'auditsCached': auditsCached,
  };
}