# Add project specific ProGuard rules here.
# You can control the set of applied configuration files using the
# proguardFiles setting in build.gradle.
#
# For more details, see
#   http://developer.android.com/guide/developing/tools/proguard.html

# Keep Flutter Wrapper classes
-keep class com.example.flutter_wrapper.** { *; }

# Keep Flutter related classes
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.plugin.** { *; }

# Keep Kotlin related classes
-keep class kotlin.** { *; }
-keep class kotlin.Metadata { *; } 