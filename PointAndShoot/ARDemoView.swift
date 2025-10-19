//
//  ARDemoView.swift
//  PointAndShoot
//
//  Demo mode to test AR features without multiplayer
//

import SwiftUI
import ARKit
import RealityKit

struct ARDemoView: View {
    
    var onExit: () -> Void
    
    @StateObject private var demoState = ARDemoState()
    @State private var showInstructions = true
    
    var body: some View {
        ZStack {
            // AR Camera View
            ARDemoContainer(demoState: demoState)
                .ignoresSafeArea()
            
            // HUD Overlay
            VStack {
                // Top: Instructions & Stats
                VStack(spacing: 10) {
                    if showInstructions {
                        VStack(spacing: 8) {
                            Text("AR Features Demo")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Text("Point your camera at people to see:")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.9))
                            
                            HStack(spacing: 15) {
                                FeatureTag(icon: "figure.stand", text: "Body Tracking")
                                FeatureTag(icon: "face.smiling", text: "Face Detection")
                            }
                            
                            Button(action: { showInstructions = false }) {
                                Text("Got it!")
                                    .font(.caption)
                                    .foregroundColor(.cyan)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.white.opacity(0.2))
                                    .cornerRadius(8)
                            }
                            .padding(.top, 5)
                        }
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(15)
                        .padding()
                    }
                    
                    // Detection Stats
                    HStack(spacing: 20) {
                        StatBadge(
                            icon: "person.fill",
                            value: "\(demoState.detectedPlayers.count)",
                            label: "Detected"
                        )
                        
                        StatBadge(
                            icon: "target",
                            value: "\(demoState.totalShots)",
                            label: "Shots"
                        )
                        
                        StatBadge(
                            icon: "checkmark.circle.fill",
                            value: "\(demoState.successfulHits)",
                            label: "Hits"
                        )
                    }
                    .padding()
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(15)
                    .padding(.horizontal)
                }
                
                Spacer()
                
                // Center: Crosshair
                CrosshairView()
                
                Spacer()
                
                // Bottom: Controls
                HStack(spacing: 30) {
                    // Toggle Instructions
                    Button(action: { showInstructions.toggle() }) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.blue.opacity(0.7))
                            .clipShape(Circle())
                    }
                    
                    // Shoot Button
                    Button(action: handleDemoShoot) {
                        ZStack {
                            Circle()
                                .fill(demoState.shootingCooldown ? Color.gray : Color.red)
                                .frame(width: 80, height: 80)
                                .shadow(radius: 10)
                            
                            Image(systemName: "scope")
                                .font(.system(size: 40))
                                .foregroundColor(.white)
                        }
                    }
                    .disabled(demoState.shootingCooldown)
                    
                    // Reset Stats
                    Button(action: { demoState.resetStats() }) {
                        Image(systemName: "arrow.counterclockwise.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.orange.opacity(0.7))
                            .clipShape(Circle())
                    }
                }
                .padding(.bottom, 40)
            }
            
            // Body tracking visualization
            BodyTrackingDemoOverlay(detectedPlayers: demoState.detectedPlayers)
                .allowsHitTesting(false)
            
            // Exit button
            VStack {
                HStack {
                    Spacer()
                    Button(action: onExit) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                    }
                    .padding()
                }
                Spacer()
            }
        }
    }
    
    private func handleDemoShoot() {
        guard !demoState.shootingCooldown else { return }
        
        demoState.totalShots += 1
        demoState.shootingCooldown = true
        
        // Check if hit any detected face
        let screenCenter = CGPoint(x: UIScreen.main.bounds.midX, y: UIScreen.main.bounds.midY)
        
        print("\n" + String(repeating: "=", count: 50))
        print("🎯 DEMO SHOOTING!")
        print(String(repeating: "=", count: 50))
        print("📍 Screen Center: (\(Int(screenCenter.x)), \(Int(screenCenter.y)))")
        print("📱 Screen Size: \(Int(UIScreen.main.bounds.width)) x \(Int(UIScreen.main.bounds.height))")
        print("👥 Detected Players: \(demoState.detectedPlayers.count)")
        print("📊 Total Shots: \(demoState.totalShots), Total Hits: \(demoState.successfulHits)")
        print(String(repeating: "-", count: 50))
        
        // 🎾 Throw a 3D sphere in the AR scene
        if let coordinator = demoState.arCoordinator as? ARDemoContainer.Coordinator {
            coordinator.throwSphere()
        }
        
        var hitDetected = false
        for (index, detected) in demoState.detectedPlayers.enumerated() {
            let contains = detected.faceRect.contains(screenCenter)
            let distance = distanceFromCenter(rect: detected.faceRect, to: screenCenter)
            
            print("Player \(index + 1): \(detected.playerName)")
            print("  📦 Face Rect: x=\(Int(detected.faceRect.minX)), y=\(Int(detected.faceRect.minY)), w=\(Int(detected.faceRect.width)), h=\(Int(detected.faceRect.height))")
            print("  🎯 Contains Center: \(contains ? "✅ YES" : "❌ NO")")
            print("  📏 Distance from center: \(Int(distance)) pixels")
            
            if contains {
                print("✅ ✅ ✅ HIT CONFIRMED! ✅ ✅ ✅")
                demoState.successfulHits += 1
                hitDetected = true
                
                // Visual feedback
                let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
                impactFeedback.impactOccurred()
                break
            }
        }
        
        if !hitDetected {
            print("❌ ❌ ❌ MISS ❌ ❌ ❌")
            print("No face at crosshair position")
            
            // Light feedback for miss
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        }
        
        print(String(repeating: "=", count: 50) + "\n")
        
        // Cooldown
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            demoState.shootingCooldown = false
        }
    }
    
    private func distanceFromCenter(rect: CGRect, to point: CGPoint) -> CGFloat {
        let rectCenter = CGPoint(x: rect.midX, y: rect.midY)
        let dx = point.x - rectCenter.x
        let dy = point.y - rectCenter.y
        return sqrt(dx * dx + dy * dy)
    }
}

// MARK: - AR Demo State

class ARDemoState: ObservableObject {
    @Published var detectedPlayers: [DetectedPlayer] = []
    @Published var totalShots: Int = 0
    @Published var successfulHits: Int = 0
    @Published var shootingCooldown: Bool = false
    
    // Weak reference to avoid retain cycle
    weak var arCoordinator: AnyObject?
    
    func resetStats() {
        totalShots = 0
        successfulHits = 0
    }
}

// MARK: - AR Demo Container

struct ARDemoContainer: UIViewRepresentable {
    
    @ObservedObject var demoState: ARDemoState
    
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
        
        // Store coordinator reference for sphere throwing
        demoState.arCoordinator = coordinator
        
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
        context.coordinator.viewportSize = uiView.bounds.size
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(demoState: demoState)
    }
    
    static func dismantleUIView(_ uiView: ARView, coordinator: Coordinator) {
        uiView.session.pause()
    }
    
    // MARK: - Coordinator
    
    class Coordinator: NSObject, ARSessionDelegate {
        
        let demoState: ARDemoState
        weak var arView: ARView?
        var viewportSize: CGSize = .zero
        
        private var visionDetector: VisionDemoDetector?
        private var frameCounter: Int = 0
        private let frameSkip: Int = 3
        
        init(demoState: ARDemoState) {
            self.demoState = demoState
            super.init()
            self.visionDetector = VisionDemoDetector(demoState: demoState)
        }
        
        func session(_ session: ARSession, didUpdate frame: ARFrame) {
            frameCounter += 1
            if frameCounter % frameSkip != 0 {
                return
            }
            
            let pixelBuffer = frame.capturedImage
            let orientation = CGImagePropertyOrientation.right
            
            visionDetector?.detectPlayers(
                in: pixelBuffer,
                orientation: orientation,
                viewportSize: viewportSize
            )
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
                materials: [SimpleMaterial(color: .cyan, isMetallic: true)]
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

// MARK: - Vision Demo Detector

class VisionDemoDetector {
    
    private var bodyPoseRequest: VNDetectHumanBodyPoseRequest?
    private var faceDetectionRequest: VNDetectFaceRectanglesRequest?
    
    weak var demoState: ARDemoState?
    
    init(demoState: ARDemoState) {
        self.demoState = demoState
        setupRequests()
    }
    
    private func setupRequests() {
        bodyPoseRequest = VNDetectHumanBodyPoseRequest()
        faceDetectionRequest = VNDetectFaceRectanglesRequest()
    }
    
    func detectPlayers(in pixelBuffer: CVPixelBuffer,
                      orientation: CGImagePropertyOrientation,
                      viewportSize: CGSize) {
        
        guard let bodyRequest = bodyPoseRequest else { return }
        
        let requestHandler = VNImageRequestHandler(
            cvPixelBuffer: pixelBuffer,
            orientation: orientation,
            options: [:]
        )
        
        do {
            try requestHandler.perform([bodyRequest])
            
            guard let bodyObservations = bodyRequest.results else {
                updateDetectedPlayers([])
                return
            }
            
            var detectedPlayersData: [(faceRect: CGRect, bodyJoints: [BodyJoint])] = []
            
            for bodyObservation in bodyObservations {
                guard let bodyBounds = calculateBoundingBox(from: bodyObservation) else {
                    continue
                }
                
                let bodyJoints = extractBodyJoints(from: bodyObservation, viewportSize: viewportSize)
                
                let faceRequest = VNDetectFaceRectanglesRequest()
                faceRequest.regionOfInterest = bodyBounds
                
                let faceHandler = VNImageRequestHandler(
                    cvPixelBuffer: pixelBuffer,
                    orientation: orientation,
                    options: [:]
                )
                
                try? faceHandler.perform([faceRequest])
                
                if let faceObservations = faceRequest.results {
                    for faceObservation in faceObservations {
                        let screenRect = convertToScreenCoordinates(
                            normalizedRect: faceObservation.boundingBox,
                            viewportSize: viewportSize
                        )
                        detectedPlayersData.append((faceRect: screenRect, bodyJoints: bodyJoints))
                    }
                }
            }
            
            updateDetectedPlayers(detectedPlayersData)
            
        } catch {
            updateDetectedPlayers([])
        }
    }
    
    // Helper methods (same as VisionDetector)
    private func calculateBoundingBox(from bodyObservation: VNHumanBodyPoseObservation) -> CGRect? {
        guard let recognizedPoints = try? bodyObservation.recognizedPoints(.all) else {
            return nil
        }
        
        let validPoints = recognizedPoints.values.filter { $0.confidence > 0.3 }
        guard !validPoints.isEmpty else { return nil }
        
        var minX: CGFloat = 1.0
        var minY: CGFloat = 1.0
        var maxX: CGFloat = 0.0
        var maxY: CGFloat = 0.0
        
        for point in validPoints {
            let location = point.location
            minX = min(minX, location.x)
            minY = min(minY, location.y)
            maxX = max(maxX, location.x)
            maxY = max(maxY, location.y)
        }
        
        let padding: CGFloat = 0.1
        let width = maxX - minX
        let height = maxY - minY
        
        minX = max(0, minX - width * padding)
        minY = max(0, minY - height * padding)
        maxX = min(1, maxX + width * padding)
        maxY = min(1, maxY + height * padding)
        
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
    
    private func extractBodyJoints(from bodyObservation: VNHumanBodyPoseObservation, viewportSize: CGSize) -> [BodyJoint] {
        var joints: [BodyJoint] = []
        
        guard let recognizedPoints = try? bodyObservation.recognizedPoints(.all) else {
            return joints
        }
        
        let jointNames: [VNHumanBodyPoseObservation.JointName] = [
            .nose, .leftEye, .rightEye, .leftEar, .rightEar, .neck,
            .leftShoulder, .rightShoulder, .leftElbow, .rightElbow,
            .leftWrist, .rightWrist, .root, .leftHip, .rightHip,
            .leftKnee, .rightKnee, .leftAnkle, .rightAnkle
        ]
        
        for jointName in jointNames {
            if let point = recognizedPoints[jointName] {
                let location = point.location
                let screenPoint = convertPointToScreenCoordinates(
                    normalizedPoint: location,
                    viewportSize: viewportSize
                )
                
                let joint = BodyJoint(
                    name: jointName.rawValue.rawValue,
                    position: screenPoint,
                    confidence: point.confidence
                )
                joints.append(joint)
            }
        }
        
        return joints
    }
    
    private func convertPointToScreenCoordinates(normalizedPoint: CGPoint, viewportSize: CGSize) -> CGPoint {
        let x = normalizedPoint.x * viewportSize.width
        let y = (1 - normalizedPoint.y) * viewportSize.height
        return CGPoint(x: x, y: y)
    }
    
    private func convertToScreenCoordinates(normalizedRect: CGRect, viewportSize: CGSize) -> CGRect {
        let w = normalizedRect.width * viewportSize.width
        let h = normalizedRect.height * viewportSize.height
        let x = normalizedRect.minX * viewportSize.width
        let y = (1 - normalizedRect.maxY) * viewportSize.height
        
        return CGRect(x: x, y: y, width: w, height: h)
    }
    
    private func updateDetectedPlayers(_ playersData: [(faceRect: CGRect, bodyJoints: [BodyJoint])]) {
        guard let demoState = demoState else { return }
        
        var detectedPlayers: [DetectedPlayer] = []
        
        for (index, playerData) in playersData.enumerated() {
            let detected = DetectedPlayer(
                playerID: UUID(),
                playerName: "Person \(index + 1)",
                faceRect: playerData.faceRect,
                bodyJoints: playerData.bodyJoints
            )
            detectedPlayers.append(detected)
        }
        
        DispatchQueue.main.async {
            demoState.detectedPlayers = detectedPlayers
        }
    }
}

// MARK: - Body Tracking Demo Overlay

struct BodyTrackingDemoOverlay: View {
    
    let detectedPlayers: [DetectedPlayer]
    
    var body: some View {
        GeometryReader { geometry in
            ForEach(detectedPlayers, id: \.playerID) { detected in
                // Draw body joints
                ForEach(detected.bodyJoints) { joint in
                    BodyJointPoint(joint: joint)
                        .position(joint.position)
                }
                
                // Draw skeleton
                BodySkeletonView(joints: detected.bodyJoints)
                
                // Face box with enhanced marking
                let screenCenter = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
                let isTargeted = detected.faceRect.contains(screenCenter)
                
                // Face bounding box overlay
                ZStack {
                    // Thick colored border
                    Rectangle()
                        .stroke(isTargeted ? Color.green : Color.cyan, lineWidth: 4)
                        .frame(width: detected.faceRect.width, height: detected.faceRect.height)
                        .position(x: detected.faceRect.midX, y: detected.faceRect.midY)
                        .shadow(color: isTargeted ? .green : .cyan, radius: 8)
                    
                    // Corner brackets
                    DemoCornerBrackets2(
                        width: detected.faceRect.width,
                        height: detected.faceRect.height,
                        color: isTargeted ? .green : .cyan
                    )
                    .position(x: detected.faceRect.midX, y: detected.faceRect.midY)
                    
                    // Pulsing effect when targeted
                    if isTargeted {
                        Rectangle()
                            .fill(Color.green.opacity(0.1))
                            .frame(width: detected.faceRect.width, height: detected.faceRect.height)
                            .position(x: detected.faceRect.midX, y: detected.faceRect.midY)
                    }
                }
                
                // Face info overlay
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
                    .background(isTargeted ? Color.green : Color.cyan)
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
                }
                .position(x: detected.faceRect.midX, y: detected.faceRect.minY - 30)
                .animation(.easeInOut(duration: 0.3), value: isTargeted)
            }
        }
    }
}

// MARK: - Demo Corner Brackets

struct DemoCornerBrackets2: View {
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

// MARK: - UI Components

struct FeatureTag: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
            Text(text)
                .font(.caption)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.white.opacity(0.2))
        .cornerRadius(6)
    }
}

struct StatBadge: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.cyan)
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            Text(label)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.7))
        }
    }
}

