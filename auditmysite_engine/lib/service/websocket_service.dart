import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:shelf_cors_headers/shelf_cors_headers.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../core/events.dart';

class WebSocketService {
  final int port;
  HttpServer? _server;
  final Set<StreamSink> _clients = {};
  StreamSubscription<AuditEvent>? _eventSubscription;

  WebSocketService({this.port = 8080});

  Future<void> start() async {
    final handler = Pipeline()
        .addMiddleware(corsHeaders())
        .addMiddleware(logRequests())
        .addHandler(_createRouter());

    _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
    print('WebSocket service running on http://localhost:$port');
    print('WebSocket endpoint: ws://localhost:$port/ws');
  }

  Future<void> stop() async {
    await _eventSubscription?.cancel();
    _eventSubscription = null;
    
    for (final client in _clients.toList()) {
      await client.close();
    }
    _clients.clear();
    
    await _server?.close();
    _server = null;
  }

  void subscribeToEvents(Stream<AuditEvent> eventStream) {
    _eventSubscription = eventStream.listen((event) {
      final eventData = _serializeEvent(event);
      _broadcastToClients(eventData);
    });
  }

  Handler _createRouter() {
    return (Request request) {
      if (request.url.path == 'ws') {
        return webSocketHandler((WebSocketChannel webSocket) {
          print('New WebSocket client connected');
          
          _clients.add(webSocket.sink);
          
          // Send welcome message
          webSocket.sink.add(jsonEncode({
            'type': 'connection',
            'status': 'connected',
            'timestamp': DateTime.now().toIso8601String(),
          }));

          webSocket.stream.listen(
            (message) {
              // Handle incoming messages from client if needed
              print('Received from client: $message');
            },
            onDone: () {
              print('WebSocket client disconnected');
              _clients.remove(webSocket.sink);
            },
            onError: (error) {
              print('WebSocket error: $error');
              _clients.remove(webSocket.sink);
            },
          );
        })(request);
      }

      if (request.url.path == 'health') {
        return Response.ok(jsonEncode({
          'status': 'healthy',
          'timestamp': DateTime.now().toIso8601String(),
          'clients': _clients.length,
        }), headers: {'content-type': 'application/json'});
      }

      if (request.url.path == 'status') {
        return Response.ok(jsonEncode({
          'service': 'auditmysite_engine',
          'version': '0.1.0',
          'websocket_clients': _clients.length,
          'timestamp': DateTime.now().toIso8601String(),
        }), headers: {'content-type': 'application/json'});
      }

      return Response.notFound('Not found');
    };
  }

  void _broadcastToClients(Map<String, dynamic> message) {
    final json = jsonEncode(message);
    final clientsToRemove = <StreamSink>[];
    
    for (final client in _clients) {
      try {
        client.add(json);
      } catch (e) {
        print('Error sending to client: $e');
        clientsToRemove.add(client);
      }
    }
    
    // Remove dead clients
    for (final client in clientsToRemove) {
      _clients.remove(client);
    }
  }

  Map<String, dynamic> _serializeEvent(AuditEvent event) {
    final base = {
      'timestamp': DateTime.now().toIso8601String(),
      'url': event.url.toString(),
      'type': event.runtimeType.toString(),
    };

    switch (event.runtimeType) {
      case PageQueued:
        return {...base, 'event': 'page_queued'};
      
      case PageStarted:
        return {...base, 'event': 'page_started'};
      
      case PageFinished:
        return {...base, 'event': 'page_finished'};
      
      case PageError:
        final errorEvent = event as PageError;
        return {
          ...base,
          'event': 'page_error',
          'message': errorEvent.message,
        };
      
      case PageRetry:
        final retryEvent = event as PageRetry;
        return {
          ...base,
          'event': 'page_retry',
          'attempt': retryEvent.attempt,
          'delay_ms': retryEvent.delayMs,
        };
      
      case AuditAttached:
        final auditEvent = event as AuditAttached;
        return {
          ...base,
          'event': 'audit_attached',
          'audit_name': auditEvent.auditName,
        };
      
      case AuditFinished:
        final auditEvent = event as AuditFinished;
        return {
          ...base,
          'event': 'audit_finished',
          'audit_name': auditEvent.auditName,
        };
      
      default:
        return {...base, 'event': 'unknown'};
    }
  }
}
