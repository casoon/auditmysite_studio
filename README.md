# AuditMySite Studio

<p align="center">
  <img src="https://img.shields.io/badge/Status-Early_Alpha-orange" alt="Status: Early Alpha">
  <img src="https://img.shields.io/badge/Platform-macOS%20%7C%20Windows-blue" alt="Platform: macOS | Windows">
  <img src="https://img.shields.io/badge/Framework-Flutter_Desktop-blue" alt="Framework: Flutter Desktop">
  <img src="https://img.shields.io/badge/Engine-Dart-blue" alt="Engine: Dart">
</p>

A comprehensive **desktop application** for website auditing, built with Flutter for **macOS and Windows**. This is a **Dart port** of the [original AuditMySite project](https://github.com/casoon/auditmysite) with the goal of **feature parity** and native desktop experience.

> ⚠️ **Early Alpha Stage**: This project is currently in active development and should be considered experimental.

## 🎯 Project Goals

- **Desktop-first**: Native macOS and Windows applications
- **Feature Parity**: Match capabilities with the [original AuditMySite project](https://github.com/casoon/auditmysite)
- **Professional UI**: Modern, responsive Flutter desktop interface  
- **Comprehensive Audits**: 6 audit categories with detailed scoring
- **Real-time Progress**: Live WebSocket updates during audits

## ✨ Current Features (v0.1-alpha)

### 🔧 **Audit Engine** (Dart)
- **HTTP Analysis**: Status codes, headers, redirects, SSL, response times
- **Performance Audits**: Core Web Vitals (TTFB, FCP, LCP, CLS) with A-F scoring
- **SEO Audits**: Meta tags, headings, images, OpenGraph, Twitter Cards
- **Content Weight**: Resource analysis, optimization recommendations
- **Mobile Friendliness**: Responsive design, touch targets, viewport
- **Accessibility**: Axe-core integration for WCAG compliance

### 🖥️ **Desktop Application** (Flutter)
- **Responsive UI**: Adaptive layouts for different window sizes
- **Live Engine Status**: Real-time connection monitoring
- **Audit Configuration**: Flexible settings for all audit categories
- **Progress Tracking**: WebSocket-based live updates
- **Results Management**: JSON export with detailed grading

## 🏗️ Architecture

```
auditmysite_studio/
├── auditmysite_engine/     # Dart audit engine (HTTP API + WebSocket)
├── auditmysite_studio/     # Flutter desktop application  
├── auditmysite_cli/        # Command-line interface
└── shared/                 # Shared models and utilities
```

### **Engine Features**:
- REST API for audit management
- WebSocket for real-time progress
- Puppeteer-based browser automation
- Sitemap parsing and URL discovery
- Concurrent processing with rate limiting

### **Desktop App Features**:
- Native macOS/Windows experience  
- NavigationRail for desktop layouts
- Minimum window size enforcement (900×700)
- Responsive breakpoints (<800px mobile, ≥800px desktop)
- Material Design 3 with consistent branding

## 🚀 Quick Start

### Prerequisites
- Flutter SDK (≥3.19.0)
- Dart SDK (≥3.3.0) 
- Chrome/Chromium (for Puppeteer)

### Development Setup
```bash
# Clone the repository
git clone https://github.com/YOUR_USERNAME/auditmysite-studio.git
cd auditmysite-studio

# Install dependencies
flutter pub get
cd auditmysite_engine && dart pub get

# Start the audit engine
cd auditmysite_engine
dart run bin/serve.dart --port 8080

# Start the Flutter desktop app (in another terminal)
cd auditmysite_studio  
flutter run -d macos  # or -d windows
```

### Using the Application
1. **Start Engine**: The audit engine provides the backend API
2. **Launch Desktop App**: Flutter app connects automatically to engine
3. **Configure Audit**: Set sitemap URL and select audit categories
4. **Run Audit**: Monitor progress in real-time via WebSocket
5. **View Results**: Detailed JSON reports with A-F grading

## 📊 Audit Categories

| Category | Features | Scoring |
|----------|----------|----------|
| **HTTP** | Status codes, redirects, SSL, headers | Info only |
| **Performance** | Core Web Vitals, optimization tips | A-F Grade |
| **SEO** | Meta tags, headings, structured data | A-F Grade |
| **Content Weight** | Resource sizes, loading optimization | A-F Grade |
| **Mobile Friendliness** | Responsive design, touch targets | A-F Grade |
| **Accessibility** | WCAG violations, axe-core analysis | Info only |

## 🎨 Screenshots

### Desktop Application (macOS)
- **Setup View**: Configure audits with modern, responsive UI
- **Progress View**: Real-time audit progress with WebSocket updates
- **Results View**: Detailed findings with actionable recommendations
- **Settings View**: Engine configuration and preferences

*(Screenshots will be added as the project matures)*

## 🚧 Development Status

### ✅ **Completed** (Early Alpha)
- [x] Dart audit engine with 6 categories
- [x] Flutter desktop application (macOS/Windows)
- [x] HTTP API with WebSocket support
- [x] Responsive UI with adaptive navigation
- [x] Real-time progress monitoring
- [x] JSON export with detailed scoring

### 🔄 **In Progress**
- [ ] Results visualization and charts
- [ ] Audit history and comparison
- [ ] Export formats (PDF, CSV)
- [ ] Advanced settings and configuration
- [ ] Performance optimizations

### 📋 **Planned**
- [ ] Feature parity with [original project](https://github.com/casoon/auditmysite)
- [ ] Signed macOS and Windows distributions
- [ ] Auto-update mechanism
- [ ] Plugin architecture for custom audits
- [ ] Batch processing and scheduling

## 🤝 Relationship to Original Project

This project is a **Dart/Flutter port** of [casoon/auditmysite](https://github.com/casoon/auditmysite) with these key differences:

- **Technology**: Dart/Flutter instead of original stack
- **Platform**: Desktop applications (macOS/Windows) as primary target
- **Architecture**: Modular design with separate engine and UI components
- **Goal**: Feature parity while leveraging Flutter's cross-platform capabilities

Both projects aim to provide comprehensive website auditing capabilities, with this version focusing on native desktop experience.

## 📋 Release Strategy

### Distribution Model
- **Manual Creation**: Applications will be manually built and signed
- **Platform-specific**: Native macOS (.app) and Windows (.exe) packages
- **Code Signing**: Applications will be properly signed for distribution
  - macOS: Developer ID Application certificate
  - Windows: Code signing certificate for trusted installation

### Versioning
- **Current**: v0.1-alpha (Early development)
- **Target**: v1.0 (Feature parity with original project)
- **Semantic Versioning**: Following semver.org conventions

## 🛠️ Development

### Contributing
This project is currently in early development. Contribution guidelines will be established as the project stabilizes.

### Building for Distribution

#### macOS
```bash
flutter build macos --release
# Code signing will be handled separately
```

#### Windows  
```bash
flutter build windows --release
# Code signing will be handled separately
```

## 📄 License

MIT License - see [LICENSE](LICENSE) file for details.

## 🙋‍♂️ Support

- **Issues**: [GitHub Issues](https://github.com/YOUR_USERNAME/auditmysite-studio/issues)
- **Discussions**: [GitHub Discussions](https://github.com/YOUR_USERNAME/auditmysite-studio/discussions)
- **Original Project**: [casoon/auditmysite](https://github.com/casoon/auditmysite)

---

**Built with ❤️ using Flutter and Dart**

> This project is part of the broader AuditMySite ecosystem, providing desktop-native website auditing capabilities.

## 📋 Detailed Technical Guide

A comprehensive website auditing system with three main components:

- **auditmysite_engine** (Dart): Loads sitemaps, performs audits via CDP + axe-core
- **auditmysite_cli** (Dart): Creates HTML reports from JSON artifacts  
- **auditmysite_studio** (Flutter Desktop): GUI for end users

### Technical Architecture

```
auditmysite_studio/
├─ shared/                    # Shared models & utilities
├─ auditmysite_engine/        # Dart engine (Sitemap → Queue → CDP + axe)
├─ auditmysite_cli/           # CLI: JSON → HTML reports
└─ auditmysite_studio/        # Flutter desktop GUI
```

### Development Setup (Detailed)

#### Prerequisites
Ensure you have Dart ≥3.3.0 and Flutter ≥3.19.0 installed.

```bash
# Navigate to root directory
cd auditmysite_studio

# Generate shared models
cd shared
dart pub get
dart run build_runner build --delete-conflicting-outputs
cd ..

# Install dependencies for all packages
cd auditmysite_engine && dart pub get && cd ..
cd auditmysite_cli && dart pub get && cd ..
cd auditmysite_studio && flutter pub get && cd ..
```

#### axe-core Integration

The actual `axe.min.js` file must be downloaded from [axe-core](https://github.com/dequelabs/axe-core):

```bash
# Download current axe-core version
wget https://cdnjs.cloudflare.com/ajax/libs/axe-core/4.8.4/axe.min.js \
  -O auditmysite_engine/third_party/axe/axe.min.js
```

#### Running the Engine

**Standard Mode:**
```bash
cd auditmysite_engine
dart run bin/run.dart \
  --sitemap=https://example.com/sitemap.xml \
  --out=./artifacts \
  --concurrency=4 \
  --perf \
  --screenshots
```

**With Live WebSocket:**
```bash
cd auditmysite_engine
dart run bin/run.dart \
  --serve \
  --sitemap=https://example.com/sitemap.xml \
  --out=./artifacts \
  --concurrency=4 \
  --perf
```

**WebSocket Server Only:**
```bash
cd auditmysite_engine
dart run bin/serve.dart --port=8080
```

This creates JSON files in `./artifacts/<runId>/pages/`.

#### Generate HTML Reports

```bash
cd auditmysite_cli
dart run bin/build.dart \
  --in=../auditmysite_engine/artifacts/<runId>/pages \
  --out=./reports \
  --title="Website Audit"
```

Then open `./reports/index.html` in your browser.

#### Start GUI Application

```bash
cd auditmysite_studio
flutter run -d macos  # or windows/linux
```

## 🚀 Advanced Features

### Engine Capabilities
- ✅ Sitemap parsing (including sitemap index)
- ✅ Concurrent processing with configurable workers
- ✅ HTTP status and header collection
- ✅ Performance metrics (TTFB, FCP, LCP, DCL)
- ✅ Accessibility audits with axe-core
- ✅ Console error collection
- ✅ Optional: Full-page screenshots
- ✅ Event system for live tracking

### CLI Capabilities  
- ✅ JSON to HTML conversion
- ✅ Overview report with table of all pages
- ✅ Detail pages per URL
- ✅ Performance metrics visualization
- ✅ Accessibility violations with impact levels
- ✅ Console error display

### Studio Application Features
- ✅ Run setup interface
- ✅ Manual command generation  
- ✅ Live progress tracking via WebSocket
- ✅ Results loading & management
- ✅ Interactive data table with statistics
- 😧 Integrated report generation (upcoming)

## 🗺️ Development Roadmap

### ✅ Completed Features
- ✅ WebSocket integration for live events  
- ✅ Retry/backoff mechanism in engine
- ✅ Results loading in studio app
- ✅ Enhanced CLI template system with filtering/search
- ✅ Performance metrics collection

### 📅 Upcoming Features  
- [ ] Engine performance metrics (CPU/RAM)
- [ ] Modular CLI template system
- [ ] Filter/search in HTML reports
- [ ] Studio export integration
- [ ] robots.txt compliance
- [ ] Authentication/cookies support
- [ ] Mobile/device profile emulation
- [ ] Project management & persistence

## 📊 Data Schema

Each page is saved as a JSON file following this schema:

```json
{
  "schemaVersion": "1.0.0",
  "runId": "2024-01-15T10-30-00",
  "url": "https://example.com/page",
  "http": {
    "statusCode": 200,
    "headers": {...}
  },
  "perf": {
    "ttfbMs": 120.5,
    "fcpMs": 890.2,
    "lcpMs": 1240.8,
    "domContentLoadedMs": 1100.0,
    "loadEventEndMs": 1250.0,
    "engine": {
      "cpuUserMs": 45.2,
      "cpuSystemMs": 12.1,
      "peakRssBytes": 125829120,
      "taskDurationMs": 2340.5
    }
  },
  "a11y": {
    "violations": [...]
  },
  "consoleErrors": [...],
  "screenshotPath": "artifacts/screenshots/...",
  "startedAt": "2024-01-15T10:30:01.000Z",
  "finishedAt": "2024-01-15T10:30:03.340Z"
}
```

## 📜 License

MIT License - see LICENSE file for implementation details.
