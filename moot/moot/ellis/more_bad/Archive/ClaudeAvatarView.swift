//
//  ClaudeAvatarView.swift
//  Kyozo
//
//  Created by Loc Nguyen on 8/16/25.
//



## ClaudeAvatarView.swift - CLAUDE WALKING AROUND
```swift
import SwiftUI
import SpriteKit
import SceneKit
import RealityKit

struct ClaudeAvatarView: View {
    @StateObject private var avatar = ClaudeAvatarEngine()
    @State private var claudeMessage = ""
    @State private var isThinking = false
    
    var body: some View {
        ZStack {
            // Main editor area
            Color.clear
            
            // Claude walking around
            SpriteView(scene: avatar.scene, options: [.allowsTransparency])
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(false)
            
            // Claude's speech bubble
            if !claudeMessage.isEmpty {
                ClaudeSpeechBubble(message: claudeMessage)
                    .position(avatar.position)
                    .offset(y: -40)
                    .animation(.spring(), value: avatar.position)
            }
            
            // Claude thinking indicator
            if isThinking {
                ClaudeThinkingView()
                    .position(avatar.position)
                    .offset(y: -20)
            }
        }
        .onReceive(avatar.$currentAction) { action in
            handleClaudeAction(action)
        }
    }
    
    private func handleClaudeAction(_ action: ClaudeAction) {
        switch action {
        case .walking:
            claudeMessage = ""
        case .thinking:
            isThinking = true
            claudeMessage = ""
        case .talking(let message):
            isThinking = false
            claudeMessage = message
        case .pointing(let location):
            claudeMessage = "Look here! 👆"
        case .celebrating:
            claudeMessage = "Great job! 🎉"
        case .confused:
            claudeMessage = "Hmm, let me think about that... 🤔"
        }
    }
}

