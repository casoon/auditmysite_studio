import 'dart:io';
import 'package:args/args.dart';
import 'package:auditmysite_engine/service/websocket_service.dart';
import 'package:auditmysite_engine/service/http_api_service.dart';
import 'dart:async';

Future<void> main(List<String> args) async {
  final parser = ArgParser()
    ..addOption('port', abbr: 'p', defaultsTo: '8080', help: 'WebSocket server port')
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show help');

  final opts = parser.parse(args);
  
  if (opts['help'] as bool) {
    print('auditmysite_engine WebSocket Server');
    print('');
    print('Usage: dart run bin/serve.dart [options]');
    print('');
    print('Options:');
    print(parser.usage);
    print('');
    print('API Endpoints:');
    print('  GET  /health   - Health check');
    print('  GET  /status   - Service status');
    print('  POST /audit    - Start comprehensive audit');
    print('  WS   /ws       - WebSocket for live events (port+1000)');
    print('');
    print('Start an audit via HTTP POST /audit with JSON payload:');
    print('{');
    print('  "sitemap_url": "https://example.com/sitemap.xml",');
    print('  "concurrency": 2,');
    print('  "collect_perf": true,');
    print('  "collect_seo": true,');
    print('  "collect_content_weight": true,');
    print('  "collect_mobile": true,');
    print('  "screenshots": false,');
    print('  "max_pages": 50');
    print('}');
    print('');
    print('Features in v2.1:');
    print('  ✅ Accessibility (Pa11y + Axe)');
    print('  ✅ Performance (Core Web Vitals + Scoring)');
    print('  ✅ SEO (Meta Tags + Headings + Images)');
    print('  ✅ Content Weight (Resource Sizes + Optimization)');
    print('  ✅ Mobile Friendliness (Responsive + Touch Targets)');
    print('  ✅ HTTP Status & Headers (Redirects + SSL)');
    print('  ✅ Live WebSocket Events');
    print('  ✅ JSON Export with Grading');
    exit(0);
  }

  final port = int.parse(opts['port'] as String);
  final wsService = WebSocketService(port: port + 1000); // WebSocket on port + 1000
  final httpApiService = HttpApiService(port: port); // HTTP API on main port

  // Handle graceful shutdown
  ProcessSignal.sigint.watch().listen((signal) async {
    print('\nReceived SIGINT, shutting down...');
    await wsService.stop();
    await httpApiService.stop();
    exit(0);
  });

  ProcessSignal.sigterm.watch().listen((signal) async {
    print('\nReceived SIGTERM, shutting down...');
    await wsService.stop();
    await httpApiService.stop();
    exit(0);
  });

  try {
    // Start HTTP API service (main functionality)
    await httpApiService.start();
    
    // Start WebSocket service (for live events)
    await wsService.start();
    
    print('🚀 AuditMySite Engine v2.1 ready!');
    print('📡 HTTP API: http://localhost:$port');
    print('🔌 WebSocket: ws://localhost:${port + 1000}/ws');
    print('📊 Features: Accessibility, Performance, SEO, Content Weight, Mobile');
    
    // Keep the server running
    final completer = Completer<void>();
    await completer.future; // This will never complete, keeping the server alive
    
  } catch (e) {
    print('Failed to start server: $e');
    exit(1);
  }
}
