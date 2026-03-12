//
//  ProdigyVimView.swift
//  Kyozo
//
//  Created by Loc Nguyen on 8/16/25.
//



## ProdigyVimView.swift - REAL VIM WITH VISUAL CHAOS
```swift
import SwiftUI
import SpriteKit
import Metal
import AVFoundation

struct ProdigyVimView: View {
    @StateObject private var vim = VimCore()
    @StateObject private var claude = ProdigyClaude()
    @State private var particleIntensity: Double = 100
    @State private var screenShake: CGFloat = 0
    
    var body: some View {
        ZStack {
            // REAL VIM EDITOR
            VimEditorView(document: $vim.document)
                .offset(x: screenShake)
                .animation(.spring(response: 0.1), value: screenShake)
            
            // Claude overlay at 120fps MINIMUM
            SpriteView(
                scene: claude.scene,
                options: [.allowsTransparency, .ignoresSiblingOrder],
                preferredFramesPerSecond: 120
            )
            .allowsHitTesting(false)
            .ignoresSafeArea()
            
            // Visual effects layer
            ParticleFieldView(intensity: particleIntensity)
                .blendMode(.screen)
                .allowsHitTesting(false)
        }
        .onReceive(vim.$lastCommand) { command in
            handleVimCommand(command)
        }
    }
    
    private func handleVimCommand(_ command: String) {
        switch command {
        case ":w":
            // SAVE = MASSIVE CELEBRATION
            claude.doFlyingSpinningFart(mega: true)
            screenShake = 10
            withAnimation(.spring()) {
                screenShake = 0
            }
            
        case "dd":
            // DELETE LINE = Claude eats it
            claude.eatLine()
            
        case "i", "a", "o":
            // INSERT MODE = Rainbow mode
            claude.activateRainbowMode()
            particleIntensity = 200
            
        case "v", "V":
            // VISUAL MODE = Lightning effects
            claude.activateLightningMode()
            
        case ":!":
            // SHELL COMMAND = ROCKET MODE
            claude.blastOff()
            
        case "gg":
            // TOP OF FILE = Claude teleports
            claude.teleportToTop()
            
        case "G":
            // BOTTOM OF FILE = Claude falls
            claude.fallToBottom()
            
        case "/":
            // SEARCH = Detective Claude
            claude.activateDetectiveMode()
            
        default:
            // Any typing = small fart propulsion
            if vim.mode == .insert {
                claude.microFart()
            }
        }
    }
}

