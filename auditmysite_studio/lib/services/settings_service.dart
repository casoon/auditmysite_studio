import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String _keyEngineUrl = 'engine_url';
  static const String _keyEnginePort = 'engine_port';
  static const String _keyLastOutputDirectory = 'last_output_directory';
  static const String _keyDefaultReportTitle = 'default_report_title';
  static const String _keyAutoConnectEngine = 'auto_connect_engine';
  
  static SettingsService? _instance;
  static SharedPreferences? _prefs;
  
  SettingsService._();
  
  static Future<SettingsService> getInstance() async {
    _instance ??= SettingsService._();
    _prefs ??= await SharedPreferences.getInstance();
    return _instance!;
  }
  
  // Engine connection settings
  Future<String> getEngineUrl() async {
    return _prefs?.getString(_keyEngineUrl) ?? 'localhost';
  }
  
  Future<void> setEngineUrl(String url) async {
    await _prefs?.setString(_keyEngineUrl, url);
  }
  
  Future<int> getEnginePort() async {
    return _prefs?.getInt(_keyEnginePort) ?? 3000;
  }
  
  Future<void> setEnginePort(int port) async {
    await _prefs?.setInt(_keyEnginePort, port);
  }
  
  Future<bool> getAutoConnectEngine() async {
    return _prefs?.getBool(_keyAutoConnectEngine) ?? true;
  }
  
  Future<void> setAutoConnectEngine(bool autoConnect) async {
    await _prefs?.setBool(_keyAutoConnectEngine, autoConnect);
  }
  
  // Report generation settings
  Future<String?> getLastOutputDirectory() async {
    return _prefs?.getString(_keyLastOutputDirectory);
  }
  
  Future<void> setLastOutputDirectory(String directory) async {
    await _prefs?.setString(_keyLastOutputDirectory, directory);
  }
  
  Future<String> getDefaultReportTitle() async {
    return _prefs?.getString(_keyDefaultReportTitle) ?? 'Audit Report';
  }
  
  Future<void> setDefaultReportTitle(String title) async {
    await _prefs?.setString(_keyDefaultReportTitle, title);
  }
  
  // Clear all settings
  Future<void> clear() async {
    await _prefs?.clear();
  }
}
