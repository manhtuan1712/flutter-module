# Flutter Module iOS Integration with CocoaPods

This guide explains how to integrate this Flutter module into an iOS app using CocoaPods.

## Prerequisites

- Xcode 14.0+
- CocoaPods 1.10.0+
- iOS project with minimum iOS version 12.0+
- This Flutter module

## Setup Process

### 1. Run the setup script

Run the `setup_cocoapods.sh` script in this module:

```bash
./setup_cocoapods.sh
```

This script ensures the Flutter module is ready for CocoaPods integration.

### 2. Configure your iOS app's Podfile

Add the following to your iOS app's Podfile (see `Podfile.template` for a complete example):

```ruby
# Path to the Flutter module relative to this Podfile
flutter_module_path = '../flutter_module'

# Load Flutter module podhelper
load File.join(flutter_module_path, '.ios', 'Flutter', 'podhelper.rb')

target 'YourApp' do
  # Other dependencies...

  # Install Flutter pods
  install_all_flutter_pods(flutter_module_path)
end

# This post-install hook ensures Flutter compatible build settings
post_install do |installer|
  flutter_post_install(installer) if defined?(flutter_post_install)
end
```

### 3. Install the pods

Run the following in your iOS app directory:

```bash
pod install
```

### 4. Open the .xcworkspace file

After running `pod install`, open your app's `.xcworkspace` file in Xcode:

```bash
open YourApp.xcworkspace
```

## Usage Options

You have two options for integrating the Flutter module:

### Option 1: Use FlutterModuleWrapper (recommended)

The `FlutterModuleWrapper` class provides a simple API for integrating Flutter into your iOS app. See `ios_wrapper/FlutterModuleUsage.swift.example` for a complete example.

```swift
import UIKit

class YourViewController: UIViewController {
    private let flutterWrapper = FlutterModuleWrapper.shared
    
    @IBAction func showFlutter(_ sender: UIButton) {
        flutterWrapper.openFlutterModule(from: self, message: "Hello from iOS!")
    }
}
```

### Option 2: Direct Flutter Engine Integration

You can also manage the Flutter engine yourself:

```swift
import Flutter
import FlutterPluginRegistrant

class YourViewController: UIViewController {
    // Initialize and run the Flutter engine
    private lazy var flutterEngine: FlutterEngine = {
        let engine = FlutterEngine(name: "my_engine")
        engine.run()
        GeneratedPluginRegistrant.register(with: engine)
        return engine
    }()
    
    @IBAction func showFlutter(_ sender: UIButton) {
        let flutterViewController = FlutterViewController(engine: flutterEngine, nibName: nil, bundle: nil)
        present(flutterViewController, animated: true)
    }
}
```

## Troubleshooting

### Common issues:

1. **Module not found errors**: Make sure the path to the Flutter module in your Podfile is correct.

2. **Undefined symbols for architecture arm64**: This usually happens when there's a mismatch between Debug/Release configurations. Make sure you're building both the Flutter module and your iOS app with the same configuration.

3. **Bitcode issues**: If you encounter Bitcode errors, add `ENABLE_BITCODE=NO` to your project's build settings.

### Still having issues?

Check the [Flutter add-to-app documentation](https://docs.flutter.dev/add-to-app/ios/project-setup) for more detailed troubleshooting information. 