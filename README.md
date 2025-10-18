# Point & Shoot - AR Multiplayer Face Battle

An innovative AR multiplayer game for iOS that uses face detection and tracking to create an immersive shooting experience.

## Overview

Point & Shoot is an iPhone AR game where players:
1. Scan their faces to create a profile
2. Connect with nearby players using local networking
3. Detect and shoot at each other in real-time using AR

## Features

- **Face Scanning**: Uses ARKit's face tracking to capture player face geometry
- **Local Multiplayer**: Peer-to-peer networking using MultipeerConnectivity
- **Real-time Detection**: Computer Vision framework detects players in the camera view
- **AR Gameplay**: Shoot at detected players with visual feedback and health tracking
- **Modern UI**: Built with SwiftUI for a clean, responsive interface

## Technical Stack

- **UI Framework**: SwiftUI
- **AR Framework**: ARKit (ARFaceTrackingConfiguration, ARWorldTrackingConfiguration)
- **Computer Vision**: Vision (VNDetectHumanBodyPoseRequest, VNDetectFaceRectanglesRequest)
- **Networking**: MultipeerConnectivity
- **Platform**: iOS 14.0+

## Requirements

- iPhone X or newer (required for ARFaceTrackingConfiguration)
- iOS 14.0 or later
- Two or more devices for multiplayer testing

## Project Structure

```
PointAndShoot/
├── PointAndShootApp.swift          # App entry point
├── ContentView.swift                # Main view with game state management
├── DataModels.swift                 # Player and GamePacket data models
├── MultipeerManager.swift           # Networking singleton
├── GameState.swift                  # Game state and health management
├── FaceScanView.swift              # Face scanning AR view
├── ARGameView.swift                 # Main game AR view with HUD
├── VisionDetector.swift            # Vision framework player detection
└── Info.plist                       # Required permissions
```

## Setup Instructions

### 1. Open Project in Xcode

1. Open Xcode 13 or later
2. Select "Create a new Xcode project"
3. Choose "iOS" → "App" template
4. Product Name: `PointAndShoot`
5. Interface: SwiftUI
6. Language: Swift
7. Save the project

### 2. Add Project Files

Copy all the Swift files from this repository into your Xcode project:
- PointAndShootApp.swift
- ContentView.swift
- DataModels.swift
- MultipeerManager.swift
- GameState.swift
- FaceScanView.swift
- ARGameView.swift
- VisionDetector.swift

### 3. Configure Info.plist

Replace the default Info.plist with the provided one, or add these keys manually:

```xml
<key>NSCameraUsageDescription</key>
<string>This app requires camera access for AR face scanning and gameplay.</string>

<key>NSLocalNetworkUsageDescription</key>
<string>This app uses local network to connect with nearby players for multiplayer gameplay.</string>

<key>NSBonjourServices</key>
<array>
    <string>_pointandshoot._tcp</string>
    <string>_pointandshoot._udp</string>
</array>

<key>UIRequiredDeviceCapabilities</key>
<array>
    <string>armv7</string>
    <string>arkit</string>
</array>
```

### 4. Configure Signing & Capabilities

1. Select your project in Xcode
2. Go to "Signing & Capabilities"
3. Select your development team
4. Ensure "Automatically manage signing" is checked

### 5. Build and Run

1. Connect your iPhone (X or newer)
2. Select your device as the build target
3. Click "Run" (⌘R)
4. Accept camera and network permissions when prompted

## How to Play

### Starting the Game

1. **Enter Your Name**: When the app launches, enter your player name
2. **Choose Role**:
   - **Host Game**: Tap to create a game session and wait for others
   - **Join Game**: Tap to search for and connect to a nearby game
3. **Scan Your Face**: Once connected, tap "Scan Face" to capture your face geometry
4. **Start Game**: After scanning, tap "Start Game" to begin

### Gameplay

1. **Position**: Hold your phone in portrait orientation
2. **Detect**: The game will automatically detect other players' faces when visible
3. **Aim**: Point your device at an opponent's face
4. **Shoot**: Tap the red shoot button when the crosshair is over an opponent
5. **Win**: Be the last player standing!

## Architecture Details

### Game Flow

```
Lobby → Face Scan → In Game → Game Over
```

### Networking Flow

1. Host advertises game using MCNearbyServiceAdvertiser
2. Client browses and auto-connects using MCNearbyServiceBrowser
3. Players exchange `.playerData` packets with face geometry
4. During game, `.playerHit` packets are sent when shooting
5. Health is synchronized via `.playerHealthUpdate` packets

### AR Detection Pipeline

1. **ARSession** captures camera frames (CVPixelBuffer)
2. **VNDetectHumanBodyPoseRequest** finds all human bodies (efficient at distance)
3. **VNDetectFaceRectanglesRequest** detects faces within body bounding boxes
4. Detected faces are matched to connected players
5. Bounding boxes are drawn with player names and health bars

### Shooting Mechanics

1. Player taps shoot button
2. Check if screen center (crosshair) intersects any detected face rectangle
3. If hit detected:
   - Send `.playerHit` packet to network
   - Apply damage locally
   - Provide haptic feedback
4. If miss: light haptic feedback

## Key Implementation Details

### Face Scanning (ARFaceTrackingConfiguration)

- Uses front-facing TrueDepth camera
- Captures 3D face geometry vertices
- Stores vertices as `[SIMD3<Float>]` for network transmission
- Progresses over 3 seconds for stability

### World Tracking (ARWorldTrackingConfiguration)

- Uses rear camera for gameplay
- Enables plane detection for raycasting
- Processes every 3rd frame for performance

### Vision Detection Optimization

Two-stage detection improves performance:
1. **Body Detection** (fast): Broad search for humans
2. **Face Detection** (precise): Limited to body regions only

This approach:
- Works at longer distances than face-only detection
- Reduces false positives
- Improves frame rate

### Player Identification

**Current Implementation** (Simple):
- Associates detected faces with players by index order
- Works for controlled multiplayer scenarios

**Production Implementation** (Suggested):
- Compare Vision face landmarks with stored `faceGeometry`
- Use feature matching algorithms (e.g., cosine similarity)
- Implement confidence thresholds

## Customization

### Adjust Game Parameters

In `GameState.swift`:
```swift
static let maxHealth = 100           // Starting health
static let damagePerHit = 20         // Damage per successful hit
static let shootCooldownSeconds = 0.5 // Time between shots
```

### Adjust Detection Performance

In `ARGameView.swift` → `Coordinator`:
```swift
private let frameSkip: Int = 3  // Higher = better performance, lower accuracy
```

## Troubleshooting

### Face Tracking Not Working
- Ensure you're using iPhone X or newer
- Check that TrueDepth camera is not obstructed
- Verify camera permissions are granted

### Players Not Connecting
- Ensure both devices are on same WiFi network or have WiFi/Bluetooth enabled
- Check that local network permissions are granted
- Try restarting the app on both devices

### Players Not Detected in Game
- Ensure sufficient lighting
- Move closer to opponent (within 2-3 meters works best)
- Face the opponent's face directly
- Check that rear camera is not obstructed

### Poor Performance
- Close background apps
- Reduce `frameSkip` value
- Test on newer iPhone models (iPhone 12 or later recommended)

## Known Limitations

1. **Face Matching**: Current implementation uses simple index-based matching rather than sophisticated feature comparison
2. **Distance**: Detection works best within 2-3 meters
3. **Lighting**: Requires adequate lighting for Vision framework
4. **Occlusion**: Partially hidden faces may not be detected
5. **Device Support**: Requires iPhone X or newer for face scanning

## Future Enhancements

- [ ] Sophisticated face matching using stored geometry
- [ ] Multiple game modes (team battles, capture the flag)
- [ ] Power-ups and special abilities
- [ ] 3D visualization of face meshes in AR
- [ ] Game statistics and leaderboards
- [ ] Sound effects and music
- [ ] Internet multiplayer (beyond local network)
- [ ] iPad support with alternate scanning methods

## License

This project is provided as-is for educational and demonstration purposes.

## Credits

Created as a demonstration of ARKit, Vision, and MultipeerConnectivity frameworks on iOS.

---

**Have fun playing Point & Shoot! 🎯**

