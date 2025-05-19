# Publishing the Flutter Module iOS Framework

This guide explains how to publish the Flutter module iOS framework to GitHub releases for easy integration by iOS developers.

## Prerequisites

1. **GitHub Account**: You need a GitHub account with permission to publish releases
2. **Personal Access Token**: Create a token with `repo` scope at https://github.com/settings/tokens
3. **Flutter Environment**: Make sure Flutter is installed and available in your PATH

## Environment Setup

Set the required environment variables:

   ```bash
export GITHUB_USERNAME="your_github_username"
export GITHUB_TOKEN="your_personal_access_token"
```

## Publishing Process

### 1. Build and Package the Framework

The `create_ios_framework.sh` script handles:
- Building the Flutter module as an iOS framework
- Processing frameworks to avoid duplication
- Creating the podspec file
- Adding a runtime cleanup script
- Packaging everything into a distributable ZIP file

Run it manually (if needed):

   ```bash
./create_ios_framework.sh
```

### 2. Publish to GitHub

The `publish_module_ios.sh` script handles:
- Running the build script
- Creating a GitHub release
- Uploading the framework package
- Publishing the podspec file

Run:

   ```bash
./publish_module_ios.sh
```

## Integration for iOS Developers

iOS developers can integrate the framework using CocoaPods:

```ruby
pod 'FlutterModuleFramework', :podspec => 'https://github.com/YOUR_USERNAME/flutter-module/releases/download/v1.0.0/FlutterModuleFramework.podspec'
   ```

## Fixing Duplicate Framework Issues

If integration issues occur, iOS developers can use the `fix_xcode_project.rb` script:

   ```bash
ruby fix_xcode_project.rb -p /path/to/YourProject.xcodeproj
   ```

## Version Management

Update the version in `publish_module_ios.sh` when releasing new versions:

   ```bash
VERSION="1.0.0"  # Change this for each release 