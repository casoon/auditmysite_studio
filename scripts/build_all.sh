#!/bin/bash

# AuditMySite - Master Build Script
# Builds all components: Studio, CLI, and Engine

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

VERSION=${1:-"dev"}
BUILD_TYPE=${2:-"release"}

echo -e "${BLUE}🚀 Building AuditMySite v${VERSION} (${BUILD_TYPE})${NC}"
echo "========================================="

# Create release directory structure
mkdir -p release/{macos,windows,linux}
mkdir -p dist

# 1. Build Flutter Studio App
echo -e "\n${YELLOW}📱 Building Flutter Studio App...${NC}"
cd auditmysite_studio

if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "Building for macOS..."
    flutter clean
    flutter pub get
    flutter build macos --release
    
    # Copy to release directory
    cp -r build/macos/Build/Products/Release/auditmysite_studio.app ../release/macos/
    echo -e "${GREEN}✅ macOS build completed${NC}"
fi

cd ..

# 2. Build CLI Tool
echo -e "\n${YELLOW}🔧 Building CLI Tool...${NC}"
cd auditmysite_cli

if command -v dart &> /dev/null; then
    dart pub get
    
    # Build for current platform
    if [[ "$OSTYPE" == "darwin"* ]]; then
        dart compile exe bin/main.dart -o release/auditmysite-cli-macos
        cp release/auditmysite-cli-macos ../bin/
        echo -e "${GREEN}✅ CLI macOS build completed${NC}"
    fi
else
    echo -e "${RED}❌ Dart SDK not found, skipping CLI build${NC}"
fi

cd ..

# 3. Prepare Engine
echo -e "\n${YELLOW}🔍 Preparing Engine...${NC}"
cd auditmysite_engine

if command -v python3 &> /dev/null; then
    # Install dependencies
    if [ -f requirements.txt ]; then
        pip3 install -r requirements.txt
    fi
    
    # Optional: Build with PyInstaller if available
    if command -v pyinstaller &> /dev/null; then
        pyinstaller --onefile --name auditmysite-engine main.py
        cp dist/auditmysite-engine release/
        echo -e "${GREEN}✅ Engine binary build completed${NC}"
    else
        echo -e "${YELLOW}⚠️  PyInstaller not found, engine remains as Python script${NC}"
    fi
else
    echo -e "${RED}❌ Python3 not found, skipping engine preparation${NC}"
fi

cd ..

echo -e "\n${GREEN}🎉 Build completed successfully!${NC}"
echo "Built components are in the respective release/ directories"

# Show build summary
echo -e "\n${BLUE}📦 Build Summary:${NC}"
find . -name "release" -type d -exec find {} -type f \; | head -20
