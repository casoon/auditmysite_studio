#!/bin/bash

# macOS Code Signing Script for AuditMySite
# This script signs the macOS app bundle using certificates from Keychain

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration - These should be set as environment variables
DEVELOPER_ID_APPLICATION=${DEVELOPER_ID_APPLICATION:-""}
DEVELOPER_ID_INSTALLER=${DEVELOPER_ID_INSTALLER:-""}
APP_BUNDLE_ID=${APP_BUNDLE_ID:-"com.auditmysite.studio"}
APP_PATH=${APP_PATH:-"release/macos/auditmysite_studio.app"}
NOTARIZE_USERNAME=${NOTARIZE_USERNAME:-""}
NOTARIZE_PASSWORD=${NOTARIZE_PASSWORD:-""}  # App-specific password
TEAM_ID=${TEAM_ID:-""}

echo -e "${BLUE}🔐 Starting macOS Code Signing Process${NC}"
echo "==========================================="

# Check if app bundle exists
if [ ! -d "$APP_PATH" ]; then
    echo -e "${RED}❌ App bundle not found: $APP_PATH${NC}"
    echo "Run build_all.sh first to create the app bundle."
    exit 1
fi

# Check for required environment variables
if [ -z "$DEVELOPER_ID_APPLICATION" ]; then
    echo -e "${RED}❌ DEVELOPER_ID_APPLICATION environment variable not set${NC}"
    echo "Set it to your 'Developer ID Application' certificate name"
    echo "Example: export DEVELOPER_ID_APPLICATION='Developer ID Application: Your Name (TEAM_ID)'"
    exit 1
fi

echo -e "${YELLOW}📝 Signing Configuration:${NC}"
echo "App Bundle ID: $APP_BUNDLE_ID"
echo "App Path: $APP_PATH"
echo "Developer ID: $DEVELOPER_ID_APPLICATION"
echo ""

# Step 1: Sign the app bundle
echo -e "${YELLOW}1️⃣ Signing app bundle...${NC}"
codesign --force --options runtime --sign "$DEVELOPER_ID_APPLICATION" \
    --entitlements scripts/entitlements.plist \
    --timestamp "$APP_PATH"

# Verify the signature
echo -e "${YELLOW}2️⃣ Verifying signature...${NC}"
codesign --verify --verbose "$APP_PATH"
spctl --assess --verbose "$APP_PATH"

echo -e "${GREEN}✅ App bundle signed successfully${NC}"

# Step 2: Create DMG (optional)
DMG_NAME="AuditMySite-$(date +%Y%m%d).dmg"
DMG_PATH="dist/$DMG_NAME"

if command -v create-dmg &> /dev/null; then
    echo -e "${YELLOW}3️⃣ Creating DMG installer...${NC}"
    create-dmg \
        --volname "AuditMySite" \
        --volicon "$APP_PATH/Contents/Resources/AppIcon.icns" \
        --window-pos 200 120 \
        --window-size 800 400 \
        --icon-size 100 \
        --icon "auditmysite_studio.app" 200 190 \
        --hide-extension "auditmysite_studio.app" \
        --app-drop-link 600 185 \
        "$DMG_PATH" \
        "$APP_PATH"
    
    # Sign the DMG
    echo -e "${YELLOW}4️⃣ Signing DMG...${NC}"
    codesign --force --sign "$DEVELOPER_ID_APPLICATION" "$DMG_PATH"
    
    echo -e "${GREEN}✅ DMG created and signed: $DMG_PATH${NC}"
else
    echo -e "${YELLOW}⚠️ create-dmg not found, skipping DMG creation${NC}"
    echo "Install with: brew install create-dmg"
fi

# Step 3: Notarization (if credentials provided)
if [ -n "$NOTARIZE_USERNAME" ] && [ -n "$NOTARIZE_PASSWORD" ] && [ -n "$TEAM_ID" ]; then
    echo -e "${YELLOW}5️⃣ Starting notarization...${NC}"
    
    # Create a temporary keychain profile for notarization
    xcrun notarytool store-credentials "notarize-profile" \
        --apple-id "$NOTARIZE_USERNAME" \
        --password "$NOTARIZE_PASSWORD" \
        --team-id "$TEAM_ID" || true
    
    # Submit for notarization
    if [ -f "$DMG_PATH" ]; then
        NOTARIZE_FILE="$DMG_PATH"
    else
        NOTARIZE_FILE="$APP_PATH"
    fi
    
    echo "Submitting $NOTARIZE_FILE for notarization..."
    xcrun notarytool submit "$NOTARIZE_FILE" \
        --keychain-profile "notarize-profile" \
        --wait
    
    # Staple the notarization ticket
    echo -e "${YELLOW}6️⃣ Stapling notarization ticket...${NC}"
    xcrun stapler staple "$NOTARIZE_FILE"
    
    echo -e "${GREEN}✅ Notarization completed${NC}"
else
    echo -e "${YELLOW}⚠️ Notarization credentials not provided, skipping notarization${NC}"
    echo "To enable notarization, set these environment variables:"
    echo "- NOTARIZE_USERNAME (your Apple ID)"
    echo "- NOTARIZE_PASSWORD (app-specific password)"
    echo "- TEAM_ID (your developer team ID)"
fi

echo -e "\n${GREEN}🎉 Code signing process completed!${NC}"
echo -e "${BLUE}📦 Signed files:${NC}"
ls -la "$APP_PATH"
if [ -f "$DMG_PATH" ]; then
    ls -la "$DMG_PATH"
fi
