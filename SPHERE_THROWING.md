# 3D Projectile Throwing Mechanic

## Overview

The app features a physics-based 3D projectile throwing system inspired by Apple's classic AR demos. When you press the shoot button, a realistic physics object is launched from the camera position in the direction you're aiming.

**🎯 Key Feature**: The system supports **any USDZ 3D model** as a projectile, not just spheres!

## How It Works

### 1. Camera-Based Throwing

**Physics Setup:**
- Uses RealityKit's physics engine for realistic motion
- Projectile spawns 30cm in front of the camera
- Launches in the exact direction the camera is facing (where the crosshair points)

**Default Projectile Properties (Generated Sphere):**
- **Size**: 5cm radius (tennis ball sized)
- **Color**: Red in game mode, Cyan in demo mode
- **Material**: Metallic finish for visual appeal
- **Physics**: Dynamic body with gravity and collision detection

**Custom USDZ Models:**
- Load any `.usdz` 3D model from your app bundle
- Automatic physics calculation based on model bounds
- See `USDZ_INTEGRATION.md` for complete guide

### 2. Physics Behavior

**Velocity & Force:**
- **Throw Force**: 3.0 m/s base velocity
- **Upward Arc**: Additional 1.0 N upward force for realistic trajectory
- **Bounce**: 80% restitution (bounciness)
- **Friction**: 0.5 coefficient for realistic rolling

**Collision:**
- Detects collisions with detected AR planes (floors, walls, tables)
- Bounces realistically off surfaces
- Rolls naturally based on momentum

### 3. Lifecycle Management

**Auto-Cleanup:**
- Spheres automatically disappear after 5 seconds
- Prevents scene clutter and maintains performance
- Each throw is independent

## Technical Implementation

### API Overview

**Main Method:**
```swift
func throwProjectile(usdzName: String? = nil)
```

**Examples:**
```swift
// Use default sphere
coordinator.throwProjectile()
coordinator.throwSphere()  // Convenience method

// Use custom USDZ model
coordinator.throwProjectile(usdzName: "soccer_ball")  // Loads soccer_ball.usdz
coordinator.throwProjectile(usdzName: "grenade")      // Loads grenade.usdz
```

### ARKit Integration

```swift
// Extract camera position and direction
let cameraTransform = currentFrame.camera.transform
let cameraPosition = SIMD3<Float>(
    cameraTransform.columns.3.x,
    cameraTransform.columns.3.y,
    cameraTransform.columns.3.z
)

// Camera forward direction (negative Z axis)
let cameraForward = SIMD3<Float>(
    -cameraTransform.columns.2.x,
    -cameraTransform.columns.2.y,
    -cameraTransform.columns.2.z
)
```

### RealityKit Physics

```swift
// Create projectile (sphere or USDZ model)
let projectile = createProjectileEntity(usdzName: usdzName)

// Physics automatically adapts to model size
let bounds = projectile.visualBounds(relativeTo: nil)
let size = bounds.extents
let physicsShape = ShapeResource.generateBox(size: size)

// Add collision and physics
projectile.collision = CollisionComponent(shapes: [physicsShape])
projectile.physicsBody = PhysicsBodyComponent(
    massProperties: .default,
    material: physicsMaterial,
    mode: .dynamic
)

// Apply impulse for initial velocity
projectile.applyLinearImpulse(direction * throwForce, relativeTo: nil)
```

### USDZ Loading

```swift
// Load custom 3D model from bundle
private func loadUSDZModel(named name: String) -> ModelEntity? {
    guard let url = Bundle.main.url(forResource: name, withExtension: "usdz") else {
        return nil
    }
    
        do {
            // Load entity and find ModelEntity
            let loadedEntity = try Entity.load(contentsOf: url)
            
            // Cast to ModelEntity or find first ModelEntity child
            if let modelEntity = loadedEntity as? ModelEntity {
                return modelEntity
            }
            
            return loadedEntity.findEntity(where: { $0 is ModelEntity }) as? ModelEntity
        } catch {
            print("Error loading USDZ: \(error)")
            return nil
        }
}
```

### Coordinate Systems

**Camera Space to World Space:**
- Camera transform provides world-space position
- Forward vector extracted from transform matrix
- Spawn position calculated in world coordinates

**Anchor System:**
- Uses `AnchorEntity(world:)` for precise positioning
- Sphere is child of anchor for easy cleanup
- Anchor removal automatically removes sphere

## Usage

### In-Game Mode
1. Aim at a target using the crosshair
2. Press the red shoot button
3. A projectile (red sphere by default) launches toward your target
4. Simultaneously checks for player hits

### Demo Mode
1. Point camera where you want to throw
2. Press the shoot button
3. A projectile (cyan sphere by default) launches in that direction
4. Watch it bounce and interact with the environment

### Using Custom USDZ Models

**Quick Example:**
```swift
// In ARGameView.swift, modify handleShoot():
if let coordinator = gameState.arCoordinator as? ARViewContainer.Coordinator {
    coordinator.throwProjectile(usdzName: "toy_ball")  // Instead of default sphere
}
```

**See `USDZ_INTEGRATION.md` for:**
- Complete integration guide
- Where to find USDZ models
- How to create your own
- Advanced customization options

## Performance Considerations

**Optimization:**
- Maximum 5-second lifetime per sphere
- Automatic cleanup prevents memory leaks
- Physics calculations handled by RealityKit engine

**Plane Detection:**
- Horizontal and vertical plane detection enabled
- Spheres interact with detected surfaces
- Better plane detection = more realistic physics

## Debugging

**Console Output:**
```
🎾 Throwing sphere:
  Camera pos: (x, y, z)
  Spawn pos: (x, y, z)
  Direction: (x, y, z)
✅ Sphere added to scene with velocity: (x, y, z)
```

**What to Look For:**
- Sphere should appear in front of camera
- Should move in crosshair direction
- Should bounce off floors and walls
- Should disappear after 5 seconds

## Customization

### Adjustable Parameters

**In `throwProjectile()` method:**

```swift
let spawnDistance: Float = 0.3      // Distance from camera (0.3 = 30cm)
let throwForce: Float = 3.0         // Launch speed (3.0 m/s)
let upwardForce: Float = 1.0        // Arc height (1.0 N)
let restitution: Float = 0.8        // Bounciness (0.8 = 80%)
let friction: Float = 0.5           // Surface friction (0.5)
```

**Default Sphere Options (when no USDZ provided):**
```swift
let sphereRadius: Float = 0.05      // Size (0.05 = 5cm)
// Color: .red (game mode), .cyan (demo mode)
```

**Using Custom Models:**
```swift
// Just change the usdzName parameter
coordinator.throwProjectile(usdzName: "your_model")
```

### Advanced Modifications

**Faster Throws:**
```swift
let throwForce: Float = 5.0  // Increase from 3.0
```

**Longer Lifetime:**
```swift
DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {  // Increase from 5.0
    anchor.removeFromParent()
}
```

**Heavier/Lighter:**
```swift
sphere.physicsBody = PhysicsBodyComponent(
    massProperties: PhysicsMassProperties(mass: 0.2),  // Set explicit mass
    material: physicsMaterial,
    mode: .dynamic
)
```

## Integration with Hit Detection

The sphere throwing is **additive** to the existing hit detection:

1. **Sphere is thrown** (visual/physical projectile)
2. **Hit detection runs** (checks if crosshair is on face)
3. **Both happen simultaneously**

This means:
- You see a physical sphere fly through the air
- If aimed correctly at a face, hit is registered immediately
- Sphere continues its physics trajectory regardless of hit

## Future Enhancements

**Potential Improvements:**
1. **Collision Hit Detection**: Detect when projectile collides with a player's body
2. **Particle Effects**: Add trail or explosion effects
3. **Projectile Selector UI**: In-game menu to switch between different models
4. **Power-Ups**: Variable throw force or special abilities
5. **Sound Effects**: Launch and collision sounds
6. **Model Variety**: Download and integrate USDZ models at runtime

**✅ Already Implemented:**
- ✓ Custom USDZ model support (see `USDZ_INTEGRATION.md`)

## Troubleshooting

**Sphere not appearing:**
- Check AR session is running
- Ensure camera permissions granted
- Verify plane detection is active

**Sphere falls through floor:**
- Wait for plane detection to initialize
- Move device to scan environment better
- May take a few seconds to detect surfaces

**Performance issues:**
- Check too many spheres aren't accumulating
- Verify 5-second cleanup is working
- Consider reducing throw frequency

## References

- **RealityKit Documentation**: Apple's physics and 3D rendering framework
- **ARKit Raycasting**: Modern approach to AR hit testing
- **SIMD Math**: Vector calculations for 3D positioning
- **Apple WWDC Sessions**: AR best practices and demos
- **USDZ Format**: Universal Scene Description format for 3D models
- **`USDZ_INTEGRATION.md`**: Complete guide to using custom 3D models in this app

