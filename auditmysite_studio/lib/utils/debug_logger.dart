import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

/// Debug logger that writes to both console and file
class DebugLogger {
  static File? _logFile;
  static bool _initialized = false;

  /// Initialize the debug logger
  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Create logs directory
      final logsDir = await _getLogsDirectory();
      if (!logsDir.existsSync()) {
        logsDir.createSync(recursive: true);
      }

      // Create log file with timestamp
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final logFileName = 'auditmysite_$timestamp.log';
      _logFile = File(p.join(logsDir.path, logFileName));

      // Write header
      await _writeToFile('=== AuditMySite Studio Debug Log ===');
      await _writeToFile('Started: ${DateTime.now()}');
      await _writeToFile('Platform: ${Platform.operatingSystem}');
      await _writeToFile('Dart Version: ${Platform.version}');
      await _writeToFile('=====================================\n');

      _initialized = true;
      log('Debug logger initialized: ${_logFile!.path}');

      // Clean old logs (keep only last 5)
      _cleanOldLogs(logsDir);
    } catch (e) {
      debugPrint('Failed to initialize debug logger: $e');
    }
  }

  /// Log a message
  static void log(String message, {String level = 'INFO'}) {
    final timestamp = DateTime.now().toIso8601String();
    final logMessage = '[$timestamp] [$level] $message';

    // Always print to console
    debugPrint(logMessage);

    // Write to file if available
    if (_logFile != null) {
      _writeToFile(logMessage).catchError((e) {
        debugPrint('Failed to write to log file: $e');
      });
    }
  }

  /// Log an error with stack trace
  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    log(message, level: 'ERROR');
    if (error != null) {
      log('Error details: $error', level: 'ERROR');
    }
    if (stackTrace != null) {
      log('Stack trace:\n$stackTrace', level: 'ERROR');
    }
  }

  /// Log a warning
  static void warn(String message) {
    log(message, level: 'WARN');
  }

  /// Log debug info
  static void debug(String message) {
    if (kDebugMode) {
      log(message, level: 'DEBUG');
    }
  }

  /// Get the current log file path
  static String? get logFilePath => _logFile?.path;

  /// Write to log file
  static Future<void> _writeToFile(String message) async {
    if (_logFile != null) {
      await _logFile!.writeAsString(
        '$message\n',
        mode: FileMode.append,
        flush: true,
      );
    }
  }

  /// Get logs directory
  static Future<Directory> _getLogsDirectory() async {
    String path;

    if (Platform.isMacOS) {
      path = p.join(
        Platform.environment['HOME']!,
        'Library',
        'Logs',
        'AuditMySite',
      );
    } else if (Platform.isWindows) {
      path = p.join(
        Platform.environment['LOCALAPPDATA']!,
        'AuditMySite',
        'Logs',
      );
    } else {
      path = p.join(
        Platform.environment['HOME']!,
        '.local',
        'share',
        'auditmysite',
        'logs',
      );
    }

    return Directory(path);
  }

  /// Clean old log files (keep only last 5)
  static void _cleanOldLogs(Directory logsDir) {
    try {
      final logFiles = logsDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.log'))
          .toList();

      if (logFiles.length > 5) {
        // Sort by modification time (oldest first)
        logFiles.sort((a, b) =>
            a.lastModifiedSync().compareTo(b.lastModifiedSync()));

        // Delete oldest files
        for (var i = 0; i < logFiles.length - 5; i++) {
          logFiles[i].deleteSync();
          debugPrint('Deleted old log: ${logFiles[i].path}');
        }
      }
    } catch (e) {
      debugPrint('Failed to clean old logs: $e');
    }
  }

  /// Open logs directory in Finder/Explorer
  static Future<void> openLogsDirectory() async {
    final logsDir = await _getLogsDirectory();

    if (Platform.isMacOS) {
      await Process.run('open', [logsDir.path]);
    } else if (Platform.isWindows) {
      await Process.run('explorer', [logsDir.path]);
    } else if (Platform.isLinux) {
      await Process.run('xdg-open', [logsDir.path]);
    }
  }
}
