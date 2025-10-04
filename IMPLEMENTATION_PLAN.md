# Klarer Implementierungsplan - Keine Workarounds

## Entscheidung: Puppeteer mit Bundled Chromium

**Warum diese Lösung:**
1. ✅ Puppeteer ist stabil in Dart verfügbar
2. ✅ Chromium-Download ist Standard bei Puppeteer
3. ✅ Feature-Parität mit Original ist erreichbar
4. ✅ Keine lokale Chrome-Installation nötig

## Was zu tun ist:

### 1. Puppeteer richtig konfigurieren
Puppeteer kann Chromium automatisch downloaden:
```dart
import 'package:puppeteer/puppeteer.dart';

// Puppeteer lädt automatisch Chromium herunter
final browser = await puppeteer.launch(
  // executablePath wird automatisch gesetzt
);
```

### 2. Alle Fallbacks entfernen
- ❌ Kein SimpleHttpAudit-Fallback
- ❌ Kein BrowserPoolV2
- ❌ Kein manueller ChromiumDownloader
- ✅ NUR BrowserPool mit Puppeteer

### 3. Code bereinigen
- Entferne: `browser_pool_v2.dart`
- Entferne: `chromium_downloader.dart`
- Entferne: `simple_browser.dart`
- Behalte: `browser_pool.dart` (vereinfacht)

### 4. Flutter App vereinfachen
- ❌ Kein Splash Screen mit Download-Dialog
- ✅ Direkter Start zur Audit-Screen
- ✅ Puppeteer handhabt Browser automatisch

## Next Steps:

1. **Browser Pool vereinfachen** - Nutze Puppeteers automatisches Browser-Management
2. **Alte Dateien löschen** - Alle Workarounds entfernen
3. **Desktop Integration bereinigen** - Einfacher, direkter Code
4. **Feature-Parität herstellen** - Fokus auf echte Features statt Fallbacks

## Das Ziel:
Eine saubere Codebasis die funktioniert - keine V2, keine Fallbacks, kein "Plan B".
