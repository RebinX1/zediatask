# Create the keystore
$keystorePath = "android/zediatask.keystore"
$alias = "zediatask"
$storepass = "android"
$keypass = "android"
$dname = "CN=ZediaTask, OU=Development, O=ZediaSolutions, L=YourCity, S=YourState, C=US"

Write-Host "Creating keystore at $keystorePath..." -ForegroundColor Cyan

# Run keytool command
& keytool -genkey -v -keystore $keystorePath -alias $alias -keyalg RSA -keysize 2048 -validity 10000 -storepass $storepass -keypass $keypass -dname $dname

# Check if keystore was created
if (Test-Path $keystorePath) {
    Write-Host "Keystore created successfully at $keystorePath" -ForegroundColor Green
    
    # Set environment variables
    $env:KEY_PASSWORD = $keypass
    $env:STORE_PASSWORD = $storepass
    
    Write-Host "Environment variables set:" -ForegroundColor Yellow
    Write-Host "KEY_PASSWORD=$keypass" -ForegroundColor Yellow
    Write-Host "STORE_PASSWORD=$storepass" -ForegroundColor Yellow
    
    Write-Host "Next, run: flutter clean && flutter build appbundle --release" -ForegroundColor Cyan
} else {
    Write-Host "Failed to create keystore" -ForegroundColor Red
} 