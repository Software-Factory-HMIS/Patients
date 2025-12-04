# Troubleshooting Flutter DevTools Connection Error

## Error Message
```
SocketException: The remote computer refused the network connection.
(OS Error: The remote computer refused the network connection.
, errno = 1225), address = localhost, port = 57142
```

## What This Means

Port **57142** is used by **Flutter DevTools** and the **Dart VM Service** for:
- Hot reload connections
- Debugging connections
- Performance profiling
- Widget inspector

This is **NOT** related to your API connection (port 7287).

## Quick Fixes

### Solution 1: Restart Flutter App
The DevTools service might not have started properly. Try:
```powershell
# Stop the current app (Ctrl+C)
# Then restart
flutter run
```

### Solution 2: Check if Port is Already in Use
```powershell
netstat -ano | findstr :57142
```
If another process is using the port, kill it or restart your computer.

### Solution 3: Clear Flutter Build Cache
```powershell
flutter clean
flutter pub get
flutter run
```

### Solution 4: Allow Flutter Through Windows Firewall

1. **Open Windows Defender Firewall**
2. Click **Allow an app or feature through Windows Defender Firewall**
3. Click **Change Settings** (if needed)
4. Find **Flutter** or **Dart** in the list
5. Check both **Private** and **Public** networks
6. If not found, click **Allow another app** and browse to:
   - `C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe`
   - Or your Flutter installation path

### Solution 5: Allow DevTools Ports Through Firewall

1. Open **Windows Defender Firewall with Advanced Security**
2. Click **Inbound Rules** → **New Rule**
3. Select **Port** → **Next**
4. Select **TCP** and enter ports: `57142, 9100, 9101, 9102` (common DevTools ports)
5. Allow the connection
6. Apply to all profiles (Domain, Private, Public)

### Solution 6: Run Without DevTools (Release Mode)

If you don't need hot reload or debugging:
```powershell
flutter run --release
```

### Solution 7: Use Specific Device

Sometimes specifying the device helps:
```powershell
# List available devices
flutter devices

# Run on specific device
flutter run -d <device-id>
```

## Check What's Using the Port

```powershell
# Find process using port 57142
netstat -ano | findstr :57142

# Kill the process (replace PID with actual process ID)
taskkill /PID <PID> /F
```

## Verify Flutter Installation

```powershell
flutter doctor -v
```

Make sure all components are properly installed.

## Network-Specific Solutions

### If Using VPN
- Disconnect VPN temporarily to test
- Add Flutter/Dart to VPN exceptions
- Contact IT to whitelist localhost connections

### If Using Antivirus
- Temporarily disable antivirus to test
- Add Flutter and Dart to antivirus exceptions
- Whitelist localhost connections in antivirus settings

### Corporate Network
- Contact IT to allow localhost connections
- May need to use a different port range
- Check if proxy is interfering

## Alternative: Use VS Code/Android Studio

Instead of command line, try running from:
- **VS Code**: Press F5 or use Run menu
- **Android Studio**: Click the Run button

These IDEs often handle DevTools connections better.

## If Firewall is Already Off

If you've turned off the firewall completely and still get connection refused errors:

### Check Antivirus/Other Security Software
- **Windows Defender**: May still block even if firewall is off
- **Third-party antivirus**: Check if it has network protection enabled
- **Corporate security software**: May have additional network restrictions

### Verify Flutter Installation
```powershell
flutter doctor -v
```
Make sure all components show green checkmarks.

### Try Running in Profile Mode
```powershell
flutter run --profile
```

### Disable DevTools Completely
If you don't need DevTools, you can disable it:
```powershell
flutter run --no-devtools
```

### Check if App is Actually Running
The error might mean the app crashed before DevTools could connect. Check:
- Is the app visible on your device/emulator?
- Are there any error messages in the console?
- Does the app function normally despite the error?

### Reset Flutter Tooling
```powershell
# Kill all Flutter processes
taskkill /F /IM dart.exe
taskkill /F /IM flutter.exe

# Clear cache
flutter clean
flutter pub get

# Restart
flutter run
```

### Check Flutter Version
```powershell
flutter --version
```
Try updating to the latest stable version:
```powershell
flutter upgrade
```

## Still Having Issues?

1. **Restart your computer** (clears all port bindings)
2. **Check Windows Event Viewer** for security blocks
3. **Try a different Flutter channel**:
   ```powershell
   flutter channel stable
   flutter upgrade
   ```
4. **Reinstall Flutter** (last resort)
5. **Run without DevTools**: The app will work fine, you just won't have hot reload

## Note

This error does **NOT** affect:
- ✅ Your API connections (port 7287)
- ✅ App functionality
- ✅ App deployment

It only affects:
- ❌ Hot reload
- ❌ Debugging tools
- ❌ DevTools performance profiling

You can still use the app normally, just without hot reload.

