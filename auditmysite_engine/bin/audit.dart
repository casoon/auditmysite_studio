#!/usr/bin/env dart
import 'dart:io';
import 'dart:async';
import 'package:xml/xml.dart';
import 'package:auditmysite_engine/core/sitemap_loader.dart';
import 'package:auditmysite_engine/core/queue.dart';
import 'package:auditmysite_engine/cdp/browser_pool.dart';
import 'package:auditmysite_engine/core/audits/audit_base.dart';
import 'package:auditmysite_engine/core/audits/audit_http.dart';
import 'package:auditmysite_engine/core/audits/audit_perf.dart';
import 'package:auditmysite_engine/core/audits/audit_a11y_axe.dart';
import 'package:auditmysite_engine/core/audits/audit_seo.dart';
import 'package:auditmysite_engine/core/audits/audit_seo_advanced.dart';
import 'package:auditmysite_engine/core/audits/audit_content_weight.dart';
import 'package:auditmysite_engine/core/audits/audit_content_quality.dart';
import 'package:auditmysite_engine/core/audits/audit_mobile.dart';
import 'package:auditmysite_engine/core/audits/audit_wcag21.dart';
import 'package:auditmysite_engine/core/audits/audit_wcag_complete.dart';
import 'package:auditmysite_engine/core/audits/audit_aria.dart';
import 'package:auditmysite_engine/core/audits/audit_performance_advanced.dart';
import 'package:auditmysite_engine/core/performance_budgets.dart';
import 'package:auditmysite_engine/writer/json_writer.dart';
import 'package:auditmysite_engine/service/websocket_service.dart';
import 'package:auditmysite_engine/core/events.dart';

void main(List<String> arguments) async {
  // Simple argument parsing without args package
  final args = Map<String, String>();
  String? currentKey;
  
  for (final arg in arguments) {
    if (arg.startsWith('--')) {
      final stripped = arg.substring(2);
      if (stripped.contains('=')) {
        final parts = stripped.split('=');
        args[parts[0]] = parts.sublist(1).join('=');
      } else {
        if (currentKey != null && !args.containsKey(currentKey)) {
          args[currentKey] = 'true'; // Flag without value
        }
        currentKey = stripped;
      }
    } else if (currentKey != null) {
      args[currentKey] = arg;
      currentKey = null;
    }
  }
  
  if (currentKey != null && !args.containsKey(currentKey)) {
    args[currentKey] = 'true';
  }

  // Check for help
  if (args.containsKey('help') || arguments.isEmpty) {
    print('''
AuditMySite Engine - Website Audit Tool

Usage: dart audit.dart --sitemap=<URL> [options]

Options:
  --sitemap=<URL>      Sitemap URL to audit (required)
  --out=<DIR>          Output directory (default: ./artifacts)
  --concurrency=<N>    Number of concurrent workers (default: 4)
  --max-pages=<N>      Maximum pages to audit (default: 1000)
  --budget=<TYPE>      Performance budget (default, ecommerce, corporate, blog)
  
Features (all enabled by default):
  --no-perf            Disable performance analysis
  --no-seo             Disable SEO analysis
  --no-content-weight  Disable content weight analysis
  --no-content-quality Disable content quality analysis
  --no-mobile          Disable mobile friendliness analysis
  --no-wcag21          Disable WCAG 2.1 analysis
  --wcag-complete      Enable complete WCAG 2.2 audit (includes all levels)
  --wcag-level-a       Enable WCAG 2.2 Level A audit only
  --wcag-level-aa      Enable WCAG 2.2 Level AA audit only
  --wcag-level-aaa     Enable WCAG 2.2 Level AAA audit
  --wcag30             Enable WCAG 3.0 preview audit
  --no-aria            Disable ARIA analysis
  
Advanced:
  --screenshots        Enable screenshots
  --serve              Start WebSocket server for live progress
  --port=<N>           WebSocket server port (default: 8080)
  --delay=<MS>         Delay between requests in milliseconds
  --rate-limit=<RPS>   Max requests per second
''');
    exit(0);
  }

  // Extract parameters
  final sitemapUrl = args['sitemap'];
  if (sitemapUrl == null) {
    stderr.writeln('Error: --sitemap is required');
    exit(1);
  }

  final outDir = Directory(args['out'] ?? './artifacts')
    ..createSync(recursive: true);
  
  final concurrency = int.tryParse(args['concurrency'] ?? '4') ?? 4;
  final maxPages = int.tryParse(args['max-pages'] ?? '1000') ?? 1000;
  final budgetName = args['budget'] ?? 'default';
  
  // Feature flags (inverted logic for --no-xxx flags)
  final collectPerf = !args.containsKey('no-perf');
  final collectSeo = !args.containsKey('no-seo');
  final collectContentWeight = !args.containsKey('no-content-weight');
  final collectContentQuality = !args.containsKey('no-content-quality');
  final collectMobile = !args.containsKey('no-mobile');
  final collectWcag21 = !args.containsKey('no-wcag21');
  final collectWcagComplete = args.containsKey('wcag-complete');
  final wcagLevelA = args.containsKey('wcag-level-a') || collectWcagComplete;
  final wcagLevelAA = args.containsKey('wcag-level-aa') || collectWcagComplete;
  final wcagLevelAAA = args.containsKey('wcag-level-aaa');
  final wcag30 = args.containsKey('wcag30');
  final collectAria = !args.containsKey('no-aria');
  final screenshots = args.containsKey('screenshots');
  final serve = args.containsKey('serve');
  final port = int.tryParse(args['port'] ?? '8080') ?? 8080;
  final delay = int.tryParse(args['delay'] ?? '0') ?? 0;
  final rateLimit = double.tryParse(args['rate-limit'] ?? '0') ?? 0;

  // Load sitemap
  print('Loading sitemap: $sitemapUrl');
  List<Uri> allUrls;
  
  // Check if it's a file path or URL
  if (sitemapUrl.startsWith('http://') || sitemapUrl.startsWith('https://')) {
    allUrls = await loadSitemapUris(Uri.parse(sitemapUrl));
  } else if (sitemapUrl == 'test') {
    // Test mode with example.com
    allUrls = [Uri.parse('https://example.com/')];
  } else {
    // Assume it's a file path
    final file = File(sitemapUrl);
    if (await file.exists()) {
      final content = await file.readAsString();
      final doc = XmlDocument.parse(content);
      allUrls = doc.findAllElements('loc').map((e) => Uri.parse(e.text)).toList();
    } else {
      stderr.writeln('Error: Sitemap file not found: $sitemapUrl');
      exit(1);
    }
  }
  
  print('Found ${allUrls.length} URLs');
  final urls = allUrls.take(maxPages).toList();
  if (urls.length < allUrls.length) {
    print('Limited to $maxPages pages');
  }

  // Setup
  final runId = DateTime.now().toIso8601String().replaceAll(':', '-').replaceAll('.', '_');
  final browserPool = await BrowserPool.launch();
  final writer = JsonWriter(baseDir: outDir, runId: runId);
  final eventController = StreamController<AuditEvent>.broadcast();

  // Start WebSocket if requested
  WebSocketService? wsService;
  if (serve) {
    wsService = WebSocketService(port: port);
    await wsService.start();
    wsService.subscribeToEvents(eventController.stream);
    print('WebSocket server running on ws://localhost:$port/ws');
  }

  // Get performance budget
  final budget = PerformanceBudgets.getBudget(budgetName);
  print('Using performance budget: ${budget.name}');
  
  // Configure audits
  final audits = <Audit>[
    HttpAudit(),
    if (collectPerf) AdvancedPerformanceAudit(budget: budget),
    if (collectSeo) AdvancedSEOAudit(),  // Use advanced SEO analyzer
    if (collectContentWeight) ContentWeightAudit(),
    if (collectContentQuality) ContentQualityAudit(),
    if (collectMobile) MobileAudit(),
    if (collectWcag21 && !collectWcagComplete) WCAG21Audit(),
    if (collectWcagComplete || wcagLevelA || wcagLevelAA || wcagLevelAAA || wcag30) 
      WCAGCompleteAudit(
        includeLevel_A: wcagLevelA,
        includeLevel_AA: wcagLevelAA,
        includeLevel_AAA: wcagLevelAAA,
        includeWCAG30: wcag30,
        takeScreenshots: screenshots,
      ),
    if (collectAria) ARIAAudit(),
    A11yAxeAudit(screenshots: screenshots, axeSourceFile: 'third_party/axe/axe.min.js'),
  ];
  
  print('Enabled audits: ${audits.map((a) => a.name).join(', ')}');

  // Create queue
  final queue = AuditQueue(
    concurrency: concurrency,
    browserPool: browserPool,
    audits: audits,
    writer: writer,
    delayBetweenRequests: delay,
    maxRequestsPerSecond: rateLimit > 0 ? rateLimit : null,
    performanceBudget: budget,
  );

  // Event logging
  eventController.stream.listen((event) {
    if (event is PageStarted) {
      print('[START] ${event.url}');
    } else if (event is PageFinished) {
      print('[DONE] ${event.url}');
    } else if (event is PageError) {
      print('[ERROR] ${event.url}: ${event.message}');
    }
  });

  // Process
  print('\nStarting audit with $concurrency workers...\n');
  await queue.process(urls, eventController);
  
  // Cleanup
  await browserPool.close();
  if (wsService != null) {
    await wsService.stop();
  }
  await eventController.close();

  print('\n✅ Audit complete! Results in: ${outDir.path}/$runId');
}