#!/bin/bash

# Exit if any command fails
set -e

# Check if GitHub credentials are set
if [ -z "$GITHUB_USERNAME" ] || [ -z "$GITHUB_TOKEN" ]; then
  echo "Error: GitHub credentials not set."
  echo "Please set the following environment variables:"
  echo "  export GITHUB_USERNAME=your_username"
  echo "  export GITHUB_TOKEN=your_personal_access_token"
  exit 1
fi

echo "===== Building Flutter Module for GitHub Packages ====="

# Navigate to the flutter module directory
cd "$(dirname "$0")"

# Make sure Flutter dependencies are up-to-date
echo "Updating Flutter dependencies..."
flutter pub get

# Build the AAR files
echo "Building Flutter module..."
flutter build aar --no-debug --no-profile

# Run the publish task
echo "Publishing to GitHub Packages..."
cd android
./gradlew publishFlutterModulePublicationToGitHubPackagesRepository

echo "===== Flutter Module Published Successfully to GitHub Packages ====="
echo ""
echo "To use this module in your Android project, add the following to your settings.gradle:"
echo "  repositories {"
echo "      maven {"
echo "          name = \"GitHubPackages\""
echo "          url = \"https://maven.pkg.github.com/REPLACE_WITH_YOUR_USERNAME/REPLACE_WITH_YOUR_REPO\""
echo "          credentials {"
echo "              username = findProperty(\"gpr.user\") ?: System.getenv(\"GITHUB_USERNAME\")"
echo "              password = findProperty(\"gpr.key\") ?: System.getenv(\"GITHUB_TOKEN\")"
echo "          }"
echo "      }"
echo "  }"
echo ""
echo "And add the following to your app-level build.gradle:"
echo "  dependencies {"
echo "      implementation 'com.example:flutter_module:1.0.0'"
echo "  }" 