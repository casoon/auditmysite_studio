import 'dart:async';
import 'package:shared/models.dart';

abstract class AuditEvent {
  final Uri url;
  AuditEvent(this.url);
}

class PageQueued extends AuditEvent { PageQueued(super.url); }
class PageStarted extends AuditEvent { PageStarted(super.url); }
class PageFinished extends AuditEvent { PageFinished(super.url); }
class PageError extends AuditEvent {
  final String message;
  PageError(super.url, this.message);
}

class PageRetry extends AuditEvent {
  final int attempt;
  final int delayMs;
  PageRetry(super.url, this.attempt, this.delayMs);
}

class AuditAttached extends AuditEvent {
  final String auditName;
  AuditAttached(super.url, this.auditName);
}
class AuditFinished extends AuditEvent {
  final String auditName;
  AuditFinished(super.url, this.auditName);
}

class AuditContext {
  final Uri url;
  final dynamic page; // puppeteer Page
  final StreamController<AuditEvent> events;
  final String runId;

  // flüchtige Zwischenergebnisse
  int? statusCode;
  Map<String, String>? headers;
  double? ttfbMs, fcpMs, lcpMs, dclMs, loadEndMs;
  List<String> consoleErrors = [];
  String? screenshotPath;
  Map<String, dynamic>? axeJson;
  EngineFootprint? engineFootprint;
  Map<String, dynamic>? performanceResult;
  Map<String, dynamic>? seoResult;
  
  // HTTP-Details
  String? redirectedTo; // Finale URL nach Redirects
  String? navigationError; // Navigation-Fehler falls aufgetreten
  int? responseTimeMs; // Gesamte Response-Zeit in Millisekunden
  int? redirectCount; // Anzahl der Redirects
  List<Map<String, dynamic>>? redirectChain; // Komplette Redirect-Kette
  Map<String, dynamic>? sslInfo; // SSL/TLS-Informationen
  
  // Neue Audit-Results
  Map<String, dynamic>? contentWeightResult; // Content Weight Audit Result
  Map<String, dynamic>? mobileResult; // Mobile Friendliness Audit Result

  final DateTime startedAt;
  
  AuditContext({
    required this.url, 
    required this.page, 
    required this.events,
    required this.runId,
  }) : startedAt = DateTime.now();

  Map<String, dynamic> buildResult() {
    return {
      'schemaVersion': '1.0.0',
      'runId': runId,
      'url': url.toString(),
      'http': {
        'statusCode': statusCode,
        'headers': headers,
        'redirectedTo': redirectedTo,
        'navigationError': navigationError,
        'responseTimeMs': responseTimeMs,
        'redirectCount': redirectCount ?? 0,
        'redirectChain': redirectChain ?? [],
        'ssl': sslInfo,
      },
      'perf': {
        'ttfbMs': ttfbMs,
        'fcpMs': fcpMs,
        'lcpMs': lcpMs,
        'domContentLoadedMs': dclMs,
        'loadEventEndMs': loadEndMs,
        'engine': engineFootprint?.toJson() ?? {
          'cpuUserMs': null,
          'cpuSystemMs': null,
          'peakRssBytes': null,
          'taskDurationMs': null,
        }
      },
      'performance': performanceResult,
      'seo': seoResult,
      'contentWeight': contentWeightResult,
      'mobile': mobileResult,
      'a11y': axeJson != null ? {'violations': axeJson!['violations'] ?? []} : null,
      'consoleErrors': consoleErrors,
      'screenshotPath': screenshotPath,
      'startedAt': startedAt.toIso8601String(),
      'finishedAt': DateTime.now().toIso8601String(),
    };
  }
}
