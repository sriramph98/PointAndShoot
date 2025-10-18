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
        
        for detected in demoState.detectedPlayers {
            if detected.faceRect.contains(screenCenter) {
                demoState.successfulHits += 1
                
                // Visual feedback
                let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
                impactFeedback.impactOccurred()
                break
            }
        }
        
        // Cooldown
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            demoState.shootingCooldown = false
        }
    }
}

// MARK: - AR Demo State

class ARDemoState: ObservableObject {
    @Published var detectedPlayers: [DetectedPlayer] = []
    @Published var totalShots: Int = 0
    @Published var successfulHits: Int = 0
    @Published var shootingCooldown: Bool = false
    
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
                
                // Face overlay
                VStack(spacing: 4) {
                    Text(detected.playerName)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.cyan.opacity(0.8))
                        .cornerRadius(6)
                }
                .position(x: detected.faceRect.midX, y: detected.faceRect.minY - 20)
                .overlay(
                    Rectangle()
                        .stroke(Color.cyan, lineWidth: 2)
                        .frame(width: detected.faceRect.width, height: detected.faceRect.height)
                        .position(x: detected.faceRect.midX, y: detected.faceRect.midY)
                )
            }
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

