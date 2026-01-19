# Server Deployment Setup Guide

## Quick Setup for Demo

### Step 1: Find Your Tailscale IP
1. On your server PC, open Tailscale
2. Note your Tailscale IP address (e.g., `100.98.154.101`)

### Step 2: Update Flutter App Configuration

**Option A: Quick Setup (Recommended for Demo)**
1. Open `lib/utils/api_config.dart`
2. Find the line: `const String TAILSCALE_IP = '';`
3. Replace with your Tailscale IP: `const String TAILSCALE_IP = '100.98.154.101';`
4. Save and rebuild the app

**Option B: Build with Environment Variable (No Code Change)**
```bash
flutter run --dart-define=EMR_BASE_URL=https://YOUR_TAILSCALE_IP:7287
```

Or for release build:
```bash
flutter build apk --dart-define=EMR_BASE_URL=https://YOUR_TAILSCALE_IP:7287
```

### Step 3: Start Backend Server

On your server PC:
```bash
cd "App-Security-and-HR/HMIS-Prod"
dotnet run
```

Or specify URLs explicitly:
```bash
dotnet run --urls "https://0.0.0.0:7287;http://0.0.0.0:5287"
```

### Step 4: Configure Firewall (Windows)

Run PowerShell as Administrator:
```powershell
New-NetFirewallRule -DisplayName "HMIS API HTTPS" -Direction Inbound -LocalPort 7287 -Protocol TCP -Action Allow
New-NetFirewallRule -DisplayName "HMIS API HTTP" -Direction Inbound -LocalPort 5287 -Protocol TCP -Action Allow
```

### Step 5: Test Connection

1. Ensure both devices (server PC and phone) are connected to Tailscale
2. From your phone browser, test: `https://YOUR_TAILSCALE_IP:7287/swagger`
3. If it loads, the backend is accessible!

### Step 6: Build and Install App

```bash
cd Patients
flutter clean
flutter pub get
flutter run
```

Or build APK:
```bash
flutter build apk --release
# Install from: build/app/outputs/flutter-apk/app-release.apk
```

## Troubleshooting

### SSL Certificate Errors
- The app is configured to accept self-signed certificates for Tailscale IPs (100.x.x.x range)
- If you still get errors, try using HTTP instead: `http://YOUR_TAILSCALE_IP:5287`

### Connection Timeout
- Verify both devices are on Tailscale network
- Check Windows Firewall allows ports 7287 and 5287
- Verify backend is running and listening on 0.0.0.0 (not just localhost)

### CORS Errors
- Backend is configured to allow requests from Tailscale IPs in development mode
- Check backend logs for CORS request details

## Notes

- The app automatically handles SSL certificate validation for Tailscale IPs
- Both HTTP (port 5287) and HTTPS (port 7287) are supported
- For production, use proper SSL certificates and restrict CORS origins
