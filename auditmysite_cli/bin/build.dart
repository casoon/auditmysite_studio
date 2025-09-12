import 'dart:convert';
import 'dart:io';
import 'package:args/args.dart';
import 'package:path/path.dart' as p;
import 'package:auditmysite_cli/report_builder.dart';

Future<void> main(List<String> args) async {
  final parser = ArgParser()
    ..addOption('in', help: 'Input pages dir: artifacts/<runId>/pages', mandatory: true)
    ..addOption('out', help: 'Output report dir', defaultsTo: './reports')
    ..addOption('title', defaultsTo: 'Audit Report')
    ..addOption('format', allowed: ['html', 'csv', 'json', 'all'], 
                defaultsTo: 'html', help: 'Output format (html, csv, json, or all)')
    ..addFlag('help', abbr: 'h', help: 'Show this help message', negatable: false);

  final opts = parser.parse(args);
  
  if (opts['help'] as bool) {
    print('AuditMySite CLI - Generate reports from audit results\n');
    print(parser.usage);
    return;
  }
  
  final inDir = Directory(opts['in'] as String);
  final outDir = Directory(opts['out'] as String)..createSync(recursive: true);
  final title = opts['title'] as String;
  final format = opts['format'] as String;

  if (!inDir.existsSync()) {
    stderr.writeln('Fehler: Input-Verzeichnis nicht gefunden: ${inDir.path}');
    exit(1);
  }

  final pages = <Map<String, dynamic>>[];
  final jsonFiles = inDir.listSync(recursive: true)
      .where((entity) => entity is File && entity.path.endsWith('.json'))
      .cast<File>();
      
  for (final file in jsonFiles) {
    try {
      final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      pages.add(json);
    } catch (e) {
      print('Warnung: Konnte ${file.path} nicht parsen: $e');
    }
  }

  print('Verarbeite ${pages.length} Seiten...');

  final builder = ReportBuilder(
    templatesDir: Directory(p.join(Directory.current.path, 'lib', 'templates')),
  );

  // Generate reports based on format
  final outputFiles = <String>[];
  
  if (format == 'html' || format == 'all') {
    await _generateHtmlReports(builder, title, pages, outDir);
    outputFiles.add('${outDir.path}/index.html');
  }
  
  if (format == 'csv' || format == 'all') {
    await _generateCsvReports(pages, outDir, title);
    outputFiles.add('${outDir.path}/audit_summary.csv');
    outputFiles.add('${outDir.path}/audit_violations.csv');
  }
  
  if (format == 'json' || format == 'all') {
    await _generateJsonReports(pages, outDir, title);
    outputFiles.add('${outDir.path}/audit_results.json');
  }
  
  print('Report erstellt:');
  for (final file in outputFiles) {
    print('  - $file');
  }
}

// HTML Report Generation
Future<void> _generateHtmlReports(ReportBuilder builder, String title, List<Map<String, dynamic>> pages, Directory outDir) async {
  // Check templates exist
  if (!builder.templatesDir.existsSync()) {
    stderr.writeln('Fehler: Templates-Verzeichnis nicht gefunden: ${builder.templatesDir.path}');
    exit(1);
  }
  
  // Build index report
  final indexHtml = await builder.buildIndexReport(title: title, pages: pages);
  await File(p.join(outDir.path, 'index.html')).writeAsString(indexHtml);

  // Build detail pages
  final pageDir = Directory(p.join(outDir.path, 'pages'))..createSync(recursive: true);
  for (final json in pages) {
    final url = (json['url'] as String);
    final slug = url.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    final html = await builder.buildPageReport(url: url, pageData: json);
    await File(p.join(pageDir.path, '$slug.html')).writeAsString(html);
  }
}

// CSV Report Generation
Future<void> _generateCsvReports(List<Map<String, dynamic>> pages, Directory outDir, String title) async {
  // Summary CSV
  final summaryRows = <String>[];
  summaryRows.add('URL,Status Code,Violations,Max Impact,TTFB (ms),FCP (ms),LCP (ms),DCL (ms),Processing Time (ms)');
  
  for (final page in pages) {
    final url = page['url'] as String? ?? '';
    final statusCode = page['http']?['statusCode'] ?? '';
    final violations = (page['a11y']?['violations'] as List?)?.length ?? 0;
    final maxImpact = _getMaxImpact(page['a11y']?['violations']);
    final ttfb = page['perf']?['ttfbMs'] ?? '';
    final fcp = page['perf']?['fcpMs'] ?? '';
    final lcp = page['perf']?['lcpMs'] ?? '';
    final dcl = page['perf']?['dclMs'] ?? '';
    final processingTime = page['meta']?['processingTimeMs'] ?? '';
    
    summaryRows.add('"$url",$statusCode,$violations,$maxImpact,$ttfb,$fcp,$lcp,$dcl,$processingTime');
  }
  
  await File(p.join(outDir.path, 'audit_summary.csv')).writeAsString(summaryRows.join('\n'));
  
  // Violations CSV
  final violationRows = <String>[];
  violationRows.add('URL,Rule ID,Impact,Description,Help,Target');
  
  for (final page in pages) {
    final url = page['url'] as String? ?? '';
    final violations = page['a11y']?['violations'] as List? ?? [];
    
    for (final violation in violations) {
      final id = violation['id'] as String? ?? '';
      final impact = violation['impact'] as String? ?? '';
      final description = violation['description'] as String? ?? '';
      final help = violation['help'] as String? ?? '';
      final targets = (violation['nodes'] as List? ?? [])
          .map((node) => node['target']?.join(' ') ?? '')
          .join('; ');
      
      violationRows.add('"$url","$id","$impact","$description","$help","$targets"');
    }
  }
  
  await File(p.join(outDir.path, 'audit_violations.csv')).writeAsString(violationRows.join('\n'));
}

// JSON Report Generation
Future<void> _generateJsonReports(List<Map<String, dynamic>> pages, Directory outDir, String title) async {
  final timestamp = DateTime.now().toIso8601String();
  
  final report = {
    'meta': {
      'title': title,
      'generated_at': timestamp,
      'total_pages': pages.length,
      'tool': 'auditmysite_cli',
      'version': '1.0.0',
    },
    'summary': _generateSummaryStats(pages),
    'pages': pages,
  };
  
  const encoder = JsonEncoder.withIndent('  ');
  await File(p.join(outDir.path, 'audit_results.json')).writeAsString(encoder.convert(report));
}

// Helper Functions
String _getMaxImpact(List? violations) {
  if (violations == null || violations.isEmpty) return 'none';
  
  final impacts = violations.map((v) => v['impact'] as String? ?? '').toList();
  
  if (impacts.contains('critical')) return 'critical';
  if (impacts.contains('serious')) return 'serious';
  if (impacts.contains('moderate')) return 'moderate';
  if (impacts.contains('minor')) return 'minor';
  
  return 'unknown';
}

Map<String, dynamic> _generateSummaryStats(List<Map<String, dynamic>> pages) {
  if (pages.isEmpty) {
    return {
      'total_pages': 0,
      'successful_pages': 0,
      'failed_pages': 0,
      'total_violations': 0,
      'performance': {},
    };
  }
  
  var successfulPages = 0;
  var failedPages = 0;
  var totalViolations = 0;
  final ttfbValues = <double>[];
  final fcpValues = <double>[];
  final lcpValues = <double>[];
  
  for (final page in pages) {
    final statusCode = page['http']?['statusCode'] as int?;
    if (statusCode != null && statusCode >= 200 && statusCode < 300) {
      successfulPages++;
    } else {
      failedPages++;
    }
    
    final violations = page['a11y']?['violations'] as List? ?? [];
    totalViolations += violations.length;
    
    final ttfb = page['perf']?['ttfbMs'];
    if (ttfb != null && ttfb is num) ttfbValues.add(ttfb.toDouble());
    
    final fcp = page['perf']?['fcpMs'];
    if (fcp != null && fcp is num) fcpValues.add(fcp.toDouble());
    
    final lcp = page['perf']?['lcpMs'];
    if (lcp != null && lcp is num) lcpValues.add(lcp.toDouble());
  }
  
  return {
    'total_pages': pages.length,
    'successful_pages': successfulPages,
    'failed_pages': failedPages,
    'success_rate': pages.length > 0 ? (successfulPages / pages.length * 100).round() : 0,
    'total_violations': totalViolations,
    'average_violations': pages.length > 0 ? (totalViolations / pages.length).round() : 0,
    'performance': {
      'ttfb_ms': {
        'average': ttfbValues.isEmpty ? null : (ttfbValues.reduce((a, b) => a + b) / ttfbValues.length).round(),
        'min': ttfbValues.isEmpty ? null : ttfbValues.reduce((a, b) => a < b ? a : b).round(),
        'max': ttfbValues.isEmpty ? null : ttfbValues.reduce((a, b) => a > b ? a : b).round(),
      },
      'fcp_ms': {
        'average': fcpValues.isEmpty ? null : (fcpValues.reduce((a, b) => a + b) / fcpValues.length).round(),
        'min': fcpValues.isEmpty ? null : fcpValues.reduce((a, b) => a < b ? a : b).round(),
        'max': fcpValues.isEmpty ? null : fcpValues.reduce((a, b) => a > b ? a : b).round(),
      },
      'lcp_ms': {
        'average': lcpValues.isEmpty ? null : (lcpValues.reduce((a, b) => a + b) / lcpValues.length).round(),
        'min': lcpValues.isEmpty ? null : lcpValues.reduce((a, b) => a < b ? a : b).round(),
        'max': lcpValues.isEmpty ? null : lcpValues.reduce((a, b) => a > b ? a : b).round(),
      },
    },
  };
}

// All template rendering is now handled by ReportBuilder
