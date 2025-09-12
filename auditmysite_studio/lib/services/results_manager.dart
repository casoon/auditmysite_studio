import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

class ResultsManager {
  static const String _keyStorageLocation = 'results_storage_location';
  static const String _keyRecentResults = 'recent_results';
  static const String _keyMaxHistoryItems = 'max_history_items';
  static const int _defaultMaxHistoryItems = 50;
  
  static ResultsManager? _instance;
  static SharedPreferences? _prefs;
  
  ResultsManager._();
  
  static Future<ResultsManager> getInstance() async {
    _instance ??= ResultsManager._();
    _prefs ??= await SharedPreferences.getInstance();
    return _instance!;
  }
  
  // Storage location management
  Future<String> getStorageLocation() async {
    final saved = _prefs?.getString(_keyStorageLocation);
    if (saved != null && Directory(saved).existsSync()) {
      return saved;
    }
    
    // Default to user documents/AuditMySite
    final homeDir = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '.';
    final defaultDir = p.join(homeDir, 'Documents', 'AuditMySite', 'Results');
    
    await Directory(defaultDir).create(recursive: true);
    await _prefs?.setString(_keyStorageLocation, defaultDir);
    
    return defaultDir;
  }
  
  Future<void> setStorageLocation(String path) async {
    await _prefs?.setString(_keyStorageLocation, path);
  }
  
  // Save results with metadata
  Future<String> saveResults(List<Map<String, dynamic>> results, {
    String? title,
    Map<String, dynamic>? metadata,
  }) async {
    final storageDir = await getStorageLocation();
    final timestamp = DateTime.now();
    final resultId = '${timestamp.toIso8601String().replaceAll(RegExp(r'[:.T-]'), '')}_${timestamp.millisecondsSinceEpoch.toString().substring(8)}';
    
    final resultDir = Directory(p.join(storageDir, resultId));
    await resultDir.create(recursive: true);
    
    // Save individual results
    final pagesDir = Directory(p.join(resultDir.path, 'pages'));
    await pagesDir.create();
    
    for (int i = 0; i < results.length; i++) {
      final result = results[i];
      final url = result['url'] as String? ?? 'page_$i';
      final fileName = url.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      final file = File(p.join(pagesDir.path, '$fileName.json'));
      await file.writeAsString(const JsonEncoder.withIndent('  ').convert(result));
    }
    
    // Save metadata
    final resultMetadata = {
      'id': resultId,
      'title': title ?? 'Untitled Audit',
      'created_at': timestamp.toIso8601String(),
      'total_pages': results.length,
      'source': metadata?['source'] ?? 'manual_load',
      'engine_url': metadata?['engine_url'],
      'sitemap_url': metadata?['sitemap_url'],
      'summary': _generateQuickSummary(results),
    };
    
    final metadataFile = File(p.join(resultDir.path, 'metadata.json'));
    await metadataFile.writeAsString(const JsonEncoder.withIndent('  ').convert(resultMetadata));
    
    // Add to recent results history
    await _addToHistory(resultMetadata);
    
    return resultId;
  }
  
  // Load results by ID
  Future<List<Map<String, dynamic>>> loadResults(String resultId) async {
    final storageDir = await getStorageLocation();
    final pagesDir = Directory(p.join(storageDir, resultId, 'pages'));
    
    if (!pagesDir.existsSync()) {
      throw Exception('Results not found: $resultId');
    }
    
    final results = <Map<String, dynamic>>[];
    final files = pagesDir.listSync().where((f) => f.path.endsWith('.json'));
    
    for (final file in files) {
      try {
        final content = await File(file.path).readAsString();
        final json = jsonDecode(content) as Map<String, dynamic>;
        results.add(json);
      } catch (e) {
        print('Warning: Could not load ${file.path}: $e');
      }
    }
    
    return results;
  }
  
  // Get results metadata
  Future<Map<String, dynamic>?> getResultsMetadata(String resultId) async {
    final storageDir = await getStorageLocation();
    final metadataFile = File(p.join(storageDir, resultId, 'metadata.json'));
    
    if (!metadataFile.existsSync()) {
      return null;
    }
    
    try {
      final content = await metadataFile.readAsString();
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }
  
  // Recent results history
  Future<List<Map<String, dynamic>>> getRecentResults() async {
    final historyJson = _prefs?.getString(_keyRecentResults) ?? '[]';
    try {
      final history = jsonDecode(historyJson) as List;
      return history.cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }
  
  Future<void> _addToHistory(Map<String, dynamic> metadata) async {
    final history = await getRecentResults();
    
    // Remove if already exists (to move to front)
    history.removeWhere((item) => item['id'] == metadata['id']);
    
    // Add to front
    history.insert(0, metadata);
    
    // Limit history size
    final maxItems = _prefs?.getInt(_keyMaxHistoryItems) ?? _defaultMaxHistoryItems;
    while (history.length > maxItems) {
      history.removeLast();
    }
    
    // Save updated history
    await _prefs?.setString(_keyRecentResults, jsonEncode(history));
  }
  
  // Delete results
  Future<void> deleteResults(String resultId) async {
    final storageDir = await getStorageLocation();
    final resultDir = Directory(p.join(storageDir, resultId));
    
    if (resultDir.existsSync()) {
      await resultDir.delete(recursive: true);
    }
    
    // Remove from history
    final history = await getRecentResults();
    history.removeWhere((item) => item['id'] == resultId);
    await _prefs?.setString(_keyRecentResults, jsonEncode(history));
  }
  
  // Search results
  Future<List<Map<String, dynamic>>> searchResults(String query) async {
    final history = await getRecentResults();
    final lowerQuery = query.toLowerCase();
    
    return history.where((result) {
      final title = (result['title'] as String? ?? '').toLowerCase();
      final sitemapUrl = (result['sitemap_url'] as String? ?? '').toLowerCase();
      
      return title.contains(lowerQuery) || sitemapUrl.contains(lowerQuery);
    }).toList();
  }
  
  // Get storage statistics
  Future<Map<String, dynamic>> getStorageStats() async {
    final storageDir = await getStorageLocation();
    final dir = Directory(storageDir);
    
    if (!dir.existsSync()) {
      return {
        'total_results': 0,
        'total_size_bytes': 0,
        'oldest_date': null,
        'newest_date': null,
      };
    }
    
    final subdirs = dir.listSync().where((e) => e is Directory).cast<Directory>();
    int totalSizeBytes = 0;
    DateTime? oldest;
    DateTime? newest;
    
    for (final subdir in subdirs) {
      // Calculate size
      final files = subdir.listSync(recursive: true).where((e) => e is File);
      for (final file in files) {
        try {
          totalSizeBytes += (file as File).lengthSync();
        } catch (e) {
          // Ignore files we can't read
        }
      }
      
      // Parse date from directory name
      try {
        final dirName = p.basename(subdir.path);
        if (dirName.length >= 15) {
          final year = int.parse(dirName.substring(0, 4));
          final month = int.parse(dirName.substring(4, 6));
          final day = int.parse(dirName.substring(6, 8));
          final hour = int.parse(dirName.substring(8, 10));
          final minute = int.parse(dirName.substring(10, 12));
          final second = int.parse(dirName.substring(12, 14));
          
          final date = DateTime(year, month, day, hour, minute, second);
          
          if (oldest == null || date.isBefore(oldest)) oldest = date;
          if (newest == null || date.isAfter(newest)) newest = date;
        }
      } catch (e) {
        // Ignore invalid directory names
      }
    }
    
    return {
      'total_results': subdirs.length,
      'total_size_bytes': totalSizeBytes,
      'total_size_mb': (totalSizeBytes / (1024 * 1024)).round(),
      'oldest_date': oldest?.toIso8601String(),
      'newest_date': newest?.toIso8601String(),
    };
  }
  
  // Cleanup old results
  Future<int> cleanupOldResults({int? keepRecentCount}) async {
    keepRecentCount ??= _prefs?.getInt(_keyMaxHistoryItems) ?? _defaultMaxHistoryItems;
    
    final history = await getRecentResults();
    if (history.length <= keepRecentCount) {
      return 0;
    }
    
    final toDelete = history.skip(keepRecentCount).toList();
    int deletedCount = 0;
    
    for (final item in toDelete) {
      try {
        await deleteResults(item['id'] as String);
        deletedCount++;
      } catch (e) {
        print('Warning: Could not delete ${item['id']}: $e');
      }
    }
    
    return deletedCount;
  }
  
  Map<String, dynamic> _generateQuickSummary(List<Map<String, dynamic>> results) {
    if (results.isEmpty) {
      return {
        'total_pages': 0,
        'total_violations': 0,
        'success_rate': 0,
        'avg_lcp_ms': null,
      };
    }
    
    var successfulPages = 0;
    var totalViolations = 0;
    final lcpValues = <double>[];
    
    for (final result in results) {
      // Count successful pages (2xx status codes)
      final statusCode = result['http']?['statusCode'] as int?;
      if (statusCode != null && statusCode >= 200 && statusCode < 300) {
        successfulPages++;
      }
      
      // Count violations
      final violations = result['a11y']?['violations'] as List? ?? [];
      totalViolations += violations.length;
      
      // Collect LCP values
      final lcp = result['perf']?['lcpMs'];
      if (lcp != null && lcp is num) {
        lcpValues.add(lcp.toDouble());
      }
    }
    
    return {
      'total_pages': results.length,
      'successful_pages': successfulPages,
      'total_violations': totalViolations,
      'success_rate': results.length > 0 ? (successfulPages / results.length * 100).round() : 0,
      'avg_violations': results.length > 0 ? (totalViolations / results.length).round() : 0,
      'avg_lcp_ms': lcpValues.isEmpty ? null : (lcpValues.reduce((a, b) => a + b) / lcpValues.length).round(),
    };
  }
}
