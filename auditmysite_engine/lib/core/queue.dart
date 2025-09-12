import 'dart:async';
import 'dart:io';
import 'package:shared/models.dart';
import 'package:auditmysite_engine/core/events.dart';
import 'package:auditmysite_engine/cdp/browser_pool.dart';
import 'package:auditmysite_engine/core/audits/audit_base.dart';
import 'package:auditmysite_engine/writer/json_writer.dart';

class AuditQueue {
  final int concurrency;
  final BrowserPool browserPool;
  final List<Audit> audits;
  final JsonWriter writer;
  final int maxRetries;
  final int baseDelayMs;
  final int delayBetweenRequests;
  final double? maxRequestsPerSecond;
  
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
  });

  Future<void> process(List<Uri> urls, [StreamController<AuditEvent>? externalController]) async {
    final controller = externalController ?? StreamController<AuditEvent>.broadcast();
    
    // Only add default logging if no external controller
    if (externalController == null) {
      controller.stream.listen((e) {
        print('[${e.runtimeType}] ${e.url}');
      });
    }

    final pool = <Future>[];
    final it = urls.iterator;
    final runId = DateTime.now().toIso8601String().replaceAll(':', '-').replaceAll('.', '_');

    Future<void> spawn() async {
      while (true) {
        if (!it.moveNext()) break;
        final url = it.current;
        controller.add(PageQueued(url));
        
        await _processPageWithRetry(url, controller, runId);
      }
    }

    for (var i = 0; i < concurrency; i++) {
      pool.add(spawn());
    }
    await Future.wait(pool);
    
    // Write run summary
    try {
      await writer.writeSummary();
      print('✅ Run summary written to artifacts/$runId/run_summary.json');
    } catch (e) {
      print('⚠️  Failed to write run summary: $e');
    }
    
    // Only close if we created the controller internally
    if (externalController == null) {
      await controller.close();
    }
  }

  Future<void> _processPageWithRetry(Uri url, StreamController<AuditEvent> controller, String runId) async {
    int attempt = 0;
    
    while (attempt <= maxRetries) {
      try {
        // Apply throttling/rate limiting
        await _applyRateLimit();
        
        final pageStartTime = DateTime.now();
        
        final page = await browserPool.newPage();
        controller.add(PageStarted(url));
        
        final ctx = AuditContext(
          url: url, 
          page: page, 
          events: controller, 
          runId: runId,
        );
        
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
        await page.close();
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
