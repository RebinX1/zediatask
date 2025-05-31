# PowerShell script to generate keystore for ZediaTask app
# Run this script from the android directory

# Define variables
$keystorePath = "zediatask.keystore"
$alias = "zediatask"
$keyPassword = "android"  # Change this to your desired password
$storePassword = "android"  # Change this to your desired password

# Check if keystore already exists
if (Test-Path $keystorePath) {
    Write-Host "Keystore already exists at: $keystorePath" -ForegroundColor Yellow
    $confirmation = Read-Host "Do you want to overwrite it? (y/n)"
    if ($confirmation -ne 'y') {
        Write-Host "Operation cancelled." -ForegroundColor Red
        exit
    }
}

Write-Host "Generating keystore file..." -ForegroundColor Cyan

# Generate keystore
$process = Start-Process -FilePath "keytool" -ArgumentList "-genkey", "-v", "-keystore", $keystorePath, "-alias", $alias, "-keyalg", "RSA", "-keysize", "2048", "-validity", "10000", "-storepass", $storePassword, "-keypass", $keyPassword, "-dname", "CN=ZediaTask, OU=Development, O=YourCompany, L=YourCity, S=YourState, C=US" -NoNewWindow -Wait -PassThru

if ($process.ExitCode -eq 0) {
    Write-Host "Keystore generated successfully at: $keystorePath" -ForegroundColor Green
    
    # Set environment variables for the current session
    $env:KEY_PASSWORD = $keyPassword
    $env:STORE_PASSWORD = $storePassword
    
    Write-Host "Environment variables set for the current session:" -ForegroundColor Green
    Write-Host "KEY_PASSWORD=$keyPassword" -ForegroundColor Green
    Write-Host "STORE_PASSWORD=$storePassword" -ForegroundColor Green
    
    Write-Host "You can now run 'flutter build appbundle --release'" -ForegroundColor Cyan
} else {
    Write-Host "Error generating keystore." -ForegroundColor Red
} 