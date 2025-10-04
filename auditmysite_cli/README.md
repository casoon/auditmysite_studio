# auditmysite_cli - Status & Zukunft

## ⚠️ Status: OBSOLETE

Dieses Dart CLI-Tool ist aktuell **nicht für den produktiven Einsatz vorgesehen**.

## Warum obsolete?

1. **Fokus auf Desktop**: Dieses Projekt (`auditmysite_studio`) konzentriert sich auf die **Desktop-Anwendung**
2. **PDF statt HTML**: Die Desktop-App generiert PDF-Reports, nicht HTML
3. **Produktive CLI existiert**: Für CLI-Nutzung gibt es bereits ein ausgereiftes Tool

## 🔧 Für produktive CLI-Nutzung

Nutze das bewährte **Node.js CLI-Tool**:

### [casoon/auditmysite](https://github.com/casoon/auditmysite)

**Features:**
- ✅ Lightning-fast web accessibility auditing
- ✅ Automated WCAG compliance testing
- ✅ Batch processing
- ✅ Detailed HTML reports
- ✅ Production-ready
- ✅ npm-Package, einfach zu installieren

**Installation:**
```bash
npm install -g @casoon/auditmysite
```

**Verwendung:**
```bash
auditmysite scan https://example.com
```

## 🔮 Zukunftsvision

### Warum bleibt auditmysite_cli im Repository?

1. **Referenz-Implementation**: Zeigt, wie die Dart-Engine auch als CLI genutzt werden könnte
2. **Code-Reuse**: Teilt Code mit `auditmysite_engine`
3. **Zukunftspotenzial**: Könnte das npm-Tool ablösen

### Langfristige Vision: Eine Codebasis

Wenn die Dart-Engine ausgereift ist:

```
┌─────────────────────────────────────┐
│   auditmysite_engine (Dart)         │
│   - Kern-Audit-Logik                │
│   - Browser-Pool (Puppeteer)        │
│   - PDF/HTML Generation             │
└────────────┬────────────────────────┘
             │
        ┌────┴────┐
        │         │
┌───────▼──────┐ ┌─▼──────────────────┐
│ Desktop App  │ │ CLI Tool           │
│ (Flutter)    │ │ (Dart)             │
│              │ │                    │
│ - Native UI  │ │ - Batch Processing │
│ - Embedded   │ │ - npm-Package      │
└──────────────┘ └────────────────────┘

         Eine Codebasis
      Zwei Distributionen
```

**Vorteile:**
- ✅ Nur eine Engine zu pflegen
- ✅ Bugfixes profitieren beide Tools
- ✅ Konsistente Audit-Logik
- ✅ Dart: Schneller als Node.js
- ✅ Cross-Platform: macOS, Windows, Linux

## 📅 Zeitplan

**Aktuell (2024-2025):**
- ✅ Desktop-App als Hauptfokus
- ✅ Node.js CLI für produktiven Einsatz
- ⏸️ Dart CLI pausiert

**Später (wenn Desktop-App stabil):**
- [ ] Dart CLI reaktivieren
- [ ] Feature-Parität mit npm-Tool
- [ ] Migration von Node.js zu Dart CLI
- [ ] Eine Codebasis für beide Tools

## 🛠️ Experimentelle Nutzung (nicht empfohlen)

Falls du trotzdem das Dart CLI testen möchtest:

```bash
cd auditmysite_cli

# JSON zu HTML konvertieren
dart run bin/build.dart \
  --in=../artifacts/pages \
  --out=./reports \
  --title="My Audit"
```

**Hinweis**: Keine Garantie für Stabilität oder Support!

## 📚 Dokumentation

- **Produktive CLI**: [casoon/auditmysite auf GitHub](https://github.com/casoon/auditmysite)
- **Desktop-App**: [Siehe README.md](../README.md)
- **Architektur**: [Siehe ARCHITECTURE.md](../ARCHITECTURE.md)

---

**Zusammenfassung**: Nutze [casoon/auditmysite](https://github.com/casoon/auditmysite) für CLI-Audits. Dieses Dart CLI ist eine Referenz-Implementation für die Zukunft.
