import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/settings_service.dart';

class RunSetupView extends ConsumerStatefulWidget {
  const RunSetupView({super.key});

  @override
  ConsumerState<RunSetupView> createState() => _RunSetupViewState();
}

class _RunSetupViewState extends ConsumerState<RunSetupView> {
  final _sitemapController = TextEditingController(text: 'https://example.com/sitemap.xml');
  int _concurrency = 4;
  bool _perf = true;
  bool _seo = true;
  bool _contentWeight = true;
  bool _mobile = true;
  bool _screenshots = false;
  bool _isStarting = false;
  String? _engineUrl;

  @override
  void initState() {
    super.initState();
    _loadEngineSettings();
  }
  
  @override
  void dispose() {
    _sitemapController.dispose();
    super.dispose();
  }
  
  Future<void> _loadEngineSettings() async {
    try {
      final settings = await SettingsService.getInstance();
      final engineHost = await settings.getEngineUrl();
      final enginePort = await settings.getEnginePort();
      
      if (mounted) {
        setState(() {
          _engineUrl = 'http://$engineHost:$enginePort';
        });
      }
    } catch (e) {
      // Use default if settings fail to load
      setState(() {
        _engineUrl = 'http://localhost:8080';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 800;
    
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.analytics, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            const Text('AuditMySite Studio'),
            const Spacer(),
            // Engine Status Indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _engineUrl != null ? Colors.green : Colors.orange,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _engineUrl != null ? Icons.check_circle : Icons.pending,
                    size: 16,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _engineUrl != null ? 'Engine Ready' : 'Loading...',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
        elevation: 1,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: EdgeInsets.all(isWideScreen ? 32.0 : 16.0),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: isWideScreen ? 1000 : double.infinity),
                child: isWideScreen ? _buildWideLayout(context) : _buildNarrowLayout(context),
              ),
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildWideLayout(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column - Configuration
        Expanded(
          flex: 2,
          child: Column(
            children: [
              _buildSitemapCard(context),
              const SizedBox(height: 16),
              _buildAuditSettingsCard(context),
            ],
          ),
        ),
        const SizedBox(width: 24),
        // Right Column - Action & Status
        Expanded(
          flex: 1,
          child: Column(
            children: [
              _buildActionCard(context),
              const SizedBox(height: 16),
              _buildStatusCard(context),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildNarrowLayout(BuildContext context) {
    return Column(
      children: [
        _buildSitemapCard(context),
        const SizedBox(height: 16),
        _buildAuditSettingsCard(context),
        const SizedBox(height: 16),
        _buildActionCard(context),
        const SizedBox(height: 16),
        _buildStatusCard(context),
      ],
    );
  }
  
  Widget _buildSitemapCard(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.language, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Website Configuration',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _sitemapController,
              decoration: InputDecoration(
                labelText: 'Sitemap URL',
                helperText: 'Enter the URL to your sitemap.xml file',
                helperMaxLines: 2,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.link),
                suffixIcon: _sitemapController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _sitemapController.clear()),
                      )
                    : null,
              ),
              onChanged: (_) => setState(() {}), // Rebuild to update button state
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildAuditSettingsCard(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.tune, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Audit Configuration',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Concurrency Setting
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.speed),
                  const SizedBox(width: 12),
                  const Text('Concurrency:', style: TextStyle(fontWeight: FontWeight.w500)),
                  const Spacer(),
                  DropdownButton<int>(
                    value: _concurrency,
                    underline: Container(),
                    items: [2, 4, 6, 8, 12, 16].map((e) =>
                      DropdownMenuItem(
                        value: e,
                        child: Text('$e workers', style: const TextStyle(fontWeight: FontWeight.w500)),
                      )
                    ).toList(),
                    onChanged: (v) => setState(() => _concurrency = v ?? 4),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            Text('Audit Categories:', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            
            _buildAuditToggle(
              context,
              'Performance Audits',
              'Core Web Vitals + Scoring (TTFB, FCP, LCP, CLS)',
              Icons.speed,
              _perf,
              (v) => setState(() => _perf = v),
              Colors.blue,
            ),
            _buildAuditToggle(
              context,
              'SEO Audits',
              'Meta Tags, Headings, Images, OpenGraph',
              Icons.search,
              _seo,
              (v) => setState(() => _seo = v),
              Colors.green,
            ),
            _buildAuditToggle(
              context,
              'Content Weight Audits',
              'Resource sizes, optimization recommendations',
              Icons.file_download,
              _contentWeight,
              (v) => setState(() => _contentWeight = v),
              Colors.orange,
            ),
            _buildAuditToggle(
              context,
              'Mobile Friendliness',
              'Responsive design, touch targets, viewport',
              Icons.phone_android,
              _mobile,
              (v) => setState(() => _mobile = v),
              Colors.purple,
            ),
            _buildAuditToggle(
              context,
              'Screenshots',
              'Full-page screenshots (slower processing)',
              Icons.camera_alt,
              _screenshots,
              (v) => setState(() => _screenshots = v),
              Colors.grey,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildAuditToggle(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    bool value,
    Function(bool) onChanged,
    Color color,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        secondary: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(subtitle, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7))),
        value: value,
        onChanged: onChanged,
      ),
    );
  }
  
  Widget _buildActionCard(BuildContext context) {
    final enabledAuditsCount = [_perf, _seo, _contentWeight, _mobile, _screenshots].where((x) => x).length;
    
    return Card(
      elevation: 3,
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Icon(
              Icons.rocket_launch,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Ready to Start Audit',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$enabledAuditsCount audit categories enabled',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton.icon(
                onPressed: _sitemapController.text.isEmpty || _isStarting || _engineUrl == null ? null : _startAudit,
                icon: _isStarting 
                    ? const SizedBox(
                        width: 20, 
                        height: 20, 
                        child: CircularProgressIndicator(
                          strokeWidth: 2, 
                          color: Colors.white
                        ),
                      )
                    : const Icon(Icons.play_arrow, size: 28),
                label: Text(
                  _isStarting ? 'Starting Audit...' : 'Start Audit',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: _isStarting ? Colors.grey : Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            if (_sitemapController.text.isEmpty || _engineUrl == null) ...[
              const SizedBox(height: 8),
              Text(
                _sitemapController.text.isEmpty 
                    ? 'Please enter a sitemap URL'
                    : 'Waiting for engine connection...',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildStatusCard(BuildContext context) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Engine Status',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _engineUrl != null 
                    ? Theme.of(context).colorScheme.primaryContainer
                    : Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _engineUrl != null ? Icons.check_circle : Icons.error,
                        color: _engineUrl != null 
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.error,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _engineUrl != null ? 'Connected' : 'Not Connected',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _engineUrl != null 
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _engineUrl ?? 'Engine not available',
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
            if (_engineUrl == null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Start the engine:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    SelectableText(
                      'dart run bin/serve.dart --port=8080',
                      style: TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Future<void> _startAudit() async {
    if (_engineUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Engine configuration not loaded. Please wait or check settings.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    setState(() {
      _isStarting = true;
    });
    
    try {
      // First check engine health
      final healthResponse = await http.get(
        Uri.parse('$_engineUrl/health'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));
      
      if (healthResponse.statusCode != 200) {
        throw Exception('Engine health check failed: ${healthResponse.statusCode}');
      }
      
      // Start audit
      final auditPayload = {
        'sitemap_url': _sitemapController.text,
        'concurrency': _concurrency,
        'collect_perf': _perf,
        'collect_seo': _seo,
        'collect_content_weight': _contentWeight,
        'collect_mobile': _mobile,
        'screenshots': _screenshots,
        'max_pages': 50, // Reasonable limit for demo
      };
      
      final auditResponse = await http.post(
        Uri.parse('$_engineUrl/audit'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(auditPayload),
      ).timeout(const Duration(seconds: 10));
      
      if (auditResponse.statusCode == 200) {
        final responseData = jsonDecode(auditResponse.body) as Map<String, dynamic>;
        final runId = responseData['run_id'] as String?;
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Audit started successfully!${runId != null ? ' Run ID: $runId' : ''}'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: 'View Progress',
                textColor: Colors.white,
                onPressed: () {
                  // Switch to Progress tab
                  final scaffold = Scaffold.of(context);
                  if (scaffold.hasDrawer) {
                    Navigator.pushReplacementNamed(context, '/progress');
                  }
                },
              ),
            ),
          );
        }
      } else {
        throw Exception('Engine returned status ${auditResponse.statusCode}: ${auditResponse.body}');
      }
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Failed to start audit: ${e.toString()}'),
                const SizedBox(height: 8),
                const Text(
                  'Make sure the engine is running:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'cd auditmysite_engine && dart run bin/serve.dart --port=8080',
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 10),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isStarting = false;
        });
      }
    }
  }
}
