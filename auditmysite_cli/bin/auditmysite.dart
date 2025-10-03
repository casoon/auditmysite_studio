#!/usr/bin/env dart

import 'dart:io';
import 'dart:convert';
import 'package:args/args.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;

/// AuditMySite CLI Tool
/// Professional website auditing from the command line
void main(List<String> arguments) async {
  // Setup logging
  _setupLogging();
  
  final logger = Logger('AuditMySite');
  
  // Parse command line arguments
  final parser = _createArgParser();
  
  try {
    final results = parser.parse(arguments);
    
    // Handle help
    if (results['help'] as bool) {
      _printUsage(parser);
      exit(0);
    }
    
    // Handle version
    if (results['version'] as bool) {
      print('AuditMySite v2.0.0');
      exit(0);
    }
    
    // Create CLI instance
    final cli = AuditMySiteCLI(results, logger);
    
    // Run the appropriate command
    await cli.run();
    
  } catch (e) {
    logger.severe('Error: $e');
    print('\nError: $e\n');
    _printUsage(parser);
    exit(1);
  }
}

/// Main CLI class
class AuditMySiteCLI {
  final ArgResults args;
  final Logger logger;
  
  AuditMySiteCLI(this.args, this.logger);
  
  Future<void> run() async {
    // Determine command
    if (args.rest.isEmpty && args['url'] == null && args['sitemap'] == null) {
      throw ArgumentError('No URL or sitemap provided. Use --url or --sitemap');
    }
    
    // Get configuration
    final config = await _loadConfig();
    
    // Handle different modes
    if (args['serve'] as bool) {
      await _runServer(config);
    } else if (args['watch'] as bool) {
      await _runWatchMode(config);
    } else if (args['batch'] as bool || args['sitemap'] != null) {
      await _runBatchMode(config);
    } else if (args['compare'] as bool) {
      await _runCompareMode(config);
    } else if (args['report-only'] as bool) {
      await _generateReportOnly(config);
    } else {
      await _runSingleAudit(config);
    }
  }
  
  /// Run single URL audit
  Future<void> _runSingleAudit(Map<String, dynamic> config) async {
    final url = args['url'] ?? args.rest.first;
    
    if (!args['quiet']) {
      print('🔍 Auditing: $url');
    }
    
    // Show progress spinner if not quiet
    final spinner = args['quiet'] ? null : Spinner('Running audit...');
    spinner?.start();
    
    try {
      // Create audit configuration
      final auditConfig = _createAuditConfig(config);
      
      // Run audit (placeholder - would call actual audit engine)
      final results = await _runAudit(url, auditConfig);
      
      spinner?.stop();
      
      // Output results
      await _outputResults(results);
      
      if (!args['quiet']) {
        print('✅ Audit complete!');
      }
      
    } catch (e) {
      spinner?.stop();
      throw e;
    }
  }
  
  /// Run batch mode for multiple URLs
  Future<void> _runBatchMode(Map<String, dynamic> config) async {
    final sitemap = args['sitemap'];
    List<String> urls;
    
    if (sitemap != null) {
      if (!args['quiet']) {
        print('📋 Loading sitemap: $sitemap');
      }
      urls = await _loadSitemap(sitemap, config);
    } else {
      urls = args.rest;
    }
    
    if (!args['quiet']) {
      print('🔄 Processing ${urls.length} URLs...');
    }
    
    final concurrency = int.tryParse(args['concurrency'] ?? '4') ?? 4;
    final progress = ProgressBar(total: urls.length, quiet: args['quiet']);
    
    // Process URLs with concurrency limit
    final results = <Map<String, dynamic>>[];
    final pool = Pool(concurrency);
    
    await Future.wait(urls.map((url) async {
      await pool.acquire();
      try {
        final result = await _runAudit(url, _createAuditConfig(config));
        results.add(result);
        progress.increment();
      } finally {
        pool.release();
      }
    }));
    
    progress.complete();
    
    // Generate batch report
    await _outputBatchResults(results);
    
    if (!args['quiet']) {
      print('✅ Batch audit complete! Processed ${urls.length} URLs');
    }
  }
  
  /// Run server mode
  Future<void> _runServer(Map<String, dynamic> config) async {
    final port = int.tryParse(args['port'] ?? '8080') ?? 8080;
    
    print('🚀 Starting AuditMySite server on port $port');
    print('   API endpoint: http://localhost:$port/api/audit');
    print('   Dashboard: http://localhost:$port');
    print('\nPress Ctrl+C to stop\n');
    
    // Start HTTP server
    final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
    
    await for (HttpRequest request in server) {
      _handleServerRequest(request, config);
    }
  }
  
  /// Run watch mode
  Future<void> _runWatchMode(Map<String, dynamic> config) async {
    final url = args['url'] ?? args.rest.first;
    final interval = int.tryParse(args['watch-interval'] ?? '60') ?? 60;
    
    print('👀 Watching: $url');
    print('   Interval: ${interval}s');
    print('\nPress Ctrl+C to stop\n');
    
    while (true) {
      try {
        final results = await _runAudit(url, _createAuditConfig(config));
        await _outputResults(results);
        
        // Check for changes
        if (_hasSignificantChanges(results)) {
          print('⚠️  Significant changes detected!');
          if (args['notify'] as bool) {
            await _sendNotification(results);
          }
        }
        
      } catch (e) {
        logger.warning('Audit failed: $e');
      }
      
      await Future.delayed(Duration(seconds: interval));
    }
  }
  
  /// Run compare mode
  Future<void> _runCompareMode(Map<String, dynamic> config) async {
    final urls = args.rest;
    if (urls.length < 2) {
      throw ArgumentError('Compare mode requires at least 2 URLs');
    }
    
    print('📊 Comparing ${urls.length} URLs...\n');
    
    // Run audits for all URLs
    final results = <String, Map<String, dynamic>>{};
    for (final url in urls) {
      print('  Auditing: $url');
      results[url] = await _runAudit(url, _createAuditConfig(config));
    }
    
    // Generate comparison report
    await _generateComparisonReport(results);
    
    print('\n✅ Comparison complete!');
  }
  
  /// Generate report from existing results
  Future<void> _generateReportOnly(Map<String, dynamic> config) async {
    final input = args['input'];
    if (input == null) {
      throw ArgumentError('--input required for report-only mode');
    }
    
    print('📄 Generating report from: $input');
    
    // Load results
    final file = File(input);
    if (!await file.exists()) {
      throw ArgumentError('Input file not found: $input');
    }
    
    final results = jsonDecode(await file.readAsString());
    
    // Generate report
    await _outputResults(results);
    
    print('✅ Report generated!');
  }
  
  /// Create audit configuration
  Map<String, dynamic> _createAuditConfig(Map<String, dynamic> config) {
    return {
      ...config,
      'headless': !(args['no-headless'] as bool),
      'throttling': args['throttle'] as bool,
      'device': args['device'],
      'userAgent': args['user-agent'],
      'viewport': _parseViewport(args['viewport']),
      'timeout': int.tryParse(args['timeout'] ?? '30000') ?? 30000,
      'waitUntil': args['wait-until'] ?? 'networkidle',
      'screenshot': args['screenshot'] as bool,
      'fullPage': args['full-page'] as bool,
      'categories': _parseCategories(args['only-categories'], args['skip-categories']),
      'audits': _parseAudits(args['only-audits'], args['skip-audits']),
    };
  }
  
  /// Output results based on format
  Future<void> _outputResults(Map<String, dynamic> results) async {
    final format = args['format'] ?? 'cli';
    final output = args['output'];
    
    String formattedOutput;
    
    switch (format) {
      case 'json':
        formattedOutput = _formatJson(results);
        break;
      case 'html':
        formattedOutput = await _generateHtmlReport(results);
        break;
      case 'csv':
        formattedOutput = _formatCsv(results);
        break;
      case 'markdown':
        formattedOutput = _formatMarkdown(results);
        break;
      case 'cli':
      default:
        formattedOutput = _formatCli(results);
        break;
    }
    
    if (output != null) {
      final file = File(output);
      await file.writeAsString(formattedOutput);
      if (!args['quiet']) {
        print('💾 Report saved to: $output');
      }
    } else if (format != 'cli' || args['verbose']) {
      print(formattedOutput);
    }
  }
  
  /// Format results for CLI display
  String _formatCli(Map<String, dynamic> results) {
    final buffer = StringBuffer();
    
    // Header
    buffer.writeln('\n' + '═' * 60);
    buffer.writeln('  AuditMySite Results');
    buffer.writeln('  URL: ${results['url']}');
    buffer.writeln('  Date: ${DateTime.now().toLocal()}');
    buffer.writeln('═' * 60 + '\n');
    
    // Scores
    final scores = results['scores'] ?? {};
    buffer.writeln('📊 SCORES:');
    scores.forEach((key, value) {
      final score = (value * 100).round();
      final bar = _generateBar(score);
      final emoji = _getScoreEmoji(score);
      buffer.writeln('  $emoji ${_formatLabel(key)}: $bar $score/100');
    });
    
    // Categories
    buffer.writeln('\n📋 CATEGORIES:');
    final categories = results['categories'] ?? {};
    categories.forEach((key, category) {
      final score = ((category['score'] ?? 0) * 100).round();
      final status = _getStatus(score);
      buffer.writeln('  $status ${category['title']}: $score/100');
      
      if (args['verbose']) {
        // Show audit details
        final audits = category['audits'] ?? [];
        for (final audit in audits.take(5)) {
          buffer.writeln('    - ${audit['title']}: ${audit['score']}');
        }
      }
    });
    
    // Issues
    final issues = results['issues'] ?? [];
    if (issues.isNotEmpty) {
      buffer.writeln('\n⚠️  ISSUES:');
      for (final issue in issues.take(10)) {
        buffer.writeln('  • ${issue['title']}');
        if (args['verbose']) {
          buffer.writeln('    ${issue['description']}');
        }
      }
    }
    
    // Recommendations
    final recommendations = results['recommendations'] ?? [];
    if (recommendations.isNotEmpty) {
      buffer.writeln('\n💡 RECOMMENDATIONS:');
      for (final rec in recommendations.take(5)) {
        buffer.writeln('  • ${rec['title']}');
      }
    }
    
    // Metrics
    if (args['verbose']) {
      buffer.writeln('\n📈 METRICS:');
      final metrics = results['metrics'] ?? {};
      metrics.forEach((key, value) {
        buffer.writeln('  ${_formatLabel(key)}: $value');
      });
    }
    
    return buffer.toString();
  }
  
  /// Format as JSON
  String _formatJson(Map<String, dynamic> results) {
    final encoder = args['pretty'] as bool 
      ? JsonEncoder.withIndent('  ')
      : JsonEncoder();
    return encoder.convert(results);
  }
  
  /// Format as CSV
  String _formatCsv(Map<String, dynamic> results) {
    final buffer = StringBuffer();
    buffer.writeln('Category,Score,Status');
    
    final scores = results['scores'] ?? {};
    scores.forEach((key, value) {
      final score = (value * 100).round();
      buffer.writeln('$key,$score,${_getStatus(score)}');
    });
    
    return buffer.toString();
  }
  
  /// Format as Markdown
  String _formatMarkdown(Map<String, dynamic> results) {
    final buffer = StringBuffer();
    
    buffer.writeln('# AuditMySite Report\n');
    buffer.writeln('**URL:** ${results['url']}  ');
    buffer.writeln('**Date:** ${DateTime.now().toLocal()}\n');
    
    buffer.writeln('## Scores\n');
    final scores = results['scores'] ?? {};
    scores.forEach((key, value) {
      final score = (value * 100).round();
      buffer.writeln('- **${_formatLabel(key)}:** $score/100');
    });
    
    buffer.writeln('\n## Issues\n');
    final issues = results['issues'] ?? [];
    for (final issue in issues) {
      buffer.writeln('- ${issue['title']}');
    }
    
    return buffer.toString();
  }
  
  /// Generate HTML report
  Future<String> _generateHtmlReport(Map<String, dynamic> results) async {
    // This would use the HtmlReportBuilder
    return '<html>Report</html>';
  }
  
  /// Load configuration file
  Future<Map<String, dynamic>> _loadConfig() async {
    final configPath = args['config'];
    if (configPath == null) {
      return _getDefaultConfig();
    }
    
    final file = File(configPath);
    if (!await file.exists()) {
      logger.warning('Config file not found: $configPath');
      return _getDefaultConfig();
    }
    
    try {
      final content = await file.readAsString();
      if (configPath.endsWith('.json')) {
        return jsonDecode(content);
      } else if (configPath.endsWith('.yaml') || configPath.endsWith('.yml')) {
        // Would use yaml package
        return {};
      }
    } catch (e) {
      logger.warning('Failed to load config: $e');
    }
    
    return _getDefaultConfig();
  }
  
  Map<String, dynamic> _getDefaultConfig() {
    return {
      'throttling': {
        'cpu': 4,
        'network': 'Fast 3G',
      },
      'categories': ['performance', 'accessibility', 'seo', 'best-practices', 'pwa'],
      'device': 'desktop',
    };
  }
  
  // Helper methods
  
  String _generateBar(int score) {
    final filled = (score / 5).round();
    final empty = 20 - filled;
    
    String color;
    if (score >= 90) {
      color = '\x1B[32m'; // Green
    } else if (score >= 50) {
      color = '\x1B[33m'; // Yellow
    } else {
      color = '\x1B[31m'; // Red
    }
    
    return '$color${'█' * filled}${'░' * empty}\x1B[0m';
  }
  
  String _getScoreEmoji(int score) {
    if (score >= 90) return '🟢';
    if (score >= 50) return '🟡';
    return '🔴';
  }
  
  String _getStatus(int score) {
    if (score >= 90) return '✅';
    if (score >= 50) return '⚠️';
    return '❌';
  }
  
  String _formatLabel(String key) {
    return key.split('-').map((word) => 
      word[0].toUpperCase() + word.substring(1)
    ).join(' ');
  }
  
  Map<String, int>? _parseViewport(String? viewport) {
    if (viewport == null) return null;
    
    final parts = viewport.split('x');
    if (parts.length != 2) return null;
    
    return {
      'width': int.tryParse(parts[0]) ?? 1920,
      'height': int.tryParse(parts[1]) ?? 1080,
    };
  }
  
  List<String> _parseCategories(String? only, String? skip) {
    final categories = ['performance', 'accessibility', 'seo', 'best-practices', 'pwa'];
    
    if (only != null) {
      return only.split(',');
    }
    
    if (skip != null) {
      final skipList = skip.split(',');
      return categories.where((c) => !skipList.contains(c)).toList();
    }
    
    return categories;
  }
  
  List<String> _parseAudits(String? only, String? skip) {
    if (only != null) {
      return only.split(',');
    }
    
    if (skip != null) {
      return ['!${skip.replaceAll(',', ',!')}'].toList();
    }
    
    return [];
  }
  
  // Placeholder methods
  
  Future<Map<String, dynamic>> _runAudit(String url, Map<String, dynamic> config) async {
    // Simulate audit
    await Future.delayed(Duration(seconds: 2));
    
    return {
      'url': url,
      'timestamp': DateTime.now().toIso8601String(),
      'scores': {
        'performance': 0.85,
        'accessibility': 0.92,
        'seo': 0.88,
        'best-practices': 0.79,
        'pwa': 0.65,
      },
      'categories': {},
      'audits': {},
      'issues': [
        {'title': 'Image optimization needed', 'severity': 'medium'},
        {'title': 'Missing meta description', 'severity': 'low'},
      ],
      'recommendations': [
        {'title': 'Enable HTTP/2'},
        {'title': 'Compress images'},
      ],
      'metrics': {
        'lcp': 2500,
        'fid': 100,
        'cls': 0.1,
      },
    };
  }
  
  Future<List<String>> _loadSitemap(String sitemap, Map<String, dynamic> config) async {
    // Placeholder
    return ['https://example.com', 'https://example.com/about'];
  }
  
  Future<void> _outputBatchResults(List<Map<String, dynamic>> results) async {
    print('Batch results: ${results.length} audits completed');
  }
  
  void _handleServerRequest(HttpRequest request, Map<String, dynamic> config) {
    request.response
      ..statusCode = HttpStatus.ok
      ..write('AuditMySite Server')
      ..close();
  }
  
  bool _hasSignificantChanges(Map<String, dynamic> results) {
    // Placeholder
    return false;
  }
  
  Future<void> _sendNotification(Map<String, dynamic> results) async {
    print('📧 Notification sent!');
  }
  
  Future<void> _generateComparisonReport(Map<String, Map<String, dynamic>> results) async {
    print('Comparison report generated');
  }
}

/// Create argument parser
ArgParser _createArgParser() {
  return ArgParser()
    // Main options
    ..addOption('url', abbr: 'u', help: 'URL to audit')
    ..addOption('sitemap', abbr: 's', help: 'Sitemap URL for batch auditing')
    ..addOption('output', abbr: 'o', help: 'Output file path')
    ..addOption('format', abbr: 'f', 
      help: 'Output format',
      allowed: ['cli', 'json', 'html', 'csv', 'markdown'],
      defaultsTo: 'cli')
    
    // Audit options
    ..addOption('device', abbr: 'd',
      help: 'Device to emulate',
      allowed: ['desktop', 'mobile', 'tablet'],
      defaultsTo: 'desktop')
    ..addOption('throttle', abbr: 't',
      help: 'Network throttling',
      allowed: ['none', '3g', '4g'],
      defaultsTo: 'none')
    ..addOption('user-agent', help: 'Custom user agent')
    ..addOption('viewport', help: 'Viewport size (e.g., 1920x1080)')
    ..addOption('timeout', help: 'Timeout in milliseconds', defaultsTo: '30000')
    ..addOption('wait-until', 
      help: 'Wait condition',
      allowed: ['load', 'domcontentloaded', 'networkidle', 'networkidle2'],
      defaultsTo: 'networkidle')
    
    // Categories and audits
    ..addOption('only-categories', help: 'Only run specific categories (comma-separated)')
    ..addOption('skip-categories', help: 'Skip specific categories (comma-separated)')
    ..addOption('only-audits', help: 'Only run specific audits (comma-separated)')
    ..addOption('skip-audits', help: 'Skip specific audits (comma-separated)')
    
    // Batch options
    ..addFlag('batch', abbr: 'b', help: 'Run in batch mode')
    ..addOption('concurrency', abbr: 'c', help: 'Number of concurrent audits', defaultsTo: '4')
    ..addOption('limit', abbr: 'l', help: 'Limit number of URLs from sitemap')
    
    // Server mode
    ..addFlag('serve', help: 'Run as HTTP server')
    ..addOption('port', abbr: 'p', help: 'Server port', defaultsTo: '8080')
    
    // Watch mode
    ..addFlag('watch', abbr: 'w', help: 'Watch URL and re-audit on changes')
    ..addOption('watch-interval', help: 'Watch interval in seconds', defaultsTo: '60')
    ..addFlag('notify', abbr: 'n', help: 'Send notifications on significant changes')
    
    // Compare mode
    ..addFlag('compare', help: 'Compare multiple URLs')
    
    // Report options
    ..addFlag('report-only', help: 'Generate report from existing results')
    ..addOption('input', abbr: 'i', help: 'Input file for report-only mode')
    ..addFlag('screenshot', help: 'Capture screenshots')
    ..addFlag('full-page', help: 'Capture full page screenshot')
    
    // Configuration
    ..addOption('config', help: 'Configuration file path')
    ..addFlag('no-headless', help: 'Run browser in non-headless mode')
    
    // Output options
    ..addFlag('quiet', abbr: 'q', help: 'Suppress output')
    ..addFlag('verbose', abbr: 'v', help: 'Verbose output')
    ..addFlag('pretty', help: 'Pretty print JSON output')
    ..addFlag('no-color', help: 'Disable colored output')
    
    // Info
    ..addFlag('help', abbr: 'h', help: 'Show help')
    ..addFlag('version', help: 'Show version');
}

/// Print usage information
void _printUsage(ArgParser parser) {
  print('''
╔═══════════════════════════════════════════════════════════╗
║                    AuditMySite CLI v2.0.0                 ║
║          Professional Website Auditing Tool               ║
╚═══════════════════════════════════════════════════════════╝

USAGE:
  auditmysite [options] [urls...]

EXAMPLES:
  # Audit single URL
  auditmysite --url https://example.com
  
  # Audit with specific device
  auditmysite -u https://example.com -d mobile
  
  # Batch audit from sitemap
  auditmysite --sitemap https://example.com/sitemap.xml
  
  # Generate HTML report
  auditmysite -u https://example.com -f html -o report.html
  
  # Compare multiple URLs
  auditmysite --compare https://example.com https://competitor.com
  
  # Run as server
  auditmysite --serve --port 8080
  
  # Watch mode with notifications
  auditmysite -u https://example.com --watch --notify

OPTIONS:
${parser.usage}

For more information, visit: https://github.com/auditmysite
''');
}

/// Setup logging
void _setupLogging() {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    if (record.level >= Level.WARNING) {
      stderr.writeln('[${record.level.name}] ${record.message}');
    }
  });
}

/// Simple spinner for CLI
class Spinner {
  final String message;
  final List<String> frames = ['⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏'];
  int _current = 0;
  Timer? _timer;
  
  Spinner(this.message);
  
  void start() {
    _timer = Timer.periodic(Duration(milliseconds: 80), (_) {
      stdout.write('\r${frames[_current]} $message');
      _current = (_current + 1) % frames.length;
    });
  }
  
  void stop() {
    _timer?.cancel();
    stdout.write('\r${' ' * (message.length + 3)}\r');
  }
}

/// Progress bar for batch operations
class ProgressBar {
  final int total;
  final bool quiet;
  int _current = 0;
  
  ProgressBar({required this.total, this.quiet = false});
  
  void increment() {
    _current++;
    if (!quiet) {
      _draw();
    }
  }
  
  void _draw() {
    final percentage = (_current / total * 100).round();
    final filled = (_current / total * 30).round();
    final bar = '█' * filled + '░' * (30 - filled);
    stdout.write('\r[$bar] $percentage% ($_current/$total)');
  }
  
  void complete() {
    if (!quiet) {
      stdout.writeln();
    }
  }
}

/// Simple concurrency pool
class Pool {
  final int maxConcurrent;
  int _current = 0;
  final _waiting = <Completer>[];
  
  Pool(this.maxConcurrent);
  
  Future<void> acquire() async {
    if (_current >= maxConcurrent) {
      final completer = Completer();
      _waiting.add(completer);
      await completer.future;
    }
    _current++;
  }
  
  void release() {
    _current--;
    if (_waiting.isNotEmpty) {
      _waiting.removeAt(0).complete();
    }
  }
}