//
//  GameState.swift
//  PointAndShoot
//
//  Manages overall game state, player health, and game logic
//

import Foundation
import Combine

class GameState: ObservableObject {
    
    // MARK: - Published Properties
    @Published var playerHealths: [UUID: Int] = [:]
    @Published var detectedPlayers: [DetectedPlayer] = []
    @Published var gamePhase: GamePhase = .lobby
    @Published var shootingCooldown: Bool = false
    @Published var showHitEffect: Bool = false
    @Published var debugMode: Bool = false
    
    // MARK: - Constants
    static let maxHealth = 100
    static let damagePerHit = 20
    static let shootCooldownSeconds = 0.5
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init() {
        // Subscribe to multipeer manager for network events
        MultipeerManager.shared.$lastReceivedPacket
            .sink { [weak self] packet in
                self?.handleReceivedPacket(packet)
            }
            .store(in: &cancellables)
        
        // Subscribe to connected players to initialize health
        MultipeerManager.shared.$connectedPlayers
            .sink { [weak self] players in
                self?.initializeHealthForPlayers(players)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Game Phase Management
    enum GamePhase {
        case lobby
        case scanning
        case inGame
        case gameOver
    }
    
    // MARK: - Public Methods
    
    /// Initialize health for all players
    func initializeHealthForPlayers(_ players: [Player]) {
        for player in players {
            if playerHealths[player.id] == nil {
                playerHealths[player.id] = GameState.maxHealth
            }
        }
        
        // Also initialize local player
        if let localPlayer = MultipeerManager.shared.localPlayer {
            if playerHealths[localPlayer.id] == nil {
                playerHealths[localPlayer.id] = GameState.maxHealth
            }
        }
    }
    
    /// Handle a successful hit on a target player
    func registerHit(on targetPlayerID: UUID) {
        guard !shootingCooldown else { return }
        
        // Apply cooldown
        shootingCooldown = true
        DispatchQueue.main.asyncAfter(deadline: .now() + GameState.shootCooldownSeconds) {
            self.shootingCooldown = false
        }
        
        // Send hit notification to network
        MultipeerManager.shared.send(packet: .playerHit(targetPlayerID: targetPlayerID))
        
        // Apply damage locally
        applyDamage(to: targetPlayerID)
    }
    
    /// Apply damage to a player
    private func applyDamage(to playerID: UUID) {
        guard var health = playerHealths[playerID] else { return }
        
        health -= GameState.damagePerHit
        health = max(0, health)
        playerHealths[playerID] = health
        
        print("Player \(playerID) took damage. Health: \(health)")
        
        // Broadcast health update
        MultipeerManager.shared.send(packet: .playerHealthUpdate(playerID: playerID, health: health))
        
        // Check for game over
        if health <= 0 {
            handlePlayerEliminated(playerID)
        }
    }
    
    /// Handle player elimination
    private func handlePlayerEliminated(_ playerID: UUID) {
        print("Player \(playerID) eliminated!")
        
        // Check if only one player remains
        let alivePlayers = playerHealths.filter { $0.value > 0 }
        if alivePlayers.count <= 1 {
            gamePhase = .gameOver
        }
    }
    
    /// Reset the game state
    func resetGame() {
        playerHealths.removeAll()
        detectedPlayers.removeAll()
        gamePhase = .lobby
        shootingCooldown = false
        
        // Reinitialize health for connected players
        initializeHealthForPlayers(MultipeerManager.shared.connectedPlayers)
        if let localPlayer = MultipeerManager.shared.localPlayer {
            initializeHealthForPlayers([localPlayer])
        }
    }
    
    // MARK: - Network Packet Handling
    
    private func handleReceivedPacket(_ packet: GamePacket?) {
        guard let packet = packet else { return }
        
        switch packet {
        case .playerData(let player):
            // Health already initialized by subscription to connectedPlayers
            print("Received player data for \(player.name)")
            
        case .playerHit(let targetPlayerID):
            // Apply damage to the target
            applyDamage(to: targetPlayerID)
            
        case .playerHealthUpdate(let playerID, let health):
            // Sync health from network
            playerHealths[playerID] = health
            
        case .gameStart:
            // Start the game
            gamePhase = .inGame
        }
    }
    
    /// Get health for a specific player
    func getHealth(for playerID: UUID) -> Int {
        return playerHealths[playerID] ?? GameState.maxHealth
    }
    
    /// Check if a point intersects with any detected player's face
    func findTargetPlayer(at point: CGPoint) -> UUID? {
        for detected in detectedPlayers {
            if detected.faceRect.contains(point) {
                return detected.playerID
            }
        }
        return nil
    }
}

