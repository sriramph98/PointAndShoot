//
//  ARGameView.swift
//  PointAndShoot
//
//  Main AR game view with shooting mechanics and player detection
//

import SwiftUI
import ARKit
import RealityKit

struct ARGameView: View {
    
    @EnvironmentObject var gameState: GameState
    @State private var viewSize: CGSize = .zero
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Main AR View
                ARViewContainer()
                    .ignoresSafeArea()
                
                // Game HUD Overlay
                VStack {
                    // Top HUD: Player health bars
                    HealthHUDView()
                        .padding()
                    
                    Spacer()
                    
                    // Center: Crosshair
                    CrosshairView()
                    
                    Spacer()
                    
                    // Bottom: Shoot button
                    ShootButtonView(viewSize: geometry.size)
                        .padding(.bottom, 40)
                }
                
                // Player name overlays on detected faces
                DetectedPlayerOverlaysView()
                    .allowsHitTesting(false)
                
                // Body tracking points overlay
                BodyTrackingOverlayView()
                    .allowsHitTesting(false)
                
                // Debug overlay (optional)
                if gameState.debugMode {
                    DebugOverlayView(viewSize: geometry.size)
                        .allowsHitTesting(false)
                }
            }
            .onAppear {
                viewSize = geometry.size
            }
        }
    }
}

// MARK: - AR View Container

struct ARViewContainer: UIViewRepresentable {
    
    @EnvironmentObject var gameState: GameState
    
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        
        // Enable physics
        arView.environment.lighting.intensityExponent = 1.5
        
        // Configure AR session
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        arView.session.run(configuration)
        
        // Set session delegate
        let coordinator = context.coordinator
        arView.session.delegate = coordinator
        coordinator.arView = arView
        coordinator.viewportSize = arView.bounds.size
        
        // Store coordinator reference in gameState for sphere throwing
        gameState.arCoordinator = coordinator
        
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
        // Update viewport size if changed
        context.coordinator.viewportSize = uiView.bounds.size
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(gameState: gameState)
    }
    
    static func dismantleUIView(_ uiView: ARView, coordinator: Coordinator) {
        uiView.session.pause()
    }
    
    // MARK: - Coordinator
    
    class Coordinator: NSObject, ARSessionDelegate {
        
        let gameState: GameState
        weak var arView: ARView?
        var viewportSize: CGSize = .zero
        
        private var visionDetector: VisionDetector?
        private var frameCounter: Int = 0
        private let frameSkip: Int = 3  // Process every 3rd frame for performance
        
        init(gameState: GameState) {
            self.gameState = gameState
            super.init()
            self.visionDetector = VisionDetector(gameState: gameState)
        }
        
        // MARK: - ARSessionDelegate
        
        func session(_ session: ARSession, didUpdate frame: ARFrame) {
            // Skip frames for performance
            frameCounter += 1
            if frameCounter % frameSkip != 0 {
                return
            }
            
            // Get captured image
            let pixelBuffer = frame.capturedImage
            
            // Determine orientation
            let orientation = CGImagePropertyOrientation.right  // Portrait mode
            
            // Perform Vision detection
            visionDetector?.detectPlayers(
                in: pixelBuffer,
                orientation: orientation,
                viewportSize: viewportSize
            )
        }
        
        // MARK: - Raycasting
        
        /// Perform a raycast from screen center and return 3D hit location
        func performRaycast() -> SIMD3<Float>? {
            guard let arView = arView else { return nil }
            
            // Raycast from center of screen
            let screenCenter = CGPoint(x: arView.bounds.midX, y: arView.bounds.midY)
            
            // Perform raycast
            let results = arView.raycast(from: screenCenter, allowing: .estimatedPlane, alignment: .any)
            
            if let firstResult = results.first {
                // Return 3D world position
                let position = firstResult.worldTransform.columns.3
                return SIMD3<Float>(position.x, position.y, position.z)
            }
            
            return nil
        }
        
        /// Convert 3D world position to 2D screen coordinates
        func worldToScreen(worldPosition: SIMD3<Float>) -> CGPoint? {
            guard let arView = arView,
                  let currentFrame = arView.session.currentFrame else {
                return nil
            }
            
            // Get camera transform
            let cameraTransform = currentFrame.camera.transform
            let cameraProjection = currentFrame.camera.projectionMatrix
            
            // Transform world position to camera space
            let worldPos = SIMD4<Float>(worldPosition.x, worldPosition.y, worldPosition.z, 1.0)
            let cameraSpacePos = cameraTransform.inverse * worldPos
            
            // Project to normalized device coordinates
            let projectedPos = cameraProjection * cameraSpacePos
            
            guard projectedPos.w != 0 else { return nil }
            
            // Perspective divide
            let ndcX = projectedPos.x / projectedPos.w
            let ndcY = projectedPos.y / projectedPos.w
            
            // Convert NDC to screen coordinates
            let screenX = (ndcX + 1.0) * 0.5 * Float(viewportSize.width)
            let screenY = (1.0 - ndcY) * 0.5 * Float(viewportSize.height)
            
            return CGPoint(x: CGFloat(screenX), y: CGFloat(screenY))
        }
        
        // MARK: - Projectile Throwing
        
        /// Throw a 3D object from the camera position in the direction of the crosshair
        /// - Parameters:
        ///   - projectileName: Optional name of USDZ file (without extension) in the app bundle
        ///                     If nil, uses default generated sphere
        func throwProjectile(usdzName: String? = nil) {
            guard let arView = arView,
                  let currentFrame = arView.session.currentFrame else {
                print("⚠️ Cannot throw projectile: AR view or frame not available")
                return
            }
            
            // Get camera transform
            let cameraTransform = currentFrame.camera.transform
            
            // Extract camera position
            let cameraPosition = SIMD3<Float>(
                cameraTransform.columns.3.x,
                cameraTransform.columns.3.y,
                cameraTransform.columns.3.z
            )
            
            // Extract camera forward direction (negative Z in camera space)
            let cameraForward = SIMD3<Float>(
                -cameraTransform.columns.2.x,
                -cameraTransform.columns.2.y,
                -cameraTransform.columns.2.z
            )
            
            // Normalize direction
            let direction = normalize(cameraForward)
            
            // Position projectile slightly in front of camera
            let spawnDistance: Float = 0.3  // 30cm in front
            let spawnPosition = cameraPosition + (direction * spawnDistance)
            
            print("🎾 Throwing projectile:")
            print("  Camera pos: \(cameraPosition)")
            print("  Spawn pos: \(spawnPosition)")
            print("  Direction: \(direction)")
            
            // Create projectile entity
            let projectile = createProjectileEntity(usdzName: usdzName)
            
            // Set position
            projectile.position = spawnPosition
            
            // Add physics - make it dynamic with collision
            // Use bounding box for collision shape
            let bounds = projectile.visualBounds(relativeTo: nil)
            let size = bounds.extents
            let physicsShape = ShapeResource.generateBox(size: size)
            projectile.collision = CollisionComponent(shapes: [physicsShape])
            
            let physicsMaterial = PhysicsMaterialResource.generate(
                friction: 0.5,
                restitution: 0.8  // Bounciness
            )
            
            projectile.physicsBody = PhysicsBodyComponent(
                massProperties: .default,
                material: physicsMaterial,
                mode: .dynamic
            )
            
            // Apply impulse for initial velocity
            let throwForce: Float = 3.0  // Adjust this for throw strength
            let impulse = direction * throwForce
            projectile.applyLinearImpulse(impulse, relativeTo: nil)
            
            // Add slight upward arc
            projectile.applyLinearImpulse([0, 0.5, 0], relativeTo: nil)
            
            // Create anchor and add projectile to scene
            let anchor = AnchorEntity(world: spawnPosition)
            anchor.addChild(projectile)
            arView.scene.addAnchor(anchor)
            
            print("✅ Projectile added to scene with impulse: \(impulse)")
            
            // Remove projectile after 5 seconds to avoid clutter
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                anchor.removeFromParent()
            }
        }
        
        /// Create a projectile entity - either from USDZ or generated sphere
        /// - Parameter usdzName: Optional USDZ filename (without extension)
        /// - Returns: ModelEntity ready to be thrown
        private func createProjectileEntity(usdzName: String?) -> ModelEntity {
            if let usdzName = usdzName {
                // Try to load USDZ model from bundle
                if let modelEntity = loadUSDZModel(named: usdzName) {
                    print("✅ Loaded USDZ model: \(usdzName)")
                    return modelEntity
                } else {
                    print("⚠️ Failed to load USDZ '\(usdzName)', falling back to sphere")
                }
            }
            
            // Default: Create a generated sphere
            let sphereRadius: Float = 0.05  // 5cm radius
            return ModelEntity(
                mesh: .generateSphere(radius: sphereRadius),
                materials: [SimpleMaterial(color: .red, isMetallic: true)]
            )
        }
        
        /// Load a USDZ model from the app bundle
        /// - Parameter name: Filename without extension (e.g., "ball", "rock", "toy_ball")
        /// - Returns: ModelEntity if successful, nil otherwise
        private func loadUSDZModel(named name: String) -> ModelEntity? {
            // Try loading from bundle
            guard let url = Bundle.main.url(forResource: name, withExtension: "usdz") else {
                print("⚠️ USDZ file not found in bundle: \(name).usdz")
                return nil
            }
            
            do {
                // Load entity and find ModelEntity
                let loadedEntity = try Entity.load(contentsOf: url)
                
                // If it's already a ModelEntity, return it
                if let modelEntity = loadedEntity as? ModelEntity {
                    print("✅ Successfully loaded USDZ from: \(url.lastPathComponent)")
                    return modelEntity
                }
                
                // Otherwise, search for first ModelEntity in hierarchy
                for child in loadedEntity.children {
                    if let modelEntity = child as? ModelEntity {
                        print("✅ Successfully loaded USDZ from: \(url.lastPathComponent)")
                        return modelEntity
                    }
                }
                
                print("⚠️ No ModelEntity found in USDZ file: \(name)")
                return nil
            } catch {
                print("❌ Error loading USDZ model '\(name)': \(error.localizedDescription)")
                return nil
            }
        }
        
        /// Convenience method for backward compatibility - throws default sphere
        func throwSphere() {
            throwProjectile(usdzName: nil)
        }
    }
}

// MARK: - Health HUD View

struct HealthHUDView: View {
    
    @EnvironmentObject var gameState: GameState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Local player health
            if let localPlayer = MultipeerManager.shared.localPlayer {
                PlayerHealthBar(
                    playerName: "\(localPlayer.name) (You)",
                    health: gameState.getHealth(for: localPlayer.id),
                    isLocalPlayer: true
                )
            }
            
            // Connected players health
            ForEach(MultipeerManager.shared.connectedPlayers) { player in
                PlayerHealthBar(
                    playerName: player.name,
                    health: gameState.getHealth(for: player.id),
                    isLocalPlayer: false
                )
            }
        }
        .padding()
        .background(Color.black.opacity(0.6))
        .cornerRadius(10)
    }
}

struct PlayerHealthBar: View {
    
    let playerName: String
    let health: Int
    let isLocalPlayer: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(playerName)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(isLocalPlayer ? .cyan : .white)
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                    
                    // Health bar
                    Rectangle()
                        .fill(healthColor)
                        .frame(width: geometry.size.width * CGFloat(health) / 100.0)
                }
            }
            .frame(height: 12)
            .cornerRadius(6)
            
            Text("\(health)/100")
                .font(.caption2)
                .foregroundColor(.white)
        }
        .frame(width: 200)
    }
    
    var healthColor: Color {
        if health > 60 {
            return .green
        } else if health > 30 {
            return .orange
        } else {
            return .red
        }
    }
}

// MARK: - Crosshair View

struct CrosshairView: View {
    
    @EnvironmentObject var gameState: GameState
    
    var body: some View {
        ZStack {
            // Outer ring
            Circle()
                .stroke(gameState.showHitEffect ? Color.green : Color.white, lineWidth: 3)
                .frame(width: 40, height: 40)
            
            // Inner ring
            Circle()
                .stroke(gameState.showHitEffect ? Color.green : Color.white, lineWidth: 2)
                .frame(width: 30, height: 30)
            
            // Center dot
            Circle()
                .fill(gameState.showHitEffect ? Color.green : Color.red)
                .frame(width: 6, height: 6)
            
            // Crosshair lines
            Rectangle()
                .fill(Color.white)
                .frame(width: 2, height: 20)
            
            Rectangle()
                .fill(Color.white)
                .frame(width: 20, height: 2)
        }
        .opacity(gameState.showHitEffect ? 1.0 : 0.9)
        .scaleEffect(gameState.showHitEffect ? 1.3 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: gameState.showHitEffect)
    }
}

// MARK: - Shoot Button View

struct ShootButtonView: View {
    
    @EnvironmentObject var gameState: GameState
    let viewSize: CGSize
    
    var body: some View {
        Button(action: handleShoot) {
            ZStack {
                Circle()
                    .fill(gameState.shootingCooldown ? Color.gray : Color.red)
                    .frame(width: 80, height: 80)
                    .shadow(radius: 10)
                
                Image(systemName: gameState.shootingCooldown ? "hourglass" : "scope")
                    .font(.system(size: 40))
                    .foregroundColor(.white)
            }
        }
        .disabled(gameState.shootingCooldown)
    }
    
    private func handleShoot() {
        // Calculate the actual center of the view (where the crosshair is)
        let screenCenter = CGPoint(x: viewSize.width / 2, y: viewSize.height / 2)
        
        print("\n" + String(repeating: "=", count: 50))
        print("🎯 SHOOTING!")
        print(String(repeating: "=", count: 50))
        print("📍 Screen Center: (\(Int(screenCenter.x)), \(Int(screenCenter.y)))")
        print("📱 View Size: \(Int(viewSize.width)) x \(Int(viewSize.height))")
        print("👥 Detected Players: \(gameState.detectedPlayers.count)")
        print(String(repeating: "-", count: 50))
        
        // 🎾 Throw a 3D sphere in the AR scene
        if let coordinator = gameState.arCoordinator as? ARViewContainer.Coordinator {
            coordinator.throwSphere()
        }
        
        // Check each detected player
        for (index, detected) in gameState.detectedPlayers.enumerated() {
            let contains = detected.faceRect.contains(screenCenter)
            let distance = distanceFromCenter(rect: detected.faceRect, to: screenCenter)
            
            print("Player \(index + 1): \(detected.playerName)")
            print("  📦 Face Rect: x=\(Int(detected.faceRect.minX)), y=\(Int(detected.faceRect.minY)), w=\(Int(detected.faceRect.width)), h=\(Int(detected.faceRect.height))")
            print("  🎯 Contains Center: \(contains ? "✅ YES" : "❌ NO")")
            print("  📏 Distance from center: \(Int(distance)) pixels")
        }
        
        print(String(repeating: "-", count: 50))
        
        // Check if screen center intersects with any detected player face
        if let targetPlayerID = gameState.findTargetPlayer(at: screenCenter) {
            print("✅ ✅ ✅ HIT CONFIRMED! ✅ ✅ ✅")
            print("Target Player ID: \(targetPlayerID)")
            
            gameState.registerHit(on: targetPlayerID)
            
            // Strong haptic feedback for hit
            let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
            impactFeedback.impactOccurred()
            
            // Flash effect
            gameState.showHitEffect = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                gameState.showHitEffect = false
            }
        } else {
            print("❌ ❌ ❌ MISS ❌ ❌ ❌")
            print("No face at crosshair position")
            
            // Light feedback for miss
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        }
        
        print(String(repeating: "=", count: 50) + "\n")
    }
    
    private func distanceFromCenter(rect: CGRect, to point: CGPoint) -> CGFloat {
        let rectCenter = CGPoint(x: rect.midX, y: rect.midY)
        let dx = point.x - rectCenter.x
        let dy = point.y - rectCenter.y
        return sqrt(dx * dx + dy * dy)
    }
}

// MARK: - Detected Player Overlays

struct DetectedPlayerOverlaysView: View {
    
    @EnvironmentObject var gameState: GameState
    
    var body: some View {
        GeometryReader { geometry in
            ForEach(gameState.detectedPlayers, id: \.playerID) { detected in
                PlayerTargetOverlay(detected: detected)
                    .position(
                        x: detected.faceRect.midX,
                        y: detected.faceRect.midY
                    )
            }
        }
    }
}

struct PlayerTargetOverlay: View {
    
    let detected: DetectedPlayer
    @EnvironmentObject var gameState: GameState
    
    // Check if this face is being targeted
    private var isTargeted: Bool {
        // Get view size from environment if possible, otherwise use screen bounds
        let screenCenter = CGPoint(x: UIScreen.main.bounds.width / 2, 
                                   y: UIScreen.main.bounds.height / 2)
        return detected.faceRect.contains(screenCenter)
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Player name tag
            HStack(spacing: 6) {
                Image(systemName: isTargeted ? "scope" : "person.fill")
                    .font(.caption)
                Text(detected.playerName)
                    .font(.headline)
                    .fontWeight(.bold)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isTargeted ? Color.green : Color.red)
            .cornerRadius(8)
            .shadow(radius: 5)
            
            // Target lock indicator
            if isTargeted {
                HStack(spacing: 4) {
                    Image(systemName: "target")
                        .font(.caption2)
                    Text("LOCKED")
                        .font(.caption2)
                        .fontWeight(.bold)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.green)
                .cornerRadius(6)
            }
            
            // Health bar
            let health = gameState.getHealth(for: detected.playerID)
            HStack(spacing: 4) {
                Image(systemName: "heart.fill")
                    .font(.caption2)
                    .foregroundColor(.red)
                ProgressView(value: Double(health), total: 100.0)
                    .progressViewStyle(LinearProgressViewStyle(tint: health > 50 ? .green : .orange))
                    .frame(width: 80)
                Text("\(health)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.black.opacity(0.7))
            .cornerRadius(6)
        }
        .overlay(
            // Face bounding box - VERY VISIBLE
            ZStack {
                // Thick colored border
                Rectangle()
                    .stroke(isTargeted ? Color.green : Color.red, lineWidth: 4)
                    .frame(width: detected.faceRect.width, height: detected.faceRect.height)
                    .shadow(color: isTargeted ? .green : .red, radius: 8)
                
                // Corner brackets for targeting feel
                CornerBrackets(
                    width: detected.faceRect.width,
                    height: detected.faceRect.height,
                    color: isTargeted ? .green : .red
                )
                
                // Pulsing effect when targeted
                if isTargeted {
                    Rectangle()
                        .fill(Color.green.opacity(0.1))
                        .frame(width: detected.faceRect.width, height: detected.faceRect.height)
                }
            }
        )
        .animation(.easeInOut(duration: 0.3), value: isTargeted)
    }
}

// MARK: - Corner Brackets

struct CornerBrackets: View {
    let width: CGFloat
    let height: CGFloat
    let color: Color
    
    var body: some View {
        ZStack {
            // Top-left
            Path { path in
                path.move(to: CGPoint(x: -width/2 + 20, y: -height/2))
                path.addLine(to: CGPoint(x: -width/2, y: -height/2))
                path.addLine(to: CGPoint(x: -width/2, y: -height/2 + 20))
            }
            .stroke(color, lineWidth: 6)
            
            // Top-right
            Path { path in
                path.move(to: CGPoint(x: width/2 - 20, y: -height/2))
                path.addLine(to: CGPoint(x: width/2, y: -height/2))
                path.addLine(to: CGPoint(x: width/2, y: -height/2 + 20))
            }
            .stroke(color, lineWidth: 6)
            
            // Bottom-left
            Path { path in
                path.move(to: CGPoint(x: -width/2 + 20, y: height/2))
                path.addLine(to: CGPoint(x: -width/2, y: height/2))
                path.addLine(to: CGPoint(x: -width/2, y: height/2 - 20))
            }
            .stroke(color, lineWidth: 6)
            
            // Bottom-right
            Path { path in
                path.move(to: CGPoint(x: width/2 - 20, y: height/2))
                path.addLine(to: CGPoint(x: width/2, y: height/2))
                path.addLine(to: CGPoint(x: width/2, y: height/2 - 20))
            }
            .stroke(color, lineWidth: 6)
        }
    }
}

// MARK: - Body Tracking Overlay

struct BodyTrackingOverlayView: View {
    
    @EnvironmentObject var gameState: GameState
    
    var body: some View {
        GeometryReader { geometry in
            ForEach(gameState.detectedPlayers, id: \.playerID) { detected in
                // Draw body joints for each detected player
                ForEach(detected.bodyJoints) { joint in
                    BodyJointPoint(joint: joint)
                        .position(joint.position)
                }
                
                // Draw skeleton connections
                BodySkeletonView(joints: detected.bodyJoints)
            }
        }
    }
}

// MARK: - Body Joint Point

struct BodyJointPoint: View {
    
    let joint: BodyJoint
    
    var body: some View {
        ZStack {
            // Outer glow
            Circle()
                .fill(jointColor.opacity(0.3))
                .frame(width: jointSize * 2, height: jointSize * 2)
                .blur(radius: 3)
            
            // Main point
            Circle()
                .fill(jointColor)
                .frame(width: jointSize, height: jointSize)
            
            // Inner highlight
            Circle()
                .fill(Color.white.opacity(0.6))
                .frame(width: jointSize * 0.4, height: jointSize * 0.4)
                .offset(x: -jointSize * 0.15, y: -jointSize * 0.15)
        }
    }
    
    private var jointSize: CGFloat {
        // Size based on confidence and joint type
        if joint.name.contains("nose") || joint.name.contains("root") {
            return joint.isHighConfidence ? 12 : 8
        } else {
            return joint.isHighConfidence ? 10 : 6
        }
    }
    
    private var jointColor: Color {
        // Color based on confidence
        if joint.confidence > 0.8 {
            return .green
        } else if joint.confidence > 0.5 {
            return .yellow
        } else {
            return .orange
        }
    }
}

// MARK: - Body Skeleton View

struct BodySkeletonView: View {
    
    let joints: [BodyJoint]
    
    var body: some View {
        // Define skeleton connections
        let connections: [(String, String)] = [
            // Head
            ("nose", "neck"),
            
            // Left arm
            ("neck", "leftShoulder"),
            ("leftShoulder", "leftElbow"),
            ("leftElbow", "leftWrist"),
            
            // Right arm
            ("neck", "rightShoulder"),
            ("rightShoulder", "rightElbow"),
            ("rightElbow", "rightWrist"),
            
            // Torso
            ("neck", "root"),
            ("root", "leftHip"),
            ("root", "rightHip"),
            
            // Left leg
            ("leftHip", "leftKnee"),
            ("leftKnee", "leftAnkle"),
            
            // Right leg
            ("rightHip", "rightKnee"),
            ("rightKnee", "rightAnkle"),
        ]
        
        Canvas { context, size in
            for (startName, endName) in connections {
                // Find the joints
                guard let startJoint = joints.first(where: { $0.name.contains(startName) }),
                      let endJoint = joints.first(where: { $0.name.contains(endName) }) else {
                    continue
                }
                
                // Only draw if both points have reasonable confidence
                guard startJoint.confidence > 0.3 && endJoint.confidence > 0.3 else {
                    continue
                }
                
                // Draw line between joints
                var path = Path()
                path.move(to: startJoint.position)
                path.addLine(to: endJoint.position)
                
                // Line color based on average confidence
                let avgConfidence = (startJoint.confidence + endJoint.confidence) / 2
                let lineColor: Color = avgConfidence > 0.7 ? .cyan : .cyan.opacity(0.5)
                
                context.stroke(
                    path,
                    with: .color(lineColor),
                    lineWidth: 2
                )
            }
        }
    }
}

// MARK: - Debug Overlay

struct DebugOverlayView: View {
    
    @EnvironmentObject var gameState: GameState
    let viewSize: CGSize
    
    var body: some View {
        ZStack {
            // Screen center marker
            Circle()
                .fill(Color.yellow)
                .frame(width: 10, height: 10)
                .position(x: viewSize.width / 2, y: viewSize.height / 2)
            
            // Debug info
            VStack {
                Spacer()
                VStack(alignment: .leading, spacing: 5) {
                    Text("DEBUG MODE")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.yellow)
                    
                    Text("View: \(Int(viewSize.width))x\(Int(viewSize.height))")
                        .font(.caption2)
                        .foregroundColor(.white)
                    
                    Text("Center: \(Int(viewSize.width/2)), \(Int(viewSize.height/2))")
                        .font(.caption2)
                        .foregroundColor(.white)
                    
                    Text("Detected: \(gameState.detectedPlayers.count)")
                        .font(.caption2)
                        .foregroundColor(.white)
                }
                .padding(8)
                .background(Color.black.opacity(0.7))
                .cornerRadius(8)
                .padding()
            }
        }
    }
}

// MARK: - Helper Extensions

extension CGRect {
    var center: CGPoint {
        return CGPoint(x: midX, y: midY)
    }
}

extension CGSize {
    var center: CGPoint {
        return CGPoint(x: width / 2, y: height / 2)
    }
}

#Preview {
    ARGameView()
        .environmentObject(GameState())
}

