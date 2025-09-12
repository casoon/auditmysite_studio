import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../services/settings_service.dart';

final settingsServiceProvider = FutureProvider<SettingsService>((ref) async {
  return await SettingsService.getInstance();
});

class SettingsView extends ConsumerStatefulWidget {
  const SettingsView({super.key});

  @override
  ConsumerState<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends ConsumerState<SettingsView> {
  final _engineUrlController = TextEditingController();
  final _enginePortController = TextEditingController();
  final _reportTitleController = TextEditingController();
  String? _lastOutputDirectory;
  bool _autoConnectEngine = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _engineUrlController.dispose();
    _enginePortController.dispose();
    _reportTitleController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final settings = await SettingsService.getInstance();
      
      _engineUrlController.text = await settings.getEngineUrl();
      _enginePortController.text = (await settings.getEnginePort()).toString();
      _reportTitleController.text = await settings.getDefaultReportTitle();
      _lastOutputDirectory = await settings.getLastOutputDirectory();
      _autoConnectEngine = await settings.getAutoConnectEngine();
    } catch (e) {
      // Handle error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load settings: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveSettings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final settings = await SettingsService.getInstance();
      
      await settings.setEngineUrl(_engineUrlController.text);
      
      final port = int.tryParse(_enginePortController.text);
      if (port != null && port > 0) {
        await settings.setEnginePort(port);
      }
      
      await settings.setDefaultReportTitle(_reportTitleController.text);
      
      if (_lastOutputDirectory != null) {
        await settings.setLastOutputDirectory(_lastOutputDirectory!);
      }
      
      await settings.setAutoConnectEngine(_autoConnectEngine);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save settings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _selectOutputDirectory() async {
    final selectedDirectory = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select default output directory',
    );
    
    if (selectedDirectory != null) {
      setState(() {
        _lastOutputDirectory = selectedDirectory;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Engine Connection Section
                  const Text(
                    'Engine Connection',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  
                  TextField(
                    controller: _engineUrlController,
                    decoration: const InputDecoration(
                      labelText: 'Engine URL',
                      border: OutlineInputBorder(),
                      helperText: 'Hostname or IP address of the audit engine server',
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  TextField(
                    controller: _enginePortController,
                    decoration: const InputDecoration(
                      labelText: 'Engine Port',
                      border: OutlineInputBorder(),
                      helperText: 'Default: 3000',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  
                  SwitchListTile(
                    title: const Text('Auto-connect to engine'),
                    subtitle: const Text('Connect to engine when Studio starts'),
                    value: _autoConnectEngine,
                    onChanged: (value) {
                      setState(() {
                        _autoConnectEngine = value;
                      });
                    },
                  ),
                  
                  const Divider(height: 48),
                  
                  // Report Settings Section
                  const Text(
                    'Report Generation',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  
                  TextField(
                    controller: _reportTitleController,
                    decoration: const InputDecoration(
                      labelText: 'Default Report Title',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Output Directory
                  const Text('Default Output Directory'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _lastOutputDirectory ?? 'No directory selected',
                          style: TextStyle(
                            color: _lastOutputDirectory != null ? Colors.black87 : Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _selectOutputDirectory,
                        icon: const Icon(Icons.folder_open),
                        label: const Text('Browse'),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 32),
                  
                  Center(
                    child: FilledButton(
                      onPressed: _saveSettings,
                      child: const Text('Save Settings'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
