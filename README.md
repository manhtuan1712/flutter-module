# Flutter Module Framework

This repository provides a clean, easy-to-integrate Flutter module that can be embedded in native iOS applications without requiring Flutter development environment setup on the iOS developer's machine.

## Overview

The repository contains the following key components:

- **Flutter Module**: The core Flutter application
- **iOS Framework Generator**: Creates a compiled iOS framework that can be easily integrated via CocoaPods
- **Xcode Project Fixer**: Utility to fix duplicate framework references in Xcode projects

## Key Files

- `create_ios_framework.sh`: Builds and packages the Flutter module for iOS integration
- `publish_module_ios.sh`: Publishes the iOS framework to GitHub releases
- `fix_xcode_project.rb`: Ruby utility to fix duplicate framework issues in Xcode projects

## Usage for iOS Teams

iOS developers can integrate the Flutter module by adding this to their Podfile:

```ruby
pod 'FlutterModuleFramework', :podspec => 'https://github.com/{USERNAME}/flutter-module/releases/download/v1.0.0/FlutterModuleFramework.podspec'
```

No Flutter environment setup is required. The module is pre-compiled and ready to use.

## Usage for Flutter Teams

To build and publish a new version of the iOS framework:

1. Make your changes to the Flutter module
2. Set your GitHub credentials:
   ```
   export GITHUB_USERNAME=your_github_username
   export GITHUB_TOKEN=your_github_personal_access_token
   ```
3. Run the publish script:
   ```
   ./publish_module_ios.sh
   ```

## Troubleshooting

If you encounter duplicate framework issues in your Xcode project, use the `fix_xcode_project.rb` script:

```
ruby fix_xcode_project.rb -p /path/to/your/project.xcodeproj
```
