import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:auditmysite_engine/core/queue.dart';
import 'package:auditmysite_engine/core/events.dart';
import 'package:auditmysite_engine/cdp/browser_pool.dart';
import 'package:auditmysite_engine/writer/json_writer.dart';
import 'package:auditmysite_engine/core/simple_http_audit.dart';
import 'package:auditmysite_engine/core/performance_budgets.dart';
import 'package:auditmysite_engine/core/redirect_handler.dart';
import 'package:auditmysite_engine/core/pdf_report_generator_enhanced.dart';
import 'package:auditmysite_engine/core/audits/audit_base.dart';
import 'package:auditmysite_engine/core/audits/audit_http.dart';
import 'package:auditmysite_engine/core/audits/audit_perf.dart';
import 'package:auditmysite_engine/core/audits/audit_seo_advanced.dart';
import 'package:auditmysite_engine/core/audits/audit_performance_advanced.dart';
import 'package:auditmysite_engine/core/audits/audit_content_weight.dart';
import 'package:auditmysite_engine/core/audits/audit_content_quality.dart';
import 'package:auditmysite_engine/core/audits/audit_mobile.dart';
import 'package:auditmysite_engine/core/audits/audit_wcag21.dart';
import 'package:auditmysite_engine/core/audits/audit_aria.dart';
import 'package:auditmysite_engine/core/audits/audit_a11y_axe.dart';

/// Desktop integration API for AuditMySite Studio
class DesktopIntegration {
  StreamController<EngineEvent>? _eventController;
  StreamSubscription<AuditEvent>? _auditSubscription;
  AuditQueue? _currentQueue;
  BrowserPool? _browserPool;
  
  /// Start an audit with configuration
  Future<AuditSession> startAudit(AuditConfiguration config) async {
    // Cancel any existing audit
    await cancelAudit();
    
    // Create new session
    final sessionId = DateTime.now().toIso8601String().replaceAll(':', '-').replaceAll('.', '_');
    final outputDir = Directory(config.outputPath ?? './artifacts')..createSync(recursive: true);
    
    // Setup event streaming
    _eventController = StreamController<EngineEvent>.broadcast();
    final auditEventController = StreamController<AuditEvent>.broadcast();
    
    // Try to setup browser pool, use simple HTTP audit if it fails
    try {
      _browserPool = await BrowserPool.launch();
    } catch (e) {
      print('Warning: Browser pool failed to launch: $e');
      print('Using simple HTTP audit mode instead.');
      // Continue without browser pool - will use SimpleHttpAudit
    }
    
    // Configure audits based on config
    final audits = _configureAudits(config);
    
    // Setup writer (use sessionId for regular audits, empty for simple HTTP)
    final writer = JsonWriter(
      baseDir: outputDir,
      runId: _browserPool == null ? null : sessionId,
    );
    
    // Configure redirect handler
    final redirectHandler = RedirectHandler(
      skipRedirects: config.skipRedirects,
      maxRedirectsToFollow: config.maxRedirectsToFollow,
    );
    
    // Get performance budget
    final budget = PerformanceBudgets.getBudget(config.performanceBudget);
    
    // If browser pool failed, use simple HTTP audit mode
    if (_browserPool == null) {
      // Use simple HTTP audit
      final processFuture = _runSimpleHttpAudit(
        config.urls,
        writer,
        auditEventController,
      );
      
      return AuditSession(
        sessionId: sessionId,
        eventStream: _eventController!.stream,
        outputPath: outputDir.path,
        processFuture: processFuture,
      );
    }
    
    // Create audit queue with browser pool
    _currentQueue = AuditQueue(
      concurrency: config.concurrency,
      browserPool: _browserPool!,
      audits: audits,
      writer: writer,
      maxRetries: config.maxRetries,
      delayBetweenRequests: config.delayMs,
      maxRequestsPerSecond: config.rateLimit,
      performanceBudget: budget,
      skipRedirects: config.skipRedirects,
      redirectHandler: redirectHandler,
    );
    
    // Bridge audit events to engine events
    _auditSubscription = auditEventController.stream.listen((event) {
      _eventController?.add(_convertAuditEvent(event));
    });
    
    // Start processing
    final processFuture = _currentQueue!.process(config.urls, auditEventController);
    
    return AuditSession(
      sessionId: sessionId,
      eventStream: _eventController!.stream,
      outputPath: outputDir.path,
      processFuture: processFuture,
    );
  }
  
  /// Cancel the current audit
  Future<void> cancelAudit() async {
    await _auditSubscription?.cancel();
    await _eventController?.close();
    await _browserPool?.close();
    _currentQueue = null;
  }
  
  /// Get audit status
  AuditStatus? getStatus() {
    if (_currentQueue == null) return null;
    
    return AuditStatus(
      isRunning: true,
      redirectsSkipped: _currentQueue!.redirectHandler.stats.totalRedirects,
      pagesProcessed: 0, // Would need to track this
    );
  }
  
  List<Audit> _configureAudits(AuditConfiguration config) {
    final audits = <Audit>[];
    
    // Always include HTTP audit
    audits.add(HttpAudit());
    
    // Add configured audits
    if (config.enablePerformance) {
      if (config.useAdvancedAudits) {
        audits.add(AdvancedPerformanceAudit(
          budget: PerformanceBudgets.getBudget(config.performanceBudget),
        ));
      } else {
        audits.add(PerfAudit());
      }
    }
    
    if (config.enableSEO) {
      if (config.useAdvancedAudits) {
        audits.add(AdvancedSEOAudit());
      } else {
        // Use basic SEO audit if available
        audits.add(AdvancedSEOAudit()); // For now, always use advanced
      }
    }
    
    if (config.enableContentWeight) {
      audits.add(ContentWeightAudit());
    }
    
    if (config.enableContentQuality) {
      audits.add(ContentQualityAudit());
    }
    
    if (config.enableMobile) {
      audits.add(MobileAudit());
    }
    
    if (config.enableWCAG21) {
      audits.add(WCAG21Audit());
    }
    
    if (config.enableARIA) {
      audits.add(ARIAAudit());
    }
    
    if (config.enableAccessibility) {
      audits.add(A11yAxeAudit(
        screenshots: config.enableScreenshots,
        axeSourceFile: 'third_party/axe/axe.min.js',
      ));
    }
    
    return audits;
  }
  
  EngineEvent _convertAuditEvent(AuditEvent event) {
    if (event is PageQueued) {
      return EngineEvent(
        type: EngineEventType.pageQueued,
        url: event.url.toString(),
        timestamp: DateTime.now(),
      );
    } else if (event is PageStarted) {
      return EngineEvent(
        type: EngineEventType.pageStarted,
        url: event.url.toString(),
        timestamp: DateTime.now(),
      );
    } else if (event is PageFinished) {
      return EngineEvent(
        type: EngineEventType.pageFinished,
        url: event.url.toString(),
        timestamp: DateTime.now(),
      );
    } else if (event is PageError) {
      return EngineEvent(
        type: EngineEventType.pageError,
        url: event.url.toString(),
        error: event.message,
        timestamp: DateTime.now(),
      );
    } else if (event is PageSkipped) {
      return EngineEvent(
        type: EngineEventType.pageSkipped,
        url: event.url.toString(),
        message: event.reason,
        timestamp: DateTime.now(),
      );
    } else if (event is PageRedirected) {
      return EngineEvent(
        type: EngineEventType.pageRedirected,
        url: event.url.toString(),
        redirectUrl: event.finalUrl.toString(),
        timestamp: DateTime.now(),
      );
    } else if (event is AuditAttached) {
      return EngineEvent(
        type: EngineEventType.auditStarted,
        url: event.url.toString(),
        auditName: event.auditName,
        timestamp: DateTime.now(),
      );
    } else if (event is AuditFinished) {
      return EngineEvent(
        type: EngineEventType.auditFinished,
        url: event.url.toString(),
        auditName: event.auditName,
        timestamp: DateTime.now(),
      );
    }
    
    return EngineEvent(
      type: EngineEventType.unknown,
      url: event.url.toString(),
      timestamp: DateTime.now(),
    );
  }
  
  /// Run simple HTTP audit when browser is not available
  Future<void> _runSimpleHttpAudit(
    List<Uri> urls,
    JsonWriter writer,
    StreamController<AuditEvent> eventController,
  ) async {
    final allResults = <Map<String, dynamic>>[];
    final startTime = DateTime.now();
    int successCount = 0;
    int failCount = 0;
    
    for (final url in urls) {
      // Emit start event
      eventController.add(PageStarted(url));
      
      try {
        // Perform enhanced HTTP audit
        final result = await SimpleHttpAudit.auditUrlEnhanced(url.toString());
        
        // Store full result for PDF
        allResults.add(result);
        
        // Write result to JSON
        await writer.write({
          'url': url.toString(),
          'timestamp': DateTime.now().toIso8601String(),
          'http': result['audits']['http'],
          'perf': result['audits']['performance'],
          'seo': result['audits']['seo'],
          'content': result['audits']['content'],
          'scores': result['scores'],
          'recommendations': result['recommendations'],
        });
        
        if (result['success'] == true) {
          successCount++;
        } else {
          failCount++;
        }
        
        // Emit finish event
        eventController.add(PageFinished(url));
      } catch (e) {
        failCount++;
        // Emit error event
        eventController.add(PageError(url, e.toString()));
        allResults.add({
          'url': url.toString(),
          'success': false,
          'error': e.toString(),
        });
      }
    }
    
    // Write summary
    await writer.writeSummary();
    
    // Generate PDF report
    try {
      final endTime = DateTime.now();
      final duration = endTime.difference(startTime);
      
      final pdfData = {
        'url': urls.isNotEmpty ? urls.first.host : 'Website',
        'totalPages': urls.length,
        'successfulPages': successCount,
        'failedPages': failCount,
        'duration': '${duration.inSeconds}s',
        'results': allResults,
        'performanceScore': _calculateAverageScore(allResults, 'performanceScore'),
        'seoScore': _calculateAverageScore(allResults, 'seoScore'),
        'a11yScore': _calculateAverageScore(allResults, 'a11yScore'),
        'bestPracticesScore': _calculateAverageScore(allResults, 'bestPracticesScore'),
        'recommendations': _aggregateRecommendations(allResults),
      };
      
      // Generate enhanced PDF report for first URL with date-based filename
      if (allResults.isNotEmpty) {
        final firstResult = allResults.first;
        
        // Extract domain for filename
        String domainName = 'website';
        try {
          final uri = Uri.parse(urls.first.toString());
          domainName = uri.host.replaceAll('www.', '').replaceAll('.', '_');
        } catch (_) {
          domainName = 'website';
        }
        
        // Create date-based filename (will overwrite if same day)
        final dateStr = DateTime.now().toIso8601String().split('T')[0]; // YYYY-MM-DD
        final pdfPath = '${writer.baseDir.path}/${domainName}_report_$dateStr.pdf';
        
        await PdfReportGeneratorEnhanced.generateReport(
          auditData: firstResult,
          outputPath: pdfPath,
          url: urls.isNotEmpty ? urls.first.toString() : 'Website',
        );
        
        print('PDF report generated successfully at: $pdfPath');
      }
      
      // Message already printed above
    } catch (e) {
      print('Failed to generate PDF report: $e');
    }
  }
  
  int _calculateAverageScore(List<Map<String, dynamic>> results, String scoreKey) {
    final scores = results
        .where((r) => r['scores'] != null && r['scores'][scoreKey] != null)
        .map((r) => r['scores'][scoreKey] as num)
        .toList();
    
    if (scores.isEmpty) return 0;
    return (scores.reduce((a, b) => a + b) / scores.length).round();
  }
  
  Map<String, List<Map<String, dynamic>>> _aggregateRecommendations(List<Map<String, dynamic>> results) {
    final high = <Map<String, dynamic>>[];
    final medium = <Map<String, dynamic>>[];
    final low = <Map<String, dynamic>>[];
    
    for (final result in results) {
      if (result['recommendations'] != null) {
        final recs = result['recommendations'] as Map<String, dynamic>;
        if (recs['high'] != null) high.addAll(List<Map<String, dynamic>>.from(recs['high']));
        if (recs['medium'] != null) medium.addAll(List<Map<String, dynamic>>.from(recs['medium']));
        if (recs['low'] != null) low.addAll(List<Map<String, dynamic>>.from(recs['low']));
      }
    }
    
    return {
      'high': high,
      'medium': medium,
      'low': low,
    };
  }
}

/// Configuration for an audit session
class AuditConfiguration {
  final List<Uri> urls;
  final String? outputPath;
  final int concurrency;
  final int maxRetries;
  final int delayMs;
  final double? rateLimit;
  final String performanceBudget;
  final bool skipRedirects;
  final int maxRedirectsToFollow;
  
  // Feature flags
  final bool enablePerformance;
  final bool enableSEO;
  final bool enableContentWeight;
  final bool enableContentQuality;
  final bool enableMobile;
  final bool enableWCAG21;
  final bool enableARIA;
  final bool enableAccessibility;
  final bool enableScreenshots;
  final bool useAdvancedAudits;
  
  AuditConfiguration({
    required this.urls,
    this.outputPath,
    this.concurrency = 4,
    this.maxRetries = 2,
    this.delayMs = 0,
    this.rateLimit,
    this.performanceBudget = 'default',
    this.skipRedirects = true,
    this.maxRedirectsToFollow = 5,
    this.enablePerformance = true,
    this.enableSEO = true,
    this.enableContentWeight = true,
    this.enableContentQuality = true,
    this.enableMobile = true,
    this.enableWCAG21 = true,
    this.enableARIA = true,
    this.enableAccessibility = true,
    this.enableScreenshots = false,
    this.useAdvancedAudits = true,
  });
  
  /// Create from JSON map
  factory AuditConfiguration.fromJson(Map<String, dynamic> json) {
    return AuditConfiguration(
      urls: (json['urls'] as List).map((u) => Uri.parse(u)).toList(),
      outputPath: json['outputPath'],
      concurrency: json['concurrency'] ?? 4,
      maxRetries: json['maxRetries'] ?? 2,
      delayMs: json['delayMs'] ?? 0,
      rateLimit: json['rateLimit'],
      performanceBudget: json['performanceBudget'] ?? 'default',
      skipRedirects: json['skipRedirects'] ?? true,
      maxRedirectsToFollow: json['maxRedirectsToFollow'] ?? 5,
      enablePerformance: json['enablePerformance'] ?? true,
      enableSEO: json['enableSEO'] ?? true,
      enableContentWeight: json['enableContentWeight'] ?? true,
      enableContentQuality: json['enableContentQuality'] ?? true,
      enableMobile: json['enableMobile'] ?? true,
      enableWCAG21: json['enableWCAG21'] ?? true,
      enableARIA: json['enableARIA'] ?? true,
      enableAccessibility: json['enableAccessibility'] ?? true,
      enableScreenshots: json['enableScreenshots'] ?? false,
      useAdvancedAudits: json['useAdvancedAudits'] ?? true,
    );
  }
  
  /// Convert to JSON map
  Map<String, dynamic> toJson() => {
    'urls': urls.map((u) => u.toString()).toList(),
    'outputPath': outputPath,
    'concurrency': concurrency,
    'maxRetries': maxRetries,
    'delayMs': delayMs,
    'rateLimit': rateLimit,
    'performanceBudget': performanceBudget,
    'skipRedirects': skipRedirects,
    'maxRedirectsToFollow': maxRedirectsToFollow,
    'enablePerformance': enablePerformance,
    'enableSEO': enableSEO,
    'enableContentWeight': enableContentWeight,
    'enableContentQuality': enableContentQuality,
    'enableMobile': enableMobile,
    'enableWCAG21': enableWCAG21,
    'enableARIA': enableARIA,
    'enableAccessibility': enableAccessibility,
    'enableScreenshots': enableScreenshots,
    'useAdvancedAudits': useAdvancedAudits,
  };
}

/// Represents an active audit session
class AuditSession {
  final String sessionId;
  final Stream<EngineEvent> eventStream;
  final String outputPath;
  final Future<void> processFuture;
  
  AuditSession({
    required this.sessionId,
    required this.eventStream,
    required this.outputPath,
    required this.processFuture,
  });
}

/// Current audit status
class AuditStatus {
  final bool isRunning;
  final int redirectsSkipped;
  final int pagesProcessed;
  
  AuditStatus({
    required this.isRunning,
    required this.redirectsSkipped,
    required this.pagesProcessed,
  });
}

/// Events emitted by the engine for desktop integration
class EngineEvent {
  final EngineEventType type;
  final String url;
  final String? message;
  final String? error;
  final String? redirectUrl;
  final String? auditName;
  final DateTime timestamp;
  
  EngineEvent({
    required this.type,
    required this.url,
    this.message,
    this.error,
    this.redirectUrl,
    this.auditName,
    required this.timestamp,
  });
  
  Map<String, dynamic> toJson() => {
    'type': type.toString(),
    'url': url,
    'message': message,
    'error': error,
    'redirectUrl': redirectUrl,
    'auditName': auditName,
    'timestamp': timestamp.toIso8601String(),
  };
}

/// Types of engine events
enum EngineEventType {
  pageQueued,
  pageStarted,
  pageFinished,
  pageError,
  pageSkipped,
  pageRedirected,
  auditStarted,
  auditFinished,
  unknown,
}