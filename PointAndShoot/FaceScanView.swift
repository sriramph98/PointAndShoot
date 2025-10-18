//
//  FaceScanView.swift
//  PointAndShoot
//
//  AR view for scanning player's face using ARFaceTrackingConfiguration
//

import SwiftUI
import ARKit
import RealityKit

struct FaceScanView: View {
    
    let playerName: String
    let onScanComplete: () -> Void
    
    @State private var isFaceDetected: Bool = false
    @State private var scanProgress: Double = 0.0
    @State private var instructionText: String = "Position your face in the frame"
    
    var body: some View {
        ZStack {
            // AR View for face tracking
            FaceScanARViewContainer(
                isFaceDetected: $isFaceDetected,
                scanProgress: $scanProgress,
                instructionText: $instructionText,
                playerName: playerName,
                onScanComplete: onScanComplete
            )
            .ignoresSafeArea()
            
            // Overlay UI
            VStack {
                // Top instruction panel
                VStack(spacing: 10) {
                    Text(instructionText)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(15)
                    
                    if isFaceDetected {
                        // Progress bar
                        ProgressView(value: scanProgress, total: 1.0)
                            .progressViewStyle(.linear)
                            .tint(.green)
                            .frame(width: 250)
                            .padding()
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(10)
                    }
                }
                .padding(.top, 50)
                
                Spacer()
                
                // Face detection indicator
                HStack {
                    Circle()
                        .fill(isFaceDetected ? Color.green : Color.red)
                        .frame(width: 15, height: 15)
                    
                    Text(isFaceDetected ? "Face Detected" : "No Face Detected")
                        .foregroundColor(.white)
                        .font(.subheadline)
                }
                .padding()
                .background(Color.black.opacity(0.7))
                .cornerRadius(10)
                .padding(.bottom, 50)
            }
        }
    }
}

// MARK: - AR View Container

struct FaceScanARViewContainer: UIViewRepresentable {
    
    @Binding var isFaceDetected: Bool
    @Binding var scanProgress: Double
    @Binding var instructionText: String
    
    let playerName: String
    let onScanComplete: () -> Void
    
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        
        // Create coordinator and set as session delegate
        let coordinator = context.coordinator
        arView.session.delegate = coordinator
        coordinator.arView = arView
        
        // Check if device supports face tracking
        guard ARFaceTrackingConfiguration.isSupported else {
            DispatchQueue.main.async {
                self.instructionText = "Face tracking not supported on this device"
            }
            return arView
        }
        
        // Configure and start AR session
        let configuration = ARFaceTrackingConfiguration()
        configuration.isLightEstimationEnabled = true
        arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
        // Configuration is handled in makeUIView, no need to update
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(
            isFaceDetected: $isFaceDetected,
            scanProgress: $scanProgress,
            instructionText: $instructionText,
            playerName: playerName,
            onScanComplete: onScanComplete
        )
    }
    
    static func dismantleUIView(_ uiView: ARView, coordinator: Coordinator) {
        uiView.session.pause()
    }
    
    // MARK: - Coordinator
    
    class Coordinator: NSObject, ARSessionDelegate {
        
        @Binding var isFaceDetected: Bool
        @Binding var scanProgress: Double
        @Binding var instructionText: String
        
        let playerName: String
        let onScanComplete: () -> Void
        
        weak var arView: ARView?
        private var scanTimer: Timer?
        private var capturedFaceGeometry: [SIMD3<Float>]?
        private var hasCompletedScan = false
        
        init(isFaceDetected: Binding<Bool>,
             scanProgress: Binding<Double>,
             instructionText: Binding<String>,
             playerName: String,
             onScanComplete: @escaping () -> Void) {
            self._isFaceDetected = isFaceDetected
            self._scanProgress = scanProgress
            self._instructionText = instructionText
            self.playerName = playerName
            self.onScanComplete = onScanComplete
        }
        
        func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
            guard !hasCompletedScan else { return }
            
            // Look for face anchor
            for anchor in anchors {
                if let faceAnchor = anchor as? ARFaceAnchor {
                    DispatchQueue.main.async {
                        self.isFaceDetected = true
                        self.instructionText = "Hold still while scanning..."
                    }
                    
                    // Start scan timer if not already running
                    if scanTimer == nil {
                        startScanning(faceAnchor: faceAnchor)
                    }
                    
                    return
                }
            }
            
            // No face detected
            DispatchQueue.main.async {
                self.isFaceDetected = false
                self.instructionText = "Position your face in the frame"
                self.scanProgress = 0.0
            }
            
            // Cancel scan timer if face lost
            scanTimer?.invalidate()
            scanTimer = nil
        }
        
        private func startScanning(faceAnchor: ARFaceAnchor) {
            // Capture face geometry
            let geometry = faceAnchor.geometry
            var vertices: [SIMD3<Float>] = []
            
            // Extract vertex positions
            for i in 0..<geometry.vertices.count {
                vertices.append(geometry.vertices[i])
            }
            
            capturedFaceGeometry = vertices
            
            // Start progress animation
            let totalDuration: Double = 3.0
            let interval: Double = 0.1
            var elapsed: Double = 0.0
            
            scanTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] timer in
                guard let self = self else {
                    timer.invalidate()
                    return
                }
                
                elapsed += interval
                let progress = min(elapsed / totalDuration, 1.0)
                
                DispatchQueue.main.async {
                    self.scanProgress = progress
                }
                
                if progress >= 1.0 {
                    timer.invalidate()
                    self.completeScan()
                }
            }
        }
        
        private func completeScan() {
            guard !hasCompletedScan else { return }
            hasCompletedScan = true
            
            DispatchQueue.main.async {
                self.instructionText = "Scan complete!"
                
                // Create player with scanned face data
                let player = Player(
                    name: self.playerName,
                    faceGeometry: self.capturedFaceGeometry ?? []
                )
                
                // Store in multipeer manager
                MultipeerManager.shared.localPlayer = player
                
                // Send to connected peers
                MultipeerManager.shared.send(packet: .playerData(player))
                
                // Wait a moment then complete
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.onScanComplete()
                }
            }
        }
    }
}

