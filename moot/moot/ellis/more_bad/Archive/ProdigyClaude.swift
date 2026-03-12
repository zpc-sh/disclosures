//
//  ProdigyClaude.swift
//  Kyozo
//
//  Created by Loc Nguyen on 8/16/25.
//



class ProdigyClaude: ObservableObject {
    let scene: SKScene
    private var claudeSprite: SKSpriteNode!
    private var currentMode: ClaudeMode = .normal
    private var fartEngine: FartPhysicsEngine!
    private var soundEngine: SoundEngine!
    
    // Physics bodies for advanced movement
    private var propulsionVector = CGVector.zero
    private var spinRate: CGFloat = 0
    
    init() {
        scene = SKScene(size: UIScreen.main.bounds.size)
        scene.backgroundColor = .clear
        scene.physicsWorld.gravity = CGVector(dx: 0, dy: -2)
        
        setupClaude()
        setupPhysics()
        setupSounds()
    }
    
    private func setupClaude() {
        // Claude with physics
        claudeSprite = SKSpriteNode(imageNamed: "claude_cool") // Cool Claude for cool kid
        claudeSprite.size = CGSize(width: 80, height: 80)
        claudeSprite.position = CGPoint(x: 100, y: 500)
        
        // Complex physics body
        claudeSprite.physicsBody = SKPhysicsBody(circleOfRadius: 40)
        claudeSprite.physicsBody?.isDynamic = true
        claudeSprite.physicsBody?.affectedByGravity = true
        claudeSprite.physicsBody?.restitution = 0.6
        claudeSprite.physicsBody?.mass = 0.1
        
        scene.addChild(claudeSprite)
        
        // Add cape that flutters
        addFlutteringCape()
        
        // Particle systems
        setupParticleSystems()
    }
    
    func doFlyingSpinningFart(mega: Bool = false) {
        // Calculate fart propulsion
        let fartPower: CGFloat = mega ? 2000 : 500
        let fartAngle = CGFloat.random(in: 0...(2 * .pi))
        
        // Apply impulse
        let impulse = CGVector(
            dx: cos(fartAngle) * fartPower,
            dy: sin(fartAngle) * fartPower
        )
        claudeSprite.physicsBody?.applyImpulse(impulse)
        
        // Start spinning
        let spin = SKAction.repeatForever(
            SKAction.rotate(byAngle: mega ? .pi * 4 : .pi * 2, duration: 1.0)
        )
        claudeSprite.run(spin, withKey: "spin")
        
        // Fart particles
        emitFartCloud(mega: mega)
        
        // Sound effect
        playFartSound(mega: mega)
        
        // Screen effects for mega fart
        if mega {
            // Rainbow explosion
            createRainbowExplosion()
            
            // Confetti cannon
            fireConfettiCannon()
            
            // Fireworks
            launchFireworks()
        }
    }
    
    private func emitFartCloud(mega: Bool) {
        let fartCloud = SKEmitterNode()
        fartCloud.particleTexture = SKTexture(imageNamed: "cloud")
        fartCloud.particleBirthRate = mega ? 500 : 100
        fartCloud.particleLifetime = 2.0
        fartCloud.particleSpeed = mega ? 400 : 200
        fartCloud.particleSpeedRange = 100
        fartCloud.particleScale = mega ? 1.0 : 0.5
        fartCloud.particleScaleSpeed = mega ? -0.5 : -0.25
        fartCloud.particleColor = UIColor.green.withAlphaComponent(0.6)
        fartCloud.particleColorBlendFactor = 1.0
        fartCloud.particleAlpha = 0.8
        fartCloud.particleAlphaSpeed = -0.4
        
        // Position at Claude's butt
        fartCloud.position = CGPoint(x: 0, y: -30)
        claudeSprite.addChild(fartCloud)
        
        // Remove after emission
        fartCloud.run(SKAction.sequence([
            SKAction.wait(forDuration: 0.5),
            SKAction.run { fartCloud.particleBirthRate = 0 },
            SKAction.wait(forDuration: 2.0),
            SKAction.removeFromParent()
        ]))
    }
    
    func activateRainbowMode() {
        // Rainbow trail following Claude
        let rainbow = SKEmitterNode()
        rainbow.particleTexture = SKTexture(imageNamed: "star")
        rainbow.particleBirthRate = 200
        rainbow.particleLifetime = 1.0
        rainbow.particleSpeed = 0
        rainbow.particleScale = 0.3
        rainbow.particleScaleSpeed = -0.3
        rainbow.particleColorSequence = SKKeyframeSequence(
            keyframeValues: [
                UIColor.red,
                UIColor.orange,
                UIColor.yellow,
                UIColor.green,
                UIColor.blue,
                UIColor.purple,
                UIColor.red
            ],
            times: [0, 0.16, 0.33, 0.5, 0.66, 0.83, 1.0] as [NSNumber]
        )
        rainbow.targetNode = scene
        
        claudeSprite.addChild(rainbow)
        
        // Oscillating flight pattern
        let floatUp = SKAction.moveBy(x: 0, y: 30, duration: 1.0)
        let floatDown = SKAction.moveBy(x: 0, y: -30, duration: 1.0)
        let float = SKAction.sequence([floatUp, floatDown])
        claudeSprite.run(SKAction.repeatForever(float), withKey: "float")
    }
    
    func activateLightningMode() {
        // Create lightning bolts around Claude
        Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { timer in
            if self.currentMode != .lightning {
                timer.invalidate()
                return
            }
            
            self.createLightningBolt()
        }
        
        currentMode = .lightning
        
        // Electric aura
        let electric = SKEffectNode()
        electric.shouldRasterize = true
        electric.filter = CIFilter(name: "CIGaussianBlur", parameters: ["inputRadius": 10])
        
        let aura = SKSpriteNode(color: .cyan, size: CGSize(width: 100, height: 100))
        aura.alpha = 0.5
        electric.addChild(aura)
        
        claudeSprite.addChild(electric)
        
        // Pulsing effect
        let pulse = SKAction.sequence([
            SKAction.scale(to: 1.2, duration: 0.1),
            SKAction.scale(to: 1.0, duration: 0.1)
        ])
        electric.run(SKAction.repeatForever(pulse))
    }
    
    private func createLightningBolt() {
        let lightning = SKShapeNode()
        let path = CGMutablePath()
        
        // Random zigzag path
        var currentPoint = claudeSprite.position
        path.move(to: currentPoint)
        
        for _ in 0..<5 {
            currentPoint.x += CGFloat.random(in: -50...50)
            currentPoint.y -= CGFloat.random(in: 20...60)
            path.addLine(to: currentPoint)
        }
        
        lightning.path = path
        lightning.strokeColor = .white
        lightning.lineWidth = 3
        lightning.glowWidth = 10
        
        scene.addChild(lightning)
        
        // Flash and fade
        lightning.run(SKAction.sequence([
            SKAction.fadeAlpha(to: 0, duration: 0.2),
            SKAction.removeFromParent()
        ]))
    }
    
    func blastOff() {
        // ROCKET MODE
        let fire = SKEmitterNode()
        fire.particleTexture = SKTexture(imageNamed: "fire")
        fire.particleBirthRate = 1000
        fire.particleLifetime = 0.5
        fire.particleSpeed = 200
        fire.particleSpeedRange = 50
        fire.particleScale = 0.5
        fire.particleScaleSpeed = -0.5
        fire.particleColor = .orange
        fire.particleColorBlendFactor = 1.0
        fire.emissionAngle = -.pi / 2
        fire.emissionAngleRange = .pi / 4
        fire.position = CGPoint(x: 0, y: -40)
        fire.targetNode = scene
        
        claudeSprite.addChild(fire)
        
        // Apply massive upward force
        claudeSprite.physicsBody?.applyImpulse(CGVector(dx: 0, dy: 5000))
        
        // Spin wildly
        claudeSprite.run(SKAction.repeatForever(
            SKAction.rotate(byAngle: .pi * 8, duration: 1.0)
        ))
        
        // Camera shake effect
        let shake = SKAction.sequence([
            SKAction.moveBy(x: 10, y: 0, duration: 0.05),
            SKAction.moveBy(x: -20, y: 0, duration: 0.05),
            SKAction.moveBy(x: 10, y: 0, duration: 0.05)
        ])
        scene.run(SKAction.repeat(shake, count: 10))
        
        // Rocket sound
        soundEngine.playSound("rocket_launch")
    }
    
    func eatLine() {
        // Claude opens mouth and chomps
        let chomp = SKAction.sequence([
            SKAction.setTexture(SKTexture(imageNamed: "claude_mouth_open")),
            SKAction.wait(forDuration: 0.1),
            SKAction.setTexture(SKTexture(imageNamed: "claude_chomping")),
            SKAction.wait(forDuration: 0.1),
            SKAction.setTexture(SKTexture(imageNamed: "claude_satisfied")),
            SKAction.wait(forDuration: 0.5),
            SKAction.setTexture(SKTexture(imageNamed: "claude_cool"))
        ])
        
        claudeSprite.run(chomp)
        
        // Burp afterwards
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.burp()
        }
    }
    
    private func burp() {
        // Burp particle effect
        let burp = SKEmitterNode()
        burp.particleTexture = SKTexture(imageNamed: "bubble")
        burp.particleBirthRate = 50
        burp.particleLifetime = 1.0
        burp.particleSpeed = 100
        burp.particleScale = 0.3
        burp.particleAlpha = 0.6
        burp.position = CGPoint(x: 0, y: 30)
        
        claudeSprite.addChild(burp)
        
        // Burp sound
        soundEngine.playSound("burp")
        
        burp.run(SKAction.sequence([
            SKAction.wait(forDuration: 0.5),
            SKAction.removeFromParent()
        ]))
    }
    
    func microFart() {
        // Small fart for each keystroke - provides propulsion!
        let tinyImpulse = CGVector(
            dx: CGFloat.random(in: -50...50),
            dy: CGFloat.random(in: 20...80)
        )
        claudeSprite.physicsBody?.applyImpulse(tinyImpulse)
        
        // Tiny fart cloud
        let tinyFart = SKSpriteNode(imageNamed: "tiny_cloud")
        tinyFart.size = CGSize(width: 20, height: 20)
        tinyFart.position = CGPoint(x: 0, y: -30)
        tinyFart.alpha = 0.6
        
        claudeSprite.addChild(tinyFart)
        
        tinyFart.run(SKAction.sequence([
            SKAction.group([
                SKAction.moveBy(x: 0, y: -50, duration: 0.5),
                SKAction.fadeOut(withDuration: 0.5),
                SKAction.scale(to: 2.0, duration: 0.5)
            ]),
            SKAction.removeFromParent()
        ]))
        
        // Quiet fart sound
        soundEngine.playSound("fart_tiny", volume: 0.3)
    }
}

