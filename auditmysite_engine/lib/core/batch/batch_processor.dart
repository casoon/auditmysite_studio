import 'dart:async';
import 'dart:collection';
import 'dart:isolate';
import 'dart:math';
import 'package:logging/logging.dart';
import '../audits/audit_base.dart';
import '../audits/audit_runner.dart';
import '../output/json_formatter.dart';

/// Batch processor for running multiple audits in parallel
class BatchProcessor {
  final Logger _logger = Logger('BatchProcessor');
  
  final int maxWorkers;
  final int maxRetries;
  final Duration timeout;
  final bool continueOnError;
  
  // Progress tracking
  final _progressController = StreamController<BatchProgress>.broadcast();
  Stream<BatchProgress> get progressStream => _progressController.stream;
  
  // Worker pool
  final List<WorkerIsolate> _workers = [];
  final Queue<BatchJob> _jobQueue = Queue();
  final Map<String, BatchResult> _results = {};
  
  // State tracking
  int _totalJobs = 0;
  int _completedJobs = 0;
  int _failedJobs = 0;
  bool _isRunning = false;
  DateTime? _startTime;
  
  BatchProcessor({
    this.maxWorkers = 4,
    this.maxRetries = 3,
    this.timeout = const Duration(minutes: 5),
    this.continueOnError = true,
  });
  
  /// Process a batch of URLs
  Future<BatchReport> processBatch(
    List<String> urls, {
    Map<String, dynamic>? options,
    String? outputDir,
    void Function(BatchProgress)? onProgress,
  }) async {
    if (_isRunning) {
      throw StateError('Batch processor is already running');
    }
    
    _isRunning = true;
    _startTime = DateTime.now();
    _totalJobs = urls.length;
    _completedJobs = 0;
    _failedJobs = 0;
    _results.clear();
    _jobQueue.clear();
    
    // Subscribe to progress if callback provided
    StreamSubscription<BatchProgress>? progressSubscription;
    if (onProgress != null) {
      progressSubscription = progressStream.listen(onProgress);
    }
    
    try {
      // Create job queue
      for (final url in urls) {
        _jobQueue.add(BatchJob(
          id: _generateJobId(),
          url: url,
          options: options ?? {},
          retries: 0,
          maxRetries: maxRetries,
        ));
      }
      
      _logger.info('Starting batch processing of ${urls.length} URLs with $maxWorkers workers');
      _emitProgress('Initializing workers...');
      
      // Initialize worker pool
      await _initializeWorkers();
      
      // Process jobs
      await _processJobs();
      
      // Wait for all jobs to complete
      await _waitForCompletion();
      
      // Generate report
      final report = _generateReport(outputDir: outputDir);
      
      _logger.info('Batch processing completed: ${report.successful} successful, ${report.failed} failed');
      
      return report;
      
    } finally {
      // Cleanup
      await progressSubscription?.cancel();
      await _shutdownWorkers();
      _isRunning = false;
      _progressController.add(BatchProgress(
        total: _totalJobs,
        completed: _completedJobs,
        failed: _failedJobs,
        message: 'Batch processing completed',
        isComplete: true,
      ));
    }
  }
  
  /// Process URLs from a sitemap
  Future<BatchReport> processSitemap(
    String sitemapUrl, {
    int? limit,
    Map<String, dynamic>? options,
    String? outputDir,
    void Function(BatchProgress)? onProgress,
  }) async {
    _logger.info('Loading sitemap: $sitemapUrl');
    _emitProgress('Loading sitemap...');
    
    // Load and parse sitemap
    final urls = await _loadSitemap(sitemapUrl, limit: limit);
    
    if (urls.isEmpty) {
      throw ArgumentError('No URLs found in sitemap');
    }
    
    _logger.info('Found ${urls.length} URLs in sitemap');
    
    // Process batch
    return processBatch(
      urls,
      options: options,
      outputDir: outputDir,
      onProgress: onProgress,
    );
  }
  
  /// Cancel batch processing
  Future<void> cancel() async {
    if (!_isRunning) return;
    
    _logger.info('Cancelling batch processing');
    _emitProgress('Cancelling...');
    
    // Clear job queue
    _jobQueue.clear();
    
    // Shutdown workers
    await _shutdownWorkers();
    
    _isRunning = false;
  }
  
  /// Get current statistics
  BatchStatistics getStatistics() {
    final elapsed = _startTime != null 
      ? DateTime.now().difference(_startTime!) 
      : Duration.zero;
    
    final averageTime = _completedJobs > 0
      ? elapsed.inMilliseconds / _completedJobs
      : 0;
    
    final estimatedRemaining = (_totalJobs - _completedJobs) * averageTime;
    
    return BatchStatistics(
      totalJobs: _totalJobs,
      completedJobs: _completedJobs,
      failedJobs: _failedJobs,
      successRate: _completedJobs > 0 
        ? ((_completedJobs - _failedJobs) / _completedJobs * 100).round() 
        : 0,
      averageTimeMs: averageTime.round(),
      elapsedTime: elapsed,
      estimatedRemaining: Duration(milliseconds: estimatedRemaining.round()),
      workersActive: _workers.where((w) => w.isBusy).length,
      queueLength: _jobQueue.length,
    );
  }
  
  // Private methods
  
  Future<void> _initializeWorkers() async {
    final workerCount = min(maxWorkers, _totalJobs);
    
    for (int i = 0; i < workerCount; i++) {
      final worker = await WorkerIsolate.spawn(i);
      _workers.add(worker);
      
      // Listen for results
      worker.resultStream.listen((result) {
        _handleJobResult(result);
      });
    }
    
    _logger.info('Initialized $workerCount workers');
  }
  
  Future<void> _processJobs() async {
    while (_jobQueue.isNotEmpty || _hasActiveJobs()) {
      // Assign jobs to available workers
      for (final worker in _workers) {
        if (!worker.isBusy && _jobQueue.isNotEmpty) {
          final job = _jobQueue.removeFirst();
          await worker.processJob(job);
        }
      }
      
      // Small delay to prevent busy-waiting
      await Future.delayed(Duration(milliseconds: 100));
    }
  }
  
  Future<void> _waitForCompletion() async {
    final completer = Completer<void>();
    
    // Set up timeout
    Timer? timeoutTimer;
    if (timeout != Duration.zero) {
      timeoutTimer = Timer(timeout, () {
        if (!completer.isCompleted) {
          _logger.warning('Batch processing timeout after ${timeout.inSeconds} seconds');
          completer.complete();
        }
      });
    }
    
    // Check for completion
    Timer.periodic(Duration(milliseconds: 500), (timer) {
      if (_completedJobs + _failedJobs >= _totalJobs || !_isRunning) {
        timer.cancel();
        timeoutTimer?.cancel();
        if (!completer.isCompleted) {
          completer.complete();
        }
      }
    });
    
    await completer.future;
  }
  
  void _handleJobResult(BatchJobResult result) {
    _results[result.jobId] = BatchResult(
      url: result.url,
      success: result.success,
      data: result.data,
      error: result.error,
      duration: result.duration,
      timestamp: result.timestamp,
    );
    
    if (result.success) {
      _completedJobs++;
      _logger.info('Completed: ${result.url} (${_completedJobs}/$_totalJobs)');
      _emitProgress('Completed ${result.url}');
    } else {
      final job = result.job;
      
      // Retry if possible
      if (job != null && job.retries < job.maxRetries) {
        job.retries++;
        _logger.warning('Retrying ${result.url} (attempt ${job.retries}/${job.maxRetries})');
        _jobQueue.add(job);
      } else {
        _failedJobs++;
        _completedJobs++;
        _logger.severe('Failed: ${result.url} - ${result.error}');
        _emitProgress('Failed ${result.url}', isError: true);
        
        if (!continueOnError) {
          _logger.severe('Stopping batch processing due to error');
          cancel();
        }
      }
    }
  }
  
  Future<void> _shutdownWorkers() async {
    for (final worker in _workers) {
      await worker.shutdown();
    }
    _workers.clear();
    _logger.info('All workers shut down');
  }
  
  bool _hasActiveJobs() {
    return _workers.any((w) => w.isBusy);
  }
  
  void _emitProgress(String message, {bool isError = false}) {
    _progressController.add(BatchProgress(
      total: _totalJobs,
      completed: _completedJobs,
      failed: _failedJobs,
      message: message,
      isError: isError,
      percentage: _totalJobs > 0 ? (_completedJobs / _totalJobs * 100).round() : 0,
    ));
  }
  
  BatchReport _generateReport({String? outputDir}) {
    final successful = <BatchResult>[];
    final failed = <BatchResult>[];
    
    _results.forEach((id, result) {
      if (result.success) {
        successful.add(result);
      } else {
        failed.add(result);
      }
    });
    
    return BatchReport(
      startTime: _startTime!,
      endTime: DateTime.now(),
      totalUrls: _totalJobs,
      successful: successful.length,
      failed: failed.length,
      results: _results.values.toList(),
      outputDir: outputDir,
      statistics: getStatistics(),
    );
  }
  
  Future<List<String>> _loadSitemap(String sitemapUrl, {int? limit}) async {
    // Simple sitemap loader - in production, use a proper XML parser
    // This is a placeholder implementation
    final urls = <String>[];
    
    try {
      // TODO: Implement actual sitemap loading
      // For now, return empty list
      _logger.warning('Sitemap loading not yet implemented');
      
    } catch (e) {
      _logger.severe('Error loading sitemap: $e');
      throw e;
    }
    
    return limit != null ? urls.take(limit).toList() : urls;
  }
  
  String _generateJobId() {
    return '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1000000)}';
  }
  
  void dispose() {
    _progressController.close();
  }
}

/// Worker isolate for processing audit jobs
class WorkerIsolate {
  final int id;
  final SendPort _sendPort;
  final ReceivePort _receivePort;
  final Stream<BatchJobResult> resultStream;
  bool isBusy = false;
  
  WorkerIsolate._(this.id, this._sendPort, this._receivePort, this.resultStream);
  
  static Future<WorkerIsolate> spawn(int id) async {
    final receivePort = ReceivePort();
    final isolate = await Isolate.spawn(_workerEntryPoint, receivePort.sendPort);
    
    final completer = Completer<SendPort>();
    final resultController = StreamController<BatchJobResult>.broadcast();
    
    receivePort.listen((message) {
      if (message is SendPort) {
        completer.complete(message);
      } else if (message is Map<String, dynamic>) {
        final result = BatchJobResult.fromMap(message);
        resultController.add(result);
      }
    });
    
    final sendPort = await completer.future;
    
    return WorkerIsolate._(id, sendPort, receivePort, resultController.stream);
  }
  
  Future<void> processJob(BatchJob job) async {
    isBusy = true;
    _sendPort.send(job.toMap());
  }
  
  Future<void> shutdown() async {
    _sendPort.send('shutdown');
    await Future.delayed(Duration(milliseconds: 100));
    _receivePort.close();
  }
  
  static void _workerEntryPoint(SendPort sendPort) async {
    final receivePort = ReceivePort();
    sendPort.send(receivePort.sendPort);
    
    final logger = Logger('WorkerIsolate');
    
    await for (final message in receivePort) {
      if (message == 'shutdown') {
        break;
      }
      
      if (message is Map<String, dynamic>) {
        final job = BatchJob.fromMap(message);
        final startTime = DateTime.now();
        
        try {
          // Run audit
          final auditResult = await _runAudit(job.url, job.options);
          
          // Send result back
          sendPort.send(BatchJobResult(
            jobId: job.id,
            url: job.url,
            success: true,
            data: auditResult,
            duration: DateTime.now().difference(startTime),
            timestamp: DateTime.now(),
            job: job,
          ).toMap());
          
        } catch (e, stackTrace) {
          logger.severe('Error processing ${job.url}: $e\n$stackTrace');
          
          sendPort.send(BatchJobResult(
            jobId: job.id,
            url: job.url,
            success: false,
            error: e.toString(),
            duration: DateTime.now().difference(startTime),
            timestamp: DateTime.now(),
            job: job,
          ).toMap());
        }
      }
    }
  }
  
  static Future<Map<String, dynamic>> _runAudit(String url, Map<String, dynamic> options) async {
    // This is where the actual audit would run
    // For now, return a placeholder
    await Future.delayed(Duration(seconds: 2 + Random().nextInt(3)));
    
    return {
      'url': url,
      'timestamp': DateTime.now().toIso8601String(),
      'scores': {
        'performance': Random().nextDouble(),
        'accessibility': Random().nextDouble(),
        'seo': Random().nextDouble(),
      },
      'audits': {},
    };
  }
}

/// Batch processing job
class BatchJob {
  final String id;
  final String url;
  final Map<String, dynamic> options;
  int retries;
  final int maxRetries;
  
  BatchJob({
    required this.id,
    required this.url,
    required this.options,
    required this.retries,
    required this.maxRetries,
  });
  
  Map<String, dynamic> toMap() => {
    'id': id,
    'url': url,
    'options': options,
    'retries': retries,
    'maxRetries': maxRetries,
  };
  
  static BatchJob fromMap(Map<String, dynamic> map) => BatchJob(
    id: map['id'],
    url: map['url'],
    options: map['options'] ?? {},
    retries: map['retries'] ?? 0,
    maxRetries: map['maxRetries'] ?? 3,
  );
}

/// Result from a batch job
class BatchJobResult {
  final String jobId;
  final String url;
  final bool success;
  final Map<String, dynamic>? data;
  final String? error;
  final Duration duration;
  final DateTime timestamp;
  final BatchJob? job;
  
  BatchJobResult({
    required this.jobId,
    required this.url,
    required this.success,
    this.data,
    this.error,
    required this.duration,
    required this.timestamp,
    this.job,
  });
  
  Map<String, dynamic> toMap() => {
    'jobId': jobId,
    'url': url,
    'success': success,
    'data': data,
    'error': error,
    'duration': duration.inMilliseconds,
    'timestamp': timestamp.toIso8601String(),
    'job': job?.toMap(),
  };
  
  static BatchJobResult fromMap(Map<String, dynamic> map) => BatchJobResult(
    jobId: map['jobId'],
    url: map['url'],
    success: map['success'],
    data: map['data'],
    error: map['error'],
    duration: Duration(milliseconds: map['duration']),
    timestamp: DateTime.parse(map['timestamp']),
    job: map['job'] != null ? BatchJob.fromMap(map['job']) : null,
  );
}

/// Batch processing progress
class BatchProgress {
  final int total;
  final int completed;
  final int failed;
  final String message;
  final bool isError;
  final bool isComplete;
  final int percentage;
  
  BatchProgress({
    required this.total,
    required this.completed,
    required this.failed,
    required this.message,
    this.isError = false,
    this.isComplete = false,
    this.percentage = 0,
  });
}

/// Batch processing result
class BatchResult {
  final String url;
  final bool success;
  final Map<String, dynamic>? data;
  final String? error;
  final Duration duration;
  final DateTime timestamp;
  
  BatchResult({
    required this.url,
    required this.success,
    this.data,
    this.error,
    required this.duration,
    required this.timestamp,
  });
  
  Map<String, dynamic> toMap() => {
    'url': url,
    'success': success,
    'data': data,
    'error': error,
    'duration': duration.inMilliseconds,
    'timestamp': timestamp.toIso8601String(),
  };
}

/// Batch processing report
class BatchReport {
  final DateTime startTime;
  final DateTime endTime;
  final int totalUrls;
  final int successful;
  final int failed;
  final List<BatchResult> results;
  final String? outputDir;
  final BatchStatistics statistics;
  
  BatchReport({
    required this.startTime,
    required this.endTime,
    required this.totalUrls,
    required this.successful,
    required this.failed,
    required this.results,
    this.outputDir,
    required this.statistics,
  });
  
  Duration get totalDuration => endTime.difference(startTime);
  double get successRate => totalUrls > 0 ? successful / totalUrls * 100 : 0;
  
  Map<String, dynamic> toMap() => {
    'startTime': startTime.toIso8601String(),
    'endTime': endTime.toIso8601String(),
    'totalUrls': totalUrls,
    'successful': successful,
    'failed': failed,
    'successRate': successRate,
    'totalDuration': totalDuration.inSeconds,
    'results': results.map((r) => r.toMap()).toList(),
    'outputDir': outputDir,
    'statistics': statistics.toMap(),
  };
  
  Future<void> saveToFile(String filePath) async {
    final formatter = JsonFormatter();
    await formatter.saveToFile(toMap(), filePath);
  }
}

/// Batch processing statistics
class BatchStatistics {
  final int totalJobs;
  final int completedJobs;
  final int failedJobs;
  final int successRate;
  final int averageTimeMs;
  final Duration elapsedTime;
  final Duration estimatedRemaining;
  final int workersActive;
  final int queueLength;
  
  BatchStatistics({
    required this.totalJobs,
    required this.completedJobs,
    required this.failedJobs,
    required this.successRate,
    required this.averageTimeMs,
    required this.elapsedTime,
    required this.estimatedRemaining,
    required this.workersActive,
    required this.queueLength,
  });
  
  int get pendingJobs => totalJobs - completedJobs;
  double get progress => totalJobs > 0 ? completedJobs / totalJobs * 100 : 0;
  
  Map<String, dynamic> toMap() => {
    'totalJobs': totalJobs,
    'completedJobs': completedJobs,
    'failedJobs': failedJobs,
    'pendingJobs': pendingJobs,
    'successRate': successRate,
    'averageTimeMs': averageTimeMs,
    'elapsedTime': elapsedTime.inSeconds,
    'estimatedRemaining': estimatedRemaining.inSeconds,
    'progress': progress,
    'workersActive': workersActive,
    'queueLength': queueLength,
  };
}

/// Batch processor configuration
class BatchConfig {
  final int maxWorkers;
  final int maxRetries;
  final Duration timeout;
  final bool continueOnError;
  final bool saveIndividualResults;
  final String? outputFormat;
  final Map<String, dynamic>? auditOptions;
  
  BatchConfig({
    this.maxWorkers = 4,
    this.maxRetries = 3,
    this.timeout = const Duration(minutes: 5),
    this.continueOnError = true,
    this.saveIndividualResults = false,
    this.outputFormat = 'json',
    this.auditOptions,
  });
  
  factory BatchConfig.fromMap(Map<String, dynamic> map) => BatchConfig(
    maxWorkers: map['maxWorkers'] ?? 4,
    maxRetries: map['maxRetries'] ?? 3,
    timeout: Duration(seconds: map['timeoutSeconds'] ?? 300),
    continueOnError: map['continueOnError'] ?? true,
    saveIndividualResults: map['saveIndividualResults'] ?? false,
    outputFormat: map['outputFormat'] ?? 'json',
    auditOptions: map['auditOptions'],
  );
  
  Map<String, dynamic> toMap() => {
    'maxWorkers': maxWorkers,
    'maxRetries': maxRetries,
    'timeoutSeconds': timeout.inSeconds,
    'continueOnError': continueOnError,
    'saveIndividualResults': saveIndividualResults,
    'outputFormat': outputFormat,
    'auditOptions': auditOptions,
  };
}