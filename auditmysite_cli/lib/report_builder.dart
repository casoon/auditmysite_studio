import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:path/path.dart' as p;

class ReportBuilder {
  final Directory templatesDir;
  
  ReportBuilder({required this.templatesDir});

  Future<String> buildIndexReport({
    required String title,
    required List<Map<String, dynamic>> pages,
  }) async {
    final layoutTemplate = await File(p.join(templatesDir.path, 'layout.html')).readAsString();
    final indexTemplate = await File(p.join(templatesDir.path, 'index.html')).readAsString();

    // Calculate statistics
    final stats = _calculateStats(pages);
    final tableRows = _buildTableRows(pages);

    // Replace template variables in index content
    var indexContent = indexTemplate
        .replaceAll('{{total_pages}}', stats['totalPages'].toString())
        .replaceAll('{{total_violations}}', stats['totalViolations'].toString())
        .replaceAll('{{success_rate}}', stats['successRate'].toString())
        .replaceAll('{{avg_lcp}}', stats['avgLcp'].toString())
        .replaceAll('{{table_rows}}', tableRows);

    // Insert into layout
    return layoutTemplate
        .replaceAll('{{title}}', _escape(title))
        .replaceAll('{{meta}}', 'Generiert am ${DateTime.now().toLocal().toString().split('.')[0]}')
        .replaceAll('{{navigation}}', '')
        .replaceAll('{{content}}', indexContent.replaceAll('{{content_start}}', '').replaceAll('{{content_end}}', ''))
        .replaceAll('{{additional_styles}}', '')
        .replaceAll('{{scripts}}', '');
  }

  Future<String> buildPageReport({
    required String url,
    required Map<String, dynamic> pageData,
  }) async {
    final layoutTemplate = await File(p.join(templatesDir.path, 'layout.html')).readAsString();
    final pageTemplate = await File(p.join(templatesDir.path, 'page.html')).readAsString();

    // Process page data
    final statusCode = pageData['http']?['statusCode']?.toString() ?? 'N/A';
    final statusStyle = _getStatusStyle(pageData['http']?['statusCode']);
    
    final startedAt = _formatTimestamp(pageData['startedAt']);
    final finishedAt = _formatTimestamp(pageData['finishedAt']);
    final duration = _calculateDuration(pageData['startedAt'], pageData['finishedAt']);

    // Performance metrics
    final perf = pageData['perf'] ?? {};
    final ttfb = _formatMetric(perf['ttfbMs']);
    final fcp = _formatMetric(perf['fcpMs']);
    final lcp = _formatMetric(perf['lcpMs']);
    final dcl = _formatMetric(perf['domContentLoadedMs']);

    // Accessibility content
    final accessibilityContent = _buildAccessibilityContent(pageData['a11y']);
    final consoleErrorsSection = _buildConsoleErrorsSection(pageData['consoleErrors']);
    final screenshotSection = _buildScreenshotSection(pageData['screenshotPath']);

    // Replace template variables
    var pageContent = pageTemplate
        .replaceAll('{{status_code}}', statusCode)
        .replaceAll('{{status_style}}', statusStyle)
        .replaceAll('{{started_at}}', startedAt)
        .replaceAll('{{finished_at}}', finishedAt)
        .replaceAll('{{duration}}', duration)
        .replaceAll('{{ttfb_ms}}', ttfb)
        .replaceAll('{{fcp_ms}}', fcp)
        .replaceAll('{{lcp_ms}}', lcp)
        .replaceAll('{{dcl_ms}}', dcl)
        .replaceAll('{{ttfb_color}}', _getPerformanceColor(perf['ttfbMs'], [100, 300]))
        .replaceAll('{{fcp_color}}', _getPerformanceColor(perf['fcpMs'], [1800, 3000]))
        .replaceAll('{{lcp_color}}', _getPerformanceColor(perf['lcpMs'], [2500, 4000]))
        .replaceAll('{{accessibility_content}}', accessibilityContent)
        .replaceAll('{{console_errors_section}}', consoleErrorsSection)
        .replaceAll('{{screenshot_section}}', screenshotSection);

    // Insert into layout
    return layoutTemplate
        .replaceAll('{{title}}', _escape(url))
        .replaceAll('{{meta}}', 'Audit Details')
        .replaceAll('{{navigation}}', '')
        .replaceAll('{{content}}', pageContent.replaceAll('{{content_start}}', '').replaceAll('{{content_end}}', ''))
        .replaceAll('{{additional_styles}}', _getPageStyles())
        .replaceAll('{{scripts}}', '');
  }

  Map<String, dynamic> _calculateStats(List<Map<String, dynamic>> pages) {
    int totalViolations = 0;
    int successCount = 0;
    final performanceStats = _calculatePerformanceHistograms(pages);
    final violationStats = _calculateViolationStats(pages);
    final statusStats = _calculateStatusStats(pages);

    for (final page in pages) {
      // Count violations
      final violations = (page['a11y']?['violations'] as List?) ?? [];
      totalViolations += violations.length;

      // Count success status codes (2xx)
      final statusCode = page['http']?['statusCode'];
      if (statusCode != null && statusCode >= 200 && statusCode < 300) {
        successCount++;
      }
    }

    final successRate = pages.isEmpty ? 0 : ((successCount / pages.length) * 100).round();

    return {
      'totalPages': pages.length,
      'totalViolations': totalViolations,
      'successRate': successRate,
      'avgLcp': performanceStats['lcp']['avg'] ?? 0,
      'performanceStats': performanceStats,
      'violationStats': violationStats,
      'statusStats': statusStats,
    };
  }
  
  Map<String, dynamic> _calculatePerformanceHistograms(List<Map<String, dynamic>> pages) {
    final ttfbValues = <double>[];
    final fcpValues = <double>[];
    final lcpValues = <double>[];
    final dclValues = <double>[];
    
    for (final page in pages) {
      final perf = page['perf'] as Map<String, dynamic>?;
      if (perf != null) {
        if (perf['ttfbMs'] is num) ttfbValues.add(perf['ttfbMs'].toDouble());
        if (perf['fcpMs'] is num) fcpValues.add(perf['fcpMs'].toDouble());
        if (perf['lcpMs'] is num) lcpValues.add(perf['lcpMs'].toDouble());
        if (perf['domContentLoadedMs'] is num) dclValues.add(perf['domContentLoadedMs'].toDouble());
      }
    }
    
    return {
      'ttfb': _buildHistogramStats(ttfbValues, [100, 300, 600], 'TTFB'),
      'fcp': _buildHistogramStats(fcpValues, [1000, 2500, 5000], 'FCP'),
      'lcp': _buildHistogramStats(lcpValues, [2500, 4000, 7000], 'LCP'),
      'dcl': _buildHistogramStats(dclValues, [800, 1600, 3200], 'DCL'),
    };
  }
  
  Map<String, dynamic> _calculateViolationStats(List<Map<String, dynamic>> pages) {
    final impactCounts = <String, int>{'critical': 0, 'serious': 0, 'moderate': 0, 'minor': 0};
    final violationCounts = <int>[];
    final ruleBreakdown = <String, int>{};
    
    for (final page in pages) {
      final violations = (page['a11y']?['violations'] as List?) ?? [];
      violationCounts.add(violations.length);
      
      for (final violation in violations) {
        final impact = violation['impact']?.toString() ?? 'minor';
        final ruleId = violation['id']?.toString() ?? 'unknown';
        
        impactCounts[impact] = (impactCounts[impact] ?? 0) + 1;
        ruleBreakdown[ruleId] = (ruleBreakdown[ruleId] ?? 0) + 1;
      }
    }
    
    // Calculate violation distribution buckets
    final violationBuckets = {'0': 0, '1-5': 0, '6-20': 0, '21+': 0};
    for (final count in violationCounts) {
      if (count == 0) violationBuckets['0'] = violationBuckets['0']! + 1;
      else if (count <= 5) violationBuckets['1-5'] = violationBuckets['1-5']! + 1;
      else if (count <= 20) violationBuckets['6-20'] = violationBuckets['6-20']! + 1;
      else violationBuckets['21+'] = violationBuckets['21+']! + 1;
    }
    
    // Top 5 most common violations
    final sortedRules = ruleBreakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topViolations = Map.fromEntries(sortedRules.take(5));
    
    return {
      'byImpact': impactCounts,
      'distribution': violationBuckets,
      'topViolations': topViolations,
    };
  }
  
  Map<String, dynamic> _calculateStatusStats(List<Map<String, dynamic>> pages) {
    final statusCounts = <String, int>{};
    
    for (final page in pages) {
      final statusCode = page['http']?['statusCode'];
      final statusGroup = _getStatusGroup(statusCode);
      statusCounts[statusGroup] = (statusCounts[statusGroup] ?? 0) + 1;
    }
    
    return statusCounts;
  }
  
  Map<String, dynamic> _buildHistogramStats(List<double> values, List<int> thresholds, String metric) {
    if (values.isEmpty) {
      return {'avg': 0, 'median': 0, 'p90': 0, 'p95': 0, 'buckets': {}, 'count': 0};
    }
    
    values.sort();
    final avg = values.reduce((a, b) => a + b) / values.length;
    final median = _getPercentile(values, 50);
    final p90 = _getPercentile(values, 90);
    final p95 = _getPercentile(values, 95);
    
    // Create histogram buckets
    final buckets = <String, int>{};
    final bucketLabels = [
      'Good (≤${thresholds[0]}ms)',
      'Needs Improvement (${thresholds[0]+1}-${thresholds[1]}ms)',
      'Poor (${thresholds[1]+1}-${thresholds[2]}ms)',
      'Critical (>${thresholds[2]}ms)',
    ];
    
    for (final label in bucketLabels) {
      buckets[label] = 0;
    }
    
    for (final value in values) {
      if (value <= thresholds[0]) {
        buckets[bucketLabels[0]] = buckets[bucketLabels[0]]! + 1;
      } else if (value <= thresholds[1]) {
        buckets[bucketLabels[1]] = buckets[bucketLabels[1]]! + 1;
      } else if (value <= thresholds[2]) {
        buckets[bucketLabels[2]] = buckets[bucketLabels[2]]! + 1;
      } else {
        buckets[bucketLabels[3]] = buckets[bucketLabels[3]]! + 1;
      }
    }
    
    return {
      'avg': avg.round(),
      'median': median.round(),
      'p90': p90.round(),
      'p95': p95.round(),
      'buckets': buckets,
      'count': values.length,
    };
  }
  
  double _getPercentile(List<double> sortedValues, int percentile) {
    if (sortedValues.isEmpty) return 0;
    final index = (percentile / 100.0) * (sortedValues.length - 1);
    if (index == index.floor()) {
      return sortedValues[index.round()];
    }
    final lower = sortedValues[index.floor()];
    final upper = sortedValues[index.ceil()];
    return lower + (upper - lower) * (index - index.floor());
  }
  
  String _getStatusGroup(int? statusCode) {
    if (statusCode == null) return 'Unknown';
    if (statusCode >= 200 && statusCode < 300) return '2xx Success';
    if (statusCode >= 300 && statusCode < 400) return '3xx Redirect';
    if (statusCode >= 400 && statusCode < 500) return '4xx Client Error';
    if (statusCode >= 500) return '5xx Server Error';
    return 'Other';
  }

  String _buildTableRows(List<Map<String, dynamic>> pages) {
    return pages.map((page) {
      final url = page['url'] as String;
      final slug = url.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      final statusCode = page['http']?['statusCode']?.toString() ?? 'N/A';
      final violations = (page['a11y']?['violations'] as List?)?.length ?? 0;
      final maxImpact = _getMaxImpact(page['a11y']?['violations']);
      final ttfb = _formatMetric(page['perf']?['ttfbMs']);
      final lcp = _formatMetric(page['perf']?['lcpMs']);

      return '''
        <tr>
          <td><a href="pages/$slug.html">${_escape(url)}</a></td>
          <td><span style="${_getStatusStyle(page['http']?['statusCode'])}">$statusCode</span></td>
          <td><span style="${_getViolationStyle(violations)}">$violations</span></td>
          <td><span style="${_getImpactStyle(maxImpact)}">$maxImpact</span></td>
          <td>$ttfb</td>
          <td>$lcp</td>
        </tr>
      ''';
    }).join('\n');
  }

  String _buildAccessibilityContent(Map<String, dynamic>? a11yData) {
    if (a11yData == null) {
      return '<p class="text-muted">Accessibility-Audit nicht verfügbar.</p>';
    }

    final violations = (a11yData['violations'] as List?) ?? [];
    
    if (violations.isEmpty) {
      return '''
        <div style="text-align: center; padding: 32px; background: #d4edda; border-radius: 8px; color: #155724;">
          <div style="font-size: 3rem;">🎉</div>
          <h3>Keine Accessibility-Violations gefunden!</h3>
          <p>Diese Seite erfüllt die axe-core Accessibility-Standards.</p>
        </div>
      ''';
    }

    // Group violations by impact
    final groupedViolations = <String, List<dynamic>>{};
    for (final violation in violations) {
      final impact = violation['impact']?.toString() ?? 'minor';
      groupedViolations.putIfAbsent(impact, () => []).add(violation);
    }

    final impactOrder = ['critical', 'serious', 'moderate', 'minor'];
    final sections = <String>[];

    for (final impact in impactOrder) {
      if (!groupedViolations.containsKey(impact)) continue;
      
      final impactViolations = groupedViolations[impact]!;
      final impactStyle = _getImpactStyle(impact);
      
      sections.add('''
        <div style="margin-bottom: 24px;">
          <h3 style="color: ${_getImpactColor(impact)}; margin-bottom: 12px;">
            <span style="$impactStyle">${impact.toUpperCase()}</span> 
            (${impactViolations.length})
          </h3>
          ${_buildViolationTable(impactViolations)}
        </div>
      ''');
    }

    return sections.join('\n');
  }

  String _buildViolationTable(List<dynamic> violations) {
    final rows = violations.map((violation) {
      final id = violation['id']?.toString() ?? '';
      final help = violation['help']?.toString() ?? '';
      final description = violation['description']?.toString() ?? '';
      final nodes = (violation['nodes'] as List?) ?? [];
      final nodeCount = nodes.length;

      return '''
        <tr>
          <td><code>${_escape(id)}</code></td>
          <td>${_escape(help)}</td>
          <td>${_escape(description)}</td>
          <td><span style="background: #e9ecef; padding: 2px 6px; border-radius: 4px;">$nodeCount Elemente</span></td>
        </tr>
      ''';
    }).join('\n');

    return '''
      <div class="table-container">
        <table>
          <thead>
            <tr>
              <th>Rule ID</th>
              <th>Hilfe</th>
              <th>Beschreibung</th>
              <th>Betroffene Elemente</th>
            </tr>
          </thead>
          <tbody>
            $rows
          </tbody>
        </table>
      </div>
    ''';
  }

  String _buildConsoleErrorsSection(dynamic consoleErrors) {
    final errors = (consoleErrors as List?)?.cast<String>() ?? [];
    
    if (errors.isEmpty) {
      return '';
    }

    final errorItems = errors.map((error) => '<li>${_escape(error)}</li>').join('\n');
    
    return '''
      <div class="card">
        <h2 style="color: #dc3545;">Console Errors (${errors.length})</h2>
        <div style="background: #f8d7da; border: 1px solid #f5c2c7; border-radius: 8px; padding: 16px;">
          <ul style="margin: 0; padding-left: 20px;">
            $errorItems
          </ul>
        </div>
      </div>
    ''';
  }

  String _buildScreenshotSection(String? screenshotPath) {
    if (screenshotPath == null || screenshotPath.isEmpty) {
      return '';
    }

    return '''
      <div class="card">
        <h2>Screenshot</h2>
        <div style="text-align: center; background: #f8f9fa; padding: 16px; border-radius: 8px;">
          <img src="../$screenshotPath" alt="Screenshot" 
               style="max-width: 100%; height: auto; border-radius: 8px; box-shadow: 0 4px 12px rgba(0,0,0,0.15);">
        </div>
      </div>
    ''';
  }

  String _getStatusStyle(int? statusCode) {
    if (statusCode == null) return 'color: #6c757d;';
    if (statusCode >= 200 && statusCode < 300) return 'color: #28a745; font-weight: 600;';
    if (statusCode >= 300 && statusCode < 400) return 'color: #ffc107; font-weight: 600;';
    if (statusCode >= 400 && statusCode < 500) return 'color: #fd7e14; font-weight: 600;';
    if (statusCode >= 500) return 'color: #dc3545; font-weight: 600;';
    return 'color: #6c757d;';
  }

  String _getViolationStyle(int count) {
    if (count == 0) return 'color: #28a745; font-weight: 600;';
    if (count <= 5) return 'color: #ffc107; font-weight: 600;';
    return 'color: #dc3545; font-weight: 600;';
  }

  String _getMaxImpact(List<dynamic>? violations) {
    if (violations == null || violations.isEmpty) return 'none';
    
    final impacts = violations
        .map((v) => v['impact']?.toString())
        .where((impact) => impact != null)
        .toList();
    
    if (impacts.contains('critical')) return 'critical';
    if (impacts.contains('serious')) return 'serious';
    if (impacts.contains('moderate')) return 'moderate';
    if (impacts.contains('minor')) return 'minor';
    return 'none';
  }

  String _getImpactStyle(String impact) {
    switch (impact.toLowerCase()) {
      case 'critical':
        return 'background: #dc3545; color: white; padding: 2px 8px; border-radius: 4px; font-size: 0.85rem; font-weight: 600;';
      case 'serious':
        return 'background: #fd7e14; color: white; padding: 2px 8px; border-radius: 4px; font-size: 0.85rem; font-weight: 600;';
      case 'moderate':
        return 'background: #ffc107; color: #000; padding: 2px 8px; border-radius: 4px; font-size: 0.85rem; font-weight: 600;';
      case 'minor':
        return 'background: #28a745; color: white; padding: 2px 8px; border-radius: 4px; font-size: 0.85rem; font-weight: 600;';
      case 'none':
        return 'background: #6c757d; color: white; padding: 2px 8px; border-radius: 4px; font-size: 0.85rem; font-weight: 600;';
      default:
        return 'background: #6c757d; color: white; padding: 2px 8px; border-radius: 4px; font-size: 0.85rem; font-weight: 600;';
    }
  }

  String _getImpactColor(String impact) {
    switch (impact.toLowerCase()) {
      case 'critical': return '#dc3545';
      case 'serious': return '#fd7e14';
      case 'moderate': return '#ffc107';
      case 'minor': return '#28a745';
      default: return '#6c757d';
    }
  }

  String _getPerformanceColor(dynamic value, List<int> thresholds) {
    if (value == null || value is! num) return '#6c757d';
    final val = value.toDouble();
    
    if (val <= thresholds[0]) return '#28a745'; // Good
    if (val <= thresholds[1]) return '#ffc107'; // Needs improvement
    return '#dc3545'; // Poor
  }

  String _formatMetric(dynamic value) {
    if (value == null || value is! num) return 'N/A';
    return value.toDouble().round().toString();
  }

  String _formatTimestamp(String? timestamp) {
    if (timestamp == null) return 'N/A';
    try {
      final dt = DateTime.parse(timestamp);
      return dt.toLocal().toString().split('.')[0];
    } catch (e) {
      return timestamp;
    }
  }

  String _calculateDuration(String? start, String? end) {
    if (start == null || end == null) return 'N/A';
    try {
      final startTime = DateTime.parse(start);
      final endTime = DateTime.parse(end);
      final duration = endTime.difference(startTime);
      
      if (duration.inSeconds < 60) {
        return '${duration.inSeconds}s';
      } else {
        final minutes = duration.inMinutes;
        final seconds = duration.inSeconds % 60;
        return '${minutes}m ${seconds}s';
      }
    } catch (e) {
      return 'N/A';
    }
  }

  String _getPageStyles() {
    return '''
      <style>
        .impact-critical { color: #dc3545; font-weight: 600; }
        .impact-serious { color: #fd7e14; font-weight: 600; }
        .impact-moderate { color: #ffc107; font-weight: 600; }
        .impact-minor { color: #28a745; font-weight: 600; }
        code { background: #f8f9fa; padding: 2px 6px; border-radius: 4px; font-size: 0.9em; }
      </style>
    ''';
  }

  String _escape(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }
}
