# Debug & Logging Setup

## ✅ Was wurde implementiert:

### 1. **Debug Logger** (`lib/utils/debug_logger.dart`)
- Schreibt alle Logs in Datei UND Konsole
- Automatische Log-Rotation (behält nur die letzten 5 Log-Dateien)
- Timestamp für jeden Log-Eintrag
- Stack-Traces bei Fehlern

**Log-Speicherorte:**
- **macOS**: `~/Library/Logs/AuditMySite/`
- **Windows**: `%LOCALAPPDATA%\AuditMySite\Logs\`
- **Linux**: `~/.local/share/auditmysite/logs/`

### 2. **Error Screen** (`lib/screens/error_screen.dart`)
- Zeigt Fehler statt sofort zu crashen
- Ermöglicht Fehlerdetails zu kopieren
- "Open Logs Folder" Button
- "Try Again" Funktion

### 3. **Global Error Handling** (in `main.dart`)
- Fängt alle Flutter Errors ab
- Fängt alle async Errors ab
- Logged alles automatisch

## 📋 Wie man Logs findet:

### Methode 1: Über die App
1. Wenn ein Fehler auftritt, zeigt die App einen Error Screen
2. Klicke auf das Ordner-Icon oben rechts
3. Der Logs-Ordner öffnet sich im Finder

### Methode 2: Manuell
```bash
# macOS
open ~/Library/Logs/AuditMySite/

# Windows
explorer %LOCALAPPDATA%\AuditMySite\Logs\

# Linux
xdg-open ~/.local/share/auditmysite/logs/
```

### Methode 3: Terminal
```bash
# Zeige neueste Log-Datei
tail -f ~/Library/Logs/AuditMySite/auditmysite_*.log

# Zeige alle Logs
ls -lt ~/Library/Logs/AuditMySite/
```

## 🔍 Log-Beispiel:

```
=== AuditMySite Studio Debug Log ===
Started: 2025-10-04T07:12:30.123456
Platform: macos
Dart Version: 3.3.0
=====================================

[2025-10-04T07:12:30.456789] [INFO] Application starting...
[2025-10-04T07:12:30.567890] [INFO] Debug logger initialized: /Users/.../auditmysite_2025-10-04T07-12-30.log
[2025-10-04T07:12:31.123456] [DEBUG] Launching browser pool...
[2025-10-04T07:12:32.234567] [INFO] ✅ Browser pool launched successfully
[2025-10-04T07:12:35.345678] [ERROR] Failed to load sitemap
[2025-10-04T07:12:35.345679] [ERROR] Error details: Exception: Network error
[2025-10-04T07:12:35.345680] [ERROR] Stack trace:
#0      loadSitemap (package:auditmysite_engine/core/sitemap.dart:45:7)
#1      startAudit (package:auditmysite_engine/desktop_integration.dart:67:12)
...
```

## 🛠️ Verwendung im Code:

### Logging
```dart
import 'package:auditmysite_studio/utils/debug_logger.dart';

// Info
DebugLogger.log('Something happened');

// Warning
DebugLogger.warn('This might be a problem');

// Error with stack trace
DebugLogger.error('Something failed', error, stackTrace);

// Debug (nur im Debug-Modus)
DebugLogger.debug('Detailed debug info');
```

### Error Screen zeigen
```dart
import 'package:auditmysite_studio/screens/error_screen.dart';

try {
  // Etwas das fehlschlagen könnte
} catch (e, stack) {
  DebugLogger.error('Operation failed', e, stack);
  showErrorScreen(
    context,
    title: 'Operation Failed',
    message: 'The operation could not be completed.',
    error: e,
    stackTrace: stack,
  );
}
```

## 🐛 Troubleshooting:

### Problem: Keine Logs werden erstellt
**Lösung:** Überprüfe Schreibrechte im Logs-Verzeichnis

### Problem: Log-Datei zu groß
**Lösung:** Alte Logs werden automatisch gelöscht (nur 5 neueste werden behalten)

### Problem: Kann Logs-Ordner nicht finden
**Lösung:** Führe aus:
```bash
# macOS
echo ~/Library/Logs/AuditMySite/
```

## 📊 Log-Levels:

| Level | Verwendung | Farbe in Console |
|-------|------------|------------------|
| `INFO` | Normale Informationen | Standard |
| `DEBUG` | Detaillierte Debug-Info | Nur im Debug-Modus |
| `WARN` | Warnungen | Gelb |
| `ERROR` | Fehler mit Details | Rot |

## ✨ Features:

- ✅ Automatische Log-Rotation
- ✅ Timestamp für jeden Eintrag
- ✅ Stack-Traces bei Fehlern
- ✅ File + Console Logging
- ✅ Error Screen statt Crash
- ✅ "Open Logs Folder" Button
- ✅ Copy Error Details
- ✅ Global Error Handling

## 🎯 Nächste Schritte bei Fehlern:

1. **Reproduziere den Fehler**
2. **Finde die Log-Datei** (siehe oben)
3. **Kopiere relevante Logs**
4. **Suche nach `[ERROR]` Einträgen**
5. **Analysiere Stack-Traces**

Die Logs enthalten alle Informationen die zum Debuggen benötigt werden!
