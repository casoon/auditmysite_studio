import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/engine_client.dart';
import '../services/settings_service.dart';

// Provider for engine client
final engineClientProvider = Provider<EngineClient>((ref) {
  return EngineClient();
});

// Provider for connection state
final connectionStateProvider = StateNotifierProvider<ConnectionStateNotifier, ConnectionState>((ref) {
  return ConnectionStateNotifier(ref.watch(engineClientProvider));
});

// Provider for audit events
final auditEventsProvider = StateNotifierProvider<AuditEventsNotifier, List<AuditEvent>>((ref) {
  return AuditEventsNotifier(ref.watch(engineClientProvider));
});

// Auto-connect provider that handles settings integration
final autoConnectProvider = FutureProvider<bool>((ref) async {
  final client = ref.watch(engineClientProvider);
  
  try {
    final settings = await SettingsService.getInstance();
    
    // Load settings
    final engineUrl = await settings.getEngineUrl();
    final enginePort = await settings.getEnginePort();
    final autoConnect = await settings.getAutoConnectEngine();
    
    // Update client URL
    client.baseUrl = 'http://$engineUrl:$enginePort';
    
    // Auto-connect if enabled
    if (autoConnect) {
      return await client.autoConnect();
    }
  } catch (e) {
    print('Auto-connect failed: $e');
  }
  
  return false;
});

class ConnectionState {
  final bool isConnected;
  final String? error;
  
  ConnectionState({required this.isConnected, this.error});
}

class ConnectionStateNotifier extends StateNotifier<ConnectionState> {
  final EngineClient _client;
  
  ConnectionStateNotifier(this._client) : super(ConnectionState(isConnected: false)) {
    // Listen to client connection status changes
    _client.connectionStatusStream.listen((status) {
      switch (status) {
        case ConnectionStatus.connected:
          state = ConnectionState(isConnected: true);
          break;
        case ConnectionStatus.connecting:
          state = ConnectionState(isConnected: false, error: 'Connecting...');
          break;
        case ConnectionStatus.disconnected:
          state = ConnectionState(isConnected: false);
          break;
        case ConnectionStatus.error:
          state = ConnectionState(isConnected: false, error: 'Connection error');
          break;
      }
    });
  }
  
  Future<void> connect() async {
    await _client.connect();
  }
  
  Future<void> autoConnect() async {
    await _client.autoConnect();
  }
  
  Future<void> disconnect() async {
    await _client.disconnect();
  }
}

class AuditEventsNotifier extends StateNotifier<List<AuditEvent>> {
  final EngineClient _client;
  
  AuditEventsNotifier(this._client) : super([]) {
    _client.getEventStream().listen((event) {
      state = [...state, event];
      // Keep only last 100 events
      if (state.length > 100) {
        state = state.sublist(state.length - 100);
      }
    });
  }
  
  void clear() {
    state = [];
  }
}

class ProgressView extends ConsumerWidget {
  const ProgressView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectionState = ref.watch(connectionStateProvider);
    final events = ref.watch(auditEventsProvider);
    // Auto-connect provider is watched for initialization
    ref.watch(autoConnectProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Audit Progress'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            onPressed: connectionState.isConnected 
                ? () => ref.read(connectionStateProvider.notifier).disconnect()
                : () => ref.read(connectionStateProvider.notifier).autoConnect(),
            icon: Icon(connectionState.isConnected ? Icons.stop : Icons.wifi_find),
            tooltip: connectionState.isConnected ? 'Disconnect' : 'Auto-Connect to Engine',
          ),
          if (!connectionState.isConnected)
            IconButton(
              onPressed: () => ref.read(connectionStateProvider.notifier).connect(),
              icon: const Icon(Icons.play_arrow),
              tooltip: 'Manual Connect',
            ),
          if (events.isNotEmpty)
            IconButton(
              onPressed: () => ref.read(auditEventsProvider.notifier).clear(),
              icon: const Icon(Icons.clear),
              tooltip: 'Clear Events',
            ),
        ],
      ),
      body: Column(
        children: [
          // Connection Status Card
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    connectionState.isConnected ? Icons.wifi : Icons.wifi_off,
                    color: connectionState.isConnected ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    connectionState.isConnected 
                        ? 'Verbunden mit Engine (ws://localhost:8080/ws)'
                        : 'Nicht verbunden',
                    style: TextStyle(
                      color: connectionState.isConnected ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (connectionState.error != null) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        connectionState.error!,
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          
          // Events List
          Expanded(
            child: events.isEmpty
                ? _buildEmptyState(connectionState.isConnected)
                : _buildEventsList(events),
          ),
        ],
      ),
    );
  }
  
  Widget _buildEmptyState(bool isConnected) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isConnected ? Icons.hourglass_empty : Icons.cable,
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            isConnected 
                ? 'Warten auf Audit-Events...'
                : 'Verbinde mit Engine um Live-Events zu sehen',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            isConnected
                ? 'Starte einen Audit in der Engine um Live-Progress zu sehen.'
                : 'Klicke auf den Play-Button oben rechts.',
            style: const TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          if (isConnected) ...[
            const SizedBox(height: 24),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      'Engine Kommando:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    SelectableText(
                      'dart run auditmysite_engine:run --serve --sitemap=https://example.com/sitemap.xml',
                      style: TextStyle(fontFamily: 'monospace', fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildEventsList(List<AuditEvent> events) {
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.all(16),
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[events.length - 1 - index];
        return _buildEventCard(event);
      },
    );
  }
  
  Widget _buildEventCard(AuditEvent event) {
    IconData icon;
    Color color;
    String title;
    String subtitle;
    
    switch (event.runtimeType) {
      case PageQueued:
        icon = Icons.queue;
        color = Colors.blue;
        title = 'Page Queued';
        subtitle = event.url;
        break;
      case PageStarted:
        icon = Icons.play_circle;
        color = Colors.orange;
        title = 'Page Started';
        subtitle = event.url;
        break;
      case PageFinished:
        final finishedEvent = event as PageFinished;
        icon = Icons.check_circle;
        color = Colors.green;
        title = 'Page Finished';
        subtitle = '${event.url} (${finishedEvent.violationCount} violations)';
        break;
      case PageError:
        final errorEvent = event as PageError;
        icon = Icons.error;
        color = Colors.red;
        title = 'Page Error';
        subtitle = '${event.url}: ${errorEvent.error}';
        break;
      case PageRetry:
        final retryEvent = event as PageRetry;
        icon = Icons.refresh;
        color = Colors.amber;
        title = 'Page Retry';
        subtitle = '${event.url} (Attempt ${retryEvent.attempt})';
        break;
      default:
        icon = Icons.info;
        color = Colors.grey;
        title = 'Unknown Event';
        subtitle = event.url;
    }
    
    return Card(
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title),
        subtitle: Text(
          subtitle,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Text(
          _formatTime(event.timestamp),
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ),
    );
  }
  
  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    
    if (diff.inSeconds < 60) {
      return '${diff.inSeconds}s ago';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else {
      return '${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
    }
  }
}
