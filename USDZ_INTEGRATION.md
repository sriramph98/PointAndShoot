# Using Custom USDZ Models as Projectiles

## Overview

The projectile system is now designed to support **any 3D USDZ model** as a throwable object. You can easily replace the default sphere with custom 3D models like balls, rocks, weapons, or any other object.

## Quick Start

### 1. Add Your USDZ File to the Project

**In Xcode:**
1. Drag and drop your `.usdz` file into the project navigator
2. Make sure "Copy items if needed" is checked
3. Ensure the file is added to your app target
4. The file will be bundled with your app

**Example file structure:**
```
PointAndShoot/
├── Assets/
│   ├── ball.usdz
│   ├── rock.usdz
│   └── toy_gun.usdz
```

### 2. Use the Custom Model

**Replace the sphere with your USDZ model:**

```swift
// In ARGameView.swift, modify the shoot handler:
if let coordinator = gameState.arCoordinator as? ARViewContainer.Coordinator {
    // Throw a custom model instead of the default sphere
    coordinator.throwProjectile(usdzName: "ball")  // Uses ball.usdz
}
```

**Or in ARDemoView.swift:**

```swift
if let coordinator = demoState.arCoordinator as? ARDemoContainer.Coordinator {
    coordinator.throwProjectile(usdzName: "rock")  // Uses rock.usdz
}
```

### 3. Fallback Behavior

If the USDZ file is not found or fails to load:
- The system automatically falls back to the default generated sphere
- An error is logged to the console
- The game continues without crashing

## API Reference

### Main Method

```swift
func throwProjectile(usdzName: String? = nil)
```

**Parameters:**
- `usdzName`: Optional filename without extension
  - Example: `"ball"` to load `ball.usdz`
  - `nil` uses the default generated sphere

**Examples:**

```swift
// Use default sphere
coordinator.throwProjectile()
coordinator.throwSphere()  // Same as above

// Use custom USDZ model
coordinator.throwProjectile(usdzName: "soccer_ball")
coordinator.throwProjectile(usdzName: "grenade")
coordinator.throwProjectile(usdzName: "snowball")
```

### Helper Methods

```swift
// Internal method that creates the projectile entity
private func createProjectileEntity(usdzName: String?) -> ModelEntity

// Internal method that loads USDZ from bundle
private func loadUSDZModel(named name: String) -> ModelEntity?
```

## How It Works

### Loading Process

1. **Check for USDZ**: System looks for `[name].usdz` in app bundle
2. **Load Model**: Uses `ModelEntity.load(contentsOf:)` to load the file
3. **Fallback**: If loading fails, creates default sphere
4. **Physics Setup**: Automatically configures physics based on model bounds

### Automatic Physics

The system automatically:
- Calculates bounding box from your model
- Creates appropriate collision shape
- Applies same physics properties (bounce, friction, gravity)
- Handles any model size or shape

```swift
// Physics automatically adapts to your model
let bounds = projectile.visualBounds(relativeTo: nil)
let size = bounds.extents
let physicsShape = ShapeResource.generateBox(size: size)
```

## Finding USDZ Models

### Apple's Sample Content

**Free USDZ models from Apple:**
- [RealityKit Sample Models](https://developer.apple.com/augmented-reality/quick-look/)
- Download sample toys, objects, and characters
- Optimized for iOS and ARKit

**Apple Quick Look Gallery:**
- Browse: https://developer.apple.com/augmented-reality/quick-look/
- Download ready-to-use USDZ files
- Examples: toy_robot, toy_biplane, toy_drummer, etc.

### Creating Your Own USDZ

**Option 1: Reality Composer**
1. Open Reality Composer (free with Xcode)
2. Import 3D models (OBJ, USD, etc.)
3. Edit materials and properties
4. Export as `.usdz`

**Option 2: Export from 3D Software**
- **Blender**: Use USDZ export plugin
- **Maya/3ds Max**: USD export tools
- **Cinema 4D**: Native USD support

**Option 3: Online Converters**
- Convert OBJ, FBX, GLB to USDZ
- Apple's Reality Converter (macOS app)

### USDZ Requirements

**Best Practices:**
- **File Size**: Keep under 10MB for best performance
- **Polygon Count**: Aim for 10,000-50,000 polygons max
- **Textures**: Use compressed textures (JPEG for color, PNG for alpha)
- **Materials**: PBR materials work best (Metallic/Roughness)

**Technical Specs:**
- Format: `.usdz` (Universal Scene Description)
- Coordinate System: Y-up, right-handed
- Units: Meters preferred
- LODs: Optional but recommended for complex models

## Example Integration

### Complete Example: Using a Soccer Ball

```swift
// 1. Add soccer_ball.usdz to your Xcode project

// 2. Modify the shoot button in ARGameView.swift
private func handleShoot() {
    let screenCenter = CGPoint(x: viewSize.width / 2, y: viewSize.height / 2)
    
    // Throw soccer ball instead of sphere
    if let coordinator = gameState.arCoordinator as? ARViewContainer.Coordinator {
        coordinator.throwProjectile(usdzName: "soccer_ball")
    }
    
    // Rest of hit detection code...
    if let targetPlayerID = gameState.findTargetPlayer(at: screenCenter) {
        gameState.registerHit(on: targetPlayerID)
    }
}
```

### Multiple Projectile Types

**Create a system with different weapons:**

```swift
enum ProjectileType: String {
    case sphere = nil           // Default
    case ball = "soccer_ball"
    case rock = "rock_model"
    case grenade = "grenade"
    
    var usdzName: String? {
        return self.rawValue
    }
}

// In your game state
@Published var currentProjectile: ProjectileType = .sphere

// When shooting
coordinator.throwProjectile(usdzName: gameState.currentProjectile.usdzName)
```

### UI Selector

**Add a picker to switch projectiles:**

```swift
Picker("Projectile", selection: $currentProjectile) {
    Text("Sphere").tag(ProjectileType.sphere)
    Text("Ball").tag(ProjectileType.ball)
    Text("Rock").tag(ProjectileType.rock)
}
```

## Troubleshooting

### Model Not Appearing

**Console shows: "USDZ file not found in bundle"**
- Check filename exactly matches (case-sensitive)
- Verify `.usdz` extension
- Ensure file is in app target membership
- Try cleaning build folder (Cmd+Shift+K)

**Console shows: "Error loading USDZ model"**
- File might be corrupted
- Try opening in Reality Composer to validate
- Check file format is valid USDZ
- Try converting/re-exporting the model

### Physics Issues

**Model falls through floor:**
- Increase mass: `PhysicsMassProperties(mass: 1.0)`
- Wait longer for plane detection
- Move device to scan environment

**Model rotates weirdly:**
- Check model's pivot point in 3D software
- Center the pivot before exporting
- Or lock rotation: `physicsBody?.mode = .kinematic`

**Model too fast/slow:**
- Adjust `throwForce` multiplier
- Scale is in meters per second

**Model bounces too much:**
- Reduce `restitution` (bounciness): `0.3` instead of `0.8`
- Increase `friction`: `1.0` instead of `0.5`

### Performance

**App running slow with custom models:**
- Reduce polygon count (decimate in Blender)
- Compress textures (smaller resolution)
- Limit projectiles on screen simultaneously
- Reduce lifetime: `3.0` seconds instead of `5.0`

## Advanced Customization

### Per-Model Physics Properties

**Different physics for each model:**

```swift
private func createProjectileEntity(usdzName: String?) -> ModelEntity {
    if let usdzName = usdzName, let model = loadUSDZModel(named: usdzName) {
        // Custom physics per model
        switch usdzName {
        case "grenade":
            // Heavy, less bouncy
            configurePhysics(model, mass: 2.0, restitution: 0.2)
        case "ball":
            // Light, very bouncy
            configurePhysics(model, mass: 0.5, restitution: 0.9)
        default:
            break
        }
        return model
    }
    
    // Default sphere
    return ModelEntity(
        mesh: .generateSphere(radius: 0.05),
        materials: [SimpleMaterial(color: .red, isMetallic: true)]
    )
}

private func configurePhysics(_ entity: ModelEntity, mass: Float, restitution: Float) {
    let material = PhysicsMaterialResource.generate(
        friction: 0.5,
        restitution: restitution
    )
    let massProperties = PhysicsMassProperties(mass: mass)
    entity.physicsBody = PhysicsBodyComponent(
        massProperties: massProperties,
        material: material,
        mode: .dynamic
    )
}
```

### Model Scaling

**Resize models at runtime:**

```swift
let projectile = createProjectileEntity(usdzName: usdzName)
projectile.scale = SIMD3<Float>(0.5, 0.5, 0.5)  // 50% smaller
```

### Audio on Impact

**Add sound effects:**

```swift
// In throwProjectile method, after adding to scene:
projectile.collision?.filter = CollisionFilter(group: .default, mask: .all)

// Subscribe to collision events
arView.scene.subscribe(to: CollisionEvents.Began.self) { event in
    // Play impact sound
    print("💥 Collision detected!")
}
```

## Summary

✅ **Future-proof**: Easy to swap models without code changes  
✅ **Flexible**: Works with any USDZ file  
✅ **Safe**: Automatic fallback to default sphere  
✅ **Performant**: Physics automatically adapts to model  
✅ **Developer-friendly**: Clear API with helpful error messages

**Next Steps:**
1. Try downloading a sample USDZ from Apple's Quick Look gallery
2. Add it to your Xcode project
3. Change `throwProjectile(usdzName: "your_model_name")`
4. Test and iterate!

