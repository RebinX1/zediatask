# Manual Keystore Creation Instructions

If you're having trouble with the automated scripts, follow these manual steps:

## 1. Create the keystore file

Open Command Prompt (not PowerShell) and run:

```
cd C:\Users\rawad\Downloads\zediatask-feature-branch
keytool -genkey -v -keystore android/zediatask.keystore -alias zediatask -keyalg RSA -keysize 2048 -validity 10000 -storepass android -keypass android
```

When prompted, enter your details as needed (name, organization, etc.)

## 2. Set environment variables

In the same Command Prompt window:

```
set KEY_PASSWORD=android
set STORE_PASSWORD=android
```

## 3. Build the app

Now run:

```
flutter build appbundle --release
```

## Note

The keystore has been configured with:
- Keystore password: android
- Key alias: zediatask
- Key password: android

For improved security, you should change these in a production environment.

## Verification

To verify your keystore was created correctly:

```
keytool -list -v -keystore android/zediatask.keystore -storepass android
``` 