# =====================================================
#   Wi-Fi Direct Legacy Hotspot Switcher
# =====================================================

# ============== EDIT THESE SETTINGS =============
$WANAdapter             = ""
$LANAdapter             = ""

$WANSSID                = ""
$WANPassword            = ""

$LANSSID                = ""
$LANPassword            = ""

$WiFiDirectLegacyAPDemo = ""
# =====================================================

# Ensure we are running as Administrator
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Please run this script as Administrator!" -ForegroundColor Red
    pause
    exit
}

Write-Host "=====================================================" -ForegroundColor Cyan
Write-Host "        Wi-Fi Direct Legacy Hotspot Switcher"          -ForegroundColor Cyan
Write-Host "=====================================================" -ForegroundColor Cyan

# Add SendKeys capability
Add-Type -AssemblyName System.Windows.Forms

# Create temporary Wi-Fi profile
$xml = @"
<?xml version="1.0"?>
<WLANProfile xmlns="http://www.microsoft.com/networking/WLAN/profile/v1">
    <name>$WANSSID</name>
    <SSIDConfig>
        <SSID>
            <name>$WANSSID</name>
        </SSID>
    </SSIDConfig>
    <connectionType>ESS</connectionType>
    <connectionMode>auto</connectionMode>
    <MSM>
        <security>
            <authEncryption>
                <authentication>WPA2PSK</authentication>
                <encryption>AES</encryption>
                <useOneX>false</useOneX>
            </authEncryption>
            <sharedKey>
                <keyType>passPhrase</keyType>
                <protected>false</protected>
                <keyMaterial>$WANPassword</keyMaterial>
            </sharedKey>
        </security>
    </MSM>
</WLANProfile>
"@
$xml | Out-File -FilePath "$env:TEMP\temp_wifi.xml" -Encoding utf8

# ===================== MAIN PROCESS =====================
Write-Host "[1/8] Disabling $WANAdapter ..." -ForegroundColor Green
netsh interface set interface "$WANAdapter" admin=disable | Out-Null

Write-Host "[2/8] Enabling AutoConfig for $LANAdapter ..." -ForegroundColor Green
netsh wlan set autoconfig enabled=yes interface="$LANAdapter" | Out-Null
Restart-Service -Name WlanSvc -Force

Write-Host "[3/8] Connecting $LANAdapter to $WANSSID ..." -ForegroundColor Green
netsh wlan add profile filename="$env:TEMP\temp_wifi.xml" interface="$LANAdapter" | Out-Null
netsh wlan connect name="$WANSSID" interface="$LANAdapter" | Out-Null
while ((Get-NetAdapter -Name $LANAdapter).Status -ne "Up") {
    Start-Sleep -Milliseconds 200
}

Write-Host "[4/8] Launching WiFiDirectLegacyAPDemo.exe ..." -ForegroundColor Green
if (-not (Test-Path $WiFiDirectLegacyAPDemo)) {
    Write-Host "ERROR: $WiFiDirectLegacyAPDemo not found in current folder!" -ForegroundColor Red
    Write-Host "Please place WiFiDirectLegacyAPDemo.exe in the same folder as this script." -ForegroundColor Red
    pause
    exit
}

Start-Process -FilePath $WiFiDirectLegacyAPDemo
Start-Sleep -Milliseconds 200

[System.Windows.Forms.SendKeys]::SendWait("ssid $LANSSID{ENTER}")
Start-Sleep -Milliseconds 200
[System.Windows.Forms.SendKeys]::SendWait("pass $LANPassword{ENTER}")
Start-Sleep -Milliseconds 200
[System.Windows.Forms.SendKeys]::SendWait("start{ENTER}")
while (-not (Get-NetAdapter -InterfaceDescription "Microsoft Wi-Fi Direct Virtual*" | Where-Object { $_.Status -eq 'Up' } | Select-Object -First 1 | Where-Object Status -eq 'Up')) {
    Start-Sleep -Milliseconds 200
}

Write-Host "Hotspot start commands sent." -ForegroundColor Green

Write-Host "[5/8] Disconnecting $LANAdapter..." -ForegroundColor Green
netsh wlan disconnect interface="$LANAdapter" | Out-Null

Write-Host "[6/8] Disabling AutoConfig for $LANAdapter..." -ForegroundColor Green
netsh wlan set autoconfig enabled=no interface="$LANAdapter" | Out-Null

Write-Host "[7/8] Enabling $WANAdapter..." -ForegroundColor Green
netsh interface set interface "$WANAdapter" admin=enable | Out-Null

Write-Host "[8/8] Connecting $WANAdapter to "$WANSSID"..." -ForegroundColor Green
netsh wlan add profile filename="$env:TEMP\temp_wifi.xml" interface="$WANAdapter" | Out-Null
netsh wlan connect name="$WANSSID" interface="$WANAdapter" | Out-Null

# Cleanup
Remove-Item "$env:TEMP\temp_wifi.xml" -Force -ErrorAction SilentlyContinue

Write-Host "Script finished. Hotspot remains running." -ForegroundColor Cyan
Start-Sleep -Seconds 3