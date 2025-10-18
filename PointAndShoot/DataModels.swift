//
//  DataModels.swift
//  PointAndShoot
//
//  Core data models for player information and network packets
//

import Foundation
import simd
import UIKit

// MARK: - Player Model

/// Represents a player in the game with their identity and face geometry data
struct Player: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var faceGeometry: [SIMD3<Float>]  // Vertices from ARFaceGeometry
    
    init(id: UUID = UUID(), name: String, faceGeometry: [SIMD3<Float>] = []) {
        self.id = id
        self.name = name
        self.faceGeometry = faceGeometry
    }
    
    static func == (lhs: Player, rhs: Player) -> Bool {
        return lhs.id == rhs.id
    }
    
    // Custom Codable implementation to handle SIMD3
    enum CodingKeys: String, CodingKey {
        case id, name, faceGeometry
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        
        // Decode face geometry as array of arrays
        let geometryArrays = try container.decode([[Float]].self, forKey: .faceGeometry)
        faceGeometry = geometryArrays.map { SIMD3<Float>($0[0], $0[1], $0[2]) }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        
        // Encode face geometry as array of arrays
        let geometryArrays = faceGeometry.map { [$0.x, $0.y, $0.z] }
        try container.encode(geometryArrays, forKey: .faceGeometry)
    }
}

// MARK: - GamePacket Enum

/// Network messages exchanged between players
enum GamePacket: Codable {
    case playerData(Player)                      // Send player profile after scanning
    case playerHit(targetPlayerID: UUID)         // Notify when a player is hit
    case playerHealthUpdate(playerID: UUID, health: Int)  // Sync health status
    case gameStart                               // Signal to start the game
    
    // Custom coding keys for enum with associated values
    private enum CodingKeys: String, CodingKey {
        case type
        case player
        case targetPlayerID
        case playerID
        case health
    }
    
    private enum PacketType: String, Codable {
        case playerData
        case playerHit
        case playerHealthUpdate
        case gameStart
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(PacketType.self, forKey: .type)
        
        switch type {
        case .playerData:
            let player = try container.decode(Player.self, forKey: .player)
            self = .playerData(player)
        case .playerHit:
            let targetID = try container.decode(UUID.self, forKey: .targetPlayerID)
            self = .playerHit(targetPlayerID: targetID)
        case .playerHealthUpdate:
            let playerID = try container.decode(UUID.self, forKey: .playerID)
            let health = try container.decode(Int.self, forKey: .health)
            self = .playerHealthUpdate(playerID: playerID, health: health)
        case .gameStart:
            self = .gameStart
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .playerData(let player):
            try container.encode(PacketType.playerData, forKey: .type)
            try container.encode(player, forKey: .player)
        case .playerHit(let targetPlayerID):
            try container.encode(PacketType.playerHit, forKey: .type)
            try container.encode(targetPlayerID, forKey: .targetPlayerID)
        case .playerHealthUpdate(let playerID, let health):
            try container.encode(PacketType.playerHealthUpdate, forKey: .type)
            try container.encode(playerID, forKey: .playerID)
            try container.encode(health, forKey: .health)
        case .gameStart:
            try container.encode(PacketType.gameStart, forKey: .type)
        }
    }
}

// MARK: - Detected Player Info

/// Runtime structure to track detected players in AR view
struct DetectedPlayer {
    let playerID: UUID
    let playerName: String
    let faceRect: CGRect  // Screen-space bounding box
    let bodyJoints: [BodyJoint]  // Body tracking points
    var silhouetteImage: UIImage?  // Optional colored silhouette overlay
}

/// Body joint tracking point
struct BodyJoint: Identifiable {
    let id = UUID()
    let name: String
    let position: CGPoint  // Screen-space coordinates
    let confidence: Float
    
    var isHighConfidence: Bool {
        return confidence > 0.5
    }
}

