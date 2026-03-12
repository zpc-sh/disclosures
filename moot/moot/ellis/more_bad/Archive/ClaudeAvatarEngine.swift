//
//  ClaudeAvatarEngine.swift
//  Kyozo
//
//  Created by Loc Nguyen on 8/16/25.
//



class ClaudeAvatarEngine: ObservableObject {
    @Published var position = CGPoint(x: 100, y: 100)
    @Published var currentAction = ClaudeAction.walking
    
    let scene: SKScene
    private var claudeSprite: SKSpriteNode!
    private var walkingAtlas: SKTextureAtlas!
    private var thinkingAtlas: SKTextureAtlas!
    
    init() {
        scene = SKScene(size: CGSize(width: 1000, height: 1000))
        scene.backgroundColor = .clear
        
        setupClaude()
        startRandomWalking()
    }
    
    private func setupClaude() {
        // Load Claude sprite sheets
        walkingAtlas = SKTextureAtlas(named: "ClaudeWalking")
        thinkingAtlas = SKTextureAtlas(named: "ClaudeThinking")
        
        // Create Claude sprite (pixel art style)
        claudeSprite = SKSpriteNode(imageNamed: "claude_idle")
        claudeSprite.size = CGSize(width: 32, height: 32)
        claudeSprite.position = CGPoint(x: 100, y: 100)
        
        // Add physics for collision
        claudeSprite.physicsBody = SKPhysicsBody(rectangleOf: claudeSprite.size)
        claudeSprite.physicsBody?.isDynamic = true
        claudeSprite.physicsBody?.affectedByGravity = false
        
        scene.addChild(claudeSprite)
        
        // Start idle animation
        startIdleAnimation()
    }
    
    private func startIdleAnimation() {
        let idleFrames = [
            SKTexture(imageNamed: "claude_idle_1"),
            SKTexture(imageNamed: "claude_idle_2"),
            SKTexture(imageNamed: "claude_idle_3"),
            SKTexture(imageNamed: "claude_idle_2")
        ]
        
        let idleAnimation = SKAction.animate(with: idleFrames, timePerFrame: 0.2)
        claudeSprite.run(SKAction.repeatForever(idleAnimation), withKey: "idle")
    }
    
    func startWalking(in bounds: CGRect) {
        // Claude walks around randomly
        let walkFrames = walkingAtlas.textureNames.sorted().map { 
            walkingAtlas.textureNamed($0) 
        }
        
        let walkAnimation = SKAction.animate(with: walkFrames, timePerFrame: 0.1)
        claudeSprite.run(SKAction.repeatForever(walkAnimation), withKey: "walk")
        
        // Random movement
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            self.walkToRandomPosition(in: bounds)
        }
    }
    
    private func walkToRandomPosition(in bounds: CGRect) {
        let randomX = CGFloat.random(in: 50...(bounds.width - 50))
        let randomY = CGFloat.random(in: 50...(bounds.height - 50))
        let destination = CGPoint(x: randomX, y: randomY)
        
        // Calculate duration based on distance
        let distance = hypot(destination.x - claudeSprite.position.x,
                           destination.y - claudeSprite.position.y)
        let duration = distance / 100.0  // 100 pixels per second
        
        // Face the right direction
        if destination.x < claudeSprite.position.x {
            claudeSprite.xScale = -1  // Flip horizontally
        } else {
            claudeSprite.xScale = 1
        }
        
        // Move Claude
        let moveAction = SKAction.move(to: destination, duration: duration)
        claudeSprite.run(moveAction) {
            self.position = destination
        }
        
        currentAction = .walking
    }
    
    func reactToVimCommand(_ command: String) {
        // Claude reacts to vim commands
        switch command {
        case "i", "a", "o":
            // Insert mode
            currentAction = .talking("Insert mode! Time to write! ✍️")
            showTypingAnimation()
            
        case "dd":
            // Delete line
            currentAction = .talking("Deleting that line! 🗑️")
            showDeleteAnimation()
            
        case ":w":
            // Save
            currentAction = .celebrating
            showCelebrationAnimation()
            
        case ":q":
            // Quit
            currentAction = .talking("Goodbye! See you later! 👋")
            showWaveAnimation()
            
        case "gg", "G":
            // Jump to top/bottom
            jumpAnimation()
            currentAction = .talking("Wheee! 🎢")
            
        case "/":
            // Search
            currentAction = .thinking
            showSearchAnimation()
            
        default:
            if command.hasPrefix(":!") {
                // Shell command
                currentAction = .talking("Running command! 🚀")
                showRocketAnimation()
            }
        }
    }
    
    func askClaude(_ question: String) async -> String {
        currentAction = .thinking
        
        // Show thinking animation
        showThinkingAnimation()
        
        // Actually call Claude API
        let response = await ClaudeAPI.ask(question)
        
        // Show response
        currentAction = .talking(response)
        
        // Point to relevant code if needed
        if let codeLocation = findRelevantCode(for: response) {
            pointToLocation(codeLocation)
        }
        
        return response
    }
    
    private func showThinkingAnimation() {
        let thinkFrames = thinkingAtlas.textureNames.sorted().map {
            thinkingAtlas.textureNamed($0)
        }
        
        let thinkAnimation = SKAction.animate(with: thinkFrames, timePerFrame: 0.15)
        let addBubble = SKAction.run {
            let bubble = SKSpriteNode(imageNamed: "thought_bubble")
            bubble.position = CGPoint(x: self.claudeSprite.position.x + 20,
                                    y: self.claudeSprite.position.y + 30)
            bubble.setScale(0)
            self.scene.addChild(bubble)
            
            bubble.run(SKAction.sequence([
                SKAction.scale(to: 1.0, duration: 0.3),
                SKAction.wait(forDuration: 2.0),
                SKAction.scale(to: 0, duration: 0.3),
                SKAction.removeFromParent()
            ]))
        }
        
        claudeSprite.run(SKAction.sequence([
            thinkAnimation,
            addBubble
        ]))
    }
    
    private func showCelebrationAnimation() {
        // Claude jumps up and down
        let jump = SKAction.sequence([
            SKAction.moveBy(x: 0, y: 20, duration: 0.2),
            SKAction.moveBy(x: 0, y: -20, duration: 0.2)
        ])
        
        // Spawn confetti particles
        let confetti = SKEmitterNode(fileNamed: "Confetti")!
        confetti.position = claudeSprite.position
        scene.addChild(confetti)
        
        claudeSprite.run(SKAction.repeat(jump, count: 3))
        
        // Remove confetti after 2 seconds
        confetti.run(SKAction.sequence([
            SKAction.wait(forDuration: 2.0),
            SKAction.removeFromParent()
        ]))
    }
    
    private func pointToLocation(_ location: CGPoint) {
        // Claude walks to near the location and points
        let nearLocation = CGPoint(
            x: location.x - 50,
            y: location.y
        )
        
        let moveAction = SKAction.move(to: nearLocation, duration: 1.0)
        
        claudeSprite.run(moveAction) {
            // Show pointing animation
            let pointSprite = SKSpriteNode(imageNamed: "claude_pointing")
            pointSprite.position = self.claudeSprite.position
            self.scene.addChild(pointSprite)
            
            // Draw arrow
            let arrow = SKSpriteNode(imageNamed: "arrow")
            arrow.position = CGPoint(
                x: self.claudeSprite.position.x + 30,
                y: self.claudeSprite.position.y + 10
            )
            arrow.zRotation = atan2(
                location.y - self.claudeSprite.position.y,
                location.x - self.claudeSprite.position.x
            )
            self.scene.addChild(arrow)
            
            // Pulse animation on arrow
            arrow.run(SKAction.repeatForever(
                SKAction.sequence([
                    SKAction.scale(to: 1.2, duration: 0.5),
                    SKAction.scale(to: 1.0, duration: 0.5)
                ])
            ))
        }
        
        currentAction = .pointing(location)
    }
}

enum ClaudeAction {
    case walking
    case thinking  
    case talking(String)
    case pointing(CGPoint)
    case celebrating
    case confused
}

struct ClaudeSpeechBubble: View {
    let message: String
    @State private var isVisible = false
    
    var body: some View {
        ZStack {
            // Bubble shape
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
                .shadow(radius: 4)
            
            // Tail
            Triangle()
                .fill(Color.white)
                .frame(width: 20, height: 10)
                .offset(y: 20)
            
            // Message
            Text(message)
                .font(.caption)
                .padding(8)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: 200)
        .scaleEffect(isVisible ? 1 : 0)
        .onAppear {
            withAnimation(.spring()) {
                isVisible = true
            }
        }
    }
}
```

