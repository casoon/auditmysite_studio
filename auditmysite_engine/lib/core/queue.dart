import 'dart:async';
import 'dart:io';
import 'package:shared/models.dart';
import 'package:auditmysite_engine/core/events.dart';
import 'package:auditmysite_engine/cdp/browser_pool.dart';
import 'package:auditmysite_engine/core/audits/audit_base.dart';
import 'package:auditmysite_engine/writer/json_writer.dart';
import 'package:auditmysite_engine/core/performance_budgets.dart';
import 'package:auditmysite_engine/core/redirect_handler.dart';
import 'package:puppeteer/puppeteer.dart';

class AuditQueue {
  final int concurrency;
  final BrowserPool browserPool;
  final List<Audit> audits;
  final JsonWriter writer;
  final int maxRetries;
  final int baseDelayMs;
  final int delayBetweenRequests;
  final double? maxRequestsPerSecond;
  final PerformanceBudget? performanceBudget;
  final bool skipRedirects;
  final RedirectHandler redirectHandler;
  
  // Rate limiting state
  DateTime? _lastRequestTime;
  final List<DateTime> _requestTimestamps = [];

  AuditQueue({
    required this.concurrency,
    required this.browserPool,
    required this.audits,
    required this.writer,
    this.maxRetries = 2,
    this.baseDelayMs = 1000,
    this.delayBetweenRequests = 0,
    this.maxRequestsPerSecond,
    this.performanceBudget,
    this.skipRedirects = true,
    RedirectHandler? redirectHandler,
  }) : redirectHandler = redirectHandler ?? RedirectHandler(skipRedirects: skipRedirects);

  Future<void> process(List<Uri> urls, [StreamController<AuditEvent>? externalController]) async {
    final controller = externalController ?? StreamController<AuditEvent>.broadcast();
    
    // Only add default logging if no external controller
    if (externalController == null) {
      controller.stream.listen((e) {
        if (e is PageRedirected) {
          print('[REDIRECT] ${e.url} -> ${e.finalUrl}');
        } else {
          print('[${e.runtimeType}] ${e.url}');
        }
      });
    }

    final pool = <Future>[];
    final processedUrls = <Uri>[];
    final skippedRedirects = <Uri>[];
    int urlIndex = 0;
    final runId = writer.runId;  // Use runId from writer for consistency

    Future<void> spawn() async {
      while (true) {
        // Thread-safe URL fetching
        Uri? url;
        if (urlIndex < urls.length) {
          url = urls[urlIndex++];
        } else {
          break;
        }
        if (url == null) break;
        
        // Check if URL should be skipped due to redirect
        if (redirectHandler.shouldSkip(url)) {
          skippedRedirects.add(url);
          controller.add(PageSkipped(url, 'Previously detected as redirect'));
          continue;
        }
        
        controller.add(PageQueued(url));
        
        // First check if this URL will redirect
        final page = await browserPool.acquire();
        final redirectInfo = await redirectHandler.detectRedirect(page, url, controller);
        
        // If redirect detected, audit the FINAL URL instead
        final urlToAudit = redirectInfo?.finalUrl ?? url;
        
        if (redirectInfo != null) {
          // Count the redirect but continue with final URL
          skippedRedirects.add(url);
          print('[REDIRECT] ${url} -> ${redirectInfo.finalUrl} (will audit final URL)');
        }
        
        // Process the final destination URL
        await _processPageWithRetry(urlToAudit, controller, runId, page);
        processedUrls.add(urlToAudit);
      }
    }

    for (var i = 0; i < concurrency; i++) {
      pool.add(spawn());
    }
    await Future.wait(pool);
    
    // Write run summary with redirect statistics
    try {
      final summary = {
        'runId': runId,
        'totalUrls': urls.length,
        'processedUrls': processedUrls.length,
        'skippedRedirects': skippedRedirects.length,
        'redirectStatistics': redirectHandler.getSummary(),
      };
      await writer.writeSummary(summary);
      print('✅ Run summary written to artifacts/$runId/run_summary.json');
      
      // Print statistics
      print('\n📊 Audit Statistics:');
      print('   - Total URLs: ${urls.length}');
      print('   - Processed: ${processedUrls.length}');
      print('   - Skipped (redirects): ${skippedRedirects.length}');
      
      if (redirectHandler.stats.totalRedirects > 0) {
        print('\n🔄 Redirect Details:');
        print('   - HTTP redirects: ${redirectHandler.stats.httpRedirects}');
        print('   - JavaScript redirects: ${redirectHandler.stats.jsRedirects}');
        print('   - Meta redirects: ${redirectHandler.stats.metaRedirects}');
      }
    } catch (e) {
      print('⚠️  Failed to write run summary: $e');
    }
    
    // Only close if we created the controller internally
    if (externalController == null) {
      await controller.close();
    }
  }

  Future<void> _processPageWithRetry(Uri url, StreamController<AuditEvent> controller, String runId, [Page? existingPage]) async {
    int attempt = 0;
    
    while (attempt <= maxRetries) {
      try {
        // Apply throttling/rate limiting
        await _applyRateLimit();
        
        final pageStartTime = DateTime.now();
        
        final page = existingPage ?? await browserPool.acquire();
        controller.add(PageStarted(url));
        
        final ctx = AuditContext(
          url: url, 
          page: page, 
          events: controller, 
          runId: runId,
        );
        
        // Set performance budget if provided
        if (performanceBudget != null) {
          ctx.performanceBudget = performanceBudget!.name;
        }
        
        // Run all audits
        for (final audit in audits) {
          controller.add(AuditAttached(url, audit.name));
          await audit.run(ctx);
          controller.add(AuditFinished(url, audit.name));
        }
        
        // Measure performance metrics
        final pageEndTime = DateTime.now();
        final finalMemory = ProcessInfo.currentRss;
        final taskDuration = pageEndTime.difference(pageStartTime).inMicroseconds / 1000.0;
        
        // Set engine footprint
        ctx.engineFootprint = EngineFootprint(
          taskDurationMs: taskDuration,
          peakRssBytes: finalMemory,
        );
        
        await writer.write(ctx.buildResult());
        browserPool.release(page);
        controller.add(PageFinished(url));
        
        return; // Success!
        
      } catch (e, st) {
        attempt++;
        
        if (attempt <= maxRetries) {
          final delay = Duration(milliseconds: baseDelayMs * (1 << (attempt - 1)));
          controller.add(PageRetry(url, attempt, delay.inMilliseconds));
          await Future.delayed(delay);
        } else {
          controller.add(PageError(url, '$e\n$st'));
          
          // Still write a failed result
          try {
            final failedResult = {
              'schemaVersion': '1.0.0',
              'runId': runId,
              'url': url.toString(),
              'http': {'statusCode': null, 'headers': null},
              'perf': {
                'ttfbMs': null,
                'fcpMs': null,
                'lcpMs': null,
                'domContentLoadedMs': null,
                'loadEventEndMs': null,
                'engine': {
                  'cpuUserMs': null,
                  'cpuSystemMs': null,
                  'peakRssBytes': null,
                  'taskDurationMs': null,
                }
              },
              'a11y': null,
              'consoleErrors': [],
              'screenshotPath': null,
              'startedAt': DateTime.now().toIso8601String(),
              'finishedAt': DateTime.now().toIso8601String(),
              'error': e.toString(),
            };
            await writer.write(failedResult);
          } catch (writeError) {
            print('Failed to write error result for $url: $writeError');
          }
        }
      }
    }
  }
  
  Future<void> _applyRateLimit() async {
    final now = DateTime.now();
    
    // Apply simple delay between requests
    if (delayBetweenRequests > 0) {
      if (_lastRequestTime != null) {
        final timeSinceLastRequest = now.difference(_lastRequestTime!);
        final requiredDelay = Duration(milliseconds: delayBetweenRequests);
        
        if (timeSinceLastRequest < requiredDelay) {
          final waitTime = requiredDelay - timeSinceLastRequest;
          await Future.delayed(waitTime);
        }
      }
      _lastRequestTime = DateTime.now();
    }
    
    // Apply requests per second rate limiting
    if (maxRequestsPerSecond != null && maxRequestsPerSecond! > 0) {
      // Clean old timestamps (older than 1 second)
      _requestTimestamps.removeWhere((timestamp) {
        return now.difference(timestamp).inMilliseconds > 1000;
      });
      
      // Check if we're over the rate limit
      if (_requestTimestamps.length >= maxRequestsPerSecond!) {
        // Calculate how long to wait until we can make another request
        final oldestTimestamp = _requestTimestamps.first;
        final waitTime = 1000 - now.difference(oldestTimestamp).inMilliseconds;
        
        if (waitTime > 0) {
          await Future.delayed(Duration(milliseconds: waitTime + 10)); // +10ms buffer
        }
      }
      
      // Record this request
      _requestTimestamps.add(DateTime.now());
    }
  }
}
