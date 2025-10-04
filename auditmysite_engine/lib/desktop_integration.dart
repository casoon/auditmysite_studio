import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:auditmysite_engine/core/queue.dart';
import 'package:auditmysite_engine/core/events.dart';
import 'package:auditmysite_engine/cdp/browser_pool.dart';
import 'package:auditmysite_engine/writer/json_writer.dart';
import 'package:auditmysite_engine/core/performance_budgets.dart';
import 'package:auditmysite_engine/core/redirect_handler.dart';
import 'package:auditmysite_engine/core/pdf/pdf_report_generator.dart';
import 'package:auditmysite_engine/core/audits/audit_base.dart' show Audit, SafeAudit;
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
    
    // Launch browser pool (Puppeteer handles Chromium automatically)
    print('[DEBUG] Launching browser pool...');
    try {
      _browserPool = await BrowserPool.launch(headless: true);
      print('[DEBUG] ✅ Browser pool launched successfully');
    } catch (e, stack) {
      print('[ERROR] ❌ Failed to launch browser pool: $e');
      print('[ERROR] Stack trace: $stack');
      rethrow;
    }
    
    // Configure audits based on config
    final audits = _configureAudits(config);
    
    // Setup writer
    final writer = JsonWriter(
      baseDir: outputDir,
      runId: sessionId,
    );
    
    // Configure redirect handler
    final redirectHandler = RedirectHandler(
      skipRedirects: config.skipRedirects,
      maxRedirectsToFollow: config.maxRedirectsToFollow,
    );
    
    // Get performance budget
    final budget = PerformanceBudgets.getBudget(config.performanceBudget);
    
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
    
    // Start processing and generate PDF after completion
    final processFuture = _processAndGeneratePDF(
      config,
      outputDir,
      sessionId,
      auditEventController,
    );
    
    return AuditSession(
      sessionId: sessionId,
      eventStream: _eventController!.stream,
      outputPath: outputDir.path,
      processFuture: processFuture,
    );
  }
  
  /// Process audit queue and generate PDF report
  Future<void> _processAndGeneratePDF(
    AuditConfiguration config,
    Directory outputDir,
    String sessionId,
    StreamController<AuditEvent> auditEventController,
  ) async {
    try {
      // Run the audit queue
      print('[DEBUG] Starting audit processing...');
      await _currentQueue!.process(config.urls, auditEventController);
      print('[DEBUG] ✅ Audit processing completed');
      
      // Generate PDF report
      print('[DEBUG] Generating PDF report...');
      await PdfReportGenerator.generateFromDirectory(
        outputDir: outputDir.path,
        runId: sessionId,
      );
      print('[DEBUG] ✅ PDF report generated successfully');
    } catch (e, stack) {
      print('[ERROR] ❌ Error during audit or PDF generation: $e');
      print('[ERROR] Stack trace: $stack');
      rethrow;
    } finally {
      // Cleanup
      await auditEventController.close();
    }
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
    final rawAudits = <Audit>[];
    
    // Always include HTTP audit
    rawAudits.add(HttpAudit());
    
    // Add configured audits
    if (config.enablePerformance) {
      if (config.useAdvancedAudits) {
        rawAudits.add(AdvancedPerformanceAudit(
          budget: PerformanceBudgets.getBudget(config.performanceBudget),
        ));
      } else {
        rawAudits.add(PerfAudit());
      }
    }
    
    if (config.enableSEO) {
      if (config.useAdvancedAudits) {
        rawAudits.add(AdvancedSEOAudit());
      } else {
        // Use basic SEO audit if available
        rawAudits.add(AdvancedSEOAudit()); // For now, always use advanced
      }
    }
    
    if (config.enableContentWeight) {
      rawAudits.add(ContentWeightAudit());
    }
    
    if (config.enableContentQuality) {
      rawAudits.add(ContentQualityAudit());
    }
    
    if (config.enableMobile) {
      rawAudits.add(MobileAudit());
    }
    
    if (config.enableWCAG21) {
      rawAudits.add(WCAG21Audit());
    }
    
    if (config.enableARIA) {
      rawAudits.add(ARIAAudit());
    }
    
    // TODO: Enable Axe audit once axe.min.js is properly bundled
    // if (config.enableAccessibility) {
    //   rawAudits.add(A11yAxeAudit(
    //     screenshots: config.enableScreenshots,
    //     axeSourceFile: 'third_party/axe/axe.min.js',
    //   ));
    // }
    
    // Wrap all audits in SafeAudit for error handling
    return rawAudits.map((audit) => SafeAudit(audit)).toList();
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
    this.skipRedirects = false,
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