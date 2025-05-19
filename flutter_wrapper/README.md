# Flutter Module Integration

This library provides easy integration with the Flutter module.

## Setup

1. Add the GitHub Packages Maven repository to your project-level `build.gradle`:

```gradle
allprojects {
    repositories {
        // Other repositories...
        maven {
            name = "GitHubPackages"
            url = "https://maven.pkg.github.com/manhtuan1712/flutter-module"
            credentials {
                username = findProperty("gpr.user") ?: System.getenv("GITHUB_USERNAME")
                password = findProperty("gpr.key") ?: System.getenv("GITHUB_TOKEN")
            }
        }
    }
}
```

2. Add the dependency to your app-level `build.gradle`:

```gradle
dependencies {
    // Use the wrapper library for simplified integration
    implementation 'com.example.flutter_module:flutter-wrapper:1.0.0'
    
    // Or use the direct Flutter module (advanced users)
    // implementation 'com.example.flutter_module:flutter_module:1.0.0'
}
```

## Usage

### Simple Integration (Recommended)

```kotlin
import com.example.flutter_wrapper.FlutterModuleWrapper

class MainActivity : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)
        
        findViewById<Button>(R.id.launch_flutter_button).setOnClickListener {
            // Get the Flutter wrapper instance
            val flutterWrapper = FlutterModuleWrapper.getInstance(this)
            
            // Open the Flutter module with an optional message
            flutterWrapper.openFlutterModule(this, "Hello from Android!")
        }
    }
}
```

### Sending Messages to Flutter

```kotlin
// Send a message to Flutter if it's currently visible
FlutterModuleWrapper.getInstance(context).sendMessageToFlutter("Message from Android!")
```

## Need Help?

For more information, visit the [GitHub repository](https://github.com/manhtuan1712/flutter-module). 