# PDF Report Generation

## Architektur

Die PDF-Generierung folgt einem modularen, template-basierten Ansatz:

```
auditmysite_engine/lib/core/pdf/
├── pdf_template.dart           # Wiederverwendbare UI-Templates und Styles
├── pdf_section.dart            # Abstract Base Class für alle Sections
├── pdf_report_generator.dart   # Hauptgenerator und Orchestrator
└── sections/
    ├── performance_section.dart
    ├── seo_section.dart
    └── accessibility_section.dart
```

## Komponenten

### 1. PdfTemplate (`pdf_template.dart`)

Zentrale Sammlung von wiederverwendbaren PDF-Widgets und Styles:

- **Theme**: Farbpalette, Schriftarten, Abstände
- **Komponenten**:
  - `buildSectionHeader()` - Überschriften mit Subtiteln
  - `buildScoreBadge()` - Farbcodierte Score-Anzeige
  - `buildMetricCard()` - Metriken mit Labels
  - `buildDataTable()` - Tabellarische Daten
  - `buildIssueItem()` - Probleme nach Schweregrad
  - `buildBulletList()` - Listen mit Icons

### 2. PdfSection (`pdf_section.dart`)

Abstract Base Class für alle Report-Sections:

```dart
abstract class PdfSection {
  final Map<String, dynamic> data;
  
  PdfSection(this.data);
  
  String get title;           // Section-Titel
  List<pw.Widget> build();    // Widget-Generierung
  bool get hasData;           // Daten vorhanden?
}
```

### 3. Section-Implementierungen

Jede Audit-Kategorie hat eine eigene Section-Klasse:

#### PerformanceSection
- Core Web Vitals (LCP, FCP, CLS, etc.)
- Metriken-Anzeige
- Performance-Score

#### SeoSection
- Meta-Tags (Title, Description)
- Heading-Struktur (H1-H4)
- SEO-Score und Issues

#### AccessibilitySection
- ARIA-Probleme
- Accessibility-Score
- Violations nach Schweregrad

### 4. PdfReportGenerator (`pdf_report_generator.dart`)

Hauptklasse zur PDF-Generierung:

```dart
class PdfReportGenerator {
  Future<void> generateReport({
    required String outputDir,
    required String scanUrl,
  });
}
```

**Ablauf**:
1. Lädt Audit-JSON-Dateien aus dem Output-Verzeichnis
2. Erstellt Section-Instanzen mit den jeweiligen Daten
3. Generiert Cover-Page mit Summary
4. Fügt alle Sections zum PDF hinzu
5. Speichert PDF-Datei

## Datenfluss

```
Audits
  ↓
JSON-Dateien (performance.json, seo.json, accessibility.json)
  ↓
PdfReportGenerator
  ↓
Section-Instanzen (Performance, SEO, Accessibility)
  ↓
PdfTemplate-Komponenten
  ↓
PDF-Dokument
```

## Verwendung

### In desktop_integration.dart

```dart
// Nach den Audits
final generator = PdfReportGenerator();
await generator.generateReport(
  outputDir: outputDir,
  scanUrl: scanUrl,
);
```

### Neue Section hinzufügen

1. Erstelle neue Datei in `sections/`:
```dart
class MySection extends PdfSection {
  MySection(super.data);
  
  @override
  String get title => 'Meine Section';
  
  @override
  List<pw.Widget> build() {
    final widgets = <pw.Widget>[];
    
    widgets.add(PdfTemplate.buildSectionHeader(title));
    // Füge weitere Widgets hinzu
    
    return widgets;
  }
}
```

2. Registriere in `pdf_report_generator.dart`:
```dart
sections.add(MySection(myData));
```

## Styling und Theming

Alle visuellen Elemente sind in `PdfTemplate` zentralisiert:

- **Farben**: Primary, Success, Warning, Error, Grays
- **Schriftgrößen**: Konsistente Hierarchie
- **Abstände**: Standardisierte Margins und Paddings
- **Icons**: Verwendung von Material Icons

## Fehlerbehandlung

- Prüfung auf fehlende JSON-Dateien
- Graceful Handling von leeren Daten
- Type-Safe Zugriffe mit Null-Checks
- Fallback-Werte für fehlende Felder

## JSON-Struktur

### performance.json
```json
{
  "score": 85,
  "metrics": {
    "fcp": {"value": 1200, "score": 90},
    "lcp": {"value": 2400, "score": 80}
  }
}
```

### seo.json
```json
{
  "score": 92,
  "title": "Page Title",
  "metaDescription": "Description",
  "headings": {
    "h1Count": 1,
    "h2Count": 5
  }
}
```

### accessibility.json
```json
{
  "score": 78,
  "issues": [
    {
      "title": "Missing alt text",
      "severity": "critical",
      "description": "..."
    }
  ]
}
```

## Bekannte Einschränkungen

1. **Axe-Core**: Aktuell deaktiviert wegen fehlender axe.min.js Bundle
2. **Seitenlimit**: Sehr große Reports können Performance-Probleme verursachen
3. **Bilder**: Screenshots noch nicht implementiert

## Nächste Schritte

- [ ] Axe-Core richtig bundeln und aktivieren
- [ ] Screenshot-Integration für visuelle Metriken
- [ ] Interaktive Charts statt statischer Badges
- [ ] HTML-Report als Alternative zum PDF
- [ ] Performance-Optimierung für große Sitemaps
