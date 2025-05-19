#!/bin/bash

# Exit if any command fails
set -e

echo "===== Creating Distributable iOS Flutter Module Package ====="

# Set up directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="$SCRIPT_DIR/dist/ios_framework"
TEMP_DIR="$SCRIPT_DIR/temp_frameworks"
FRAMEWORKS_DIR="$OUTPUT_DIR/Frameworks"
DIST_ZIP="$SCRIPT_DIR/dist/flutter_module_ios_framework.zip"

# Clean previous build - more thorough cleanup
echo "🧹 Cleaning previous builds..."
rm -rf "$OUTPUT_DIR" "$TEMP_DIR" "$DIST_ZIP"
find "$SCRIPT_DIR/dist" -name "*.zip" -delete
mkdir -p "$OUTPUT_DIR" "$TEMP_DIR" "$FRAMEWORKS_DIR"

# Build the Flutter module framework
echo "🏗️ Building Flutter iOS framework..."
flutter build ios-framework --output="$TEMP_DIR" --no-debug --no-profile

# Print directory structure for debugging
echo "📂 Temporary directory structure:"
find "$TEMP_DIR" -type d | sort

# List all framework files to see what we have
echo "🔍 Framework files found:"
find "$TEMP_DIR" -name "*.framework" -o -name "*.xcframework"

# IMPORTANT: Handle each critical framework specifically to avoid duplicates
echo "⚙️ Processing frameworks to create a deterministic structure..."

# 1. Detect what framework types we have (standard or xcframework)
HAS_XCFRAMEWORKS=false
if find "$TEMP_DIR" -name "*.xcframework" | grep -q .; then
  HAS_XCFRAMEWORKS=true
  echo "✅ Found XCFrameworks - using these for better compatibility"
else
  echo "✅ Using standard frameworks"
fi

# 2. Create a focused list of frameworks to include
FRAMEWORK_SPECS=""

# If we have XCFrameworks, use those preferentially
if [ "$HAS_XCFRAMEWORKS" = true ]; then
  # Process each framework we care about explicitly
  for framework in "App" "Flutter"; do
    XC_PATH=$(find "$TEMP_DIR" -name "${framework}.xcframework" | head -n 1)
    if [ -n "$XC_PATH" ]; then
      echo "Using $framework.xcframework"
      # Extract the filename only
      FILENAME=$(basename "$XC_PATH")
      # Copy to our frameworks directory
      cp -R "$XC_PATH" "$FRAMEWORKS_DIR/"
      
      # Add to our podspec list
      if [ -z "$FRAMEWORK_SPECS" ]; then
        FRAMEWORK_SPECS="'Frameworks/$FILENAME'"
      else
        FRAMEWORK_SPECS="$FRAMEWORK_SPECS, 'Frameworks/$FILENAME'"
      fi
    fi
  done
  
  # Don't include standard frameworks for the same components
  echo "⚠️ Explicitly excluding standard frameworks for components that have XCFrameworks"
else
  # No XCFrameworks, use standard frameworks
  for framework in "App" "Flutter"; do
    STD_PATH=$(find "$TEMP_DIR" -name "${framework}.framework" | head -n 1)
    if [ -n "$STD_PATH" ]; then
      echo "Using $framework.framework"
      # Extract the filename only
      FILENAME=$(basename "$STD_PATH")
      # Copy to our frameworks directory
      cp -R "$STD_PATH" "$FRAMEWORKS_DIR/"
      
      # Add to our podspec list
      if [ -z "$FRAMEWORK_SPECS" ]; then
        FRAMEWORK_SPECS="'Frameworks/$FILENAME'"
      else
        FRAMEWORK_SPECS="$FRAMEWORK_SPECS, 'Frameworks/$FILENAME'"
      fi
    fi
  done
fi

# Check if we found and processed any frameworks
if [ -z "$FRAMEWORK_SPECS" ]; then
  echo "❌ No frameworks were processed. Check Flutter version and build settings."
  exit 1
fi

echo "✅ Processed frameworks successfully"

# Copy the Swift wrapper
echo "Adding Swift wrapper..."
if [ -f "$SCRIPT_DIR/ios_wrapper/FlutterModuleWrapper.swift" ]; then
  cp "$SCRIPT_DIR/ios_wrapper/FlutterModuleWrapper.swift" "$OUTPUT_DIR/"
else
  echo "❌ FlutterModuleWrapper.swift not found. Creating a placeholder..."
  mkdir -p "$SCRIPT_DIR/ios_wrapper"
  cat > "$SCRIPT_DIR/ios_wrapper/FlutterModuleWrapper.swift" << EOF
import UIKit
import Flutter

public class FlutterModuleWrapper {
    public static let shared = FlutterModuleWrapper()
    
    private let engine: FlutterEngine
    private var methodChannel: FlutterMethodChannel?
    
    private init() {
        engine = FlutterEngine(name: "flutter_module_engine")
        engine.run()
        
        // Set up method channel
        let binaryMessenger = engine.binaryMessenger
        methodChannel = FlutterMethodChannel(name: "com.example.flutter_module/channel",
                                                binaryMessenger: binaryMessenger)
            
        methodChannel?.setMethodCallHandler { [weak self] (call, result) in
            if call.method == "messageFromFlutter" {
                if let args = call.arguments as? [String: Any],
                   let message = args["message"] as? String {
                    print("Message from Flutter: \(message)")
                }
                result(nil)
            } else {
                result(FlutterMethodNotImplemented)
            }
        }
    }
    
    public func openFlutterModule(from viewController: UIViewController, message: String? = nil) {
        // Create the FlutterViewController
        let flutterViewController = FlutterViewController(engine: engine, nibName: nil, bundle: nil)
        
        // Send initial message if needed
        if let message = message {
            sendMessageToFlutter(message)
        }
        
        // Present the Flutter view controller
        viewController.present(flutterViewController, animated: true, completion: nil)
    }
    
    public func sendMessageToFlutter(_ message: String) {
        methodChannel?.invokeMethod("messageFromNative", arguments: ["message": message])
    }
}
EOF
  cp "$SCRIPT_DIR/ios_wrapper/FlutterModuleWrapper.swift" "$OUTPUT_DIR/"
fi

# Create the Resources directory
mkdir -p "$OUTPUT_DIR/Resources"

# Create the script for handling build-time framework cleanup (fallback safety) in Resources directory
cat > "$OUTPUT_DIR/Resources/remove_duplicate_frameworks.sh" << 'BASH_SCRIPT'
#!/bin/bash

# Force the script to always exit with a success code
# This is critical to prevent build failures in Xcode
trap "exit 0" EXIT

# Tell bash to not exit on error
set +e

# Improved error handling and debugging
# Function to log messages with timestamp
log_message() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') [Flutter Framework Cleanup] $1"
}

# Log to a file for better debugging
LOG_FILE="/tmp/flutter_framework_cleanup.log"
log_message "Starting cleanup of duplicate Flutter frameworks..." > "$LOG_FILE"
log_message "Running as user: $(whoami)" >> "$LOG_FILE"
log_message "Current directory: $(pwd)" >> "$LOG_FILE"
log_message "Environment variables:" >> "$LOG_FILE"
env | grep -E 'BUILT_|FRAMEWORK|POD' >> "$LOG_FILE" 2>&1

# Get the list of frameworks
FRAMEWORKS_DIR="${BUILT_PRODUCTS_DIR}/${FRAMEWORKS_FOLDER_PATH}"
FRAMEWORKS_TO_CLEAN=("App.framework" "Flutter.framework")

# Default success
SCRIPT_SUCCESS=true

# Log important variables
log_message "BUILT_PRODUCTS_DIR: ${BUILT_PRODUCTS_DIR}" >> "$LOG_FILE"
log_message "FRAMEWORKS_FOLDER_PATH: ${FRAMEWORKS_FOLDER_PATH}" >> "$LOG_FILE"
log_message "FRAMEWORKS_DIR: ${FRAMEWORKS_DIR}" >> "$LOG_FILE"

# Make sure FRAMEWORKS_DIR is set
if [ -z "$FRAMEWORKS_DIR" ]; then
  log_message "Error: FRAMEWORKS_FOLDER_PATH not set in environment. This is required." | tee -a "$LOG_FILE"
  log_message "Will try to find frameworks in predefined locations..." | tee -a "$LOG_FILE"
  
  # Try to find frameworks in common locations
  POSSIBLE_DIRS=(
    "${BUILT_PRODUCTS_DIR}/Frameworks"
    "${PODS_CONFIGURATION_BUILD_DIR}/FlutterModuleFramework/Frameworks"
    "${PODS_ROOT}/FlutterModuleFramework/Frameworks"
  )
  
  for DIR in "${POSSIBLE_DIRS[@]}"; do
    if [ -d "$DIR" ]; then
      log_message "Found potential frameworks directory: $DIR" | tee -a "$LOG_FILE"
      FRAMEWORKS_DIR="$DIR"
      break
    fi
  done
  
  # If still no valid directory, exit safely
  if [ -z "$FRAMEWORKS_DIR" ] || [ ! -d "$FRAMEWORKS_DIR" ]; then
    log_message "Could not find a valid frameworks directory. Exiting safely." | tee -a "$LOG_FILE"
    exit 0
  fi
fi

if [ -d "$FRAMEWORKS_DIR" ]; then
    log_message "Checking frameworks in: $FRAMEWORKS_DIR" | tee -a "$LOG_FILE"
    
    # List all files in frameworks directory for debugging
    log_message "Contents of frameworks directory:" >> "$LOG_FILE"
    ls -la "$FRAMEWORKS_DIR" >> "$LOG_FILE" 2>&1
    
    for FRAMEWORK_NAME in "${FRAMEWORKS_TO_CLEAN[@]}"; do
        log_message "Looking for duplicates of $FRAMEWORK_NAME..." | tee -a "$LOG_FILE"
        
        # Find all copies of this framework - safely
        COPIES=()
        while IFS= read -r path; do
            # Skip empty lines
            [ -z "$path" ] && continue
            # Add to array if it's a directory
            [ -d "$path" ] && COPIES+=("$path")
        done < <(find "$FRAMEWORKS_DIR" -name "$FRAMEWORK_NAME" -type d 2>/dev/null || echo "")
        
        # Log what we found
        log_message "Found ${#COPIES[@]} copies of $FRAMEWORK_NAME" >> "$LOG_FILE"
        for copy in "${COPIES[@]}"; do
            log_message "  - $copy" >> "$LOG_FILE"
        done
        
        # If we have multiple copies, keep only one
        if [ ${#COPIES[@]} -gt 1 ]; then
            log_message "Found ${#COPIES[@]} copies of $FRAMEWORK_NAME" | tee -a "$LOG_FILE"
            
            # Keep the first one, remove the rest
            log_message "Keeping: ${COPIES[0]}" | tee -a "$LOG_FILE"
            for ((i=1; i<${#COPIES[@]}; i++)); do
                log_message "Removing duplicate: ${COPIES[$i]}" | tee -a "$LOG_FILE"
                rm -rf "${COPIES[$i]}" 2>> "$LOG_FILE" || {
                    log_message "Warning: Failed to remove ${COPIES[$i]}. Continuing anyway." | tee -a "$LOG_FILE"
                    SCRIPT_SUCCESS=false
                }
            done
        elif [ ${#COPIES[@]} -eq 1 ]; then
            log_message "✓ Single copy of $FRAMEWORK_NAME found, nothing to clean." | tee -a "$LOG_FILE"
        else
            log_message "⚠️ No copies of $FRAMEWORK_NAME found. This might be normal depending on your configuration." | tee -a "$LOG_FILE"
        fi
    done
else
    log_message "Frameworks directory not found or not yet created: $FRAMEWORKS_DIR" | tee -a "$LOG_FILE"
    log_message "This might be normal during certain build phases." | tee -a "$LOG_FILE"
fi

if [ "$SCRIPT_SUCCESS" = true ]; then
    log_message "✅ Framework cleanup completed successfully." | tee -a "$LOG_FILE"
else
    log_message "⚠️ Framework cleanup completed with warnings (see log at $LOG_FILE)." | tee -a "$LOG_FILE"
fi

# Always exit with success to avoid failing builds
exit 0
BASH_SCRIPT

chmod +x "$OUTPUT_DIR/Resources/remove_duplicate_frameworks.sh"

# Create a placeholder license file if it doesn't exist
if [ ! -f "$OUTPUT_DIR/LICENSE" ]; then
  echo "Creating placeholder LICENSE file..."
  cat > "$OUTPUT_DIR/LICENSE" << EOF
MIT License

Copyright (c) $(date +%Y) Flutter Module Developers

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
EOF
fi

# Create a Podspec file for the framework with explicit framework paths
cat > "$OUTPUT_DIR/FlutterModuleFramework.podspec" << EOF
Pod::Spec.new do |s|
  s.name             = 'FlutterModuleFramework'
  s.version          = '1.0.0'
  s.summary          = 'Pre-compiled Flutter module framework'
  s.description      = <<-DESC
This pod provides a pre-compiled Flutter module framework that can be integrated into iOS apps.
It includes both the Flutter framework and a Swift wrapper for easy integration.
                       DESC
  s.homepage         = 'https://github.com/manhtuan1712/flutter-module'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Flutter Developer' => 'manhtuan1712@gmail.com' }
  s.source           = { :http => 'YOUR_CDN_URL/flutter_module_ios_framework.zip' }
  
  s.ios.deployment_target = '12.0'
  s.swift_version = '5.0'
  
  s.source_files = 'FlutterModuleWrapper.swift'
  
  # We list the specific frameworks explicitly to avoid duplicates
  s.vendored_frameworks = $FRAMEWORK_SPECS
  
  # Settings to fix common issues
  s.pod_target_xcconfig = { 
    'DEFINES_MODULE' => 'YES', 
    'ENABLE_BITCODE' => 'NO',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'arm64'
  }
  
  s.user_target_xcconfig = { 
    'ENABLE_BITCODE' => 'NO',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'arm64'
  }
  
  # Commenting out the script phase to avoid issues with missing script
  # s.script_phase = {
  #   :name => 'Remove Duplicate Flutter Frameworks',
  #   :script => 'bash "${PODS_ROOT}/FlutterModuleFramework/Resources/remove_duplicate_frameworks.sh"',
  #   :execution_position => :before_compile,
  #   :shell_path => '/bin/bash'
  # }
end
EOF

# Create sample Podfile with fixes for the client app
cat > "$OUTPUT_DIR/SamplePodfile" << EOF
platform :ios, '12.0'

target 'YourAppName' do  # Replace with your target name
  use_frameworks!
  
  # Pull the Flutter module from the remote URL
  pod 'FlutterModuleFramework', :podspec => 'https://github.com/YOUR_USERNAME/flutter-module/releases/download/v1.0.0/FlutterModuleFramework.podspec'
  
  # Add this post-install hook to fix potential issues
  post_install do |installer|
    # Apply standard configuration fixes
    installer.pods_project.targets.each do |target|
      target.build_configurations.each do |config|
        # Ensure Flutter compatibility
        config.build_settings['ENABLE_BITCODE'] = 'NO'
        
        # Fix for Apple Silicon simulators
        config.build_settings['EXCLUDED_ARCHS[sdk=iphonesimulator*]'] = 'arm64'
      end
    end
  end
end
EOF

# Create Integration Guide
cat > "$OUTPUT_DIR/REMOTE_INTEGRATION_GUIDE.md" << EOF
# Flutter Module Integration Guide for iOS

This guide shows how to integrate the pre-compiled Flutter module into your iOS app without downloading the Flutter source code.

## Using CocoaPods

Copy this exact Podfile to your iOS project:

\\\`\\\`\\\`ruby
platform :ios, '12.0'

target 'YourAppName' do  # Replace with your target name
  use_frameworks!
  
  # Pull the Flutter module from the remote URL
  pod 'FlutterModuleFramework', :podspec => 'https://github.com/YOUR_USERNAME/flutter-module/releases/download/v1.0.0/FlutterModuleFramework.podspec'
  
  # Add this post-install hook to fix potential issues
  post_install do |installer|
    # Apply standard configuration fixes
    installer.pods_project.targets.each do |target|
      target.build_configurations.each do |config|
        # Ensure Flutter compatibility
        config.build_settings['ENABLE_BITCODE'] = 'NO'
        
        # Fix for Apple Silicon simulators
        config.build_settings['EXCLUDED_ARCHS[sdk=iphonesimulator*]'] = 'arm64'
      end
    end
  end
end
\\\`\\\`\\\`

Then run:

\\\`\\\`\\\`bash
pod install
\\\`\\\`\\\`

If you see any errors during installation, try:
\\\`\\\`\\\`bash
pod repo update
pod install --repo-update
\\\`\\\`\\\`

## Using the Flutter Module

1. Import the module in your Swift file:

\\\`\\\`\\\`swift
import FlutterModuleFramework
import Flutter
\\\`\\\`\\\`

2. Initialize in your AppDelegate:

\\\`\\\`\\\`swift
@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Initialize the Flutter module
        _ = FlutterModuleWrapper.shared
        
        return true
    }
}
\\\`\\\`\\\`

3. Open Flutter UI from any view controller:

\\\`\\\`\\\`swift
FlutterModuleWrapper.shared.openFlutterModule(from: self, message: "Hello from iOS!")
\\\`\\\`\\\`

4. Send messages to Flutter:

\\\`\\\`\\\`swift
FlutterModuleWrapper.shared.sendMessageToFlutter("Message from iOS")
\\\`\\\`\\\`

## For SwiftUI Apps

If you're using SwiftUI, create a UIViewControllerRepresentable:

\\\`\\\`\\\`swift
import SwiftUI
import FlutterModuleFramework
import Flutter

struct FlutterView: UIViewControllerRepresentable {
    var message: String
    
    func makeUIViewController(context: Context) -> UIViewController {
        let hostController = UIViewController()
        FlutterModuleWrapper.shared.openFlutterModule(from: hostController, message: message)
        return hostController
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // Updates happen through the FlutterModuleWrapper
    }
}

// Then use it in your SwiftUI view
struct ContentView: View {
    @State private var showFlutterSheet = false
    
    var body: some View {
        Button("Open Flutter") {
            showFlutterSheet = true
        }
        .sheet(isPresented: $showFlutterSheet) {
            FlutterView(message: "Hello from SwiftUI!")
        }
    }
}
\\\`\\\`\\\`

## Troubleshooting

If you encounter "Multiple commands produce framework" errors:

1. Clean project: In Xcode, select Product > Clean Build Folder
2. If that doesn't work, try:
   \\\`\\\`\\\`bash
   cd /path/to/your/project
   pod deintegrate
   pod cache clean --all
   pod install
   \\\`\\\`\\\`

3. If still having issues, make sure you're using the exact Podfile shown above

For simulator issues on M1/M2 Macs: The post_install hook is already configured to handle this by excluding the arm64 architecture for simulator builds.
EOF

# Create a zip file of the framework
echo "Creating distributable ZIP archive..."
(cd "$OUTPUT_DIR" && zip -r "../flutter_module_ios_framework.zip" .)

# Create example_project directory and a simple Podfile example
mkdir -p "$OUTPUT_DIR/example_project"
cp "$OUTPUT_DIR/SamplePodfile" "$OUTPUT_DIR/example_project/Podfile"

# Clean up temporary files
rm -rf "$TEMP_DIR"

# Verify the package
echo "Verifying package contents..."
unzip -l "$DIST_ZIP" | head -n 20

echo "===== iOS Framework Package Created Successfully ====="
echo ""
echo "✅ Files created:"
echo "  - dist/ios_framework/ (Framework and wrapper files)"
echo "  - dist/flutter_module_ios_framework.zip (Distributable package)"
echo ""
echo "Framework details:"
find "$FRAMEWORKS_DIR" -type d -maxdepth 1 | grep -v "^$FRAMEWORKS_DIR$" | sed 's/^/  - /'
echo ""
echo "Next steps:"
echo "1. Upload the flutter_module_ios_framework.zip to your CDN or file hosting service"
echo "2. Update the podspec URL in FlutterModuleFramework.podspec"
echo "3. Share the podspec URL with iOS developers"
echo ""
echo "iOS developers can integrate your Flutter module using just the podspec URL!"