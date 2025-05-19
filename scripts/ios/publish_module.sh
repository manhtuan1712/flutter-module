#!/bin/bash

# Exit if any command fails
set -e

# Configuration - Update these values
GITHUB_REPO_NAME="flutter-module"           # Just the repo name, not username/repo
VERSION="1.0.1"                             # Version of the release
TAG_NAME="v$VERSION"                        # Tag name for the release

# Set up directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
OUTPUT_DIR="$SCRIPT_DIR/dist/ios_framework"
ZIP_FILE="$SCRIPT_DIR/dist/flutter_module_ios_framework.zip"
PODSPEC_FILE="$SCRIPT_DIR/dist/FlutterModuleFramework.podspec"

# Create directories if they don't exist
mkdir -p "$SCRIPT_DIR/dist"
mkdir -p "$OUTPUT_DIR"

echo "===== Starting Flutter iOS Framework Publication Process ====="

# Step 1: Check if GITHUB_USERNAME and GITHUB_TOKEN are set
if [ -z "$GITHUB_USERNAME" ] || [ -z "$GITHUB_TOKEN" ]; then
    echo "❌ GITHUB_USERNAME and/or GITHUB_TOKEN environment variables are not set."
    echo "   Please set them by running:"
    echo "   export GITHUB_USERNAME=your_github_username"
    echo "   export GITHUB_TOKEN=your_github_personal_access_token"
    exit 1
fi

# Check if this is a git repository and initialize if not
if [ ! -d ".git" ]; then
    echo "📁 Not a git repository. Initializing..."
    git init
    
    # Check if the remote exists
    if ! git remote | grep -q "origin"; then
        echo "Adding GitHub remote origin..."
        git remote add origin "https://github.com/$GITHUB_USERNAME/$GITHUB_REPO_NAME.git"
    fi
    
    # Check if we need an initial commit
    if ! git log -1 &>/dev/null; then
        echo "Creating initial commit..."
        git add .
        git commit -m "Initial commit for Flutter module"
    fi
fi

# Construct the full GitHub repo with username
GITHUB_REPO="$GITHUB_USERNAME/$GITHUB_REPO_NAME"

# Step 2: Create the iOS framework using the existing script
echo "📦 Building iOS Framework..."
if [ -f "$SCRIPT_DIR/create_ios_framework.sh" ]; then
    bash "$SCRIPT_DIR/create_ios_framework.sh"
else
    echo "❌ create_ios_framework.sh not found. Please make sure it exists."
    exit 1
fi

# Step 3: Update the podspec file with correct version and URL
echo "📝 Updating podspec with GitHub release URL..."
PODSPEC_PATH="$OUTPUT_DIR/FlutterModuleFramework.podspec"
RELEASE_URL="https://github.com/$GITHUB_REPO/releases/download/$TAG_NAME/flutter_module_ios_framework.zip"

# Update version and source URL in podspec
sed -i '' "s/s.version          = '.*'/s.version          = '$VERSION'/" "$PODSPEC_PATH"
sed -i '' "s|s.source           = { :http => '.*' }|s.source           = { :http => '$RELEASE_URL' }|" "$PODSPEC_PATH"

# Step 4: Copy the podspec to dist directory for direct upload
cp "$PODSPEC_PATH" "$PODSPEC_FILE"

# Step 5: Create a GitHub release using the API
echo "🚀 Creating GitHub release $TAG_NAME..."

# Make sure the GitHub repository exists
echo "Checking if GitHub repository exists..."
REPO_EXISTS=$(curl -s -o /dev/null -w "%{http_code}" \
  -H "Authorization: token $GITHUB_TOKEN" \
  "https://api.github.com/repos/$GITHUB_REPO")

if [ "$REPO_EXISTS" == "404" ]; then
    echo "Repository $GITHUB_REPO does not exist. Creating it..."
    curl -s -X POST \
      -H "Authorization: token $GITHUB_TOKEN" \
      -H "Accept: application/vnd.github.v3+json" \
      "https://api.github.com/user/repos" \
      -d "{\"name\":\"$GITHUB_REPO_NAME\",\"description\":\"Flutter module for easy integration\"}"
    
    sleep 2  # Give GitHub a moment to create the repo
    
    # Push code to the new repository
    git push -u origin master || git push -u origin main
fi

# First, check if the tag exists on remote
TAG_EXISTS=$(curl -s -o /dev/null -w "%{http_code}" \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  "https://api.github.com/repos/$GITHUB_REPO/git/refs/tags/$TAG_NAME")

# If tag doesn't exist, create it
if [ "$TAG_EXISTS" != "200" ]; then
    echo "Creating tag $TAG_NAME on remote..."
    
    # Get the current commit SHA
    COMMIT_SHA=$(git rev-parse HEAD)
    
    # Create tag via API
    curl -s -X POST \
      -H "Authorization: token $GITHUB_TOKEN" \
      -H "Accept: application/vnd.github.v3+json" \
      "https://api.github.com/repos/$GITHUB_REPO/git/refs" \
      -d "{\"ref\":\"refs/tags/$TAG_NAME\",\"sha\":\"$COMMIT_SHA\"}"
fi

# Create a release
echo "Creating GitHub release..."
RELEASE_RESPONSE=$(curl -s -X POST \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  "https://api.github.com/repos/$GITHUB_REPO/releases" \
  -d "{\"tag_name\":\"$TAG_NAME\",\"name\":\"Flutter Module iOS Framework $VERSION\",\"body\":\"Pre-compiled Flutter module for iOS integration\",\"draft\":false,\"prerelease\":false}")

# Extract the release ID from the response
RELEASE_ID=$(echo "$RELEASE_RESPONSE" | grep -o '"id": [0-9]*' | head -1 | awk '{print $2}')

if [ -z "$RELEASE_ID" ]; then
    echo "❌ Failed to create release. Response:"
    echo "$RELEASE_RESPONSE"
    exit 1
fi

echo "Release created with ID: $RELEASE_ID"

# Step 6: Upload the ZIP file to the release
echo "Uploading framework ZIP file..."
curl -s -X POST \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  -H "Content-Type: application/zip" \
  --data-binary @"$ZIP_FILE" \
  "https://uploads.github.com/repos/$GITHUB_REPO/releases/$RELEASE_ID/assets?name=flutter_module_ios_framework.zip"

# Step 7: Upload the podspec file to the release
echo "Uploading podspec file..."
curl -s -X POST \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  -H "Content-Type: text/plain" \
  --data-binary @"$PODSPEC_FILE" \
  "https://uploads.github.com/repos/$GITHUB_REPO/releases/$RELEASE_ID/assets?name=FlutterModuleFramework.podspec"

# Step 8: Get and display the Podspec URL
PODSPEC_URL="https://github.com/$GITHUB_REPO/releases/download/$TAG_NAME/FlutterModuleFramework.podspec"

echo ""
echo "===== 🎉 Flutter iOS Framework Published Successfully! ====="
echo ""
echo "✅ Podspec URL: $PODSPEC_URL"
echo ""
echo "iOS developers can add this to their Podfile:"
echo ""
echo "pod 'FlutterModuleFramework', :podspec => '$PODSPEC_URL'"
echo ""
echo "Note: Make sure your GitHub repository is public, or you've set up proper access controls if it's private." 