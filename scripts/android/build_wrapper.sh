#!/bin/bash

# Exit if any command fails
set -e

# Set up directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
FLUTTER_WRAPPER_DIR="$ROOT_DIR/flutter_wrapper"
DIST_DIR="$ROOT_DIR/dist"
VERSION="1.0.0"
AAR_FILE="$DIST_DIR/flutter-wrapper-$VERSION.aar"

echo "===== Building Flutter Android Wrapper ====="

# Create dist directory if it doesn't exist
mkdir -p "$DIST_DIR"

# Step 1: Build the Flutter module
echo "📦 Building Flutter AAR..."
cd "$ROOT_DIR"

# Build the Flutter module AAR
flutter build aar --no-debug --no-profile

# Copy the Flutter release AAR to the dist directory
FLUTTER_AAR=$(find "$ROOT_DIR/build/host/outputs/repo/com/example/flutter_module/flutter_release/" -name "*.aar" | sort -V | tail -n 1)
if [ -n "$FLUTTER_AAR" ]; then
    cp "$FLUTTER_AAR" "$DIST_DIR/flutter-release-$VERSION.aar"
    echo "✅ Flutter AAR copied to $DIST_DIR/flutter-release-$VERSION.aar"
else
    echo "❌ Could not find Flutter AAR file."
    exit 1
fi

# Step 2: Build the Flutter wrapper
echo "📦 Building Flutter Wrapper AAR..."
cd "$FLUTTER_WRAPPER_DIR"

# Ensure Gradle wrapper is executable
chmod +x "./gradlew"

# Clean and build the wrapper
./gradlew clean assembleRelease

# Copy the wrapper AAR to the dist directory
WRAPPER_AAR=$(find "$FLUTTER_WRAPPER_DIR/build/outputs/aar" -name "*.aar" | head -n 1)
if [ -n "$WRAPPER_AAR" ]; then
    cp "$WRAPPER_AAR" "$AAR_FILE"
    echo "✅ Wrapper AAR copied to $AAR_FILE"
else
    echo "❌ Could not find wrapper AAR file."
    exit 1
fi

echo ""
echo "===== 🎉 Flutter Android Wrapper Built Successfully! ====="
echo ""
echo "Output files:"
echo "✅ Flutter AAR: $DIST_DIR/flutter-release-$VERSION.aar"
echo "✅ Wrapper AAR: $AAR_FILE"
echo ""
echo "You can now use these AAR files in your Android project by:"
echo "1. Copying them to your app's libs directory"
echo "2. Adding the following to your app build.gradle:"
echo ""
echo "   dependencies {"
echo "       implementation files('libs/flutter-release-$VERSION.aar')"
echo "       implementation files('libs/flutter-wrapper-$VERSION.aar')"
echo "   }" 