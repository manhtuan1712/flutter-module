# Publishing Flutter Module to GitHub Packages

This guide will help you publish your Flutter module to GitHub Packages.

## Prerequisites

1. A GitHub account
2. A personal access token with `write:packages` permission
3. Your Flutter module pushed to a GitHub repository

## Setup

1. First, make sure your Flutter module is in a GitHub repository.

2. Edit `flutter_module/android/build.gradle` and update the following placeholders:
   - `REPLACE_WITH_YOUR_USERNAME` - Your GitHub username
   - `REPLACE_WITH_YOUR_REPO` - Your repository name
   - `REPLACE_WITH_YOUR_NAME` - Your name
   - `REPLACE_WITH_YOUR_EMAIL` - Your email

3. Set up environment variables for your GitHub credentials:
   ```bash
   export GITHUB_USERNAME=your_github_username
   export GITHUB_TOKEN=your_personal_access_token
   ```

   Note: On Windows, use:
   ```bash
   set GITHUB_USERNAME=your_github_username
   set GITHUB_TOKEN=your_personal_access_token
   ```

## Publishing

Run the provided script:
```bash
chmod +x ./publish_module.sh  # Make sure the script is executable
./publish_module.sh
```

This will:
1. Build the Flutter module
2. Generate the AAR file
3. Publish the module to GitHub Packages

## Using the Published Module

In your Android project:

1. Add the GitHub Packages repository to your `settings.gradle`:
   ```groovy
   repositories {
       maven {
           name = "GitHubPackages"
           url = "https://maven.pkg.github.com/REPLACE_WITH_YOUR_USERNAME/REPLACE_WITH_YOUR_REPO"
           credentials {
               username = findProperty("gpr.user") ?: System.getenv("GITHUB_USERNAME")
               password = findProperty("gpr.key") ?: System.getenv("GITHUB_TOKEN")
           }
       }
   }
   ```

2. Add the dependency to your app-level `build.gradle`:
   ```groovy
   dependencies {
       implementation 'com.example:flutter_module:1.0.0'
   }
   ```

## Troubleshooting

- **Authentication Issues**: Make sure your GitHub token has the correct permissions.
- **Build Failures**: Check the Gradle output for specific error messages.
- **Access Control**: Ensure the GitHub repository is accessible to users who will consume the package.

For more information, refer to the [GitHub Packages documentation](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-gradle-registry). 