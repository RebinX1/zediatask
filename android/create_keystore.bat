@echo off
echo ====================================
echo ZediaTask Keystore Creation Tool
echo ====================================
echo.

set KEYSTORE_PATH=zediatask.keystore
set ALIAS=zediatask
set KEY_PASSWORD=android
set STORE_PASSWORD=android

echo Generating keystore file...
echo.

keytool -genkey -v ^
    -keystore %KEYSTORE_PATH% ^
    -alias %ALIAS% ^
    -keyalg RSA ^
    -keysize 2048 ^
    -validity 10000 ^
    -storepass %STORE_PASSWORD% ^
    -keypass %KEY_PASSWORD% ^
    -dname "CN=ZediaTask, OU=Development, O=ZediaSolutions, L=YourCity, S=YourState, C=US"

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo Error generating keystore!
    exit /b 1
)

echo.
echo Keystore generated successfully at: %KEYSTORE_PATH%
echo.

echo Setting environment variables for the current session:
echo.
set KEY_PASSWORD=%KEY_PASSWORD%
set STORE_PASSWORD=%STORE_PASSWORD%
echo KEY_PASSWORD=%KEY_PASSWORD%
echo STORE_PASSWORD=%STORE_PASSWORD%
echo.

echo You can now run: flutter build appbundle --release
echo.

pause 