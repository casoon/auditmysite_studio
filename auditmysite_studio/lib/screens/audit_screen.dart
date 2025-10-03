import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:auditmysite_engine/core/sitemap_parser.dart';
import '../providers/embedded_engine_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuditScreen extends ConsumerStatefulWidget {
  const AuditScreen({super.key});

  @override
  ConsumerState<AuditScreen> createState() => _AuditScreenState();
}

class _AuditScreenState extends ConsumerState<AuditScreen> {
  final _urlController = TextEditingController();
  final _urls = <String>[];
  bool _isRunning = false;
  bool _parseSitemap = false;
  bool _isLoadingSitemap = false;
  String _outputPath = '';
  List<String> _recentDomains = [];
  
  static const String _prefKeyOutputPath = 'audit_output_path';
  static const String _prefKeyRecentDomains = 'audit_recent_domains';

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }
  
  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Load saved output path or use default
    final savedPath = prefs.getString(_prefKeyOutputPath);
    if (savedPath != null && savedPath.isNotEmpty && mounted) {
      setState(() {
        _outputPath = savedPath;
      });
    } else {
      // Set default output path - use Documents folder for better access
      final home = Platform.environment['HOME'] ?? '/Users/${Platform.environment['USER']}';
      setState(() {
        _outputPath = path.join(
          home,
          'Documents',
          'AuditMySite_Results',
        );
      });
    }
    
    // Load recent domains
    final domains = prefs.getStringList(_prefKeyRecentDomains) ?? [];
    if (mounted) {
      setState(() {
        _recentDomains = domains;
      });
    }
  }
  
  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Save output path
    if (_outputPath.isNotEmpty) {
      await prefs.setString(_prefKeyOutputPath, _outputPath);
    }
  }
  
  Future<void> _saveDomain(String url) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Extract domain from URL for cleaner history
    Uri? uri = Uri.tryParse(url);
    final domainToSave = uri?.host ?? url;
    
    if (domainToSave.isNotEmpty) {
      // Remove if already exists, then add to front
      _recentDomains.remove(domainToSave);
      _recentDomains.insert(0, domainToSave);
      
      // Keep only last 5
      if (_recentDomains.length > 5) {
        _recentDomains = _recentDomains.take(5).toList();
      }
      
      await prefs.setStringList(_prefKeyRecentDomains, _recentDomains);
      
      if (mounted) {
        setState(() {});
      }
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  void _addUrl() async {
    final url = _urlController.text.trim();
    if (url.isNotEmpty && Uri.tryParse(url) != null) {
      if (_parseSitemap) {
        // Parse sitemap and add all URLs
        setState(() {
          _isLoadingSitemap = true;
        });
        
        try {
          final sitemapUrls = await SitemapParser.parseSitemapFromUrl(url);
          if (sitemapUrls.isNotEmpty) {
            setState(() {
              _urls.addAll(sitemapUrls);
              _urlController.clear();
            });
            
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Found ${sitemapUrls.length} URLs from sitemap'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          } else {
            // No sitemap found, add single URL
            setState(() {
              _urls.add(url);
              _urlController.clear();
            });
            
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('No sitemap found, added single URL'),
                  backgroundColor: Colors.orange,
                ),
              );
            }
          }
        } catch (e) {
          // Error parsing sitemap, add single URL
          setState(() {
            _urls.add(url);
            _urlController.clear();
          });
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error parsing sitemap: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        } finally {
          setState(() {
            _isLoadingSitemap = false;
          });
        }
      } else {
        // Add single URL
        setState(() {
          _urls.add(url);
          _urlController.clear();
        });
      }
    }
  }

  void _removeUrl(String url) {
    setState(() {
      _urls.remove(url);
    });
  }

  Future<void> _startAudit() async {
    if (_urls.isEmpty) return;

    setState(() {
      _isRunning = true;
    });
    
    // Save the first domain to history
    if (_urls.isNotEmpty) {
      await _saveDomain(_urls.first);
    }
    
    // Extract domain name for folder
    String domainFolder = 'unknown';
    try {
      final uri = Uri.parse(_urls.first);
      domainFolder = uri.host.replaceAll('www.', '').replaceAll('.', '_');
    } catch (_) {
      domainFolder = 'unknown_${DateTime.now().millisecondsSinceEpoch}';
    }
    
    // Create domain-based folder path
    final domainPath = path.join(
      _outputPath,
      domainFolder,
    );

    try {
      final engineService = ref.read(engineServiceProvider);
      
      // Start the audit
      final session = await engineService.startAudit(
        urls: _urls,
        outputPath: domainPath,
        concurrency: 4,
        enablePerformance: true,
        enableSEO: true,
        enableContentWeight: true,
        enableContentQuality: true,
        enableAccessibility: true,
        useAdvancedAudits: true,
      );
      
      // Store session in provider
      ref.read(auditSessionProvider.notifier).state = session;
      
      // Start monitoring progress
      ref.read(auditProgressProvider.notifier).startMonitoring(_urls.length);
      
      // Wait for completion
      await session.processFuture;
      
      // Show completion message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Audit completed! Results saved to $domainPath'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Audit failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRunning = false;
        });
      }
      ref.read(auditProgressProvider.notifier).stopMonitoring();
    }
  }

  Future<void> _cancelAudit() async {
    final engineService = ref.read(engineServiceProvider);
    await engineService.cancelAudit();
    
    setState(() {
      _isRunning = false;
    });
    
    ref.read(auditProgressProvider.notifier).stopMonitoring();
  }
  
  Future<void> _selectOutputPath() async {
    try {
      // Use FilePicker for free folder selection
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select Output Folder for Audit Results',
      );
      
      if (selectedDirectory != null) {
        setState(() {
          // Use selected directory directly (timestamped subfolder created per audit)
          _outputPath = selectedDirectory;
        });
        
        // Save the selected path
        await _savePreferences();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Output folder set to: $_outputPath'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting folder: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  Future<void> _openOutputFolder() async {
    try {
      final directory = Directory(_outputPath);
      
      // Create directory if it doesn't exist
      if (!await directory.exists()) {
        await directory.create(recursive: true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Created folder: $_outputPath'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
      
      // Open the folder in Finder (macOS) - use full path
      if (Platform.isMacOS) {
        final result = await Process.run('/usr/bin/open', [_outputPath]);
        if (result.exitCode != 0) {
          throw Exception('Failed to open folder: ${result.stderr}');
        }
      } else if (Platform.isWindows) {
        await Process.run('explorer', [_outputPath]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [_outputPath]);
      }
    } catch (e) {
      if (mounted) {
        // Show the path in the error message so user can navigate manually
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Cannot open folder automatically.'),
                const SizedBox(height: 4),
                Text('Path: $_outputPath', style: const TextStyle(fontSize: 12)),
                const Text('You can navigate there manually in Finder.', style: TextStyle(fontSize: 12)),
              ],
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(auditProgressProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('AuditMySite - Direct Engine'),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // URL Input Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add URLs to Audit',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _urlController,
                            decoration: InputDecoration(
                              hintText: 'https://example.com',
                              border: const OutlineInputBorder(),
                              suffixIcon: _recentDomains.isNotEmpty
                                ? PopupMenuButton<String>(
                                    icon: const Icon(Icons.history),
                                    tooltip: 'Recent domains',
                                    onSelected: (String domain) {
                                      setState(() {
                                        // Add https:// if not present
                                        final url = domain.startsWith('http') 
                                          ? domain 
                                          : 'https://$domain';
                                        _urlController.text = url;
                                      });
                                    },
                                    itemBuilder: (BuildContext context) {
                                      return _recentDomains.map((String domain) {
                                        return PopupMenuItem<String>(
                                          value: domain,
                                          child: ListTile(
                                            dense: true,
                                            leading: const Icon(Icons.web, size: 20),
                                            title: Text(domain),
                                          ),
                                        );
                                      }).toList();
                                    },
                                  )
                                : null,
                            ),
                            enabled: !_isRunning && !_isLoadingSitemap,
                            onSubmitted: (_) => _addUrl(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: (_isRunning || _isLoadingSitemap) ? null : _addUrl,
                          icon: _isLoadingSitemap 
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.add),
                          label: Text(_isLoadingSitemap ? 'Loading...' : 'Add'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      title: const Text('Parse sitemap.xml and include all URLs'),
                      subtitle: const Text('Automatically discovers and adds all pages from the website\'s sitemap'),
                      value: _parseSitemap,
                      onChanged: _isRunning ? null : (value) {
                        setState(() {
                          _parseSitemap = value ?? false;
                        });
                      },
                      controlAffinity: ListTileControlAffinity.leading,
                      dense: true,
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // URLs List
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'URLs to Audit (${_urls.length})',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: _urls.isEmpty
                            ? Center(
                                child: Text(
                                  'No URLs added yet',
                                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              )
                            : ListView.builder(
                                itemCount: _urls.length,
                                itemBuilder: (context, index) {
                                  final url = _urls[index];
                                  return ListTile(
                                    leading: const Icon(Icons.link),
                                    title: Text(url),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.remove_circle_outline),
                                      onPressed: _isRunning ? null : () => _removeUrl(url),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Progress Section
            if (_isRunning) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Audit Progress',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 16),
                      LinearProgressIndicator(
                        value: progress.progress,
                        minHeight: 8,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Processing: ${progress.currentUrl ?? 'Starting...'}'),
                          Text('${progress.processedUrls + progress.failedUrls + progress.skippedUrls}/${progress.totalUrls}'),
                        ],
                      ),
                      if (progress.lastError != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Error: ${progress.lastError}',
                          style: TextStyle(color: Theme.of(context).colorScheme.error),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            // Output Path
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.folder_outlined),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Output Path',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _outputPath,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  fontFamily: 'monospace',
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: _isRunning ? null : _selectOutputPath,
                          icon: const Icon(Icons.folder_open),
                          label: const Text('Change Folder'),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: _openOutputFolder,
                          icon: const Icon(Icons.launch),
                          label: const Text('Open Folder'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (_isRunning)
                  FilledButton.icon(
                    onPressed: _cancelAudit,
                    icon: const Icon(Icons.stop),
                    label: const Text('Cancel'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.error,
                    ),
                  )
                else
                  FilledButton.icon(
                    onPressed: _urls.isEmpty ? null : _startAudit,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start Audit'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}