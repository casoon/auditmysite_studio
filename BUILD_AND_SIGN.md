# AuditMySite - Build & Code Signing Guide

This guide explains how to build and sign AuditMySite applications for distribution.

## 📁 Directory Structure

```
auditmysite_studio/
├── release/                    # Final signed binaries
│   ├── macos/                  # macOS .app bundles
│   ├── windows/                # Windows .exe files
│   └── linux/                  # Linux binaries
├── dist/                       # Distribution packages (DMG, MSI, etc.)
├── bin/                        # Development binaries
└── scripts/                    # Build and signing scripts

auditmysite_cli/
├── bin/                        # CLI binaries
└── release/                    # Release CLI builds

auditmysite_engine/
├── dist/                       # Compiled Python engine
└── release/                    # Release engine builds
```

## 🔨 Building Applications

### Prerequisites

**macOS:**
```bash
# Install Flutter
# Install Xcode Command Line Tools
xcode-select --install

# Install dependencies
brew install create-dmg
```

**All platforms:**
```bash
# Install PyInstaller for engine builds
pip install pyinstaller
```

### Build All Components

```bash
# From the root directory
./scripts/build_all.sh [version] [build_type]

# Examples:
./scripts/build_all.sh 1.0.0 release
./scripts/build_all.sh dev debug
```

This script builds:
- Flutter Studio App (GUI)
- CLI Tool
- Python Engine (if PyInstaller available)

## 🔐 Code Signing (macOS)

### Setup Apple Developer Account

1. **Join Apple Developer Program** ($99/year)
   - Sign up at https://developer.apple.com/

2. **Create Certificates**
   - Go to https://developer.apple.com/account/resources/certificates
   - Create "Developer ID Application" certificate
   - Create "Developer ID Installer" certificate (optional, for PKG)

3. **Download and Install Certificates**
   - Download .cer files
   - Double-click to install in Keychain Access

### Local Signing Setup

1. **Copy environment template:**
   ```bash
   cp scripts/.env.template scripts/.env
   ```

2. **Find your certificate names:**
   ```bash
   security find-identity -v -p codesigning
   ```
   
   Look for entries like:
   ```
   1) ABC123... "Developer ID Application: Your Name (TEAM123)"
   2) DEF456... "Developer ID Installer: Your Name (TEAM123)"
   ```

3. **Edit `scripts/.env`:**
   ```bash
   DEVELOPER_ID_APPLICATION="Developer ID Application: Your Name (TEAM123)"
   DEVELOPER_ID_INSTALLER="Developer ID Installer: Your Name (TEAM123)"
   TEAM_ID="TEAM123"
   
   # For notarization
   NOTARIZE_USERNAME="your-apple-id@example.com"
   NOTARIZE_PASSWORD="app-specific-password"
   ```

4. **Create App-Specific Password:**
   - Go to https://appleid.apple.com/account/manage
   - Sign-In and Security → App-Specific Passwords
   - Generate password for "AuditMySite Notarization"

### Sign the Application

```bash
# Build first
./scripts/build_all.sh 1.0.0 release

# Load environment variables
source scripts/.env

# Sign the macOS app
./scripts/sign_macos.sh
```

The script will:
1. ✅ Sign the app bundle
2. ✅ Verify signature
3. ✅ Create DMG installer (optional)
4. ✅ Submit for notarization (optional)
5. ✅ Staple notarization ticket

### Troubleshooting Code Signing

**"No identity found" error:**
```bash
# Check if certificates are installed
security find-identity -v -p codesigning

# Check keychain
security list-keychains
```

**Notarization fails:**
```bash
# Check notarization history
xcrun notarytool history --keychain-profile "notarize-profile"

# Get detailed log
xcrun notarytool log [submission-id] --keychain-profile "notarize-profile"
```

**App won't run (Gatekeeper):**
```bash
# Check signature
codesign -dv --verbose=4 release/macos/auditmysite_studio.app

# Check Gatekeeper assessment
spctl -a -t exec -vv release/macos/auditmysite_studio.app
```

## 🚀 GitHub Actions (CI/CD)

### Setup Repository Secrets

Go to your GitHub repository → Settings → Secrets and variables → Actions

**Required Secrets:**
```
DEVELOPER_ID_APPLICATION_P12         # Base64 encoded .p12 file
DEVELOPER_ID_APPLICATION_PASSWORD    # Password for .p12 file
DEVELOPER_ID_APPLICATION             # Certificate name
TEAM_ID                             # Apple Developer Team ID
NOTARIZE_USERNAME                   # Apple ID email
NOTARIZE_PASSWORD                   # App-specific password
KEYCHAIN_PASSWORD                   # Temporary keychain password
```

### Export Certificate as P12

```bash
# Export from Keychain Access
# Or use command line:
security export -t identities -f p12 -o certificate.p12 -P "your-password"

# Convert to base64 for GitHub secrets
base64 -i certificate.p12 | pbcopy
```

### Trigger Builds

**Automatic (on tags):**
```bash
git tag v1.0.0
git push origin v1.0.0
```

**Manual:**
- Go to Actions → Build Release → Run workflow
- Enter version number

## 🔒 Security Best Practices

### ✅ DO:
- Store certificates in system Keychain
- Use environment variables for credentials
- Use GitHub Secrets for CI/CD
- Rotate app-specific passwords regularly
- Use temporary keychains in CI

### ❌ DON'T:
- Commit `.env` files
- Commit `.p12` certificate files
- Store passwords in scripts
- Use developer certificates for distribution
- Share certificate private keys

### Files to NEVER commit:
```
scripts/.env
*.p12
*.mobileprovision
*.certSigningRequest
certificate.pem
private-key.pem
```

## 📦 Distribution

### macOS
- **Development:** `.app` bundle
- **Distribution:** `.dmg` installer
- **App Store:** Upload via Transporter

### Windows
- **Development:** `.exe` file
- **Distribution:** `.msi` installer (future)

### Linux
- **Development:** Binary executable
- **Distribution:** `.deb`, `.rpm`, `.AppImage` (future)

## 🐛 Common Issues

**1. "App is damaged" message:**
```bash
# Remove quarantine attribute
xattr -rd com.apple.quarantine /path/to/app.app
```

**2. Flutter build fails:**
```bash
# Clean and rebuild
flutter clean
flutter pub get
flutter build macos --release
```

**3. Code signing permission denied:**
```bash
# Unlock keychain
security unlock-keychain ~/Library/Keychains/login.keychain-db
```

**4. Notarization timeout:**
- Large apps can take 10-30 minutes
- Check status: `xcrun notarytool history`

## 📞 Support

For issues with:
- **Flutter builds:** Check Flutter documentation
- **Code signing:** Apple Developer documentation
- **Notarization:** Apple Notarization documentation
- **CI/CD:** GitHub Actions documentation

## 🔄 Version Updates

When releasing a new version:

1. Update version in `pubspec.yaml`
2. Update `APP_VERSION` in `.env`
3. Run build and sign scripts
4. Test on clean system
5. Create GitHub release
6. Update distribution channels
