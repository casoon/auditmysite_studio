import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_cors_headers/shelf_cors_headers.dart';
import '../core/events.dart';
import '../core/queue.dart';
import '../core/sitemap_loader.dart' show loadSitemapUris;
import '../cdp/browser_pool.dart';
import '../core/audits/audit_base.dart';
import '../core/audits/audit_http.dart';
import '../core/audits/audit_perf.dart';
import '../core/audits/audit_a11y_axe.dart';
import '../core/audits/audit_seo.dart';
import '../core/audits/audit_content_weight.dart';
import '../core/audits/audit_mobile.dart';
import '../writer/json_writer.dart';

class HttpApiService {
  final int port;
  HttpServer? _server;
  final Map<String, StreamController<AuditEvent>> _runningAudits = {};
  final Map<String, Timer> _runTimers = {};
  BrowserPool? _browserPool;

  HttpApiService({this.port = 3000});

  Future<void> start() async {
    final handler = Pipeline()
        .addMiddleware(corsHeaders())
        .addMiddleware(logRequests())
        .addHandler(_createRouter());

    _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
    print('HTTP API service running on http://localhost:$port');
    print('Available endpoints:');
    print('  GET  /health   - Health check');
    print('  POST /audit    - Start audit');
    print('  GET  /status   - Service status');
  }

  Future<void> stop() async {
    // Clean up running audits
    for (final controller in _runningAudits.values) {
      await controller.close();
    }
    _runningAudits.clear();
    
    // Cancel all timers
    for (final timer in _runTimers.values) {
      timer.cancel();
    }
    _runTimers.clear();
    
    // Close browser pool
    await _browserPool?.close();
    _browserPool = null;
    
    await _server?.close();
    _server = null;
  }

  Handler _createRouter() {
    return (Request request) async {
      final path = request.url.path;
      final method = request.method;

      if (path == 'health' && method == 'GET') {
        return _handleHealth(request);
      }

      if (path == 'status' && method == 'GET') {
        return _handleStatus(request);
      }

      if (path == 'audit' && method == 'POST') {
        return await _handleStartAudit(request);
      }

      return Response.notFound(jsonEncode({'error': 'Not found'}));
    };
  }

  Response _handleHealth(Request request) {
    return Response.ok(jsonEncode({
      'status': 'healthy',
      'timestamp': DateTime.now().toIso8601String(),
      'running_audits': _runningAudits.length,
    }), headers: {'content-type': 'application/json'});
  }

  Response _handleStatus(Request request) {
    return Response.ok(jsonEncode({
      'service': 'auditmysite_engine',
      'version': '2.1.0',
      'features': ['accessibility', 'performance', 'seo', 'content_weight', 'mobile'],
      'running_audits': _runningAudits.length,
      'available_audits': ['http', 'perf', 'a11y_axe', 'seo', 'content_weight', 'mobile'],
      'timestamp': DateTime.now().toIso8601String(),
    }), headers: {'content-type': 'application/json'});
  }

  Future<Response> _handleStartAudit(Request request) async {
    try {
      final body = await request.readAsString();
      final payload = jsonDecode(body) as Map<String, dynamic>;

      // Validate required fields
      final sitemapUrl = payload['sitemap_url'] as String?;
      if (sitemapUrl == null || sitemapUrl.isEmpty) {
        return Response.badRequest(body: jsonEncode({
          'error': 'Missing required field: sitemap_url',
          'example': {
            'sitemap_url': 'https://example.com/sitemap.xml',
            'concurrency': 2,
            'collect_perf': true,
            'collect_seo': true,
            'collect_content_weight': true,
            'collect_mobile': true,
            'screenshots': false,
            'max_pages': 50
          }
        }), headers: {'content-type': 'application/json'});
      }

      // Parse configuration
      final concurrency = (payload['concurrency'] as num?)?.toInt() ?? 2;
      final collectPerf = payload['collect_perf'] as bool? ?? true;
      final collectSeo = payload['collect_seo'] as bool? ?? true;
      final collectContentWeight = payload['collect_content_weight'] as bool? ?? true;
      final collectMobile = payload['collect_mobile'] as bool? ?? true;
      final screenshots = payload['screenshots'] as bool? ?? false;
      final maxPages = (payload['max_pages'] as num?)?.toInt() ?? 50;

      // Generate run ID
      final runId = 'audit_${DateTime.now().millisecondsSinceEpoch}';

      // Start audit asynchronously
      unawaited(_startAuditAsync(
        runId: runId,
        sitemapUrl: sitemapUrl,
        concurrency: concurrency,
        collectPerf: collectPerf,
        collectSeo: collectSeo,
        collectContentWeight: collectContentWeight,
        collectMobile: collectMobile,
        screenshots: screenshots,
        maxPages: maxPages,
      ));

      return Response.ok(jsonEncode({
        'status': 'started',
        'run_id': runId,
        'sitemap_url': sitemapUrl,
        'configuration': {
          'concurrency': concurrency,
          'collect_perf': collectPerf,
          'collect_seo': collectSeo,
          'collect_content_weight': collectContentWeight,
          'collect_mobile': collectMobile,
          'screenshots': screenshots,
          'max_pages': maxPages,
        },
        'timestamp': DateTime.now().toIso8601String(),
      }), headers: {'content-type': 'application/json'});

    } catch (e) {
      return Response.internalServerError(body: jsonEncode({
        'error': 'Failed to start audit',
        'message': e.toString(),
      }), headers: {'content-type': 'application/json'});
    }
  }

  Future<void> _startAuditAsync({
    required String runId,
    required String sitemapUrl,
    required int concurrency,
    required bool collectPerf,
    required bool collectSeo,
    required bool collectContentWeight,
    required bool collectMobile,
    required bool screenshots,
    required int maxPages,
  }) async {
    StreamController<AuditEvent>? controller;
    
    try {
      print('🚀 Starting audit $runId for $sitemapUrl');
      
      // Create event controller for this run
      controller = StreamController<AuditEvent>.broadcast();
      _runningAudits[runId] = controller;
      
      // Set up run timeout (10 minutes)
      _runTimers[runId] = Timer(Duration(minutes: 10), () {
        print('⏱️ Audit $runId timed out');
        _cleanupRun(runId);
      });
      
      // Initialize browser pool if needed
      _browserPool ??= await BrowserPool.launch();
      
      // Load sitemap
      final urls = await loadSitemapUris(Uri.parse(sitemapUrl));
      
      if (urls.isEmpty) {
        throw Exception('No URLs found in sitemap');
      }
      
      // Limit URLs if needed
      final limitedUrls = urls.take(maxPages).toList();
      print('📊 Found ${urls.length} URLs, processing ${limitedUrls.length}');
      
      // Create audit pipeline
      final audits = <Audit>[
        HttpAudit(), // Always collect HTTP status/headers
        if (collectPerf) PerfAudit(), // Enhanced performance audit
        A11yAxeAudit(
          screenshots: screenshots,
          axeSourceFile: 'third_party/axe/axe.min.js',
        ),
        if (collectSeo) SEOAudit(), // SEO audit
        if (collectContentWeight) ContentWeightAudit(), // Content Weight audit
        if (collectMobile) MobileAudit(), // Mobile Friendliness audit
      ];
      
      print('🔧 Running ${audits.length} audit types: ${audits.map((a) => a.name).join(', ')}');
      
      // Create JSON writer
      final writer = JsonWriter(
        baseDir: Directory('artifacts'),
        runId: runId,
      );
      
      // Create and run audit queue
      final queue = AuditQueue(
        concurrency: concurrency,
        browserPool: _browserPool!,
        audits: audits,
        writer: writer,
        maxRetries: 2,
        baseDelayMs: 1000,
        delayBetweenRequests: 500,
        maxRequestsPerSecond: 2.0,
      );
      
      // Run the audit
      await queue.process(limitedUrls, controller);
      
      print('✅ Audit $runId completed successfully');
      
    } catch (e, stackTrace) {
      print('❌ Audit $runId failed: $e');
      print('Stack trace: $stackTrace');
      
      // Send error event to clients if controller exists
      if (controller != null && !controller.isClosed) {
        // Create a dummy URL for error event
        final errorUrl = Uri.parse(sitemapUrl);
        controller.add(PageError(errorUrl, 'Audit failed: $e'));
      }
    } finally {
      // Cleanup
      _cleanupRun(runId);
    }
  }
  
  void _cleanupRun(String runId) {
    // Cancel timer
    _runTimers[runId]?.cancel();
    _runTimers.remove(runId);
    
    // Close event controller
    final controller = _runningAudits.remove(runId);
    if (controller != null && !controller.isClosed) {
      controller.close();
    }
    
    print('🧹 Cleaned up audit run $runId');
  }
}
