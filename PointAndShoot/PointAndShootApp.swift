//
//  PointAndShootApp.swift
//  PointAndShoot
//
//  Main app entry point
//

import SwiftUI

@main
struct PointAndShootApp: App {
    
    // Initialize game state as environment object
    @StateObject private var gameState = GameState()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(gameState)
                .statusBar(hidden: true)
        }
    }
}

