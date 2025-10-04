# Feature-Parität Plan - Desktop Studio vs npm-Tool

## Ziel
Eine funktionierende, fehlerfreie Desktop-Version mit Feature-Parität zum npm-Tool [casoon/auditmysite](https://github.com/casoon/auditmysite).

## Aktueller Status (Analyse benötigt)

### ✅ Was bereits funktioniert:
- Browser-Pool mit Puppeteer
- Sitemap-Parsing
- Basic HTTP-Audits
- Modulare PDF-Generierung
- Progress-Tracking im UI
- Redirect-Handling

### ⚠️ Was Probleme macht:
- Viele Errors in Audit-Ergebnissen
- Axe-Core möglicherweise nicht korrekt integriert
- Audit-Daten unvollständig/fehlerhaft
- PDF-Reports zeigen nur wenig Daten

## Phase 1: Fehleranalyse & Stabilisierung (PRIORITÄT 1)

### 1.1 Test-Run durchführen
- [ ] Studio-App gegen Test-URL laufen lassen
- [ ] JSON-Output prüfen (alle Audit-Files)
- [ ] Fehler dokumentieren
- [ ] PDF-Output prüfen

### 1.2 Audit-Fehler beheben
- [ ] Performance-Audit: Core Web Vitals validieren
- [ ] SEO-Audit: Meta-Tags korrekt extrahieren
- [ ] Accessibility-Audit: Axe-Core Integration testen
- [ ] HTTP-Audit: Status Codes & Headers

### 1.3 Axe-Core Integration prüfen
- [ ] Ist axe.min.js korrekt eingebunden?
- [ ] Wird das Script ins Page-Context injiziert?
- [ ] Werden Violations korrekt ausgelesen?
- [ ] Error-Handling für JS-Evaluation-Fehler

## Phase 2: npm-Tool Feature-Mapping

### 2.1 Features des npm-Tools identifizieren
**Aus casoon/auditmysite:**
```
Expected Features:
- ✅ Sitemap parsing
- ✅ Batch processing
- ⚠️  WCAG compliance testing (Axe-Core)
- ⚠️  Performance metrics (Web Vitals)
- ⚠️  SEO analysis
- ❓ HTML reports (Desktop hat PDF)
- ❓ Console error collection
- ❓ Screenshot capability
```

### 2.2 Gap-Analyse
**Fehlende Features dokumentieren:**
- [ ] npm-Tool Features auflisten
- [ ] Desktop-Features auflisten
- [ ] Delta identifizieren
- [ ] Prioritäten festlegen

## Phase 3: Feature-Implementierung

### 3.1 Core Web Vitals (HIGH PRIORITY)
```dart
// Benötigt:
- LCP (Largest Contentful Paint)
- FCP (First Contentful Paint)
- CLS (Cumulative Layout Shift)
- INP (Interaction to Next Paint)
- TTFB (Time to First Byte)
- TBT (Total Blocking Time)
```

**Aktionen:**
- [ ] Performance-Audit erweitern
- [ ] Correct Metrics Collection über CDP
- [ ] Validation gegen Lighthouse-Werte

### 3.2 Vollständige Accessibility (HIGH PRIORITY)
```dart
// Benötigt:
- Axe-Core vollständig integriert
- Alle WCAG 2.1 AA Rules
- Alle WCAG 2.2 Rules (optional)
- WCAG 3.0 Preview (optional)
```

**Aktionen:**
- [ ] Axe-Core Script Injection debuggen
- [ ] Alle Violations erfassen
- [ ] Impact Levels korrekt zuordnen
- [ ] ARIA-Prüfungen implementieren

### 3.3 SEO-Audit vervollständigen
```dart
// Benötigt:
- Title & Meta Description
- OpenGraph Tags
- Twitter Cards
- Canonical URLs
- Structured Data (JSON-LD)
- Robots Meta Tags
- Sitemap Validation
```

**Aktionen:**
- [ ] Meta-Tag Extraction komplett
- [ ] Structured Data Parser
- [ ] Robots.txt Integration
- [ ] Sitemap Cross-Check

### 3.4 Content-Audit
```dart
// Benötigt:
- Heading Structure (H1-H6)
- Image Alt-Texts
- Link Analysis (internal/external)
- Text/HTML Ratio
- Content Length
- Keyword Density (optional)
```

### 3.5 Mobile-Friendliness
```dart
// Benötigt:
- Viewport Configuration
- Touch Targets Size
- Font Sizes
- Content Width
- Tap Targets spacing
```

## Phase 4: Report-Qualität

### 4.1 JSON-Reports verbessern
- [ ] Alle Felder mit korrekten Daten füllen
- [ ] Schema-Validierung
- [ ] Timestamps korrekt
- [ ] Error-Handling

### 4.2 PDF-Reports verbessern
- [ ] Mehr Details anzeigen
- [ ] Charts/Graphs hinzufügen
- [ ] Severity-Indicators
- [ ] Actionable Recommendations

## Phase 5: Testing & Validation

### 5.1 Vergleichstests
```bash
# Gleiche URL mit beiden Tools testen:
npm: casoon/auditmysite scan https://example.com
desktop: auditmysite_studio

# Ergebnisse vergleichen:
- Anzahl gefundener Issues
- Severity Levels
- Performance Scores
- Accessibility Violations
```

### 5.2 Test-Matrix
| Feature | npm-Tool | Desktop | Status |
|---------|----------|---------|--------|
| Sitemap Parsing | ✅ | ✅ | OK |
| HTTP Status | ✅ | ⚠️  | Check |
| Performance | ✅ | ❌ | Fix |
| SEO | ✅ | ⚠️  | Fix |
| Accessibility | ✅ | ❌ | Fix |
| Mobile | ✅ | ❌ | Implement |
| Console Errors | ✅ | ❓ | Check |
| Screenshots | ✅ | ❓ | Check |

## Phase 6: Optimierung

### 6.1 Performance
- [ ] Concurrent Processing optimieren
- [ ] Memory Management
- [ ] Browser Resource Handling
- [ ] Queue Management

### 6.2 User Experience
- [ ] Real-time Progress
- [ ] Pause/Resume Functionality
- [ ] Cancel Button
- [ ] Export Formats (PDF, JSON)

## Success Criteria

### Minimum Viable Product (MVP):
1. ✅ Keine Fehler in Audit-Ergebnissen
2. ✅ Core Web Vitals vollständig
3. ✅ Axe-Core funktioniert
4. ✅ SEO-Audit vollständig
5. ✅ PDF-Reports aussagekräftig
6. ✅ Gleiche Anzahl gefundener Issues wie npm-Tool (±10%)

### Feature Parity:
1. ✅ Alle npm-Tool Features vorhanden
2. ✅ Gleiche Qualität der Ergebnisse
3. ✅ Zusätzlich: Native Desktop UI
4. ✅ Zusätzlich: PDF Reports

## Nächste Schritte

### Sofort:
1. **Test-Run** gegen bekannte URL
2. **Fehler dokumentieren** in JSON-Files
3. **Axe-Core Status** prüfen
4. **Performance Metrics** validieren

### Diese Woche:
1. Phase 1 abschließen (Fehleranalyse)
2. Phase 2 abschließen (Gap-Analyse)
3. Phase 3.1 starten (Core Web Vitals)
4. Phase 3.2 starten (Accessibility)

### Dieser Monat:
1. MVP erreichen
2. Vergleichstests durchführen
3. Feedback einarbeiten
4. Feature Parity erreichen

## Tracking

- [ ] Phase 1: Fehleranalyse
- [ ] Phase 2: Gap-Analyse
- [ ] Phase 3: Feature-Implementierung
- [ ] Phase 4: Report-Qualität
- [ ] Phase 5: Testing & Validation
- [ ] Phase 6: Optimierung
- [ ] **MVP erreicht**
- [ ] **Feature Parity erreicht**
