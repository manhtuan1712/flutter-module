#!/bin/bash

# Exit on error
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    echo "Flutter is not installed. Please install Flutter and try again."
    exit 1
fi

# Ensure Flutter module is up to date
echo "Ensuring Flutter module is up to date..."
flutter pub get

# Generate the podhelper.rb file if it doesn't exist
if [ ! -f ".ios/Flutter/podhelper.rb" ]; then
    echo "Generating podhelper.rb..."
    # This will create the necessary files in .ios/Flutter/
    flutter build ios-framework --output=build/ios/framework
fi

echo "✅ Flutter module is ready for CocoaPods integration!"
echo ""
echo "==== INTEGRATION INSTRUCTIONS ===="
echo ""
echo "To integrate this Flutter module into your iOS app using CocoaPods:"
echo ""
echo "1. Add the following to your iOS app's Podfile:"
echo ""
echo "   # The Flutter project directory relative to your iOS app"
echo "   flutter_module_path = '../flutter_module'"
echo ""
echo "   load File.join(flutter_module_path, '.ios', 'Flutter', 'podhelper.rb')"
echo ""
echo "   target 'YourAppTarget' do"
echo "     # Your existing pod dependencies"
echo "     # ..."
echo ""
echo "     # Add Flutter module"
echo "     install_all_flutter_pods(flutter_module_path)"
echo "   end"
echo ""
echo "   # This post_install hook ensures Flutter compatible build settings"
echo "   post_install do |installer|"
echo "     flutter_post_install(installer) if defined?(flutter_post_install)"
echo "   end"
echo ""
echo "2. Run 'pod install' in your iOS app directory"
echo ""
echo "3. Import and use Flutter in your app:"
echo ""
echo "   // Swift:"
echo "   import Flutter"
echo "   import FlutterPluginRegistrant"
echo ""
echo "   // Initialize Flutter"
echo "   let flutterEngine = FlutterEngine(name: \"my flutter engine\")"
echo "   flutterEngine.run()"
echo "   GeneratedPluginRegistrant.register(with: flutterEngine)"
echo ""
echo "   // Present Flutter view controller"
echo "   let flutterViewController = FlutterViewController(engine: flutterEngine, nibName: nil, bundle: nil)"
echo "   present(flutterViewController, animated: true, completion: nil)"
echo ""
echo "For more advanced integration options, see the Flutter documentation:"
echo "https://docs.flutter.dev/add-to-app/ios/add-flutter-screen"
echo ""
echo "If you're using our FlutterModuleWrapper, check ios_wrapper/FlutterModuleWrapper.swift"
echo "for convenient methods to integrate Flutter in your iOS app." 