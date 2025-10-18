# Quick Setup Guide for Point & Shoot

## Prerequisites
- macOS with Xcode 13 or later installed
- iPhone X or newer (required for face tracking)
- iOS 14.0 or later
- Apple Developer Account (for device deployment)

## Step-by-Step Setup

### 1. Open the Project

The project structure has been created. You have two options:

**Option A: Use the existing structure**
```bash
cd /Users/sriram/PointAndShoot
open PointAndShoot.xcodeproj
```

**Option B: Create a fresh Xcode project and copy files**
1. Open Xcode
2. File → New → Project
3. Choose iOS → App
4. Product Name: `PointAndShoot`
5. Interface: SwiftUI
6. Language: Swift
7. Save and create
8. Copy all `.swift` files from the generated structure into your new project

### 2. Verify Project Structure

Your project should have these files in the `PointAndShoot` folder:

```
PointAndShoot/
├── PointAndShootApp.swift          ✓ Main app entry
├── ContentView.swift                ✓ Main UI
├── DataModels.swift                 ✓ Data structures
├── MultipeerManager.swift           ✓ Networking
├── GameState.swift                  ✓ Game logic
├── FaceScanView.swift              ✓ Face scanning
├── ARGameView.swift                 ✓ AR gameplay
├── VisionDetector.swift            ✓ Player detection
├── Info.plist                       ✓ Permissions
└── Assets.xcassets/                 ✓ App resources
```

### 3. Configure Bundle Identifier

1. In Xcode, select the project in the navigator
2. Select the `PointAndShoot` target
3. Go to "Signing & Capabilities"
4. Change Bundle Identifier from `com.yourcompany.PointAndShoot` to your own (e.g., `com.yourname.PointAndShoot`)
5. Select your Team from the dropdown

### 4. Verify Info.plist Permissions

Ensure your Info.plist contains these required keys (already included):
- `NSCameraUsageDescription` - For AR camera access
- `NSLocalNetworkUsageDescription` - For multiplayer
- `NSBonjourServices` - For peer discovery
- `UIRequiredDeviceCapabilities` - ARKit requirement

### 5. Build and Deploy

1. Connect your iPhone via USB
2. Select your device from the device dropdown in Xcode toolbar
3. Click the "Build and Run" button (or press ⌘R)
4. On first run, you may need to trust your developer certificate:
   - On iPhone: Settings → General → VPN & Device Management
   - Tap your certificate and choose "Trust"

### 6. Testing Multiplayer

Since this is a multiplayer game, you'll need at least 2 devices:

1. **Build on Device 1:**
   - Deploy the app to your first iPhone
   - Grant camera and network permissions when prompted
   
2. **Build on Device 2:**
   - Deploy to a second iPhone (or borrow one)
   - Grant permissions
   
3. **Test the Connection:**
   - On Device 1: Launch app → Enter name → Tap "Host Game"
   - On Device 2: Launch app → Enter name → Tap "Join Game"
   - Both devices should connect automatically
   
4. **Scan Faces:**
   - On each device: Tap "Scan Face"
   - Hold still while the progress bar fills
   - Wait for "Scan complete!"
   
5. **Start Game:**
   - Tap "Start Game" on either device
   - Both devices enter AR mode
   
6. **Play:**
   - Point your device at the other player's face
   - When detected, you'll see their name and bounding box
   - Aim the crosshair at their face
   - Tap the red shoot button

## Troubleshooting Common Issues

### Build Errors

**Error: "No such module 'ARKit'"**
- Solution: Ensure deployment target is iOS 14.0+
- Check: Project Settings → Deployment Info → iOS Deployment Target

**Error: "Cannot find type 'ARView' in scope"**
- Solution: Add `import RealityKit` to files (already included)

**Error: "Signing for 'PointAndShoot' requires a development team"**
- Solution: Go to Signing & Capabilities and select your team

### Runtime Issues

**"Face tracking not supported on this device"**
- Cause: Device doesn't have TrueDepth camera
- Solution: Use iPhone X or newer

**Players not connecting**
- Cause: Network permissions not granted or devices on different networks
- Solutions:
  - Grant local network permission when prompted
  - Ensure both devices have WiFi/Bluetooth enabled
  - Try restarting both apps
  - Check firewall settings

**Players not detected in AR**
- Cause: Poor lighting, distance, or angle
- Solutions:
  - Move to well-lit area
  - Stay within 2-3 meters of each other
  - Face each other directly
  - Ensure rear camera isn't obstructed

**App crashes on launch**
- Cause: Permission denied or ARKit not available
- Solutions:
  - Check camera permissions: Settings → Privacy → Camera
  - Verify device supports ARKit (iPhone 6s or newer)
  - Check crash logs in Xcode

## Advanced Configuration

### Adjust Game Balance

Edit `GameState.swift`:
```swift
static let maxHealth = 100           // Starting health (default: 100)
static let damagePerHit = 20         // Damage per hit (default: 20)
static let shootCooldownSeconds = 0.5 // Cooldown time (default: 0.5s)
```

### Improve Performance

Edit `ARGameView.swift` → `Coordinator`:
```swift
private let frameSkip: Int = 3  // Process every Nth frame
```
- Lower value = better detection, worse performance
- Higher value = better performance, detection lag

### Change Network Service Name

Edit `MultipeerManager.swift`:
```swift
private let serviceType = "pointandshoot"  // Must be 1-15 chars, lowercase, letters/numbers/hyphens only
```

## Testing Without Multiple Devices

If you only have one device, you can still test most features:

1. **Lobby & UI**: Works on single device
2. **Face Scanning**: Works on single device
3. **Multiplayer/Detection**: Requires at least 2 devices

Consider using the iOS Simulator for UI testing, but note:
- ARKit doesn't work in Simulator
- MultipeerConnectivity is limited in Simulator

## Project Architecture Summary

### Game Flow
```
App Launch
    ↓
Lobby (enter name, host/join)
    ↓
Face Scan (capture face geometry)
    ↓
AR Game (detect & shoot players)
    ↓
Game Over (show results)
    ↓
Return to Lobby
```

### Key Components

1. **MultipeerManager** (Singleton)
   - Manages all networking
   - Broadcasts/receives game packets
   - Maintains connected players list

2. **GameState** (Observable)
   - Tracks player health
   - Manages detected players
   - Handles game logic & hit registration

3. **FaceScanView**
   - Uses ARFaceTrackingConfiguration
   - Captures face geometry vertices
   - Sends player data over network

4. **ARGameView**
   - Uses ARWorldTrackingConfiguration
   - Displays AR camera feed
   - Shows HUD and shoot button

5. **VisionDetector**
   - Processes camera frames
   - Detects bodies → faces (two-stage)
   - Updates detected players in GameState

## Next Steps

After successful setup:

1. ✅ Test on a single device (lobby, face scan)
2. ✅ Test multiplayer connection with 2 devices
3. ✅ Test gameplay (detection and shooting)
4. 🎨 Customize UI colors and styling
5. 🎮 Adjust game balance parameters
6. 🚀 Add your own features!

## Getting Help

If you encounter issues:

1. Check the main [README.md](README.md) for detailed documentation
2. Review the troubleshooting section above
3. Check Xcode console for error messages
4. Verify all permissions are granted on device
5. Test on newer devices (iPhone 12+ recommended)

## Resources

- [ARKit Documentation](https://developer.apple.com/documentation/arkit)
- [Vision Framework](https://developer.apple.com/documentation/vision)
- [MultipeerConnectivity](https://developer.apple.com/documentation/multipeerconnectivity)
- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui)

---

**Ready to build! 🚀**

Run `open PointAndShoot.xcodeproj` in the terminal to get started.

