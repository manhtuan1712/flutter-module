#!/bin/bash

# Exit if any command fails
set -e

# Configuration - Update these values
GITHUB_REPO_NAME="flutter-module"          # Just the repo name, not username/repo
VERSION="1.0.0"                            # Version of the release
TAG_NAME="v$VERSION"                       # Tag name for the release

# Set up directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
FLUTTER_WRAPPER_DIR="$ROOT_DIR/flutter_wrapper"
DIST_DIR="$ROOT_DIR/dist"
AAR_FILE="$DIST_DIR/flutter-wrapper-$VERSION.aar"
FLUTTER_AAR_FILE="$DIST_DIR/flutter-release-$VERSION.aar"

echo "===== Starting Flutter Android Module Publication Process ====="

# Step 1: Check if GITHUB_USERNAME and GITHUB_TOKEN are set
if [ -z "$GITHUB_USERNAME" ] || [ -z "$GITHUB_TOKEN" ]; then
    echo "❌ GITHUB_USERNAME and/or GITHUB_TOKEN environment variables are not set."
    echo "   Please set them by running:"
    echo "   export GITHUB_USERNAME=your_github_username"
    echo "   export GITHUB_TOKEN=your_github_personal_access_token"
    exit 1
fi

# Check if this is a git repository and initialize if not
if [ ! -d "$ROOT_DIR/.git" ]; then
    echo "📁 Not a git repository. Initializing..."
    cd "$ROOT_DIR"
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

# Step 2: Build and publish to GitHub Packages
echo "📦 Preparing to publish to GitHub Packages..."

mkdir -p "$DIST_DIR"

# Build Flutter AAR and update Flutter engine hash
cd "$ROOT_DIR"
echo "Building Flutter AAR..."
flutter build aar --no-debug --no-profile

# Update Flutter engine hash in wrapper's build.gradle
echo "Updating Flutter engine hash in wrapper's build.gradle..."

# Get the engine hash directly from Flutter (more reliable)
ENGINE_HASH=$(flutter --version --machine | grep engineRevision | cut -d'"' -f4)
if [ -z "$ENGINE_HASH" ]; then
    echo "⚠️ Could not get Flutter engine hash from flutter --version command. Using default."
    # Use a default value
    ENGINE_HASH="cf56914b326edb0ccb123ffdc60f00060bd513fa"
fi

echo "✅ Using Flutter engine hash: $ENGINE_HASH"

# Create a completely new build.gradle with the correct structure
if [ -f "$FLUTTER_WRAPPER_DIR/build.gradle" ]; then
    # Create backup first
    cp "$FLUTTER_WRAPPER_DIR/build.gradle" "$FLUTTER_WRAPPER_DIR/build.gradle.bak.$(date +%s)"
    
    # Write a new build.gradle file with correct structure
    cat > "$FLUTTER_WRAPPER_DIR/build.gradle" << EOF
buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath 'com.android.tools.build:gradle:7.2.2'
        classpath 'org.jetbrains.kotlin:kotlin-gradle-plugin:1.8.0'
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
        maven {
            url 'https://storage.googleapis.com/download.flutter.io'
        }
    }
}

apply plugin: 'com.android.library'
apply plugin: 'kotlin-android'
apply plugin: 'maven-publish'

android {
    compileSdkVersion 33
    
    defaultConfig {
        minSdkVersion 21
        targetSdkVersion 33
        versionCode 1
        versionName "1.0.0"
    }
    
    buildTypes {
        release {
            minifyEnabled false
            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
        }
    }
    
    compileOptions {
        sourceCompatibility JavaVersion.VERSION_1_8
        targetCompatibility JavaVersion.VERSION_1_8
    }
    
    kotlinOptions {
        jvmTarget = '1.8'
    }
    
    lintOptions {
        disable 'InvalidPackage'
        abortOnError false
    }
    
    configurations.all {
        resolutionStrategy {
            force "org.jetbrains.kotlin:kotlin-stdlib:1.8.0"
            force "org.jetbrains.kotlin:kotlin-stdlib-common:1.8.0"
            force "org.jetbrains.kotlin:kotlin-stdlib-jdk7:1.8.0"
            force "org.jetbrains.kotlin:kotlin-stdlib-jdk8:1.8.0"
            force "org.jetbrains.kotlin:kotlin-reflect:1.8.0"
            eachDependency { details ->
                if (details.requested.group == 'org.jetbrains.kotlin') {
                    details.useVersion '1.8.0'
                }
            }
        }
    }
}

// Function to dynamically find the Flutter engine hash
def findFlutterEngineHash() {
    // Use a simpler approach - directly use flutter command
    try {
        def result = new ByteArrayOutputStream()
        exec {
            workingDir rootProject.projectDir.parent
            commandLine 'flutter', '--version', '--machine'
            standardOutput = result
        }
        
        def text = result.toString()
        def matcher = text =~ /"engineRevision":"([a-f0-9]+)"/
        if (matcher.find()) {
            return matcher.group(1)
        }
    } catch (Exception e) {
        println "Error finding Flutter engine hash: \${e.message}"
    }
    
    // If all else fails, use a default hash
    return "$ENGINE_HASH"
}

// Get the engine hash
def engineHash = findFlutterEngineHash()
println "Using Flutter engine hash: \${engineHash}"

dependencies {
    implementation "org.jetbrains.kotlin:kotlin-stdlib:1.8.0"
    implementation "androidx.core:core-ktx:1.8.0"
    implementation "androidx.appcompat:appcompat:1.4.2"
    
    // Use api instead of implementation to make Flutter embedding transitive
    // This ensures any app using the wrapper automatically gets Flutter embedding
    api "io.flutter:flutter_embedding_release:1.0.0-$ENGINE_HASH"
    api "io.flutter:armeabi_v7a_release:1.0.0-$ENGINE_HASH"
    api "io.flutter:arm64_v8a_release:1.0.0-$ENGINE_HASH"
    api "io.flutter:x86_64_release:1.0.0-$ENGINE_HASH"
}

def getGithubUsername() {
    return project.findProperty('gpr.user') ?: System.getenv("GITHUB_USERNAME")
}

def getGithubToken() {
    return project.findProperty('gpr.key') ?: System.getenv("GITHUB_TOKEN")
}

def getGithubRepoName() {
    if (project.hasProperty('githubRepoName')) {
        return project.getProperty('githubRepoName')
    }
    return "flutter-module"
}

afterEvaluate {
    publishing {
        publications {
            release(MavenPublication) {
                from components.release
                
                groupId = 'com.example.flutter_module'
                artifactId = 'flutter_wrapper'
                version = '1.0.0'
                
                pom {
                    name = 'Flutter Module Wrapper'
                    description = 'A wrapper library for easy Flutter module integration'
                    url = 'https://github.com/' + getGithubUsername() + '/' + getGithubRepoName()
                    licenses {
                        license {
                            name = 'The Apache License, Version 2.0'
                            url = 'http://www.apache.org/licenses/LICENSE-2.0.txt'
                        }
                    }
                    developers {
                        developer {
                            id = getGithubUsername()
                            name = 'Flutter Developer'
                        }
                    }
                }
            }
        }
        
        repositories {
            maven {
                name = 'GitHubPackages'
                url = uri("https://maven.pkg.github.com/" + getGithubUsername() + "/" + getGithubRepoName())
                credentials {
                    username = getGithubUsername()
                    password = getGithubToken()
                }
            }
        }
    }
}
EOF

    echo "✅ Completely rebuilt Flutter wrapper build.gradle with engine hash: $ENGINE_HASH"
else
    echo "❌ Flutter wrapper build.gradle not found at $FLUTTER_WRAPPER_DIR/build.gradle"
    exit 1
fi

# Copy the Flutter release AAR to the dist directory
FLUTTER_AAR=$(find "$ROOT_DIR/build/host/outputs/repo/com/example/flutter_module/flutter_release/" -name "*.aar" | sort -V | tail -n 1)
if [ -n "$FLUTTER_AAR" ]; then
    cp "$FLUTTER_AAR" "$FLUTTER_AAR_FILE"
    echo "✅ Flutter AAR copied to $FLUTTER_AAR_FILE"
else
    echo "❌ Could not find Flutter AAR file."
    exit 1
fi

# Create settings.xml for Maven authentication if it doesn't exist
MAVEN_SETTINGS_DIR="$HOME/.m2"
MAVEN_SETTINGS_FILE="$MAVEN_SETTINGS_DIR/settings.xml"

mkdir -p "$MAVEN_SETTINGS_DIR"

if [ ! -f "$MAVEN_SETTINGS_FILE" ] || ! grep -q "<id>github</id>" "$MAVEN_SETTINGS_FILE"; then
cat > "$MAVEN_SETTINGS_FILE" << EOF
<settings xmlns="http://maven.apache.org/SETTINGS/1.0.0"
          xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
          xsi:schemaLocation="http://maven.apache.org/SETTINGS/1.0.0
                              http://maven.apache.org/xsd/settings-1.0.0.xsd">
  <servers>
    <server>
      <id>github</id>
      <username>${GITHUB_USERNAME}</username>
      <password>${GITHUB_TOKEN}</password>
    </server>
  </servers>
</settings>
EOF
echo "Created Maven settings file with GitHub credentials."
fi

# Use GitHub API to publish Flutter module directly to GitHub Packages
echo "📦 Publishing Flutter Module to GitHub Packages via API..."

# First create a new package version using the GitHub API
echo "Creating package version for Flutter module..."
# Try user-level API endpoint first (for personal accounts)
RESPONSE=$(curl -s -w "%{http_code}" -o /dev/null -X POST \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  "https://api.github.com/user/packages/maven/com.example.flutter_module/versions" \
  -d "{\"name\":\"$VERSION\",\"description\":\"Flutter module for Android integration\"}")

# If that fails, try organization-level API endpoint
if [ "$RESPONSE" != "201" ]; then
  echo "Trying organization-level package API..."
  curl -s -X POST \
    -H "Authorization: token $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github.v3+json" \
    "https://api.github.com/orgs/$GITHUB_USERNAME/packages/maven/com.example.flutter_module/versions" \
    -d "{\"name\":\"$VERSION\",\"description\":\"Flutter module for Android integration\"}"
fi

# Upload the content to GitHub Packages
echo "Uploading Flutter module AAR to GitHub Packages..."
curl -s -X PUT \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  -H "Content-Type: application/octet-stream" \
  --data-binary @"$FLUTTER_AAR_FILE" \
  "https://maven.pkg.github.com/$GITHUB_REPO/com/example/flutter_module/flutter_module/$VERSION/flutter_module-$VERSION.aar"

# Create a basic POM file
TEMP_DIR=$(mktemp -d)
POM_FILE="$TEMP_DIR/flutter_module-$VERSION.pom"

cat > "$POM_FILE" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0" 
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
  <modelVersion>4.0.0</modelVersion>
  <groupId>com.example.flutter_module</groupId>
  <artifactId>flutter_module</artifactId>
  <version>$VERSION</version>
  <packaging>aar</packaging>
  <name>Flutter Module</name>
  <description>Flutter module for Android integration</description>
</project>
EOF

# Upload the POM to GitHub Packages
echo "Uploading POM file for Flutter module to GitHub Packages..."
curl -s -X PUT \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  -H "Content-Type: application/octet-stream" \
  --data-binary @"$POM_FILE" \
  "https://maven.pkg.github.com/$GITHUB_REPO/com/example/flutter_module/flutter_module/$VERSION/flutter_module-$VERSION.pom"

echo "✅ Flutter Module published to GitHub Packages directly via API"

# Build and publish Flutter Wrapper to GitHub Packages
echo "📦 Building and publishing Flutter Wrapper..."
cd "$FLUTTER_WRAPPER_DIR"

# Ensure Gradle wrapper is executable
chmod +x "./gradlew"

# Clean and build
./gradlew clean

# Publish the wrapper
./gradlew -Pgpr.user="$GITHUB_USERNAME" -Pgpr.key="$GITHUB_TOKEN" -PgithubRepoName="$GITHUB_REPO_NAME" publishAllPublicationsToGitHubPackagesRepository

# Copy the wrapper AAR to the dist directory
WRAPPER_AAR=$(find "$FLUTTER_WRAPPER_DIR/build/outputs/aar" -name "*.aar" | head -n 1)
if [ -n "$WRAPPER_AAR" ]; then
    cp "$WRAPPER_AAR" "$AAR_FILE"
    echo "✅ Wrapper AAR copied to $AAR_FILE"
else
    echo "❌ Could not find wrapper AAR file."
    exit 1
fi

echo "✅ Published to GitHub Packages: https://github.com/$GITHUB_REPO/packages"

# Step 3: Create a GitHub release using the API
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
    cd "$ROOT_DIR"
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
    cd "$ROOT_DIR"
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
  -d "{\"tag_name\":\"$TAG_NAME\",\"name\":\"Flutter Module Android Release $VERSION\",\"body\":\"Pre-compiled Flutter module for Android integration\",\"draft\":false,\"prerelease\":false}")

# Extract the release ID from the response
RELEASE_ID=$(echo "$RELEASE_RESPONSE" | grep -o '"id": [0-9]*' | head -1 | awk '{print $2}')

if [ -z "$RELEASE_ID" ]; then
    echo "❌ Failed to create release. Response:"
    echo "$RELEASE_RESPONSE"
    exit 1
fi

echo "Release created with ID: $RELEASE_ID"

# Step 4: Upload the AAR files to the release
echo "Uploading Flutter AAR file..."
curl -s -X POST \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  -H "Content-Type: application/octet-stream" \
  --data-binary @"$FLUTTER_AAR_FILE" \
  "https://uploads.github.com/repos/$GITHUB_REPO/releases/$RELEASE_ID/assets?name=flutter-release-$VERSION.aar"

echo "Uploading wrapper AAR file..."
curl -s -X POST \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  -H "Content-Type: application/octet-stream" \
  --data-binary @"$AAR_FILE" \
  "https://uploads.github.com/repos/$GITHUB_REPO/releases/$RELEASE_ID/assets?name=flutter-wrapper-$VERSION.aar"

# Step 5: Create integration info JSON
cat > "$DIST_DIR/flutter-integration-info.json" << EOF
{
  "version": "$VERSION",
  "flutter_aar": "flutter-release-$VERSION.aar",
  "wrapper_aar": "flutter-wrapper-$VERSION.aar",
  "integration_guide": "https://github.com/$GITHUB_REPO/blob/main/README.md"
}
EOF

echo "Uploading integration info file..."
curl -s -X POST \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  -H "Content-Type: application/json" \
  --data-binary @"$DIST_DIR/flutter-integration-info.json" \
  "https://uploads.github.com/repos/$GITHUB_REPO/releases/$RELEASE_ID/assets?name=flutter-integration-info.json"

# Step 6: Display download URLs and instructions
FLUTTER_URL="https://github.com/$GITHUB_REPO/releases/download/$TAG_NAME/flutter-release-$VERSION.aar"
WRAPPER_URL="https://github.com/$GITHUB_REPO/releases/download/$TAG_NAME/flutter-wrapper-$VERSION.aar"
INFO_URL="https://github.com/$GITHUB_REPO/releases/download/$TAG_NAME/flutter-integration-info.json"

echo ""
echo "===== 🎉 Flutter Android Module Published Successfully! ====="
echo ""
echo "AAR Files:"
echo "✅ Flutter AAR: $FLUTTER_URL"
echo "✅ Wrapper AAR: $WRAPPER_URL"
echo "✅ Info JSON: $INFO_URL"
echo ""
echo "Package Repository:"
echo "✅ GitHub Packages: https://github.com/$GITHUB_REPO/packages"
echo ""
echo "To verify GitHub Packages, visit: https://github.com/$GITHUB_REPO/packages"
echo ""
echo "Android developers can use these artifacts by:"
echo ""
echo "Option 1: GitHub Packages (Recommended)"
echo "   Add to settings.gradle:"
echo "   dependencyResolutionManagement {"
echo "       repositories {"
echo "           maven {"
echo "               name = \"GitHubPackages\""
echo "               url = uri(\"https://maven.pkg.github.com/$GITHUB_REPO\")"
echo "               credentials {"
echo "                   username = '<github-username>'"
echo "                   password = '<github-token>'"
echo "               }"
echo "           }"
echo "           maven {"
echo "               url = uri(\"https://storage.googleapis.com/download.flutter.io\")"
echo "           }"
echo "       }"
echo "   }"
echo ""
echo "   Add to build.gradle:"
echo "   dependencies {"
echo "       // Flutter components - both are needed"
echo "       implementation 'com.example.flutter_module:flutter_wrapper:$VERSION'"
echo "       implementation 'com.example.flutter_module:flutter-release:$VERSION'"
echo "   }"
echo ""
echo "Option 2: Direct AAR Files"
echo "   1. Download the AAR files and add to your app's libs directory"
echo "   2. Add to build.gradle:"
echo "      dependencies {"
echo "          implementation files('libs/flutter-release-$VERSION.aar')"
echo "          implementation files('libs/flutter-wrapper-$VERSION.aar')"
echo "          // Also need Flutter engine files from Flutter repo"
echo "      }"
echo ""
echo "Note: Make sure your GitHub repository is public, or you've set up proper access controls if it's private."
echo ""
echo "We've created an integration guide at android-integration-guide.md with more detailed instructions."
echo ""
echo "Important: Your Android app must also include proper AndroidManifest.xml configuration for Flutter."
echo "See android-integration-guide.md for complete setup instructions."