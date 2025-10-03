# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Project Overview

AuditMySite Studio is a comprehensive website auditing system with three main components:

- **auditmysite_engine** (Dart): Backend engine that loads sitemaps and performs audits via Chrome CDP + axe-core
- **auditmysite_studio** (Flutter Desktop): GUI application for macOS/Windows users  
- **auditmysite_cli** (Dart): Command-line tool that creates HTML reports from JSON artifacts
- **shared** (Dart): Shared models and utilities used by all components

## Architecture

The project follows a modular architecture where the engine processes audits, generates JSON artifacts, and communicates via WebSocket. The studio provides a desktop GUI, while the CLI generates reports.

```
auditmysite_studio/
├─ shared/                    # Shared models & utilities (JSON serialization)
├─ auditmysite_engine/        # Dart engine (Sitemap → Queue → CDP + axe)
├─ auditmysite_cli/           # CLI: JSON → HTML reports  
└─ auditmysite_studio/        # Flutter desktop GUI
```

## Common Development Commands

### Initial Setup
```bash
# Run complete setup (installs dependencies for all packages)
make setup
# OR
./setup.sh

# Download axe-core library (required for accessibility audits)
make axe
# OR  
curl -o auditmysite_engine/third_party/axe/axe.min.js https://cdnjs.cloudflare.com/ajax/libs/axe-core/4.8.4/axe.min.js
```

### Development Workflow
```bash
# Start the engine server (WebSocket + HTTP API)
make engine-serve
# OR
cd auditmysite_engine && dart run bin/serve.dart --port=8080

# Start Flutter desktop app (in another terminal)  
make studio
# OR
cd auditmysite_studio && flutter run -d macos

# Run a complete audit with live WebSocket updates
make engine-live
# OR  
cd auditmysite_engine && dart run bin/run.dart --serve --sitemap=https://example.com/sitemap.xml --concurrency=4

# Generate HTML reports from JSON artifacts
make cli
# OR
cd auditmysite_cli && dart run bin/build.dart --in=../auditmysite_engine/artifacts/<runId>/pages --out=./reports --title="Website Audit"
```

### Testing and Validation
```bash
# Test engine with simple sitemap
make engine

# Clean all build artifacts
make clean

# Build release versions
./scripts/build_all.sh 1.0.0 release
```

### Shared Models Development
```bash
# When modifying shared models, regenerate JSON serialization
cd shared && dart run build_runner build --delete-conflicting-outputs
```

## Development Environment Requirements

- **Dart SDK**: ≥3.3.0
- **Flutter SDK**: ≥3.19.0 (for studio app)
- **Chrome/Chromium**: Required for Puppeteer engine automation
- **axe-core library**: Must be downloaded to `auditmysite_engine/third_party/axe/axe.min.js`

## Key Architecture Patterns

### Engine WebSocket Communication
The engine supports real-time progress updates via WebSocket. Events include:
- `audit_started`: Audit beginning
- `page_started`: Individual page processing
- `page_completed`: Individual page finished  
- `audit_completed`: Full audit finished

### State Management (Studio)
The Flutter app uses Riverpod for state management with these key providers:
- Engine connection status
- Audit progress tracking
- Results data management
- Settings persistence

### Data Flow
1. Studio configures audit parameters (sitemap URL, concurrency, etc.)
2. Engine loads sitemap, discovers URLs, queues them for processing
3. Engine processes pages concurrently using Chrome CDP
4. Each page generates JSON artifact with HTTP/Performance/SEO/A11y data
5. CLI reads JSON artifacts to generate interactive HTML reports
6. Studio can load and display results from JSON artifacts

## File Structure Patterns

### Engine Artifacts
- `artifacts/<runId>/pages/*.json`: Individual page audit results
- `artifacts/<runId>/screenshots/`: Optional page screenshots

### Shared Models
- Uses `json_annotation` and `json_serializable` for data serialization
- Central `PageAuditJson` model represents audit results
- Build runner generates `.g.dart` files (do not edit manually)

## Docker Support

The project includes Docker compose setup for production deployment:
```bash
# Start engine only
docker-compose up auditmysite-engine

# Full production stack with Nginx
docker-compose --profile production up -d
```

## Platform-Specific Notes

### macOS Development
- Flutter desktop builds to `.app` bundle
- Code signing setup available in `scripts/sign_macos.sh`
- Build scripts handle macOS-specific packaging

### Windows Development  
- Flutter builds to `.exe` executable
- Cross-platform Dart CLI tools work on Windows

## Code Signing and Distribution

The project includes comprehensive build and signing infrastructure:
- `scripts/build_all.sh`: Master build script for all components
- `scripts/sign_macos.sh`: macOS code signing with notarization
- `BUILD_AND_SIGN.md`: Complete signing documentation

## Testing

### Engine Testing
- Test with small sitemaps first: `https://httpbin.org/robots.txt`
- Monitor WebSocket events for real-time feedback
- Check artifacts directory for generated JSON files

### Studio Testing
- Verify engine connection in Settings tab
- Test audit configuration and progress monitoring
- Validate results loading and export functionality

## Common Issues

### Missing axe-core
If accessibility audits fail, ensure axe.min.js is downloaded to the correct location.

### Engine Connection Issues
Verify engine is running and accessible at configured URL/port. Use curl to test: `curl http://localhost:8080/health`

### Flutter Desktop Issues
Ensure desktop support is enabled: `flutter config --enable-macos-desktop`

## Performance Considerations

- **Concurrency**: Default 4 workers, adjust based on system resources and target server capacity
- **Rate Limiting**: Engine includes backoff/retry mechanisms  
- **Memory**: Chrome processes can consume significant memory during audits
- **Screenshots**: Optional but increases storage requirements significantly

## Development Tips

- Run `make setup` after pulling changes to ensure dependencies are current
- Use `make engine-live` to test full workflow with WebSocket updates
- Check engine logs for detailed processing information
- Studio app automatically discovers local engine instances
- CLI can process multiple runs and generate comparative reports