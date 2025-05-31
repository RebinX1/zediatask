# ZediaTask App Signing Guide

This document outlines the steps needed to sign the ZediaTask app for release to the Google Play Store.

## Quick Start (Windows)

We've created a PowerShell script to make the signing process easier:

1. Navigate to the android directory:
   ```powershell
   cd android
   ```

2. Run the PowerShell script:
   ```powershell
   .\create_keystore.ps1
   ```

3. Build the app bundle:
   ```powershell
   flutter build appbundle --release
   ```

The script will:
- Create a keystore file with default passwords
- Set the environment variables automatically
- Provide instructions for building the app

## Manual Method

If you prefer to do it manually, follow these steps:

### Generating the Keystore

A keystore file is required to sign your Android app. If you haven't created one yet, use the following command:

```bash
keytool -genkey -v -keystore zediatask.keystore -alias zediatask -keyalg RSA -keysize 2048 -validity 10000
```

When prompted:
1. Enter a password for the keystore
2. Provide information about your organization
3. Confirm the information is correct

Save the keystore file (`zediatask.keystore`) in the `android/` directory.

### Setting Environment Variables

For security, you should set environment variables for your keystore password rather than hardcoding them:

For Windows (PowerShell):
```powershell
$env:KEY_PASSWORD="your_key_password"
$env:STORE_PASSWORD="your_store_password"
```

For macOS/Linux:
```bash
export KEY_PASSWORD="your_key_password"
export STORE_PASSWORD="your_store_password"
```

## Building the App for Release

To build a signed APK:

```bash
flutter build apk --release
```

To build an Android App Bundle for the Play Store (recommended):

```bash
flutter build appbundle --release
```

The output file will be located at:
- APK: `build/app/outputs/flutter-apk/app-release.apk`
- AAB: `build/app/outputs/bundle/release/app-release.aab`

## Troubleshooting

### Package Name
The app now uses the package name `com.zediasolutions.zediatask` instead of the restricted `com.example.zediatask`.

### Play Core Libraries
We've updated the Play Core libraries to be compatible with SDK 34 (Android 14). The app now uses:

```gradle
dependencies {
    // Other dependencies
    implementation 'com.google.android.play:app-update:2.1.0'
    implementation 'com.google.android.play:app-update-ktx:2.1.0'
    implementation 'com.google.android.play:integrity:1.3.0'
}
```

If you run into issues with the Flutter engine unable to find Play Core classes, you may need to update any code that references the old Play Core API.

## Important Notes

1. **KEEP YOUR KEYSTORE SAFE**: If you lose your keystore, you cannot update your app on the Play Store.
2. **BACKUP YOUR KEYSTORE**: Store a backup of the keystore file and password in a secure location.
3. **DO NOT COMMIT KEYSTORE TO VERSION CONTROL**: Add the keystore file to your `.gitignore` to prevent it from being committed.

## Play Store Preparation

1. Create a developer account on the Google Play Console
2. Create a new application and fill in all required metadata
3. Upload your signed AAB file
4. Complete the store listing information and screenshots
5. Set up pricing and distribution
6. Submit for review

## Testing Before Release

Always test your signed APK/AAB before uploading to the Play Store:

```bash
flutter install --release
```

This will install the release version on a connected device for testing. 