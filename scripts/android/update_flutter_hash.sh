#!/bin/bash

# Exit if any command fails
set -e

# Set up directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
FLUTTER_WRAPPER_DIR="$ROOT_DIR/flutter_wrapper"
BUILD_DIR="$ROOT_DIR/build"

echo "===== Updating Flutter Engine Hash ====="

# Step 1: Build Flutter AAR to get the latest hash
echo "Building Flutter AAR to extract engine hash..."
cd "$ROOT_DIR"
flutter build aar --no-debug --no-profile

# Step 2: Find the hash from the repo directory
ENGINE_HASH=$(find "$BUILD_DIR/host/outputs/repo" -path "*flutter_embedding_release*.pom" | xargs grep -o "1.0.0-[a-f0-9]*" | head -1 | cut -d'-' -f2)

if [ -z "$ENGINE_HASH" ]; then
    echo "❌ Could not find Flutter engine hash in build output."
    exit 1
fi

echo "✅ Found Flutter engine hash: $ENGINE_HASH"

# Step 3: Update the build.gradle file
echo "Updating Flutter wrapper build.gradle..."

# Create a temp file
TEMP_FILE=$(mktemp)

# Replace the old hash with the new one
sed -E "s/io.flutter:flutter_embedding_release:1.0.0-[a-f0-9]*/io.flutter:flutter_embedding_release:1.0.0-$ENGINE_HASH/g" "$FLUTTER_WRAPPER_DIR/build.gradle" > "$TEMP_FILE"
sed -E "s/io.flutter:armeabi_v7a_release:1.0.0-[a-f0-9]*/io.flutter:armeabi_v7a_release:1.0.0-$ENGINE_HASH/g" "$TEMP_FILE" > "$TEMP_FILE.2"
sed -E "s/io.flutter:arm64_v8a_release:1.0.0-[a-f0-9]*/io.flutter:arm64_v8a_release:1.0.0-$ENGINE_HASH/g" "$TEMP_FILE.2" > "$TEMP_FILE"
sed -E "s/io.flutter:x86_64_release:1.0.0-[a-f0-9]*/io.flutter:x86_64_release:1.0.0-$ENGINE_HASH/g" "$TEMP_FILE" > "$TEMP_FILE.2"

# Overwrite the original file
cp "$TEMP_FILE.2" "$FLUTTER_WRAPPER_DIR/build.gradle"

# Clean up
rm "$TEMP_FILE" "$TEMP_FILE.2"

echo "✅ Flutter engine hash updated to $ENGINE_HASH"
echo ""
echo "===== Flutter Engine Hash Update Complete ====="
echo ""
echo "To publish with the updated hash, run:"
echo "  scripts/android/publish_module.sh" 