# Publishing Flutter Module to Maven Repositories

This guide explains how to publish your Flutter module to various Maven repositories.

## Local Maven Repository

The simplest way to publish your Flutter module is to a local Maven repository:

1. Run the included script:
   ```bash
   ./publish_module.sh
   ```

2. The module will be published to: `flutter_module/android/build/repo/`

3. In the consuming Android project, add this repository to `settings.gradle`:
   ```groovy
   repositories {
       maven { url 'file:///path/to/flutter_module/android/build/repo' }
   }
   ```

4. In your app's `build.gradle`, add the dependency:
   ```groovy
   dependencies {
       implementation 'com.example:flutter_module:1.0.0'
   }
   ```

## GitHub Packages

To publish to GitHub Packages:

1. Open `flutter_module/android/build.gradle` and uncomment the GitHub Packages repository section.

2. Set up environment variables for your GitHub credentials:
   ```bash
   export GITHUB_USERNAME=your_username
   export GITHUB_TOKEN=your_personal_access_token
   ```

3. Run the publish command:
   ```bash
   cd flutter_module/android
   ./gradlew publishFlutterModulePublicationToGitHubPackagesRepository
   ```

4. In the consuming project's `settings.gradle`, add:
   ```groovy
   repositories {
       maven {
           name = "GitHubPackages"
           url = "https://maven.pkg.github.com/yourusername/flutter_module"
           credentials {
               username = findProperty("gpr.user") ?: System.getenv("GITHUB_USERNAME")
               password = findProperty("gpr.key") ?: System.getenv("GITHUB_TOKEN")
           }
       }
   }
   ```

## Maven Central

To publish to Maven Central:

1. Create a Sonatype OSSRH account if you don't have one.

2. Add the required plugins to `flutter_module/android/build.gradle`:
   ```groovy
   apply plugin: 'signing'
   ```

3. Add the signing configuration:
   ```groovy
   signing {
       sign publishing.publications.flutterModule
   }
   ```

4. Add the Maven Central repository:
   ```groovy
   repositories {
       maven {
           name = "OSSRH"
           url = "https://s01.oss.sonatype.org/service/local/staging/deploy/maven2/"
           credentials {
               username = System.getenv("OSSRH_USERNAME")
               password = System.getenv("OSSRH_PASSWORD")
           }
       }
   }
   ```

5. Set up environment variables:
   ```bash
   export OSSRH_USERNAME=your_sonatype_username
   export OSSRH_PASSWORD=your_sonatype_password
   ```

6. Run the publish command:
   ```bash
   cd flutter_module/android
   ./gradlew publishFlutterModulePublicationToOSSRHRepository
   ```

## JitPack

JitPack makes publishing much easier:

1. Push your Flutter module to GitHub.

2. Make sure the root `build.gradle` includes JitPack's repository:
   ```groovy
   repositories {
       maven { url 'https://jitpack.io' }
   }
   ```

3. Tag a release in your GitHub repository.

4. JitPack will build the module when first requested.

5. In the consuming project, add JitPack to `settings.gradle`:
   ```groovy
   repositories {
       maven { url 'https://jitpack.io' }
   }
   ```

6. Add the dependency:
   ```groovy
   dependencies {
       implementation 'com.github.yourusername:flutter_module:tag'
   }
   ```

## Versioning

When updating your Flutter module, remember to increment the version in `android/build.gradle`:

```groovy
group = 'com.example'
version = '1.0.0' // Increment this for new releases
``` 