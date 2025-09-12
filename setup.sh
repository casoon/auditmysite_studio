#!/bin/bash

# auditmysite_studio Setup Script
set -e

echo "🚀 auditmysite_studio Setup"
echo "============================"

# Check Dart installation
if ! command -v dart &> /dev/null; then
    echo "❌ Dart nicht gefunden. Bitte installiere Dart ≥3.3.0"
    exit 1
fi

# Check Flutter installation  
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter nicht gefunden. Bitte installiere Flutter ≥3.19.0"
    exit 1
fi

echo "✅ Dart: $(dart --version | head -n 1)"
echo "✅ Flutter: $(flutter --version | head -n 1)"
echo ""

# Setup shared package
echo "📦 Setting up shared package..."
cd shared
dart pub get
dart run build_runner build --delete-conflicting-outputs
cd ..
echo "✅ Shared package ready"

# Setup engine
echo "🔧 Setting up auditmysite_engine..."
cd auditmysite_engine  
dart pub get
cd ..
echo "✅ Engine ready"

# Setup CLI
echo "📝 Setting up auditmysite_cli..."
cd auditmysite_cli
dart pub get  
cd ..
echo "✅ CLI ready"

# Setup Studio
echo "🎨 Setting up auditmysite_studio..."
cd auditmysite_studio
flutter pub get
cd ..  
echo "✅ Studio ready"

echo ""
echo "🎉 Setup abgeschlossen!"
echo ""
echo "Nächste Schritte:"
echo "1. Lade axe.min.js herunter:"
echo "   curl -o auditmysite_engine/third_party/axe/axe.min.js https://cdnjs.cloudflare.com/ajax/libs/axe-core/4.8.4/axe.min.js"
echo ""  
echo "2. Teste die Engine:"
echo "   cd auditmysite_engine && dart run bin/run.dart --sitemap=https://example.com/sitemap.xml"
echo ""
echo "3. Starte die Studio-GUI:"
echo "   cd auditmysite_studio && flutter run -d macos"
echo ""
echo "Siehe README.md für weitere Details!"
