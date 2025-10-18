//
//  ContentView.swift
//  PointAndShoot
//
//  Main view that manages different game states
//

import SwiftUI

struct ContentView: View {
    
    @EnvironmentObject var gameState: GameState
    @StateObject private var multipeerManager = MultipeerManager.shared
    @State private var playerName: String = ""
    @State private var showingNameAlert: Bool = false
    @State private var appState: AppState = .initial
    
    enum AppState {
        case initial          // Enter name, choose to scan face
        case scanning         // Scanning face
        case profileReady     // Profile created, ready to host/join
        case lobby            // In lobby waiting
        case inGame           // Playing the game
        case gameOver         // Game finished
        case demoMode         // Testing AR features
    }
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [Color.black, Color.blue.opacity(0.3)]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            // Main content based on app state
            switch appState {
            case .initial:
                InitialView(
                    playerName: $playerName,
                    showingNameAlert: $showingNameAlert,
                    onScanFace: { appState = .scanning },
                    onTestAR: { appState = .demoMode }
                )
                
            case .scanning:
                ZStack(alignment: .topLeading) {
                    FaceScanView(
                        playerName: playerName,
                        onScanComplete: handleScanComplete
                    )
                    
                    // Back button
                    Button(action: {
                        appState = .initial
                    }) {
                        HStack {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(10)
                    }
                    .padding()
                }
                
            case .profileReady:
                NetworkingView(
                    playerName: playerName,
                    onConnected: { appState = .lobby },
                    onBack: { appState = .initial }
                )
                
            case .lobby:
                LobbyWaitingView(
                    onStartGame: startGame,
                    onLeave: {
                        multipeerManager.disconnect()
                        multipeerManager.stopNetworking()
                        appState = .profileReady
                    }
                )
                
            case .inGame:
                ZStack(alignment: .topTrailing) {
                    ARGameView()
                    
                    // Exit button
                    Button(action: {
                        let alert = UIAlertController(
                            title: "Leave Game?",
                            message: "Are you sure you want to leave the game?",
                            preferredStyle: .alert
                        )
                        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
                        alert.addAction(UIAlertAction(title: "Leave", style: .destructive) { _ in
                            resetGame()
                        })
                        
                        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                           let rootViewController = windowScene.windows.first?.rootViewController {
                            rootViewController.present(alert, animated: true)
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                    }
                    .padding()
                }
                
            case .gameOver:
                GameOverView(onRestart: resetGame)
                
            case .demoMode:
                ARDemoView(onExit: {
                    appState = .initial
                })
            }
        }
        .onAppear {
            // Show name input on first launch
            if playerName.isEmpty {
                showingNameAlert = true
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func handleScanComplete() {
        appState = .profileReady
    }
    
    private func startGame() {
        appState = .inGame
        gameState.gamePhase = .inGame
        // Notify peers that game is starting
        multipeerManager.send(packet: .gameStart)
    }
    
    private func resetGame() {
        gameState.resetGame()
        multipeerManager.disconnect()
        appState = .initial
        gameState.gamePhase = .lobby
    }
}

// MARK: - Initial View (Enter Name & Scan Face)

struct InitialView: View {
    
    @Binding var playerName: String
    @Binding var showingNameAlert: Bool
    var onScanFace: () -> Void
    var onTestAR: () -> Void
    
    var body: some View {
        VStack(spacing: 40) {
            
            Spacer()
            
            // Title
            Text("Point & Shoot")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            Text("AR Multiplayer Face Battle")
                .font(.headline)
                .foregroundColor(.white.opacity(0.8))
            
            Spacer()
            
            // Player info
            VStack(spacing: 15) {
                HStack {
                    Text("Player:")
                        .foregroundColor(.white)
                    Text(playerName.isEmpty ? "Not set" : playerName)
                        .foregroundColor(.cyan)
                        .fontWeight(.bold)
                    
                    Button(action: { showingNameAlert = true }) {
                        Image(systemName: "pencil.circle.fill")
                            .foregroundColor(.cyan)
                    }
                }
                .font(.title3)
            }
            .padding()
            .background(Color.white.opacity(0.1))
            .cornerRadius(15)
            .padding(.horizontal, 40)
            
            // Instructions
            VStack(spacing: 10) {
                Image(systemName: "faceid")
                    .font(.system(size: 60))
                    .foregroundColor(.purple)
                
                Text("First, let's scan your face")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text("We'll create your profile for multiplayer")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            .padding()
            
            Spacer()
            
            // Buttons
            VStack(spacing: 15) {
                // Scan Face Button
                Button(action: {
                    guard !playerName.isEmpty else {
                        showingNameAlert = true
                        return
                    }
                    onScanFace()
                }) {
                    Label("Scan Face", systemImage: "faceid")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.purple)
                        .cornerRadius(15)
                }
                
                // Test AR Features Button
                Button(action: onTestAR) {
                    HStack {
                        Image(systemName: "arkit")
                            .font(.title3)
                        Text("Test AR Features")
                            .font(.title3)
                            .fontWeight(.semibold)
                        Image(systemName: "target")
                            .font(.title3)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [Color.orange, Color.red],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(15)
                    .overlay(
                        RoundedRectangle(cornerRadius: 15)
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
                }
            }
            .padding(.horizontal, 40)
            
            // Helper text for demo mode
            Text("Try body tracking, face detection & shooting")
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
                .italic()
            
            Spacer()
        }
        .alert("Enter Your Name", isPresented: $showingNameAlert) {
            TextField("Name", text: $playerName)
            Button("OK", action: {})
        } message: {
            Text("Enter your player name to continue")
        }
    }
}

// MARK: - Networking View (Host or Join)

struct NetworkingView: View {
    
    let playerName: String
    var onConnected: () -> Void
    var onBack: () -> Void
    
    @StateObject private var multipeerManager = MultipeerManager.shared
    @State private var isBrowsing = false
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 30) {
                
                Spacer()
            
            // Profile Created Confirmation
            VStack(spacing: 15) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.green)
                
                Text("Profile Ready!")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text(playerName)
                    .font(.title2)
                    .foregroundColor(.cyan)
            }
            
            Spacer()
            
            // Show discovered hosts when browsing
            if isBrowsing {
                VStack(alignment: .leading, spacing: 15) {
                    HStack {
                        Text("Available Hosts:")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        // Refresh button
                        Button(action: {
                            multipeerManager.stopNetworking()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                multipeerManager.startBrowsing()
                            }
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(.cyan)
                                .font(.title3)
                        }
                    }
                    
                    if multipeerManager.discoveredPeers.isEmpty {
                        VStack(spacing: 10) {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(1.5)
                                .padding()
                            
                            Text("Searching for hosts...")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.7))
                                .italic()
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    } else {
                        ScrollView {
                            VStack(spacing: 10) {
                                ForEach(multipeerManager.discoveredPeers, id: \.self) { peer in
                                    HostCard(
                                        hostName: peer.displayName,
                                        onJoin: {
                                            multipeerManager.connectToPeer(peer)
                                        }
                                    )
                                }
                            }
                        }
                        .frame(maxHeight: 300)
                    }
                }
                .padding()
                .background(Color.white.opacity(0.1))
                .cornerRadius(15)
                .padding(.horizontal, 40)
            }
            
            // Connection status
            if multipeerManager.connectionStatus != "Not Connected" && !isBrowsing {
                VStack(spacing: 10) {
                    Text(multipeerManager.connectionStatus)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    if !multipeerManager.connectedPlayers.isEmpty {
                        Text("\(multipeerManager.connectedPlayers.count) player(s) connected")
                            .font(.subheadline)
                            .foregroundColor(.green)
                    }
                }
                .padding()
                .background(Color.white.opacity(0.1))
                .cornerRadius(15)
                .padding(.horizontal, 40)
            }
            
            Spacer()
            
            // Action buttons (only show if not browsing)
            if !isBrowsing {
                VStack(spacing: 10) {
                    Text("Choose how to connect:")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    VStack(spacing: 20) {
                        Button(action: {
                            multipeerManager.startAdvertising()
                            // Wait a moment then go to lobby
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                onConnected()
                            }
                        }) {
                            VStack(spacing: 8) {
                                Image(systemName: "wifi.circle.fill")
                                    .font(.system(size: 40))
                                Text("Host a Party")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 25)
                            .background(Color.green)
                            .cornerRadius(15)
                        }
                        
                        Button(action: {
                            isBrowsing = true
                            multipeerManager.startBrowsing()
                        }) {
                            VStack(spacing: 8) {
                                Image(systemName: "magnifyingglass.circle.fill")
                                    .font(.system(size: 40))
                                Text("Join a Party")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 25)
                            .background(Color.blue)
                            .cornerRadius(15)
                        }
                    }
                    .padding(.horizontal, 40)
                }
            }
            
                Spacer()
            }
            .onChange(of: multipeerManager.connectedPlayers.count) { oldValue, newValue in
                // Transition to lobby when connected
                if newValue > 0 && isBrowsing {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        onConnected()
                    }
                }
            }
            
            // Back button
            Button(action: {
                if isBrowsing {
                    isBrowsing = false
                    multipeerManager.stopNetworking()
                } else {
                    onBack()
                }
            }) {
                HStack {
                    Image(systemName: "chevron.left")
                    Text("Back")
                }
                .foregroundColor(.white)
                .padding()
                .background(Color.black.opacity(0.6))
                .cornerRadius(10)
            }
            .padding()
        }
    }
}

// MARK: - Host Card

struct HostCard: View {
    
    let hostName: String
    let onJoin: () -> Void
    
    var body: some View {
        Button(action: onJoin) {
            HStack {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 35))
                    .foregroundColor(.yellow)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(hostName)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text("HOST")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.yellow)
                }
                
                Spacer()
                
                Image(systemName: "arrow.right.circle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
            .padding()
            .background(Color.white.opacity(0.15))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Lobby Waiting View

struct LobbyWaitingView: View {
    
    var onStartGame: () -> Void
    var onLeave: () -> Void
    
    @StateObject private var multipeerManager = MultipeerManager.shared
    @StateObject private var gameState = GameState()
    @State private var showLeaveAlert = false
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 30) {
                
                Spacer()
                
                // Title
                Text("Party Lobby")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            
            if multipeerManager.isHosting {
                Text("You are the host")
                    .font(.headline)
                    .foregroundColor(.green)
            } else {
                Text("Waiting for host...")
                    .font(.headline)
                    .foregroundColor(.cyan)
            }
            
            Spacer()
            
            // Players in lobby
            VStack(alignment: .leading, spacing: 15) {
                Text("Players in Lobby:")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                // Local player
                if let localPlayer = multipeerManager.localPlayer {
                    PlayerLobbyCard(
                        playerName: "\(localPlayer.name) (You)",
                        isReady: true,
                        isHost: multipeerManager.isHosting
                    )
                }
                
                // Connected players
                ForEach(multipeerManager.connectedPlayers) { player in
                    PlayerLobbyCard(
                        playerName: player.name,
                        isReady: true,
                        isHost: false
                    )
                }
                
                if multipeerManager.connectedPlayers.isEmpty && multipeerManager.isHosting {
                    Text("Waiting for players to join...")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.6))
                        .italic()
                }
            }
            .padding()
            .background(Color.white.opacity(0.1))
            .cornerRadius(15)
            .padding(.horizontal, 40)
            
            Spacer()
            
            // Start game button (host only, or when game start received)
            if multipeerManager.isHosting {
                Button(action: onStartGame) {
                    Label("Start the Game", systemImage: "play.circle.fill")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(multipeerManager.connectedPlayers.isEmpty ? Color.gray : Color.orange)
                        .cornerRadius(15)
                }
                .padding(.horizontal, 40)
                .disabled(multipeerManager.connectedPlayers.isEmpty)
            } else {
                Text("Waiting for host to start...")
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.7))
                    .padding()
            }
            
                Spacer()
            }
            .onReceive(multipeerManager.$lastReceivedPacket) { packet in
                if case .gameStart = packet {
                    onStartGame()
                }
            }
            
            // Leave/Back button
            Button(action: {
                showLeaveAlert = true
            }) {
                HStack {
                    Image(systemName: "chevron.left")
                    Text("Leave")
                }
                .foregroundColor(.white)
                .padding()
                .background(Color.red.opacity(0.8))
                .cornerRadius(10)
            }
            .padding()
        }
        .alert("Leave Lobby?", isPresented: $showLeaveAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Leave", role: .destructive) {
                onLeave()
            }
        } message: {
            Text("Are you sure you want to leave the lobby?")
        }
    }
}

// MARK: - Player Lobby Card

struct PlayerLobbyCard: View {
    
    let playerName: String
    let isReady: Bool
    let isHost: Bool
    
    var body: some View {
        HStack {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 30))
                .foregroundColor(isHost ? .yellow : .cyan)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(playerName)
                    .font(.headline)
                    .foregroundColor(.white)
                
                if isHost {
                    Text("HOST")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.yellow)
                }
            }
            
            Spacer()
            
            if isReady {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title3)
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(10)
    }
}

// MARK: - Game Over View

struct GameOverView: View {
    
    var onRestart: () -> Void
    @EnvironmentObject var gameState: GameState
    
    var body: some View {
        VStack(spacing: 30) {
            Text("Game Over")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            // Show final scores
            VStack(alignment: .leading, spacing: 15) {
                Text("Final Scores:")
                    .font(.title2)
                    .foregroundColor(.white)
                
                ForEach(Array(gameState.playerHealths.keys), id: \.self) { playerID in
                    if let health = gameState.playerHealths[playerID] {
                        HStack {
                            Text(getPlayerName(for: playerID))
                                .foregroundColor(.white)
                            Spacer()
                            Text("Health: \(health)")
                                .foregroundColor(health > 0 ? .green : .red)
                        }
                    }
                }
            }
            .padding()
            .background(Color.white.opacity(0.1))
            .cornerRadius(15)
            .padding(.horizontal, 40)
            
            Button(action: onRestart) {
                Label("Return to Lobby", systemImage: "arrow.counterclockwise.circle.fill")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(15)
            }
            .padding(.horizontal, 40)
        }
    }
    
    private func getPlayerName(for playerID: UUID) -> String {
        if let player = MultipeerManager.shared.connectedPlayers.first(where: { $0.id == playerID }) {
            return player.name
        }
        if let localPlayer = MultipeerManager.shared.localPlayer, localPlayer.id == playerID {
            return "\(localPlayer.name) (You)"
        }
        return "Unknown Player"
    }
}

#Preview {
    ContentView()
        .environmentObject(GameState())
}

