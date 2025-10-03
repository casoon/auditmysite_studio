import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:auditmysite_engine/desktop_integration.dart';
import 'package:auditmysite_engine/deployment/embedded_config.dart';
import 'package:shared/models.dart';

/// Provider for the embedded engine instance
final embeddedEngineProvider = Provider<DesktopIntegration>((ref) {
  return DesktopIntegration();
});

/// Provider for current audit session
final auditSessionProvider = StateProvider<AuditSession?>((ref) => null);

/// Provider for audit events stream
final auditEventsProvider = StreamProvider<EngineEvent>((ref) async* {
  final session = ref.watch(auditSessionProvider);
  if (session != null) {
    await for (final event in session.eventStream) {
      yield event;
    }
  }
});

/// Provider for audit progress
final auditProgressProvider = StateNotifierProvider<AuditProgressNotifier, AuditProgress>((ref) {
  return AuditProgressNotifier(ref);
});

/// Audit progress state
class AuditProgress {
  final bool isRunning;
  final int totalUrls;
  final int processedUrls;
  final int failedUrls;
  final int skippedUrls;
  final String? currentUrl;
  final String? lastError;
  final List<ProcessedPage> processedPages;
  
  const AuditProgress({
    this.isRunning = false,
    this.totalUrls = 0,
    this.processedUrls = 0,
    this.failedUrls = 0,
    this.skippedUrls = 0,
    this.currentUrl,
    this.lastError,
    this.processedPages = const [],
  });
  
  double get progress {
    if (totalUrls == 0) return 0;
    return (processedUrls + failedUrls + skippedUrls) / totalUrls;
  }
  
  AuditProgress copyWith({
    bool? isRunning,
    int? totalUrls,
    int? processedUrls,
    int? failedUrls,
    int? skippedUrls,
    String? currentUrl,
    String? lastError,
    List<ProcessedPage>? processedPages,
  }) {
    return AuditProgress(
      isRunning: isRunning ?? this.isRunning,
      totalUrls: totalUrls ?? this.totalUrls,
      processedUrls: processedUrls ?? this.processedUrls,
      failedUrls: failedUrls ?? this.failedUrls,
      skippedUrls: skippedUrls ?? this.skippedUrls,
      currentUrl: currentUrl ?? this.currentUrl,
      lastError: lastError ?? this.lastError,
      processedPages: processedPages ?? this.processedPages,
    );
  }
}

/// Processed page info
class ProcessedPage {
  final String url;
  final bool success;
  final String? error;
  final DateTime timestamp;
  
  const ProcessedPage({
    required this.url,
    required this.success,
    this.error,
    required this.timestamp,
  });
}

/// Audit progress notifier
class AuditProgressNotifier extends StateNotifier<AuditProgress> {
  final Ref ref;
  StreamSubscription<EngineEvent>? _eventSubscription;
  
  AuditProgressNotifier(this.ref) : super(const AuditProgress());
  
  /// Start monitoring audit progress
  void startMonitoring(int totalUrls) {
    state = AuditProgress(
      isRunning: true,
      totalUrls: totalUrls,
      processedPages: [],
    );
    
    // Listen to engine events
    _eventSubscription?.cancel();
    _eventSubscription = ref.read(auditEventsProvider.stream).listen((event) {
      _handleEngineEvent(event);
    });
  }
  
  /// Stop monitoring
  void stopMonitoring() {
    _eventSubscription?.cancel();
    state = state.copyWith(isRunning: false);
  }
  
  /// Handle engine events
  void _handleEngineEvent(EngineEvent event) {
    switch (event.type) {
      case EngineEventType.pageStarted:
        state = state.copyWith(currentUrl: event.url);
        break;
        
      case EngineEventType.pageFinished:
        final pages = [...state.processedPages];
        pages.add(ProcessedPage(
          url: event.url,
          success: true,
          timestamp: event.timestamp,
        ));
        state = state.copyWith(
          processedUrls: state.processedUrls + 1,
          processedPages: pages,
        );
        break;
        
      case EngineEventType.pageError:
        final pages = [...state.processedPages];
        pages.add(ProcessedPage(
          url: event.url,
          success: false,
          error: event.error,
          timestamp: event.timestamp,
        ));
        state = state.copyWith(
          failedUrls: state.failedUrls + 1,
          lastError: event.error,
          processedPages: pages,
        );
        break;
        
      case EngineEventType.pageSkipped:
      case EngineEventType.pageRedirected:
        state = state.copyWith(
          skippedUrls: state.skippedUrls + 1,
        );
        break;
        
      default:
        break;
    }
  }
  
  @override
  void dispose() {
    _eventSubscription?.cancel();
    super.dispose();
  }
}

/// Engine service for audit operations
class EmbeddedEngineService {
  final DesktopIntegration _engine;
  
  EmbeddedEngineService(this._engine);
  
  /// Initialize the engine
  static Future<void> initialize() async {
    // Initialize deployment directories
    await EmbeddedEngineConfig.initializeDirectories();
    
    // Print diagnostics in debug mode
    assert(() {
      DeploymentInfo.printDiagnostics();
      return true;
    }());
  }
  
  /// Start an audit
  Future<AuditSession> startAudit({
    required List<String> urls,
    required String outputPath,
    int concurrency = 4,
    bool enablePerformance = true,
    bool enableSEO = true,
    bool enableContentWeight = true,
    bool enableContentQuality = true,
    bool enableMobile = true,
    bool enableWCAG21 = true,
    bool enableARIA = true,
    bool enableAccessibility = true,
    bool enableScreenshots = false,
    bool useAdvancedAudits = true,
    String performanceBudget = 'default',
  }) async {
    final config = AuditConfiguration(
      urls: urls.map(Uri.parse).toList(),
      outputPath: outputPath,
      concurrency: concurrency,
      enablePerformance: enablePerformance,
      enableSEO: enableSEO,
      enableContentWeight: enableContentWeight,
      enableContentQuality: enableContentQuality,
      enableMobile: enableMobile,
      enableWCAG21: enableWCAG21,
      enableARIA: enableARIA,
      enableAccessibility: enableAccessibility,
      enableScreenshots: enableScreenshots,
      useAdvancedAudits: useAdvancedAudits,
      performanceBudget: performanceBudget,
    );
    
    return await _engine.startAudit(config);
  }
  
  /// Cancel current audit
  Future<void> cancelAudit() async {
    await _engine.cancelAudit();
  }
  
  /// Get audit status
  AuditStatus? getStatus() {
    return _engine.getStatus();
  }
}

/// Provider for engine service
final engineServiceProvider = Provider<EmbeddedEngineService>((ref) {
  final engine = ref.watch(embeddedEngineProvider);
  return EmbeddedEngineService(engine);
});

/// Initialize engine on app startup
final engineInitializerProvider = FutureProvider<void>((ref) async {
  await EmbeddedEngineService.initialize();
});