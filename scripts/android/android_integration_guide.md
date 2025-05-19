# Flutter Module Android Integration Guide

This guide explains how to integrate the Flutter module into your Android application.

## IMPORTANT: Dependency Setup

To integrate the Flutter module, you need to use two separate dependencies and ensure the Flutter repository is properly configured:

```gradle
// In settings.gradle
dependencyResolutionManagement {
    repositories {
        google()
        mavenCentral()
        // GitHub Packages for your Flutter module
        maven {
            name = "GitHubPackages"
            url = uri("https://maven.pkg.github.com/YOUR_USERNAME/flutter-module")
            credentials {
                username = 'YOUR_GITHUB_USERNAME' 
                password = 'YOUR_GITHUB_TOKEN'
            }
        }
        // Flutter repository - REQUIRED
        maven {
            url 'https://storage.googleapis.com/download.flutter.io'
        }
    }
}

// In app/build.gradle
dependencies {
    // Your other dependencies...
    implementation 'com.example.flutter_module:flutter_wrapper:1.0.0'
    implementation 'com.example.flutter_module:flutter-release:1.0.0'
}
```

The Flutter repository is essential because the Flutter wrapper depends on Flutter engine libraries.

## Option 1: Using GitHub Packages

### Prerequisites
- Android Studio 4.0+
- Minimum Android API Level 16+
- An existing Android application
- Android Gradle Plugin 4.1+ (this is important for proper AAR handling)

### Setup Process

1. Configure your app's repositories in settings.gradle:
   ```gradle
   dependencyResolutionManagement {
       repositories {
           google()
           mavenCentral()
           
           // GitHub Packages repository
           maven {
               name = "GitHubPackages"
               url = uri("https://maven.pkg.github.com/YOUR_USERNAME/flutter-module")
               credentials {
                   username = 'YOUR_GITHUB_USERNAME'
                   password = 'YOUR_GITHUB_TOKEN'
               }
           }
           
           // Flutter repository - ESSENTIAL
           maven {
               url 'https://storage.googleapis.com/download.flutter.io'
           }
       }
   }
   ```

2. Add the dependencies to your app's build.gradle:
   ```gradle
   dependencies {
       // Your existing dependencies...
       
       // Flutter module components
       implementation 'com.example.flutter_module:flutter_wrapper:1.0.0'
       implementation 'com.example.flutter_module:flutter-release:1.0.0'
   }
   ```

3. Sync your project with Gradle files

### Usage

#### For Regular Activities

```kotlin
import android.os.Bundle
import androidx.appcompat.app.AppCompatActivity
import com.example.flutter_wrapper.FlutterModuleWrapper

class MainActivity : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)
        
        // Find the button to launch Flutter
        findViewById<Button>(R.id.launch_flutter_button).setOnClickListener {
            // Launch Flutter activity using the wrapper
            FlutterModuleWrapper.startFlutterActivity(this)
            
            // Or with a message
            // FlutterModuleWrapper.startFlutterActivity(this, "Hello from Android!")
        }
    }
}
```

#### For Jetpack Compose

```kotlin
import androidx.compose.material.Button
import androidx.compose.material.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.platform.LocalContext
import com.example.flutter_wrapper.FlutterModuleWrapper

@Composable
fun FlutterLaunchButton() {
    val context = LocalContext.current
    
    Button(onClick = {
        FlutterModuleWrapper.startFlutterActivity(context)
    }) {
        Text("Launch Flutter")
    }
}
```

## Option 2: Using Direct AAR Files

If you prefer to not use GitHub Packages, you can use direct AAR files:

1. Download the following AAR files:
   - `flutter-release-1.0.0.aar`: Your Flutter module code
   - `flutter-wrapper-1.0.0.aar`: The wrapper that simplifies Flutter integration
   - `flutter_embedding_release.aar`: Flutter engine embedding
   - `armeabi_v7a_release.aar`: Flutter engine for armeabi-v7a architecture
   - `arm64_v8a_release.aar`: Flutter engine for arm64-v8a architecture
   - `x86_64_release.aar`: Flutter engine for x86_64 architecture

2. Place the AAR files in your app's `libs` directory:
   ```
   app/
     libs/
       flutter-release-1.0.0.aar
       flutter-wrapper-1.0.0.aar
       flutter_embedding_release.aar
       armeabi_v7a_release.aar
       arm64_v8a_release.aar
       x86_64_release.aar
   ```

3. Update your app's `build.gradle` to include the AAR files:
   ```gradle
   dependencies {
       // Your existing dependencies...
       
       // Flutter module
       implementation files('libs/flutter-release-1.0.0.aar')
       implementation files('libs/flutter-wrapper-1.0.0.aar')
       implementation files('libs/flutter_embedding_release.aar')
       implementation files('libs/armeabi_v7a_release.aar')
       implementation files('libs/arm64_v8a_release.aar')
       implementation files('libs/x86_64_release.aar')
   }
   ```

## Communication with Flutter

The FlutterModuleWrapper includes a simple channel-based API for communication:

```kotlin
// Send a message to Flutter
FlutterModuleWrapper.sendMessageToFlutter(context, "Hello from Android!")

// Register a callback to receive messages from Flutter
FlutterModuleWrapper.setMessageCallback { message ->
    Log.d("FlutterModule", "Message from Flutter: $message")
}
```

## Troubleshooting

### Common issues:

1. **Duplicate classes**: Add the following to your app's `build.gradle`:
   ```gradle
   android {
       // Your existing configuration...
       
       packagingOptions {
           exclude 'META-INF/DEPENDENCIES'
           exclude 'META-INF/LICENSE'
           exclude 'META-INF/LICENSE.txt'
           exclude 'META-INF/license.txt'
           exclude 'META-INF/NOTICE'
           exclude 'META-INF/NOTICE.txt'
           exclude 'META-INF/notice.txt'
           exclude 'META-INF/*.kotlin_module'
       }
   }
   ```

2. **AndroidManifest.xml processing errors**: If you encounter errors during resource processing, try these approaches:
   
   **For Groovy build.gradle:**
   ```gradle
   android {
       // In your defaultConfig or at the android level
       manifestPlaceholders = [
           applicationName: "androidx.multidex.MultiDexApplication"
       ]
       
       // Add these packaging options
       packagingOptions {
           resources {
               excludes += ['AndroidManifest.xml']
           }
           exclude 'AndroidManifest.xml'
       }
   }
   ```

   **For Kotlin DSL (build.gradle.kts):**
   ```kotlin
   android {
       defaultConfig {
           manifestPlaceholders["applicationName"] = "androidx.multidex.MultiDexApplication"
       }
       
       packagingOptions {
           resources {
               excludes.add("AndroidManifest.xml")
           }
           resources.excludes.add("AndroidManifest.xml")
       }
   }
   ```
   
   **Alternative Packaging Options:**
   ```gradle
   android {
       packagingOptions {
           pickFirst 'AndroidManifest.xml'
       }
   }
   ```
   
   **Add tools namespace and replace attributes to your app's manifest:**
   
   In your app's AndroidManifest.xml, add the tools namespace and replace attributes:
   ```xml
   <manifest xmlns:android="http://schemas.android.com/apk/res/android"
       xmlns:tools="http://schemas.android.com/tools"
       package="your.app.package">
       
       <application
           android:allowBackup="true"
           tools:replace="android:label"
           android:label="@string/app_name"
           ...>
           ...
       </application>
   </manifest>
   ```

3. **Version conflicts**: If you see version conflicts with libraries like Kotlin or AndroidX, make sure your app uses compatible versions with the Flutter module.

4. **"Could not find io.flutter:flutter_embedding_release" errors**: This error occurs when you're using the Flutter dependencies but haven't added the Flutter repository. Make sure you have added:
   
   ```gradle
   // In settings.gradle
   dependencyResolutionManagement {
       repositories {
           // Your existing repositories...
           maven {
               url 'https://storage.googleapis.com/download.flutter.io'
           }
       }
   }
   ```
   
   You can also download all required Flutter engine AARs manually:
   - flutter_embedding_release.aar
   - armeabi_v7a_release.aar
   - arm64_v8a_release.aar
   - x86_64_release.aar
   
   Place them in your app's libs folder and add them to your dependencies:
   ```gradle
   dependencies {
       implementation files('libs/flutter-release-1.0.0.aar')
       implementation files('libs/flutter-wrapper-1.0.0.aar')
       implementation files('libs/flutter_embedding_release.aar')
       implementation files('libs/armeabi_v7a_release.aar')
       implementation files('libs/arm64_v8a_release.aar')
       implementation files('libs/x86_64_release.aar')
   }
   ```

5. **Multidex issues**: If your app exceeds the method limit, enable multidex:
   ```gradle
   android {
       defaultConfig {
           // Your existing configuration...
           multiDexEnabled true
       }
   }
   dependencies {
       implementation "androidx.multidex:multidex:2.0.1"
   }
   ```

### Still having issues?

Check the [Flutter add-to-app documentation](https://docs.flutter.dev/add-to-app) for more detailed troubleshooting information. 