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
    
    var body: some View {
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
                ShootButtonView()
                    .padding(.bottom, 40)
            }
            
            // Player name overlays on detected faces
            DetectedPlayerOverlaysView()
            
            // Body tracking points overlay
            BodyTrackingOverlayView()
        }
    }
}

// MARK: - AR View Container

struct ARViewContainer: UIViewRepresentable {
    
    @EnvironmentObject var gameState: GameState
    
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        
        // Configure AR session
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        arView.session.run(configuration)
        
        // Set session delegate
        let coordinator = context.coordinator
        arView.session.delegate = coordinator
        coordinator.arView = arView
        coordinator.viewportSize = arView.bounds.size
        
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
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white, lineWidth: 2)
                .frame(width: 30, height: 30)
            
            Circle()
                .fill(Color.red)
                .frame(width: 4, height: 4)
        }
    }
}

// MARK: - Shoot Button View

struct ShootButtonView: View {
    
    @EnvironmentObject var gameState: GameState
    
    var body: some View {
        Button(action: handleShoot) {
            ZStack {
                Circle()
                    .fill(gameState.shootingCooldown ? Color.gray : Color.red)
                    .frame(width: 80, height: 80)
                    .shadow(radius: 10)
                
                Image(systemName: "scope")
                    .font(.system(size: 40))
                    .foregroundColor(.white)
            }
        }
        .disabled(gameState.shootingCooldown)
    }
    
    private func handleShoot() {
        // Get the ARView's coordinator to perform raycast
        // We need to find the target player at screen center
        
        let screenCenter = UIScreen.main.bounds.center
        
        // Check if screen center intersects with any detected player face
        if let targetPlayerID = gameState.findTargetPlayer(at: screenCenter) {
            print("Hit player: \(targetPlayerID)")
            gameState.registerHit(on: targetPlayerID)
            
            // Visual/haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
            impactFeedback.impactOccurred()
        } else {
            print("Missed - no player at crosshair")
            
            // Light feedback for miss
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        }
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
    
    var body: some View {
        VStack(spacing: 4) {
            // Player name
            Text(detected.playerName)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.red.opacity(0.8))
                .cornerRadius(6)
            
            // Health bar
            let health = gameState.getHealth(for: detected.playerID)
            ProgressView(value: Double(health), total: 100.0)
                .progressViewStyle(LinearProgressViewStyle(tint: .green))
                .frame(width: 80)
        }
        .overlay(
            // Bounding box
            Rectangle()
                .stroke(Color.red, lineWidth: 2)
                .frame(width: detected.faceRect.width, height: detected.faceRect.height)
        )
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

