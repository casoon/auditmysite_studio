import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'dart:io';
import 'package:process_run/process_run.dart';
import '../services/settings_service.dart';
import '../services/results_manager.dart';

// Provider for loaded results
final loadedResultsProvider = StateNotifierProvider<LoadedResultsNotifier, List<Map<String, dynamic>>>((ref) {
  return LoadedResultsNotifier();
});

// Provider for loading state
final loadingStateProvider = StateProvider<bool>((ref) => false);

// Provider for results history
final resultsHistoryProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final manager = await ResultsManager.getInstance();
  return await manager.getRecentResults();
});

// Provider for storage stats
final storageStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final manager = await ResultsManager.getInstance();
  return await manager.getStorageStats();
});

class LoadedResultsNotifier extends StateNotifier<List<Map<String, dynamic>>> {
  LoadedResultsNotifier() : super([]);
  
  void setResults(List<Map<String, dynamic>> results) {
    state = results;
  }
  
  void clear() {
    state = [];
  }
}

class ResultsView extends ConsumerStatefulWidget {
  const ResultsView({super.key});

  @override
  ConsumerState<ResultsView> createState() => _ResultsViewState();
}

class _ResultsViewState extends ConsumerState<ResultsView> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(loadedResultsProvider);
    final isLoading = ref.watch(loadingStateProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Audit Results'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            onPressed: isLoading ? null : () => _loadResults(context, ref),
            icon: const Icon(Icons.folder_open),
            tooltip: 'Load Results',
          ),
          if (results.isNotEmpty) ...[
            IconButton(
              onPressed: () => _saveCurrentResults(context, ref),
              icon: const Icon(Icons.save),
              tooltip: 'Save Results to History',
            ),
            IconButton(
              onPressed: () => _showGenerateReportDialog(context, ref),
              icon: const Icon(Icons.file_download),
              tooltip: 'Generate HTML Report',
            ),
            IconButton(
              onPressed: () => ref.read(loadedResultsProvider.notifier).clear(),
              icon: const Icon(Icons.clear),
              tooltip: 'Clear Results',
            ),
          ],
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              icon: const Icon(Icons.analytics),
              text: 'Current Results${results.isNotEmpty ? ' (${results.length})' : ''}',
            ),
            const Tab(
              icon: Icon(Icons.history),
              text: 'History',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Current Results Tab
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : results.isEmpty
                  ? _buildEmptyState()
                  : _buildResultsTable(results),
          
          // History Tab
          _buildHistoryView(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.analytics,
            size: 64,
            color: Colors.grey,
          ),
          SizedBox(height: 16),
          Text(
            'No Results Loaded',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'Click the folder icon to load audit results from JSON files.',
            style: TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24),
          Card(
            margin: EdgeInsets.all(24),
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Text(
                    'Unterstützte Formate:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text('• artifacts/<runId>/pages/ Verzeichnis'),
                  Text('• Einzelne *.json Dateien'),
                  Text('• Mehrere *.json Dateien gleichzeitig'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsTable(List<Map<String, dynamic>> results) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary Cards
          _buildSummaryCards(results),
          const SizedBox(height: 24),
          
          // Data Table
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Audit Results',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('URL')),
                        DataColumn(label: Text('Status')),
                        DataColumn(label: Text('Violations')),
                        DataColumn(label: Text('Max Impact')),
                        DataColumn(label: Text('TTFB (ms)')),
                        DataColumn(label: Text('LCP (ms)')),
                        DataColumn(label: Text('Started')),
                      ],
                      rows: results.map((result) => _buildDataRow(result)).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(List<Map<String, dynamic>> results) {
    final totalPages = results.length;
    final totalViolations = results
        .map((r) => (r['a11y']?['violations'] as List?)?.length ?? 0)
        .fold(0, (sum, count) => sum + count);
    final successCount = results
        .where((r) {
          final status = r['http']?['statusCode'];
          return status != null && status >= 200 && status < 300;
        })
        .length;
    final successRate = totalPages > 0 ? (successCount / totalPages * 100).round() : 0;
    
    final lcpValues = results
        .map((r) => r['perf']?['lcpMs'])
        .where((lcp) => lcp != null && lcp is num)
        .map((lcp) => lcp.toDouble())
        .toList();
    final avgLcp = lcpValues.isEmpty ? 0 : (lcpValues.reduce((a, b) => a + b) / lcpValues.length).round();

    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2,
      children: [
        _buildSummaryCard('Pages', totalPages.toString(), Colors.blue),
        _buildSummaryCard('Violations', totalViolations.toString(), Colors.orange),
        _buildSummaryCard('Success Rate', '$successRate%', Colors.green),
        _buildSummaryCard('Avg LCP', '${avgLcp}ms', Colors.purple),
      ],
    );
  }

  Widget _buildSummaryCard(String title, String value, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  DataRow _buildDataRow(Map<String, dynamic> result) {
    final url = result['url'] as String? ?? 'N/A';
    final statusCode = result['http']?['statusCode']?.toString() ?? 'N/A';
    final violations = (result['a11y']?['violations'] as List?)?.length ?? 0;
    final maxImpact = _getMaxImpact(result['a11y']?['violations']);
    final ttfb = _formatMetric(result['perf']?['ttfbMs']);
    final lcp = _formatMetric(result['perf']?['lcpMs']);
    final startedAt = _formatTimestamp(result['startedAt']);

    return DataRow(
      cells: [
        DataCell(
          SizedBox(
            width: 200,
            child: Text(
              url,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _getStatusColor(result['http']?['statusCode']),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              statusCode,
              style: const TextStyle(color: Colors.white, fontSize: 11),
            ),
          ),
        ),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _getViolationColor(violations),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              violations.toString(),
              style: const TextStyle(color: Colors.white, fontSize: 11),
            ),
          ),
        ),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _getImpactColor(maxImpact),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              maxImpact,
              style: const TextStyle(color: Colors.white, fontSize: 11),
            ),
          ),
        ),
        DataCell(Text(ttfb, style: const TextStyle(fontSize: 12))),
        DataCell(Text(lcp, style: const TextStyle(fontSize: 12))),
        DataCell(Text(startedAt, style: const TextStyle(fontSize: 12))),
      ],
    );
  }

  Future<void> _loadResults(BuildContext context, WidgetRef ref) async {
    try {
      ref.read(loadingStateProvider.notifier).state = true;
      
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        allowMultiple: true,
        dialogTitle: 'Select audit JSON files',
      );
      
      if (result != null && result.files.isNotEmpty) {
        final List<Map<String, dynamic>> loadedResults = [];
        
        for (final file in result.files) {
          if (file.path != null) {
            try {
              final jsonString = await File(file.path!).readAsString();
              final jsonData = jsonDecode(jsonString) as Map<String, dynamic>;
              loadedResults.add(jsonData);
            } catch (e) {
              print('Error loading file ${file.name}: $e');
            }
          }
        }
        
        if (loadedResults.isNotEmpty) {
          ref.read(loadedResultsProvider.notifier).setResults(loadedResults);
          
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Successfully loaded ${loadedResults.length} audit results'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No valid JSON files found'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading results: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      ref.read(loadingStateProvider.notifier).state = false;
    }
  }

  Future<void> _saveCurrentResults(BuildContext context, WidgetRef ref) async {
    final results = ref.read(loadedResultsProvider);
    if (results.isEmpty) return;
    
    final titleController = TextEditingController(text: 'Audit Results ${DateTime.now().toString().substring(0, 16)}');
    
    final title = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save Results'),
        content: TextField(
          controller: titleController,
          decoration: const InputDecoration(
            labelText: 'Title',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, titleController.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    
    if (title != null && title.isNotEmpty) {
      try {
        final manager = await ResultsManager.getInstance();
        await manager.saveResults(
          results,
          title: title,
          metadata: {
            'source': 'manual_save',
          },
        );
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Results saved: $title'),
              backgroundColor: Colors.green,
            ),
          );
          
          // Refresh history
          ref.invalidate(resultsHistoryProvider);
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error saving results: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
    
    titleController.dispose();
  }

  void _showGenerateReportDialog(BuildContext context, WidgetRef ref) {
    final results = ref.read(loadedResultsProvider);
    showDialog(
      context: context,
      builder: (context) => ReportGenerationDialog(results: results),
    );
  }
  
  Widget _buildHistoryView() {
    return Consumer(
      builder: (context, ref, child) {
        final historyAsync = ref.watch(resultsHistoryProvider);
        final statsAsync = ref.watch(storageStatsProvider);
        
        return historyAsync.when(
          data: (history) => _buildHistoryContent(history, statsAsync),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error loading history: $error'),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => ref.invalidate(resultsHistoryProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildHistoryContent(List<Map<String, dynamic>> history, AsyncValue<Map<String, dynamic>> statsAsync) {
    if (history.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No Saved Results',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Save current results to build up your audit history.',
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    
    return Column(
      children: [
        // Storage Stats Card
        statsAsync.when(
          data: (stats) => Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.storage, color: Colors.blue),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Storage: ${stats['total_results']} results, ${stats['total_size_mb']} MB',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        if (stats['oldest_date'] != null)
                          Text(
                            'Oldest: ${DateTime.parse(stats['oldest_date']).toString().substring(0, 16)}',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () => _showStorageManagement(),
                    icon: const Icon(Icons.settings),
                    label: const Text('Manage'),
                  ),
                ],
              ),
            ),
          ),
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),
        
        // History List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: history.length,
            itemBuilder: (context, index) {
              final item = history[index];
              return _buildHistoryItem(item);
            },
          ),
        ),
      ],
    );
  }
  
  Widget _buildHistoryItem(Map<String, dynamic> item) {
    final title = item['title'] as String? ?? 'Untitled';
    final createdAt = DateTime.tryParse(item['created_at'] as String? ?? '') ?? DateTime.now();
    final summary = item['summary'] as Map<String, dynamic>? ?? {};
    final totalPages = summary['total_pages'] as int? ?? 0;
    final totalViolations = summary['total_violations'] as int? ?? 0;
    final successRate = summary['success_rate'] as int? ?? 0;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: successRate >= 80 ? Colors.green : 
                           successRate >= 60 ? Colors.orange : Colors.red,
          child: Text('${successRate}%', style: const TextStyle(color: Colors.white, fontSize: 12)),
        ),
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$totalPages pages • $totalViolations violations'),
            Text(
              createdAt.toString().substring(0, 16),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: () => _loadHistoryItem(item),
              icon: const Icon(Icons.open_in_new),
              tooltip: 'Load Results',
            ),
            IconButton(
              onPressed: () => _deleteHistoryItem(item),
              icon: const Icon(Icons.delete, color: Colors.red),
              tooltip: 'Delete',
            ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }
  
  Future<void> _loadHistoryItem(Map<String, dynamic> item) async {
    final resultId = item['id'] as String;
    
    try {
      ref.read(loadingStateProvider.notifier).state = true;
      
      final manager = await ResultsManager.getInstance();
      final results = await manager.loadResults(resultId);
      
      ref.read(loadedResultsProvider.notifier).setResults(results);
      
      // Switch to current results tab
      _tabController.animateTo(0);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Loaded: ${item['title']}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading results: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      ref.read(loadingStateProvider.notifier).state = false;
    }
  }
  
  Future<void> _deleteHistoryItem(Map<String, dynamic> item) async {
    final resultId = item['id'] as String;
    final title = item['title'] as String? ?? 'Untitled';
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Results'),
        content: Text('Are you sure you want to delete "$title"?\n\nThis action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      try {
        final manager = await ResultsManager.getInstance();
        await manager.deleteResults(resultId);
        
        // Refresh history
        ref.invalidate(resultsHistoryProvider);
        ref.invalidate(storageStatsProvider);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Deleted: $title'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting results: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
  
  Future<void> _showStorageManagement() async {
    final manager = await ResultsManager.getInstance();
    final stats = await manager.getStorageStats();
    final storageLocation = await manager.getStorageLocation();
    
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Storage Management'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Location: $storageLocation'),
              const SizedBox(height: 8),
              Text('Total Results: ${stats['total_results']}'),
              Text('Total Size: ${stats['total_size_mb']} MB'),
              if (stats['oldest_date'] != null) ...[
                const SizedBox(height: 8),
                Text('Oldest: ${DateTime.parse(stats['oldest_date']).toString().substring(0, 16)}'),
                Text('Newest: ${DateTime.parse(stats['newest_date']).toString().substring(0, 16)}'),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => _openStorageFolder(storageLocation),
            child: const Text('Open Folder'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _cleanupOldResults();
            },
            child: const Text('Cleanup Old'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
  
  void _openStorageFolder(String path) {
    if (Platform.isMacOS) {
      Process.run('open', [path]);
    } else if (Platform.isWindows) {
      Process.run('explorer', [path]);
    } else if (Platform.isLinux) {
      Process.run('xdg-open', [path]);
    }
  }
  
  Future<void> _cleanupOldResults() async {
    try {
      final manager = await ResultsManager.getInstance();
      final deletedCount = await manager.cleanupOldResults(keepRecentCount: 20);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cleaned up $deletedCount old results'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Refresh stats
        ref.invalidate(resultsHistoryProvider);
        ref.invalidate(storageStatsProvider);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error during cleanup: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

// Helper functions for formatting
String _getMaxImpact(List<dynamic>? violations) {
  if (violations == null || violations.isEmpty) return 'none';
  
  final impacts = violations
      .map((v) => v['impact']?.toString())
      .where((impact) => impact != null)
      .toList();
  
  if (impacts.contains('critical')) return 'critical';
  if (impacts.contains('serious')) return 'serious';
  if (impacts.contains('moderate')) return 'moderate';
  if (impacts.contains('minor')) return 'minor';
  return 'none';
}

String _formatMetric(dynamic value) {
  if (value == null || value is! num) return 'N/A';
  return value.toDouble().round().toString();
}

String _formatTimestamp(String? timestamp) {
  if (timestamp == null) return 'N/A';
  try {
    final dt = DateTime.parse(timestamp);
    return '${dt.day}.${dt.month} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  } catch (e) {
    return 'N/A';
  }
}

Color _getStatusColor(int? statusCode) {
  if (statusCode == null) return Colors.grey;
  if (statusCode >= 200 && statusCode < 300) return Colors.green;
  if (statusCode >= 300 && statusCode < 400) return Colors.orange;
  if (statusCode >= 400) return Colors.red;
  return Colors.grey;
}

Color _getViolationColor(int count) {
  if (count == 0) return Colors.green;
  if (count <= 5) return Colors.orange;
  return Colors.red;
}

Color _getImpactColor(String impact) {
  switch (impact.toLowerCase()) {
    case 'critical': return Colors.red;
    case 'serious': return Colors.deepOrange;
    case 'moderate': return Colors.orange;
    case 'minor': return Colors.yellow.shade700;
    case 'none': return Colors.green;
    default: return Colors.grey;
  }
}

class ReportGenerationDialog extends ConsumerStatefulWidget {
  final List<Map<String, dynamic>> results;
  
  const ReportGenerationDialog({super.key, required this.results});
  
  @override
  ConsumerState<ReportGenerationDialog> createState() => _ReportGenerationDialogState();
}

class _ReportGenerationDialogState extends ConsumerState<ReportGenerationDialog> {
  bool _isGenerating = false;
  String? _outputDirectory;
  String _reportTitle = 'Audit Report';
  String _selectedFormat = 'html';
  final _titleController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    _titleController.text = _reportTitle;
    _titleController.addListener(() {
      setState(() {
        _reportTitle = _titleController.text;
      });
    });
    _loadSettings();
  }
  
  Future<void> _loadSettings() async {
    try {
      final settings = await SettingsService.getInstance();
      final defaultTitle = await settings.getDefaultReportTitle();
      final lastDirectory = await settings.getLastOutputDirectory();
      
      if (mounted) {
        setState(() {
          _reportTitle = defaultTitle;
          _titleController.text = defaultTitle;
          _outputDirectory = lastDirectory;
        });
      }
    } catch (e) {
      // Ignore settings loading errors
    }
  }
  
  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Generate HTML Report'),
      content: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Generate a comprehensive HTML report from ${widget.results.length} loaded results.',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            
            // Report Title
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Report Title',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.title),
              ),
            ),
            const SizedBox(height: 16),
            
            // Format Selection
            DropdownButtonFormField<String>(
              initialValue: _selectedFormat,
              decoration: const InputDecoration(
                labelText: 'Export Format',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.file_copy),
              ),
              items: const [
                DropdownMenuItem(value: 'html', child: Text('HTML Report (Interactive)')),
                DropdownMenuItem(value: 'csv', child: Text('CSV Files (Data Analysis)')),
                DropdownMenuItem(value: 'json', child: Text('JSON (Raw Data)')),
                DropdownMenuItem(value: 'all', child: Text('All Formats')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedFormat = value;
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            
            // Output Directory
            Row(
              children: [
                Expanded(
                  child: Text(
                    _outputDirectory ?? 'No output directory selected',
                    style: TextStyle(
                      color: _outputDirectory != null ? Colors.black87 : Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _isGenerating ? null : _selectOutputDirectory,
                  icon: const Icon(Icons.folder_open),
                  label: const Text('Browse'),
                ),
              ],
            ),
            
            if (_isGenerating) ...[
              const SizedBox(height: 16),
              const Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Text('Generating report...'),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isGenerating ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: (_isGenerating || _outputDirectory == null) ? null : _generateReport,
          child: const Text('Generate'),
        ),
      ],
    );
  }
  
  Future<void> _selectOutputDirectory() async {
    final selectedDirectory = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select output directory for HTML report',
    );
    
    if (selectedDirectory != null) {
      setState(() {
        _outputDirectory = selectedDirectory;
      });
      
      // Save to settings for next time
      try {
        final settings = await SettingsService.getInstance();
        await settings.setLastOutputDirectory(selectedDirectory);
      } catch (e) {
        // Ignore settings save errors
      }
    }
  }
  
  Future<void> _generateReport() async {
    if (_outputDirectory == null) return;
    
    setState(() {
      _isGenerating = true;
    });
    
    try {
      // Create temporary directory for JSON files
      final tempDir = Directory.systemTemp.createTempSync('auditmysite_report_');
      final jsonDir = Directory('${tempDir.path}/pages')..createSync();
      
      // Write all results as JSON files
      for (int i = 0; i < widget.results.length; i++) {
        final result = widget.results[i];
        final url = result['url'] as String? ?? 'page_$i';
        final fileName = url.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
        final jsonFile = File('${jsonDir.path}/$fileName.json');
        await jsonFile.writeAsString(const JsonEncoder.withIndent('  ').convert(result));
      }
      
      // Find CLI executable path
      final cliPath = await _findCliPath();
      if (cliPath == null) {
        throw Exception('Could not find auditmysite_cli. Make sure it\'s in the project directory.');
      }
      
      // Execute CLI command
      final process = await runExecutableArguments(
        'dart',
        [
          'run',
          '$cliPath/bin/build.dart',
          '--in=${jsonDir.path}',
          '--out=$_outputDirectory',
          '--title=$_reportTitle',
          '--format=$_selectedFormat',
        ],
        workingDirectory: cliPath,
      );
      
      if (process.exitCode == 0) {
        // Success! Clean up temp directory
        try {
          tempDir.deleteSync(recursive: true);
        } catch (e) {
          // Ignore cleanup errors
        }
        
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Report generated successfully in $_outputDirectory'),
              backgroundColor: Colors.green,
              action: SnackBarAction(
                label: 'Open Folder',
                textColor: Colors.white,
                onPressed: () => _openFolder(_outputDirectory!),
              ),
            ),
          );
        }
      } else {
        throw Exception('CLI process failed: ${process.stderr}');
      }
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating report: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }
  
  Future<String?> _findCliPath() async {
    // Look for CLI in common locations relative to current directory
    final candidates = [
      '../../auditmysite_cli',  // From studio app
      '../auditmysite_cli',     // From project root
      './auditmysite_cli',      // Direct path
    ];
    
    for (final candidate in candidates) {
      final dir = Directory(candidate);
      final pubspecFile = File('${dir.path}/pubspec.yaml');
      
      if (await pubspecFile.exists()) {
        final content = await pubspecFile.readAsString();
        if (content.contains('auditmysite_cli')) {
          return dir.absolute.path;
        }
      }
    }
    
    return null;
  }
  
  void _openFolder(String path) {
    if (Platform.isMacOS) {
      Process.run('open', [path]);
    } else if (Platform.isWindows) {
      Process.run('explorer', [path]);
    } else if (Platform.isLinux) {
      Process.run('xdg-open', [path]);
    }
  }
}
