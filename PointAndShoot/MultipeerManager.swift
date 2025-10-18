//
//  MultipeerManager.swift
//  PointAndShoot
//
//  Manages all peer-to-peer networking using MultipeerConnectivity
//

import Foundation
import MultipeerConnectivity

class MultipeerManager: NSObject, ObservableObject {
    
    // MARK: - Singleton
    static let shared = MultipeerManager()
    
    // MARK: - Published Properties
    @Published var connectedPlayers: [Player] = []
    @Published var lastReceivedPacket: GamePacket?
    @Published var isHosting: Bool = false
    @Published var connectionStatus: String = "Not Connected"
    @Published var discoveredPeers: [MCPeerID] = []
    
    // MARK: - MultipeerConnectivity Properties
    private let serviceType = "pointandshoot"
    private var myPeerID: MCPeerID!
    private var session: MCSession!
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    
    var localPlayer: Player?
    
    // MARK: - Initialization
    private override init() {
        super.init()
        setupMultipeer()
    }
    
    private func setupMultipeer() {
        // Create a unique peer ID based on device name
        myPeerID = MCPeerID(displayName: UIDevice.current.name)
        
        // Create session
        session = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self
    }
    
    // MARK: - Public Methods
    
    /// Start hosting a game (advertise to nearby devices)
    func startAdvertising() {
        isHosting = true
        advertiser = MCNearbyServiceAdvertiser(peer: myPeerID, discoveryInfo: nil, serviceType: serviceType)
        advertiser?.delegate = self
        advertiser?.startAdvertisingPeer()
        connectionStatus = "Hosting..."
        print("Started advertising as host")
    }
    
    /// Start searching for a game to join
    func startBrowsing() {
        isHosting = false
        browser = MCNearbyServiceBrowser(peer: myPeerID, serviceType: serviceType)
        browser?.delegate = self
        browser?.startBrowsingForPeers()
        connectionStatus = "Searching for games..."
        print("Started browsing for peers")
    }
    
    /// Stop advertising and browsing
    func stopNetworking() {
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        advertiser = nil
        browser = nil
        connectionStatus = "Stopped"
        print("Stopped networking")
    }
    
    /// Send a game packet to all connected peers
    func send(packet: GamePacket) {
        guard !session.connectedPeers.isEmpty else {
            print("No connected peers to send to")
            return
        }
        
        do {
            let data = try JSONEncoder().encode(packet)
            try session.send(data, toPeers: session.connectedPeers, with: .reliable)
            print("Sent packet: \(packet)")
        } catch {
            print("Error sending packet: \(error.localizedDescription)")
        }
    }
    
    /// Connect to a specific peer
    func connectToPeer(_ peerID: MCPeerID) {
        guard let browser = browser else { return }
        print("Inviting peer: \(peerID.displayName)")
        browser.invitePeer(peerID, to: session, withContext: nil, timeout: 30)
    }
    
    /// Disconnect from all peers
    func disconnect() {
        session.disconnect()
        connectedPlayers.removeAll()
        discoveredPeers.removeAll()
        connectionStatus = "Disconnected"
    }
}

// MARK: - MCNearbyServiceAdvertiserDelegate

extension MultipeerManager: MCNearbyServiceAdvertiserDelegate {
    
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, 
                   didReceiveInvitationFromPeer peerID: MCPeerID, 
                   withContext context: Data?, 
                   invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        print("Received invitation from \(peerID.displayName)")
        // Automatically accept invitations when hosting
        invitationHandler(true, session)
    }
    
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, 
                   didNotStartAdvertisingPeer error: Error) {
        print("Error advertising: \(error.localizedDescription)")
        connectionStatus = "Error hosting"
    }
}

// MARK: - MCNearbyServiceBrowserDelegate

extension MultipeerManager: MCNearbyServiceBrowserDelegate {
    
    func browser(_ browser: MCNearbyServiceBrowser, 
                foundPeer peerID: MCPeerID, 
                withDiscoveryInfo info: [String : String]?) {
        print("Found peer: \(peerID.displayName)")
        
        // Add to discovered peers list (don't auto-invite)
        DispatchQueue.main.async {
            if !self.discoveredPeers.contains(peerID) {
                self.discoveredPeers.append(peerID)
            }
        }
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, 
                lostPeer peerID: MCPeerID) {
        print("Lost peer: \(peerID.displayName)")
        
        // Remove from discovered peers list
        DispatchQueue.main.async {
            self.discoveredPeers.removeAll { $0 == peerID }
        }
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, 
                didNotStartBrowsingForPeers error: Error) {
        print("Error browsing: \(error.localizedDescription)")
        connectionStatus = "Error searching"
    }
}

// MARK: - MCSessionDelegate

extension MultipeerManager: MCSessionDelegate {
    
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async {
            switch state {
            case .connected:
                print("Connected to \(peerID.displayName)")
                self.connectionStatus = "Connected to \(session.connectedPeers.count) player(s)"
                
                // Send our player data when connected
                if let localPlayer = self.localPlayer {
                    self.send(packet: .playerData(localPlayer))
                }
                
            case .connecting:
                print("Connecting to \(peerID.displayName)")
                self.connectionStatus = "Connecting..."
                
            case .notConnected:
                print("Not connected to \(peerID.displayName)")
                // Remove disconnected player
                self.connectedPlayers.removeAll { $0.name == peerID.displayName }
                self.connectionStatus = "Connected to \(session.connectedPeers.count) player(s)"
                
            @unknown default:
                break
            }
        }
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        do {
            let packet = try JSONDecoder().decode(GamePacket.self, from: data)
            print("Received packet: \(packet)")
            
            DispatchQueue.main.async {
                // Update connected players list if receiving player data
                if case .playerData(let player) = packet {
                    if !self.connectedPlayers.contains(where: { $0.id == player.id }) {
                        self.connectedPlayers.append(player)
                    }
                }
                
                // Publish the received packet
                self.lastReceivedPacket = packet
            }
        } catch {
            print("Error decoding packet: \(error.localizedDescription)")
        }
    }
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        // Not used in this implementation
    }
    
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        // Not used in this implementation
    }
    
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        // Not used in this implementation
    }
}

