//
//  SoundEngine.swift
//  Kyozo
//
//  Created by Loc Nguyen on 8/16/25.
//



class SoundEngine {
    private var sounds: [String: AVAudioPlayer] = [:]
    
    init() {
        // Preload all sounds
        let soundFiles = [
            "fart_mega", "fart_tiny", "fart_wet", "fart_squeaky",
            "rocket_launch", "burp", "teleport", "celebration",
            "lightning", "chomp", "giggle"
        ]
        
        for sound in soundFiles {
            if let url = Bundle.main.url(forResource: sound, withExtension: "mp3") {
                do {
                    let player = try AVAudioPlayer(contentsOf: url)
                    player.prepareToPlay()
                    sounds[sound] = player
                } catch {
                    print("Failed to load sound: \(sound)")
                }
            }
        }
    }
    
    func playSound(_ name: String, volume: Float = 1.0) {
        sounds[name]?.volume = volume
        sounds[name]?.play()
    }
}

// Metal shader for 120fps particle rendering
let particleShader = """
#include <metal_stdlib>
using namespace metal;

kernel void updateParticles(device Particle* particles [[buffer(0)]],
                           constant SimParams& params [[buffer(1)]],
                           uint id [[thread_position_in_grid]]) {
    Particle p = particles[id];
    
    // Update position with velocity
    p.position += p.velocity * params.deltaTime;
    
    // Apply gravity
    p.velocity.y -= params.gravity * params.deltaTime;
    
    // Spin
    p.rotation += p.angularVelocity * params.deltaTime;
    
    // Fade out
    p.alpha -= p.fadeRate * params.deltaTime;
    
    // Rainbow color shift
    p.hue = fmod(p.hue + params.deltaTime * 0.5, 1.0);
    
    particles[id] = p;
}
"""
```

