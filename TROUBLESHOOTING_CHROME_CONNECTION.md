# Troubleshooting Chrome WebSocket Connection Error

## Error Message
```
Failed to establish connection with the application instance in Chrome.
This can happen if the websocket connection used by the web tooling is unable to correctly establish a connection, for example due to a firewall.
```

## Quick Fixes

### Solution 1: Run with Specific Web Port
```powershell
flutter run -d chrome --web-port=8080
```

### Solution 2: Use HTML Renderer (Lighter, Better Compatibility)
```powershell
flutter run -d chrome --web-renderer html
```

### Solution 3: Use HTML Renderer Instead of CanvasKit
```powershell
flutter run -d chrome --web-renderer html
```

### Solution 4: Combine Multiple Flags
```powershell
flutter run -d chrome --web-port=8080 --web-renderer html
```

## Windows Firewall Configuration

### Allow Flutter Through Firewall
1. Open **Windows Defender Firewall**
2. Click **Allow an app or feature through Windows Defender Firewall**
3. Click **Change Settings** (if needed)
4. Find **Flutter** or **Dart** in the list
5. Check both **Private** and **Public** networks
6. If not found, click **Allow another app** and browse to:
   - `C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe`
   - Or your Flutter installation path

### Allow Chrome Debugging Ports
1. Open **Windows Defender Firewall with Advanced Security**
2. Click **Inbound Rules** → **New Rule**
3. Select **Port** → **Next**
4. Select **TCP** and enter ports: `8080, 9100, 9101, 9102` (or your custom ports)
5. Allow the connection
6. Apply to all profiles (Domain, Private, Public)

## Alternative: Run Without DevTools Connection

If you don't need hot reload or debugging, you can run in release mode:

```powershell
flutter run -d chrome --release
```

## Check Current Flutter Configuration

Run this to see your current Flutter setup:
```powershell
flutter doctor -v
```

## Network-Specific Solutions

### If Using VPN or Corporate Network
- Disconnect VPN temporarily to test
- Add Flutter/Chrome to VPN exceptions
- Contact IT to whitelist localhost connections

### If Using Antivirus
- Temporarily disable antivirus to test
- Add Flutter and Chrome to antivirus exceptions
- Whitelist localhost connections in antivirus settings

## Verify Chrome Can Connect

Test if Chrome can access localhost:
1. Open Chrome
2. Navigate to `http://localhost:8080` (or your configured port)
3. If it works, the issue is specifically with the websocket connection

## Environment Variables

You can also set these environment variables before running:

```powershell
$env:FLUTTER_WEB_USE_SKIA="false"
flutter run -d chrome
```

## Still Having Issues?

1. **Restart Chrome completely** (close all instances)
2. **Clear Flutter build cache**:
   ```powershell
   flutter clean
   flutter pub get
   ```
3. **Try a different browser** (Edge, Firefox):
   ```powershell
   flutter run -d edge
   ```
4. **Check if another process is using the port**:
   ```powershell
   netstat -ano | findstr :8080
   ```

