import 'dart:io';
import 'dart:async';
import 'package:args/args';
import 'package:auditmysite_engine/core/sitemap_loader.dart';
import 'package:auditmysite_engine/core/queue.dart';
import 'package:auditmysite_engine/cdp/browser_pool.dart';
import 'package:auditmysite_engine/core/audits/audit_http.dart';
import 'package:auditmysite_engine/core/audits/audit_perf.dart';
import 'package:auditmysite_engine/core/audits/audit_a11y_axe.dart';
import 'package:auditmysite_engine/writer/json_writer.dart';
import 'package:auditmysite_engine/service/websocket_service.dart';
import 'package:auditmysite_engine/core/events.dart';

Future<void> main(List<String> args) async {
  final parser = ArgParser()
    ..addOption('sitemap', abbr: 's', help: 'Sitemap URL')
    ..addOption('out', defaultsTo: './artifacts')
    ..addOption('concurrency', defaultsTo: '4')
    ..addFlag('perf', defaultsTo: true)
    ..addFlag('screenshots', defaultsTo: false)
    ..addFlag('serve', help: 'Start WebSocket server for live progress', defaultsTo: false)
    ..addOption('port', help: 'WebSocket server port', defaultsTo: '8080')
    ..addOption('include', help: 'Include URLs matching regex pattern')
    ..addOption('exclude', help: 'Exclude URLs matching regex pattern')
    ..addOption('max-pages', help: 'Maximum number of pages to audit', defaultsTo: '1000')
    ..addOption('delay', help: 'Delay between requests in milliseconds', defaultsTo: '0')
    ..addOption('rate-limit', help: 'Maximum requests per second', defaultsTo: '0');

  final opts = parser.parse(args);
  final sitemapUrl = opts['sitemap'] as String?;
  if (sitemapUrl == null) {
    stderr.writeln('Fehler: --sitemap erforderlich');
    exit(2);
  }

  final outDir = Directory(opts['out'] as String)..createSync(recursive: true);
  final concurrency = int.parse(opts['concurrency'] as String);
  final collectPerf = opts['perf'] as bool;
  final screenshots = opts['screenshots'] as bool;

  final allUrls = await loadSitemapUris(Uri.parse(sitemapUrl));
  final filteredUrls = _filterUrls(allUrls, opts);
  final runId = DateTime.now().toIso8601String().replaceAll(':', '-');
  
  print('Found ${allUrls.length} URLs from sitemap');
  if (filteredUrls.length != allUrls.length) {
    print('Filtered to ${filteredUrls.length} URLs after include/exclude patterns');
  }

  final browserPool = await BrowserPool.launch();
  final writer = JsonWriter(baseDir: outDir, runId: runId);
  
  // Setup event stream controller
  final eventController = StreamController<AuditEvent>.broadcast();
  
  // Start WebSocket server if requested
  WebSocketService? wsService;
  if (opts['serve'] as bool) {
    final port = int.parse(opts['port'] as String);
    wsService = WebSocketService(port: port);
    await wsService.start();
    wsService.subscribeToEvents(eventController.stream);
    print('WebSocket server running on ws://localhost:$port/ws');
  }

  final delay = int.parse(opts['delay'] as String);
  final rateLimit = double.parse(opts['rate-limit'] as String);
  
  final queue = AuditQueue(
    concurrency: concurrency,
    browserPool: browserPool,
    audits: [
      HttpAudit(),
      if (collectPerf) PerfAudit(),
      A11yAxeAudit(screenshots: screenshots, axeSourceFile: 'third_party/axe/axe.min.js'),
    ],
    writer: writer,
    delayBetweenRequests: delay,
    maxRequestsPerSecond: rateLimit > 0 ? rateLimit : null,
  );

  // Register event handler to controller
  eventController.stream.listen((event) {
    print('[${event.runtimeType}] ${event.url}');
  });

  print('Starte Audit mit $concurrency Workern für ${filteredUrls.length} URLs...');
  await queue.process(filteredUrls, eventController);
  await browserPool.close();
  
  if (wsService != null) {
    print('Stopping WebSocket server...');
    await wsService.stop();
  }
  
  await eventController.close();

  print('Fertig. Artefakte: ${outDir.path}/$runId');
}

List<Uri> _filterUrls(List<Uri> urls, ArgResults opts) {
  final includePattern = opts['include'] as String?;
  final excludePattern = opts['exclude'] as String?;
  final maxPages = int.parse(opts['max-pages'] as String);
  
  RegExp? includeRegex;
  RegExp? excludeRegex;
  
  try {
    if (includePattern != null) {
      includeRegex = RegExp(includePattern, caseSensitive: false);
    }
    if (excludePattern != null) {
      excludeRegex = RegExp(excludePattern, caseSensitive: false);
    }
  } catch (e) {
    print('⚠️  Invalid regex pattern: $e');
    return urls.take(maxPages).toList();
  }
  
  var filtered = urls.where((url) {
    final urlString = url.toString();
    
    // Apply include filter
    if (includeRegex != null && !includeRegex.hasMatch(urlString)) {
      return false;
    }
    
    // Apply exclude filter
    if (excludeRegex != null && excludeRegex.hasMatch(urlString)) {
      return false;
    }
    
    return true;
  }).toList();
  
  // Apply max pages limit
  if (filtered.length > maxPages) {
    print('🔢 Limiting to first $maxPages pages (use --max-pages to change)');
    filtered = filtered.take(maxPages).toList();
  }
  
  return filtered;
}
