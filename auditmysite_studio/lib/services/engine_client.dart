import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';

class EngineClient {
  String baseUrl;
  WebSocketChannel? _wsChannel;
  StreamController<AuditEvent>? _eventController;
  Timer? _reconnectTimer;
  Timer? _healthCheckTimer;
  bool _shouldReconnect = false;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  static const Duration _reconnectInterval = Duration(seconds: 5);
  static const Duration _healthCheckInterval = Duration(seconds: 30);

  EngineClient({this.baseUrl = 'http://localhost:8080'});
  
  // Connection status stream
  final _connectionStatusController = StreamController<ConnectionStatus>.broadcast();
  Stream<ConnectionStatus> get connectionStatusStream => _connectionStatusController.stream;
  ConnectionStatus _currentStatus = ConnectionStatus.disconnected;

  // Auto-discovery of engine
  Future<String?> discoverEngine() async {
    final candidates = [
      'http://localhost:8080',
      'http://localhost:3000', 
      'http://127.0.0.1:8080',
      'http://127.0.0.1:3000',
    ];
    
    for (final url in candidates) {
      if (await _testEngineUrl(url)) {
        return url;
      }
    }
    return null;
  }
  
  Future<bool> _testEngineUrl(String url) async {
    try {
      final response = await http.get(Uri.parse('$url/health')).timeout(
        const Duration(seconds: 2),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> checkHealth() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/health')).timeout(
        const Duration(seconds: 3),
      );
      final isHealthy = response.statusCode == 200;
      
      if (isHealthy && _currentStatus != ConnectionStatus.connected) {
        _setConnectionStatus(ConnectionStatus.connected);
      } else if (!isHealthy && _currentStatus == ConnectionStatus.connected) {
        _setConnectionStatus(ConnectionStatus.error, 'Engine health check failed');
      }
      
      return isHealthy;
    } catch (e) {
      if (_currentStatus != ConnectionStatus.disconnected) {
        _setConnectionStatus(ConnectionStatus.error, e.toString());
      }
      return false;
    }
  }

  // Auto-connect with discovery
  Future<bool> autoConnect() async {
    _setConnectionStatus(ConnectionStatus.connecting);
    
    // First try current baseUrl
    if (await checkHealth()) {
      return await connect();
    }
    
    // Try auto-discovery
    final discoveredUrl = await discoverEngine();
    if (discoveredUrl != null) {
      baseUrl = discoveredUrl;
      return await connect();
    }
    
    _setConnectionStatus(ConnectionStatus.disconnected);
    return false;
  }

  Future<bool> connect({bool enableAutoReconnect = true}) async {
    try {
      _setConnectionStatus(ConnectionStatus.connecting);
      _shouldReconnect = enableAutoReconnect;
      
      // Test health first
      if (!await checkHealth()) {
        throw Exception('Engine health check failed');
      }
      
      // WebSocket läuft auf Port + 1000
      final baseUri = Uri.parse(baseUrl);
      final wsPort = baseUri.port + 1000;
      final wsUrl = 'ws://${baseUri.host}:$wsPort/ws';
      _wsChannel = IOWebSocketChannel.connect(Uri.parse(wsUrl));
      _eventController ??= StreamController<AuditEvent>.broadcast();
      
      _wsChannel!.stream.listen(
        (data) {
          try {
            final json = jsonDecode(data) as Map<String, dynamic>;
            final event = _parseEvent(json);
            if (event != null) {
              _eventController!.add(event);
            }
          } catch (e) {
            print('Error parsing WebSocket message: $e');
          }
        },
        onError: (error) {
          print('WebSocket error: $error');
          _setConnectionStatus(ConnectionStatus.error, error.toString());
          _eventController?.addError(error);
          
          if (_shouldReconnect) {
            _scheduleReconnect();
          }
        },
        onDone: () {
          print('WebSocket connection closed');
          _setConnectionStatus(ConnectionStatus.disconnected);
          
          if (_shouldReconnect && _reconnectAttempts < _maxReconnectAttempts) {
            _scheduleReconnect();
          }
        },
      );
      
      _setConnectionStatus(ConnectionStatus.connected);
      _reconnectAttempts = 0;
      
      // Start periodic health checks
      if (enableAutoReconnect) {
        _startHealthChecks();
      }
      
      return true;
    } catch (e) {
      _setConnectionStatus(ConnectionStatus.error, e.toString());
      
      if (_shouldReconnect && _reconnectAttempts < _maxReconnectAttempts) {
        _scheduleReconnect();
      }
      
      return false;
    }
  }
  
  Future<void> disconnect() async {
    _shouldReconnect = false;
    _reconnectTimer?.cancel();
    _healthCheckTimer?.cancel();
    
    await _wsChannel?.sink.close();
    _wsChannel = null;
    
    _setConnectionStatus(ConnectionStatus.disconnected);
  }
  
  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectAttempts++;
    
    print('Scheduling reconnect attempt $_reconnectAttempts/$_maxReconnectAttempts in ${_reconnectInterval.inSeconds}s');
    
    _reconnectTimer = Timer(_reconnectInterval, () async {
      if (_shouldReconnect && _reconnectAttempts <= _maxReconnectAttempts) {
        print('Attempting reconnect...');
        await connect(enableAutoReconnect: true);
      }
    });
  }
  
  void _startHealthChecks() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer.periodic(_healthCheckInterval, (timer) async {
      if (_currentStatus == ConnectionStatus.connected) {
        final isHealthy = await checkHealth();
        if (!isHealthy && _shouldReconnect) {
          print('Health check failed, attempting reconnect...');
          await disconnect();
          _scheduleReconnect();
        }
      }
    });
  }
  
  void _setConnectionStatus(ConnectionStatus status, [String? error]) {
    _currentStatus = status;
    _connectionStatusController.add(status);
    
    if (error != null) {
      print('Connection status changed to $status: $error');
    } else {
      print('Connection status changed to $status');
    }
  }
  
  ConnectionStatus get connectionStatus => _currentStatus;
  
  void dispose() {
    _shouldReconnect = false;
    _reconnectTimer?.cancel();
    _healthCheckTimer?.cancel();
    _connectionStatusController.close();
    _eventController?.close();
  }

  Future<String> startAudit({
    required String sitemapUrl,
    int concurrency = 4,
    bool collectPerf = true,
    bool screenshots = false,
  }) async {
    // For MVP, return instruction for manual execution
    return 'dart run auditmysite_engine:run --sitemap="$sitemapUrl" --concurrency=$concurrency ${collectPerf ? '--perf' : ''} ${screenshots ? '--screenshots' : ''}';
  }

  Stream<AuditEvent> getEventStream() {
    return _eventController?.stream ?? Stream.empty();
  }
  
  bool get isConnected => _currentStatus == ConnectionStatus.connected;
  
  AuditEvent? _parseEvent(Map<String, dynamic> json) {
    final url = json['url'] as String? ?? '';
    final timestamp = DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now();
    final eventType = json['event'] as String? ?? '';
    
    switch (eventType) {
      case 'page_queued':
        return PageQueued(url: url, timestamp: timestamp);
      case 'page_started':
        return PageStarted(url: url, timestamp: timestamp);
      case 'page_finished':
        final statusCode = json['status_code'] as int?;
        final violationCount = json['violation_count'] as int? ?? 0;
        return PageFinished(
          url: url, 
          timestamp: timestamp,
          statusCode: statusCode,
          violationCount: violationCount,
        );
      case 'page_error':
        final error = json['message'] as String? ?? 'Unknown error';
        return PageError(url: url, timestamp: timestamp, error: error);
      case 'page_retry':
        final attempt = json['attempt'] as int? ?? 1;
        return PageRetry(url: url, timestamp: timestamp, attempt: attempt);
      default:
        return null;
    }
  }
}

abstract class AuditEvent {
  final String url;
  final DateTime timestamp;
  
  AuditEvent({required this.url, required this.timestamp});
}

class PageQueued extends AuditEvent {
  PageQueued({required super.url, required super.timestamp});
}

class PageStarted extends AuditEvent {
  PageStarted({required super.url, required super.timestamp});
}

class PageFinished extends AuditEvent {
  final int? statusCode;
  final int violationCount;
  
  PageFinished({
    required super.url,
    required super.timestamp,
    this.statusCode,
    required this.violationCount,
  });
}

class PageError extends AuditEvent {
  final String error;
  
  PageError({
    required super.url,
    required super.timestamp,
    required this.error,
  });
}

class PageRetry extends AuditEvent {
  final int attempt;
  
  PageRetry({
    required super.url,
    required super.timestamp,
    required this.attempt,
  });
}

// Connection Status Enum
enum ConnectionStatus {
  disconnected,
  connecting,
  connected,
  error,
}
