//
//  VisionDetector.swift
//  PointAndShoot
//
//  Handles real-time player detection using Vision framework
//

import Foundation
import Vision
import CoreImage
import ARKit

class VisionDetector {
    
    // MARK: - Properties
    
    private var bodyPoseRequest: VNDetectHumanBodyPoseRequest?
    private var faceDetectionRequest: VNDetectFaceRectanglesRequest?
    
    weak var gameState: GameState?
    
    // Background queue for Vision processing to avoid blocking main thread
    private let visionQueue = DispatchQueue(label: "com.pointandshoot.vision", qos: .userInitiated)
    
    // MARK: - Initialization
    
    init(gameState: GameState) {
        self.gameState = gameState
        setupRequests()
    }
    
    private func setupRequests() {
        // Body pose detection request with optimizations
        bodyPoseRequest = VNDetectHumanBodyPoseRequest()
        bodyPoseRequest?.revision = VNDetectHumanBodyPoseRequestRevision1  // Use specific revision
        
        // Face detection request with optimizations
        faceDetectionRequest = VNDetectFaceRectanglesRequest()
        faceDetectionRequest?.revision = VNDetectFaceRectanglesRequestRevision3  // Latest stable
    }
    
    // MARK: - Detection Methods
    
    /// Process a camera frame to detect players
    /// This is a two-stage detection:
    /// 1. Detect human bodies (fast, works at distance)
    /// 2. For each body, detect face in that region (precise)
    func detectPlayers(in pixelBuffer: CVPixelBuffer, 
                      orientation: CGImagePropertyOrientation,
                      viewportSize: CGSize) {
        
        guard let bodyRequest = bodyPoseRequest else { return }
        
        // Perform detection on background queue to avoid blocking AR rendering
        visionQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Create image request handler
            let requestHandler = VNImageRequestHandler(
                cvPixelBuffer: pixelBuffer,
                orientation: orientation,
                options: [:]
            )
            
            do {
                // First: Detect human bodies
                try requestHandler.perform([bodyRequest])
            
                guard let bodyObservations = bodyRequest.results else {
                    self.updateDetectedPlayers([])
                    return
                }
                
                // Second: For each body, detect faces in that region and extract joints
                var detectedPlayersData: [(faceRect: CGRect, bodyJoints: [BodyJoint])] = []
                
                for bodyObservation in bodyObservations {
                    // Calculate bounding box from body pose joints
                    guard let bodyBounds = self.calculateBoundingBox(from: bodyObservation) else {
                        continue
                    }
                    
                    // Extract body joints
                    let bodyJoints = self.extractBodyJoints(from: bodyObservation, viewportSize: viewportSize)
                
                    // Create a face detection request with region of interest
                    let faceRequest = VNDetectFaceRectanglesRequest()
                    faceRequest.regionOfInterest = bodyBounds
                    
                    // Perform face detection in the body region
                    let faceHandler = VNImageRequestHandler(
                        cvPixelBuffer: pixelBuffer,
                        orientation: orientation,
                        options: [:]
                    )
                    
                    try? faceHandler.perform([faceRequest])
                    
                    if let faceObservations = faceRequest.results {
                        for faceObservation in faceObservations {
                            // Convert normalized coordinates to screen coordinates
                            let screenRect = self.convertToScreenCoordinates(
                                normalizedRect: faceObservation.boundingBox,
                                viewportSize: viewportSize
                            )
                            detectedPlayersData.append((faceRect: screenRect, bodyJoints: bodyJoints))
                        }
                    }
                }
                
                // Update game state with detected faces and body joints
                self.updateDetectedPlayers(detectedPlayersData)
                
            } catch {
                print("Error performing vision requests: \(error.localizedDescription)")
                self.updateDetectedPlayers([])
            }
        }
    }
    
    // MARK: - Helper Methods
    
    /// Calculate bounding box from body pose observation
    private func calculateBoundingBox(from bodyObservation: VNHumanBodyPoseObservation) -> CGRect? {
        // Get all recognized body points
        guard let recognizedPoints = try? bodyObservation.recognizedPoints(.all) else {
            return nil
        }
        
        // Filter for high-confidence points
        let validPoints = recognizedPoints.values.filter { $0.confidence > 0.3 }
        guard !validPoints.isEmpty else { return nil }
        
        // Find min/max coordinates to create bounding box
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
        
        // Add padding (10% on each side)
        let padding: CGFloat = 0.1
        let width = maxX - minX
        let height = maxY - minY
        
        minX = max(0, minX - width * padding)
        minY = max(0, minY - height * padding)
        maxX = min(1, maxX + width * padding)
        maxY = min(1, maxY + height * padding)
        
        return CGRect(
            x: minX,
            y: minY,
            width: maxX - minX,
            height: maxY - minY
        )
    }
    
    /// Convert Vision's normalized coordinates to screen coordinates
    /// Vision uses bottom-left origin (0,0), while UIKit uses top-left
    private func convertToScreenCoordinates(normalizedRect: CGRect, viewportSize: CGSize) -> CGRect {
        let w = normalizedRect.width * viewportSize.width
        let h = normalizedRect.height * viewportSize.height
        let x = normalizedRect.minX * viewportSize.width
        // Flip Y coordinate (Vision is bottom-left, UIKit is top-left)
        let y = (1 - normalizedRect.maxY) * viewportSize.height
        
        return CGRect(x: x, y: y, width: w, height: h)
    }
    
    /// Extract body joints from body pose observation
    private func extractBodyJoints(from bodyObservation: VNHumanBodyPoseObservation, viewportSize: CGSize) -> [BodyJoint] {
        var joints: [BodyJoint] = []
        
        // Get all recognized body points
        guard let recognizedPoints = try? bodyObservation.recognizedPoints(.all) else {
            return joints
        }
        
        // Define the joints we want to track and display
        let jointNames: [VNHumanBodyPoseObservation.JointName] = [
            .nose,
            .leftEye, .rightEye,
            .leftEar, .rightEar,
            .neck,
            .leftShoulder, .rightShoulder,
            .leftElbow, .rightElbow,
            .leftWrist, .rightWrist,
            .root, // Center of body
            .leftHip, .rightHip,
            .leftKnee, .rightKnee,
            .leftAnkle, .rightAnkle
        ]
        
        for jointName in jointNames {
            if let point = recognizedPoints[jointName] {
                // Convert normalized coordinates to screen coordinates
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
    
    /// Convert a single point from normalized to screen coordinates
    private func convertPointToScreenCoordinates(normalizedPoint: CGPoint, viewportSize: CGSize) -> CGPoint {
        let x = normalizedPoint.x * viewportSize.width
        // Flip Y coordinate (Vision is bottom-left, UIKit is top-left)
        let y = (1 - normalizedPoint.y) * viewportSize.height
        return CGPoint(x: x, y: y)
    }
    
    /// Update game state with detected players
    /// Simple association: match detected faces with connected players in order
    private func updateDetectedPlayers(_ playersData: [(faceRect: CGRect, bodyJoints: [BodyJoint])]) {
        guard let gameState = gameState else { return }
        
        let connectedPlayers = MultipeerManager.shared.connectedPlayers
        var detectedPlayers: [DetectedPlayer] = []
        
        // Simple matching: associate each detected face with a player
        // For a production app, you'd use feature matching with the stored faceGeometry
        for (index, playerData) in playersData.enumerated() {
            if index < connectedPlayers.count {
                let player = connectedPlayers[index]
                let detected = DetectedPlayer(
                    playerID: player.id,
                    playerName: player.name,
                    faceRect: playerData.faceRect,
                    bodyJoints: playerData.bodyJoints
                )
                detectedPlayers.append(detected)
            } else {
                // Unknown player (shouldn't happen in controlled multiplayer)
                // You could add logic here to identify unknown players
                break
            }
        }
        
        // Update game state on main thread
        DispatchQueue.main.async {
            gameState.detectedPlayers = detectedPlayers
        }
    }
    
    /// Alternative: More sophisticated matching using face geometry
    /// This is a placeholder for production implementation
    /// You would compare detected face landmarks with stored faceGeometry
    private func matchFaceToPlayer(faceObservation: VNFaceObservation) -> UUID? {
        // In a production app, you would:
        // 1. Extract face landmarks from faceObservation
        // 2. Compare with stored Player.faceGeometry using feature matching
        // 3. Return the UUID of the best match
        // For this demo, we use simple index-based matching in updateDetectedPlayers
        return nil
    }
}

