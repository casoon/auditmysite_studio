# AuditMySite Engine Deployment Guide

This guide explains how to bundle and deploy the AuditMySite engine with the desktop Studio application.

## Overview

The AuditMySite engine is designed to be embedded within the desktop application, providing:
- Full offline capability
- Custom user agent identification
- Firewall-friendly operation
- Bundled Chrome/Chromium support
- Platform-specific deployment

## User Agent

All browser requests identify as:
```
AuditMySite/1.0 (Desktop Studio; +https://auditmysite.io)
```

## Directory Structure

### macOS App Bundle
```
AuditMySite Studio.app/
├── Contents/
│   ├── MacOS/
│   │   └── auditmysite_studio        # Main executable
│   ├── Resources/
│   │   ├── chrome/                   # Bundled Chromium
│   │   │   └── Chromium.app/
│   │   ├── third_party/
│   │   │   └── axe/
│   │   │       └── axe.min.js       # Accessibility library
│   │   └── engine/                   # Engine binaries
│   └── Info.plist
```

### Windows Distribution
```
AuditMySite Studio/
├── auditmysite_studio.exe            # Main executable
├── chrome/                           # Bundled Chrome
│   └── chrome.exe
├── third_party/
│   └── axe/
│       └── axe.min.js               # Accessibility library
└── engine/                          # Engine files
```

### Linux Package
```
/opt/auditmysite-studio/
├── bin/
│   └── auditmysite_studio           # Main executable
├── chrome/                          # Bundled Chromium
│   └── chrome
├── third_party/
│   └── axe/
│       └── axe.min.js              # Accessibility library
└── lib/                             # Engine libraries
```

## Build & Bundle Process

### 1. Prepare Engine

```bash
# Build engine
cd auditmysite_engine
dart compile exe bin/engine.dart -o build/engine

# Copy required files
mkdir -p build/third_party/axe
cp third_party/axe/axe.min.js build/third_party/axe/
```

### 2. Bundle Chrome/Chromium

#### macOS
```bash
# Download Chromium for macOS
curl -L https://download-chromium.appspot.com/dl/Mac?type=snapshots \
  -o chromium-mac.zip
unzip chromium-mac.zip
mv chrome-mac/Chromium.app build/chrome/

# Or use existing Chrome installation
cp -R "/Applications/Google Chrome.app" "build/chrome/Chromium.app"
```

#### Windows
```powershell
# Download Chrome portable
Invoke-WebRequest -Uri "https://dl.google.com/chrome/install/chrome_installer.exe" `
  -OutFile "chrome_installer.exe"

# Extract Chrome files to build/chrome/
```

#### Linux
```bash
# Download Chromium
wget -O chromium-linux.zip \
  https://download-chromium.appspot.com/dl/Linux_x64?type=snapshots
unzip chromium-linux.zip -d build/
mv build/chrome-linux build/chrome
```

### 3. Build Desktop App with Engine

```bash
# Build Flutter desktop app
cd auditmysite_studio
flutter build macos --release

# Copy engine files into app bundle
cp -R ../auditmysite_engine/build/* \
  "build/macos/Build/Products/Release/AuditMySite Studio.app/Contents/Resources/"
```

## Runtime Configuration

### Automatic Chrome Detection

The engine automatically searches for Chrome/Chromium in this order:

1. **Bundled Chrome** - Within the app bundle
2. **System Chrome** - Standard installation paths
3. **User-specified** - Via configuration

### Offline Mode Support

The engine detects network restrictions and automatically:
- Switches to offline mode
- Uses cached resources
- Restricts to local/intranet URLs
- Disables telemetry and updates

### Firewall Configuration

If deploying in enterprise environments with firewalls:

1. **No external connections required** for local site audits
2. **User Agent** always identifies as AuditMySite
3. **Proxy support** via system settings or configuration
4. **Local cache** for offline resource access

## Deployment Checklist

### Pre-deployment
- [ ] Engine compiled for target platform
- [ ] Chrome/Chromium bundled or system Chrome available
- [ ] axe-core library included
- [ ] User agent configured
- [ ] Offline resources bundled

### Platform-specific
#### macOS
- [ ] Code signed with Developer ID
- [ ] Notarized for Gatekeeper
- [ ] Sandboxing exceptions for Chrome
- [ ] Hardened runtime configured

#### Windows
- [ ] Code signed with certificate
- [ ] Windows Defender exclusions
- [ ] Chrome executable permissions
- [ ] Firewall rules configured

#### Linux
- [ ] AppImage/Snap/Flatpak packaging
- [ ] Chrome sandbox permissions
- [ ] Desktop file created
- [ ] Dependencies bundled

### Testing
- [ ] Test with bundled Chrome
- [ ] Test in offline mode
- [ ] Test behind firewall
- [ ] Test local site audits
- [ ] Verify user agent in requests

## Environment Variables

The engine respects these environment variables:

```bash
# Chrome executable path
AUDITMYSITE_CHROME_PATH=/path/to/chrome

# Disable GPU (for VMs/containers)
AUDITMYSITE_DISABLE_GPU=1

# Offline mode
AUDITMYSITE_OFFLINE_MODE=1

# Proxy settings
HTTP_PROXY=http://proxy.company.com:8080
HTTPS_PROXY=http://proxy.company.com:8080
NO_PROXY=localhost,127.0.0.1,*.local
```

## Troubleshooting

### Chrome Not Found
```dart
// Check deployment info
import 'package:auditmysite_engine/deployment/embedded_config.dart';

void main() {
  DeploymentInfo.printDiagnostics();
}
```

Output:
```
=== AuditMySite Engine Deployment Info ===
platform: macos
chromePath: /Applications/Google Chrome.app/Contents/MacOS/Google Chrome
chromeFound: true
userAgent: AuditMySite/1.0 (Desktop Studio; +https://auditmysite.io)
==========================================
```

### Offline Mode Detection
```dart
import 'package:auditmysite_engine/deployment/offline_handler.dart';

void main() async {
  final status = await OfflineHandler.checkConnectivity();
  print(status); // "Local network only (offline mode)"
}
```

### Firewall Blocking
Symptoms:
- External URLs timeout
- Only local sites work

Solution:
1. Enable offline mode
2. Configure proxy if available
3. Whitelist local/intranet domains

## Security Considerations

1. **Chrome Sandbox**: Ensure Chrome sandbox is enabled for security
2. **User Data**: Store in platform-appropriate user directories
3. **Cache Security**: Encrypt sensitive cached data
4. **Network Security**: Respect system proxy and certificate settings
5. **Update Mechanism**: Implement secure auto-update for engine

## Distribution Formats

### macOS
- DMG with drag-to-Applications
- Mac App Store (with entitlements)
- Direct download with notarization

### Windows
- MSI installer
- Portable ZIP
- Microsoft Store (with MSIX)

### Linux
- AppImage (universal)
- Snap (Ubuntu)
- Flatpak (Fedora/others)
- DEB/RPM packages

## Support

For deployment issues:
1. Check deployment diagnostics
2. Review Chrome/Chromium availability
3. Verify offline resources
4. Test network connectivity
5. Check user agent in network requests

## Example Integration

```dart
import 'package:auditmysite_engine/desktop_integration.dart';
import 'package:auditmysite_engine/deployment/embedded_config.dart';

void main() async {
  // Initialize deployment
  await EmbeddedEngineConfig.initializeDirectories();
  
  // Check connectivity
  final isRestricted = await EmbeddedEngineConfig.isRestrictedEnvironment();
  
  // Configure audit
  final config = AuditConfiguration(
    urls: [Uri.parse('http://localhost:8080')],
    useAdvancedAudits: true,
  );
  
  // Start audit with embedded engine
  final integration = DesktopIntegration();
  final session = await integration.startAudit(config);
  
  // Monitor progress
  session.eventStream.listen((event) {
    print('${event.type}: ${event.url}');
  });
  
  // Wait for completion
  await session.processFuture;
}
```