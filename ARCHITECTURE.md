# AuditMySite Studio - Architektur

## Projektübersicht

Das Projekt besteht aus **4 Hauptkomponenten**:

```
auditmysite_studio/
├── auditmysite_engine/     ✅ AKTIV - Kern-Audit-Engine
├── auditmysite_studio/     ✅ AKTIV - Flutter Desktop App
├── auditmysite_cli/        ⚠️  LEGACY - HTML Report Generator
└── shared/                 ✅ AKTIV - Gemeinsame Models
```

## Komponenten-Status

### 1. ✅ auditmysite_engine (AKTIV & BENÖTIGT)

**Zweck**: Kern der Audit-Funktionalität

**Verwendung**: 
- Wird **direkt als Dart Package** in auditmysite_studio eingebunden
- Läuft **embedded** innerhalb der Desktop-App (nicht als separater Server)
- Enthält alle Audit-Logik, Browser-Pool, PDF-Generierung

**Hauptbestandteile**:
- `lib/cdp/browser_pool.dart` - Puppeteer Browser Management
- `lib/core/audits/` - Audit-Implementierungen (Performance, SEO, Accessibility)
- `lib/core/pdf/` - Modulare PDF-Generierung
- `lib/core/queue.dart` - URL Queue Management
- `lib/core/redirect_handler.dart` - HTTP Redirect Handling
- `lib/desktop_integration.dart` - Public API für Desktop-App
- `lib/writer/json_writer.dart` - JSON Report Export

**Abhängigkeiten**:
```yaml
dependencies:
  puppeteer: ^3.16.0
  pdf: ^3.11.1
  # ... weitere
```

**Status**: ✅ Voll funktionsfähig und aktiv in Entwicklung

---

### 2. ✅ auditmysite_studio (AKTIV & BENÖTIGT)

**Zweck**: Flutter Desktop Anwendung (macOS/Windows)

**Verwendung**:
- Hauptanwendung für End-User
- Bindet `auditmysite_engine` als **lokales Package** ein
- Nutzt Engine direkt via `DesktopIntegration` API

**Integration**:
```dart
// pubspec.yaml
dependencies:
  auditmysite_engine:
    path: ../auditmysite_engine
  shared:
    path: ../shared
```

**Hauptbestandteile**:
- `lib/main.dart` - App Entry Point
- `lib/screens/audit_screen.dart` - Haupt-UI für Audits
- `lib/screens/error_screen.dart` - Error Handling
- `lib/screens/splash_screen.dart` - Initialisierung
- `lib/providers/embedded_engine_provider.dart` - Engine Integration
- `lib/utils/debug_logger.dart` - Logging Utility

**Status**: ✅ Voll funktionsfähig, aktiv in Entwicklung

---

### 3. ⚠️ auditmysite_cli (OBSOLETE - Für Referenz behalten)

**Zweck**: Kommandozeilen-Tool für HTML Report-Generierung

**Status**: ⚠️ **OBSOLETE** - Wird nicht weiterentwickelt

**Verwendung**:
- Konvertiert JSON-Audit-Daten zu HTML-Reports
- **Wird NICHT von auditmysite_studio verwendet**
- Eigenständiges CLI-Tool (experimentell)

**Warum obsolete?**
1. Desktop-App (auditmysite_studio) nutzt jetzt **PDF-Reports** statt HTML
2. Keine direkte Integration in die Desktop-App
3. Für CLI-Funktionalität siehe: **[casoon/auditmysite](https://github.com/casoon/auditmysite)** (npm/Node.js)

**Befehl** (falls noch benötigt):
```bash
cd auditmysite_cli
dart run bin/build.dart \
  --in=../artifacts/pages \
  --out=./reports
```

**Zukunftsvision**:
- Dieses Dart-CLI-Tool bleibt als **Referenz-Implementation** im Repository
- Wenn die Dart-Engine einen ausgereiften Stand erreicht, **könnte** sie das npm-Tool ablösen
- Vorteil: **Eine einzige Codebasis** für Desktop-App und CLI
- Aktuell: Nutze **[casoon/auditmysite](https://github.com/casoon/auditmysite)** für produktive CLI-Nutzung

📚 **Weitere Informationen**: Siehe [auditmysite_cli/README.md](auditmysite_cli/README.md)

---

### 4. ✅ shared/ (AKTIV & BENÖTIGT)

**Zweck**: Gemeinsame Models und Utilities

**Verwendung**:
- Von beiden `auditmysite_engine` und `auditmysite_studio` verwendet
- Enthält Datenmodelle, die zwischen Engine und UI geteilt werden

**Status**: ✅ Aktiv genutzt

---

## Architektur-Diagramm

### Aktuelle Struktur (Desktop App):

```
┌─────────────────────────────────────┐
│   auditmysite_studio (Flutter)      │
│   - Embedded Engine Provider        │
│   - UI Screens                      │
│   - Progress Tracking               │
└──────────┬──────────────────────────┘
           │ Direct Library Import
           │ (nicht Server/Client!)
┌──────────▼──────────────────────────┐
│   auditmysite_engine (Dart)         │
│   ┌─────────────────────────────┐   │
│   │ DesktopIntegration API      │   │
│   └─────────┬───────────────────┘   │
│             │                        │
│   ┌─────────▼───────────┐           │
│   │   Browser Pool      │           │
│   │   (Puppeteer)       │           │
│   └─────────┬───────────┘           │
│             │                        │
│   ┌─────────▼───────────┐           │
│   │  Audit Modules      │           │
│   │  - Performance      │           │
│   │  - SEO              │           │
│   │  - Accessibility    │           │
│   └─────────┬───────────┘           │
│             │                        │
│   ┌─────────▼───────────┐           │
│   │  Output Generation  │           │
│   │  - JSON Writer      │           │
│   │  - PDF Generator    │           │
│   └─────────────────────┘           │
└─────────────────────────────────────┘
```

### Alte CLI-Struktur (Optional/Legacy):

```
┌────────────────┐
│ auditmysite_   │      ┌───────────────┐
│ engine         │─────►│ JSON Files    │
│ (Standalone)   │      │ (artifacts/)  │
└────────────────┘      └───────┬───────┘
                                │
                        ┌───────▼───────┐
                        │ auditmysite_  │
                        │ cli           │
                        │ (HTML Gen)    │
                        └───────┬───────┘
                                │
                        ┌───────▼───────┐
                        │ HTML Reports  │
                        └───────────────┘
```

---

## Build & Run

### Desktop App (Hauptverwendung):

```bash
cd auditmysite_studio
flutter run -d macos  # oder windows
```

Die Engine läuft automatisch embedded - kein separater Server nötig!

### Build für Distribution:

```bash
cd auditmysite_studio
flutter build macos --release
# Output: build/macos/Build/Products/Release/auditmysite_studio.app
```

---

## Empfehlungen

### ✅ Behalten:
- **auditmysite_engine** - Kern-Funktionalität
- **auditmysite_studio** - Hauptanwendung
- **shared** - Gemeinsame Models

### ❓ Entscheiden:
- **auditmysite_cli** - Falls HTML-Reports nicht benötigt werden, kann entfernt werden

### Vorteile der aktuellen Architektur:
1. ✅ **Einfach**: Keine Server-Client Komplexität
2. ✅ **Performance**: Direkte Library-Integration
3. ✅ **Distribution**: Single Binary ohne Dependencies
4. ✅ **Entwicklung**: Schnellere Iteration, weniger Overhead

---

## Deployment

Die Desktop-App ist **self-contained**:
- Enthält Engine als eingebundene Library
- Puppeteer lädt Chromium automatisch beim ersten Start
- PDF-Generation läuft direkt in der App
- Keine externen Services benötigt

**Single Binary Distribution** - perfekt für Desktop Apps!
