import 'dart:convert';
import 'dart:io';

class JsonWriter {
  final Directory baseDir;
  final String runId;
  final List<Map<String, dynamic>> _processedPages = [];
  final DateTime _runStartTime = DateTime.now();
  
  JsonWriter({required Directory baseDir, String? runId}) 
      : this.baseDir = baseDir,
        this.runId = runId ?? '';

  Future<void> write(Map<String, dynamic> pageJson) async {
    // Create main directory if needed
    baseDir.createSync(recursive: true);
    
    // Use date-based filename
    final dateStr = DateTime.now().toIso8601String().split('T')[0]; // YYYY-MM-DD
    final url = pageJson['url'] as String;
    final urlSlug = url.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    final fileName = 'audit_${dateStr}_$urlSlug';
    final file = File('${baseDir.path}/$fileName.json');
    
    // Overwrite if exists (same day = overwrite)
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(pageJson));
    
    // Store page data for summary aggregation
    _processedPages.add(pageJson);
  }
  
  Future<void> writeSummary([Map<String, dynamic>? additionalData]) async {
    // Create main directory if needed
    baseDir.createSync(recursive: true);
    
    // Use date-based summary filename
    final dateStr = DateTime.now().toIso8601String().split('T')[0]; // YYYY-MM-DD
    final summaryFile = File('${baseDir.path}/summary_$dateStr.json');
    final summary = _generateSummary();
    
    // Merge additional data if provided
    if (additionalData != null) {
      summary.addAll(additionalData);
    }
    
    // Overwrite if exists (same day = overwrite)
    await summaryFile.writeAsString(const JsonEncoder.withIndent('  ').convert(summary));
  }
  
  Map<String, dynamic> _generateSummary() {
    final runEndTime = DateTime.now();
    final totalDuration = runEndTime.difference(_runStartTime);
    
    // HTTP Status Code Kategorisierung
    final totalPages = _processedPages.length;
    final httpStats = _calculateHttpStatusStats();
    final successfulPages = httpStats['successful'] as int;
    final redirectPages = httpStats['redirects'] as int;
    final errorPages = httpStats['errors'] as int;
    final crashedPages = httpStats['crashed'] as int;
    
    // Accessibility statistics
    final allViolations = _processedPages
        .expand((p) => (p['a11y']?['violations'] as List?) ?? [])
        .toList();
    final violationsByImpact = <String, int>{};
    for (final violation in allViolations) {
      final impact = violation['impact']?.toString() ?? 'unknown';
      violationsByImpact[impact] = (violationsByImpact[impact] ?? 0) + 1;
    }
    
    // Performance statistics
    final performanceStats = _calculateAggregatedPerformanceStats();
    
    // SEO statistics  
    final seoStats = _calculateAggregatedSEOStats();
    
    // Performance statistics
    final perfMetrics = _calculatePerformanceStats();
    
    // Engine performance
    final engineStats = _calculateEngineStats();
    
    return {
      'schemaVersion': '1.0.0',
      'runId': runId,
      'startedAt': _runStartTime.toIso8601String(),
      'finishedAt': runEndTime.toIso8601String(),
      'duration': {
        'totalMs': totalDuration.inMilliseconds,
        'formatted': _formatDuration(totalDuration),
      },
      'pages': {
        'total': totalPages,
        'successful': successfulPages,
        'redirects': redirectPages,
        'errors': errorPages,
        'crashed': crashedPages,
        'successRate': totalPages > 0 ? (((successfulPages + redirectPages) / totalPages) * 100).round() : 0,
        'httpStatusBreakdown': httpStats['breakdown'],
      },
      'violations': {
        'total': allViolations.length,
        'byImpact': violationsByImpact,
        'avgPerPage': totalPages > 0 ? (allViolations.length / totalPages).toStringAsFixed(1) : '0',
      },
      'performance': performanceStats,
      'seo': seoStats,
      'legacyPerf': perfMetrics, // Keep old format for compatibility
      'engine': engineStats,
      'urls': _processedPages.map((p) => p['url']).toList(),
    };
  }
  
  Map<String, dynamic> _calculatePerformanceStats() {
    final ttfbValues = <double>[];
    final fcpValues = <double>[];
    final lcpValues = <double>[];
    final dclValues = <double>[];
    
    for (final page in _processedPages) {
      final perf = page['perf'] as Map<String, dynamic>?;
      if (perf != null) {
        if (perf['ttfbMs'] is num) ttfbValues.add(perf['ttfbMs'].toDouble());
        if (perf['fcpMs'] is num) fcpValues.add(perf['fcpMs'].toDouble());
        if (perf['lcpMs'] is num) lcpValues.add(perf['lcpMs'].toDouble());
        if (perf['domContentLoadedMs'] is num) dclValues.add(perf['domContentLoadedMs'].toDouble());
      }
    }
    
    return {
      'ttfb': _calculateStats(ttfbValues, 'ms'),
      'fcp': _calculateStats(fcpValues, 'ms'),
      'lcp': _calculateStats(lcpValues, 'ms'),
      'domContentLoaded': _calculateStats(dclValues, 'ms'),
    };
  }
  
  Map<String, dynamic> _calculateEngineStats() {
    final taskDurations = <double>[];
    final peakRssValues = <int>[];
    
    for (final page in _processedPages) {
      final engine = page['perf']?['engine'] as Map<String, dynamic>?;
      if (engine != null) {
        if (engine['taskDurationMs'] is num) {
          taskDurations.add(engine['taskDurationMs'].toDouble());
        }
        if (engine['peakRssBytes'] is num) {
          peakRssValues.add(engine['peakRssBytes'].toInt());
        }
      }
    }
    
    return {
      'taskDuration': _calculateStats(taskDurations, 'ms'),
      'peakRss': _calculateStatsInt(peakRssValues, 'bytes'),
    };
  }
  
  Map<String, dynamic> _calculateStats(List<double> values, String unit) {
    if (values.isEmpty) {
      return {'count': 0, 'avg': null, 'min': null, 'max': null, 'unit': unit};
    }
    
    values.sort();
    final sum = values.reduce((a, b) => a + b);
    final avg = sum / values.length;
    final median = values.length % 2 == 0
        ? (values[values.length ~/ 2 - 1] + values[values.length ~/ 2]) / 2
        : values[values.length ~/ 2];
    
    return {
      'count': values.length,
      'avg': avg.round(),
      'median': median.round(),
      'min': values.first.round(),
      'max': values.last.round(),
      'unit': unit,
    };
  }
  
  Map<String, dynamic> _calculateStatsInt(List<int> values, String unit) {
    if (values.isEmpty) {
      return {'count': 0, 'avg': null, 'min': null, 'max': null, 'unit': unit};
    }
    
    values.sort();
    final sum = values.reduce((a, b) => a + b);
    final avg = sum / values.length;
    final median = values.length % 2 == 0
        ? (values[values.length ~/ 2 - 1] + values[values.length ~/ 2]) / 2
        : values[values.length ~/ 2].toDouble();
    
    return {
      'count': values.length,
      'avg': avg.round(),
      'median': median.round(),
      'min': values.first,
      'max': values.last,
      'unit': unit,
    };
  }
  
  String _formatDuration(Duration duration) {
    if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m ${duration.inSeconds % 60}s';
    }
    return '${duration.inSeconds}s';
  }
  
  /// Calculate HTTP status code statistics with proper redirect handling
  Map<String, dynamic> _calculateHttpStatusStats() {
    var successful = 0;  // 2xx Success
    var redirects = 0;   // 3xx Redirects (including 301) - nicht als Fehler zählen
    var errors = 0;      // 4xx Client errors + 5xx Server errors
    var crashed = 0;     // null status (browser crashes, network failures)
    
    final statusBreakdown = <String, int>{};
    
    for (final page in _processedPages) {
      final status = page['http']?['statusCode'] as int?;
      
      if (status == null) {
        // Kein HTTP-Status = Browser-Crash oder Netzwerk-Fehler
        crashed++;
        statusBreakdown['crashed'] = (statusBreakdown['crashed'] ?? 0) + 1;
      } else if (status >= 200 && status < 300) {
        // 2xx Success
        successful++;
        final statusKey = '${status}xx';
        statusBreakdown[statusKey] = (statusBreakdown[statusKey] ?? 0) + 1;
      } else if (status >= 300 && status < 400) {
        // 3xx Redirects - als erfolgreiche Navigation behandeln!
        // 301: Moved Permanently (gelöschte Seiten → Startseite) 
        // 302: Found (temporäre Redirects)
        redirects++;
        if (status == 301) {
          statusBreakdown['301 (Permanent Redirect)'] = (statusBreakdown['301 (Permanent Redirect)'] ?? 0) + 1;
        } else if (status == 302) {
          statusBreakdown['302 (Temporary Redirect)'] = (statusBreakdown['302 (Temporary Redirect)'] ?? 0) + 1;
        } else {
          statusBreakdown['3xx (Other Redirects)'] = (statusBreakdown['3xx (Other Redirects)'] ?? 0) + 1;
        }
      } else if (status >= 400) {
        // 4xx Client errors + 5xx Server errors
        errors++;
        if (status == 404) {
          statusBreakdown['404 (Not Found)'] = (statusBreakdown['404 (Not Found)'] ?? 0) + 1;
        } else if (status >= 400 && status < 500) {
          statusBreakdown['4xx (Client Error)'] = (statusBreakdown['4xx (Client Error)'] ?? 0) + 1;
        } else {
          statusBreakdown['5xx (Server Error)'] = (statusBreakdown['5xx (Server Error)'] ?? 0) + 1;
        }
      }
    }
    
    return {
      'successful': successful,
      'redirects': redirects,
      'errors': errors,
      'crashed': crashed,
      'breakdown': statusBreakdown,
    };
  }
  
  /// Calculate aggregated performance statistics
  Map<String, dynamic> _calculateAggregatedPerformanceStats() {
    final scores = <int>[];
    final grades = <String, int>{};
    final issuesByType = <String, int>{};
    
    for (final page in _processedPages) {
      final perfResult = page['performance'] as Map<String, dynamic>?;
      if (perfResult != null) {
        // Collect scores
        final score = perfResult['score'] as int?;
        if (score != null) scores.add(score);
        
        // Collect grades
        final grade = perfResult['grade'] as String?;
        if (grade != null) {
          grades[grade] = (grades[grade] ?? 0) + 1;
        }
        
        // Collect issues
        final issues = (perfResult['issues'] as List?) ?? [];
        for (final issue in issues) {
          final type = issue['type'] as String?;
          if (type != null) {
            issuesByType[type] = (issuesByType[type] ?? 0) + 1;
          }
        }
      }
    }
    
    return {
      'totalPagesWithPerf': scores.length,
      'averageScore': scores.isNotEmpty ? (scores.reduce((a, b) => a + b) / scores.length).round() : 0,
      'scoreDistribution': {
        'A (90-100)': scores.where((s) => s >= 90).length,
        'B (80-89)': scores.where((s) => s >= 80 && s < 90).length,
        'C (70-79)': scores.where((s) => s >= 70 && s < 80).length,
        'D (60-69)': scores.where((s) => s >= 60 && s < 70).length,
        'F (0-59)': scores.where((s) => s < 60).length,
      },
      'issuesByType': issuesByType,
    };
  }
  
  /// Calculate aggregated SEO statistics
  Map<String, dynamic> _calculateAggregatedSEOStats() {
    final scores = <int>[];
    final grades = <String, int>{};
    final issuesByType = <String, int>{};
    final titleIssues = <String, int>{};
    final descriptionIssues = <String, int>{};
    final headingIssues = <String, int>{};
    final imageIssues = <String, int>{};
    
    for (final page in _processedPages) {
      final seoResult = page['seo'] as Map<String, dynamic>?;
      if (seoResult != null) {
        // Collect scores
        final score = seoResult['score'] as int?;
        if (score != null) scores.add(score);
        
        // Collect grades
        final grade = seoResult['grade'] as String?;
        if (grade != null) {
          grades[grade] = (grades[grade] ?? 0) + 1;
        }
        
        // Collect issues
        final issues = (seoResult['issues'] as List?) ?? [];
        for (final issue in issues) {
          final type = issue['type'] as String?;
          if (type != null) {
            issuesByType[type] = (issuesByType[type] ?? 0) + 1;
            
            // Categorize issues
            if (type.contains('title')) {
              titleIssues[type] = (titleIssues[type] ?? 0) + 1;
            } else if (type.contains('description')) {
              descriptionIssues[type] = (descriptionIssues[type] ?? 0) + 1;
            } else if (type.contains('h1')) {
              headingIssues[type] = (headingIssues[type] ?? 0) + 1;
            } else if (type.contains('image')) {
              imageIssues[type] = (imageIssues[type] ?? 0) + 1;
            }
          }
        }
        
        // Collect meta tag statistics
        final metaTags = seoResult['metaTags'] as Map<String, dynamic>?;
        if (metaTags != null) {
          final title = metaTags['title'] as Map<String, dynamic>?;
          final description = metaTags['description'] as Map<String, dynamic>?;
          
          if (title == null) {
            titleIssues['missing'] = (titleIssues['missing'] ?? 0) + 1;
          }
          if (description == null) {
            descriptionIssues['missing'] = (descriptionIssues['missing'] ?? 0) + 1;
          }
        }
      }
    }
    
    return {
      'totalPagesWithSeo': scores.length,
      'averageScore': scores.isNotEmpty ? (scores.reduce((a, b) => a + b) / scores.length).round() : 0,
      'scoreDistribution': {
        'A (90-100)': scores.where((s) => s >= 90).length,
        'B (80-89)': scores.where((s) => s >= 80 && s < 90).length,
        'C (70-79)': scores.where((s) => s >= 70 && s < 80).length,
        'D (60-69)': scores.where((s) => s >= 60 && s < 70).length,
        'F (0-59)': scores.where((s) => s < 60).length,
      },
      'issuesByCategory': {
        'title': titleIssues,
        'description': descriptionIssues,
        'headings': headingIssues,
        'images': imageIssues,
      },
      'totalIssues': issuesByType.values.fold(0, (sum, count) => sum + count),
    };
  }
}
