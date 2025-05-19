@echo off
echo ===================================================
echo ZediaTask Android Release Build Script
echo ===================================================
echo.

:: Check if keystore exists
if not exist "android\zediatask.keystore" (
    echo Keystore not found. Creating keystore...
    echo.
    
    :: Create the keystore
    keytool -genkey -v ^
        -keystore android\zediatask.keystore ^
        -alias zediatask ^
        -keyalg RSA ^
        -keysize 2048 ^
        -validity 10000 ^
        -storepass android ^
        -keypass android ^
        -dname "CN=ZediaTask, OU=Development, O=ZediaSolutions, L=YourCity, S=YourState, C=US"
    
    if %ERRORLEVEL% NEQ 0 (
        echo.
        echo Error creating keystore!
        pause
        exit /b 1
    )
    
    echo.
    echo Keystore created successfully.
    echo.
) else (
    echo Keystore found at android\zediatask.keystore
    echo.
)

:: Set environment variables
set KEY_PASSWORD=android
set STORE_PASSWORD=android

echo Building release App Bundle...
echo.

:: Clean the project first
call flutter clean

echo.
echo Running flutter pub get...
echo.
call flutter pub get

echo.
echo Building app bundle...
echo.
call flutter build appbundle --release

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo Build failed! See errors above.
    echo.
    pause
    exit /b 1
)

echo.
echo App Bundle built successfully!
echo.
echo You can find the release bundle at:
echo build\app\outputs\bundle\release\app-release.aab
echo.
echo This file can be uploaded to the Google Play Store.
echo.

pause 