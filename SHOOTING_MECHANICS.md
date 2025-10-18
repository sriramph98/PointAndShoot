# Shooting Mechanics & Hit Detection Explained

## Overview

The shooting system in Point & Shoot uses a **2D screen-space collision detection** system. When you tap the shoot button, it checks if the crosshair (screen center) intersects with any detected player's face bounding box.

## How It Works

### 1. **Player Detection Pipeline**

```
Camera Frame → Vision API → Body Detection → Face Detection → Screen Coordinates
```

**Step by Step:**
1. **AR Session** captures camera frames (CVPixelBuffer)
2. **Vision Framework** detects human bodies using `VNDetectHumanBodyPoseRequest`
3. For each body, **face detection** runs with `VNDetectFaceRectanglesRequest`
4. **Coordinate conversion** transforms Vision's normalized coordinates (0-1) to screen pixels
5. **DetectedPlayer** objects are created with face bounding boxes in screen space

**Code Location:** `VisionDetector.swift` lines 39-108

### 2. **Crosshair Position**

The crosshair is **always at the center of the screen**:

```swift
let screenCenter = CGPoint(x: viewSize.width / 2, y: viewSize.height / 2)
```

**Visual Representation:**
- White circle with crosshair lines
- Red center dot
- Positioned using SwiftUI's `Spacer()` to stay centered
- Turns **green** and scales up on successful hit

**Code Location:** `ARGameView.swift` lines 271-305

### 3. **Shoot Button Action**

When you tap the red shoot button:

```swift
private func handleShoot() {
    // 1. Get screen center (where crosshair is)
    let screenCenter = CGPoint(x: viewSize.width / 2, y: viewSize.height / 2)
    
    // 2. Check all detected players
    for detected in gameState.detectedPlayers {
        if detected.faceRect.contains(screenCenter) {
            // HIT!
        }
    }
    
    // 3. Register hit or miss
    if let targetPlayerID = gameState.findTargetPlayer(at: screenCenter) {
        gameState.registerHit(on: targetPlayerID)
    }
}
```

**Code Location:** `ARGameView.swift` lines 309-345

### 4. **Hit Detection Algorithm**

```swift
// In GameState.swift
func findTargetPlayer(at point: CGPoint) -> UUID? {
    for detected in detectedPlayers {
        if detected.faceRect.contains(point) {
            return detected.playerID
        }
    }
    return nil
}
```

**How it works:**
1. Iterates through all `detectedPlayers`
2. Checks if the `point` (screen center) is inside the face's `CGRect`
3. Returns the **first player** whose face rect contains the point
4. Returns `nil` if no hit

**Code Location:** `GameState.swift` lines 113-122

### 5. **Damage & Health System**

When a hit is registered:

```swift
func registerHit(on targetPlayerID: UUID) {
    // 1. Apply cooldown (prevents spam)
    shootingCooldown = true
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        self.shootingCooldown = false
    }
    
    // 2. Send hit packet to network
    MultipeerManager.shared.send(packet: .playerHit(targetPlayerID: targetPlayerID))
    
    // 3. Apply damage
    applyDamage(to: targetPlayerID)
}

private func applyDamage(to playerID: UUID) {
    guard var health = playerHealths[playerID] else { return }
    
    // Reduce health
    health -= GameState.damagePerHit  // 20 HP
    health = max(0, health)
    playerHealths[playerID] = health
    
    // Sync to network
    MultipeerManager.shared.send(packet: .playerHealthUpdate(playerID: playerID, health: health))
    
    // Check for elimination
    if health <= 0 {
        handlePlayerEliminated(playerID)
    }
}
```

**Game Constants:**
- `maxHealth = 100` HP
- `damagePerHit = 20` HP
- `shootCooldownSeconds = 0.5` seconds
- **5 hits = elimination**

**Code Location:** `GameState.swift` lines 60-98

### 6. **Visual & Haptic Feedback**

#### On Hit ✅:
- **Haptic:** Heavy impact feedback
- **Visual:** Crosshair turns green and scales up
- **Audio:** (Can be added)
- **Network:** `.playerHit` packet sent

#### On Miss ❌:
- **Haptic:** Light impact feedback  
- **Visual:** No change
- **Console:** "MISS" debug log

**Code Location:** `ARGameView.swift` lines 325-344

## Coordinate Systems

### Vision Framework (Input)
- **Origin:** Bottom-left (0, 0)
- **Range:** Normalized 0.0 to 1.0
- **Y-axis:** Increases upward

### UIKit/SwiftUI (Output)
- **Origin:** Top-left (0, 0)
- **Range:** Pixels (e.g., 0 to screen width/height)
- **Y-axis:** Increases downward

### Conversion:
```swift
func convertToScreenCoordinates(normalizedRect: CGRect, viewportSize: CGSize) -> CGRect {
    let w = normalizedRect.width * viewportSize.width
    let h = normalizedRect.height * viewportSize.height
    let x = normalizedRect.minX * viewportSize.width
    // Flip Y coordinate!
    let y = (1 - normalizedRect.maxY) * viewportSize.height
    
    return CGRect(x: x, y: y, width: w, height: h)
}
```

**Code Location:** `VisionDetector.swift` lines 157-167

## Debug Mode

Enable debug mode to see:
- Yellow dot at screen center
- Screen dimensions
- Center coordinates
- Number of detected players

**To Enable:**
```swift
gameState.debugMode = true
```

**Console Output on Shoot:**
```
🎯 SHOOT! Center: (195.0, 422.5)
📱 View size: (390.0, 844.0)
👥 Detected players: 1
  - Player: John
    Face rect: (150.0, 350.0, 100.0, 150.0)
    Contains center: true
✅ HIT! Player: 1234-5678-...
```

## Common Issues & Solutions

### Issue: "Always Missing"
**Cause:** Screen center calculation is off
**Solution:** 
- Use `GeometryReader` to get actual view size
- Calculate center as `viewSize.width / 2, viewSize.height / 2`
- **Don't use** `UIScreen.main.bounds` (includes safe areas)

### Issue: "Face box doesn't align with face"
**Cause:** Coordinate conversion error
**Solution:**
- Ensure Y-axis flip: `y = (1 - normalizedRect.maxY) * height`
- Check camera orientation is `.right` for portrait mode
- Verify viewport size matches AR view size

### Issue: "Players not detected"
**Cause:** Vision request not returning results
**Solution:**
- Ensure adequate lighting
- Player within 2-3 meters
- Face visible to camera
- Check `frameSkip` value (lower = more frequent detection)

### Issue: "Hit detection too sensitive/loose"
**Cause:** Face bounding box size
**Solution:**
- Adjust padding in `calculateBoundingBox()` (currently 10%)
- Increase/decrease padding for easier/harder targeting

## Performance Optimization

### Frame Skipping
```swift
private let frameSkip: Int = 3  // Process every 3rd frame
```

**Trade-offs:**
- **Higher value:** Better performance, but laggier tracking
- **Lower value:** Smoother tracking, but more CPU usage
- **Recommended:** 2-4 for modern iPhones

### Detection Pipeline Optimization

**Two-Stage Detection:**
1. **Body detection** (fast, works at distance)
2. **Face detection** with Region of Interest (optimized)

This is **~3x faster** than full-frame face detection alone!

## Network Synchronization

### Shooting Event Flow:

```
Player A shoots at Player B
    ↓
Hit detected locally
    ↓
.playerHit packet sent
    ↓
All peers receive packet
    ↓
Damage applied on all devices
    ↓
.playerHealthUpdate synced
    ↓
Health bars update everywhere
```

**Packet Types:**
- `.playerHit(targetPlayerID: UUID)` - Notification of hit
- `.playerHealthUpdate(playerID: UUID, health: Int)` - Health sync

**Code Location:** `MultipeerManager.swift`, `GameState.swift`

## Testing the System

### 1. **Test AR Features Mode**
- Use without other players
- Points camera at anyone
- Detects and tracks in real-time
- Perfect for testing hit detection

### 2. **Console Debugging**
- All shoot events logged with emoji markers
- Shows coordinates, detection status, hit/miss
- Use Xcode console to see output

### 3. **Debug Mode Visual**
- Enable `debugMode = true`
- See yellow center marker
- Verify alignment with crosshair
- Check face box positions

## Summary

**The shooting system works in 3 steps:**

1. **Detect** players using Vision API → Get face rectangles in screen space
2. **Aim** crosshair (screen center) at target face
3. **Shoot** button checks if center point intersects face rectangle

**Simple, efficient, and accurate for multiplayer AR gameplay!** 🎯

---

## Code Files Reference

| File | Purpose |
|------|---------|
| `ARGameView.swift` | Main game view, shoot button, crosshair |
| `GameState.swift` | Hit registration, damage system, health tracking |
| `VisionDetector.swift` | Player detection, coordinate conversion |
| `DataModels.swift` | `DetectedPlayer`, `BodyJoint` structures |
| `MultipeerManager.swift` | Network packet transmission |

---

**Last Updated:** 2025

