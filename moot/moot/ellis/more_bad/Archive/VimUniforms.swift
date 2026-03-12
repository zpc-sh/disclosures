//
//  VimUniforms.swift
//  Kyozo
//
//  Created by Loc Nguyen on 8/16/25.
//



## VimMetalRenderer.swift - GPU-ACCELERATED VIM RENDERING
```swift
import Metal
import MetalKit

extension VimViewController: MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // Handle resize
    }
    
    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let commandBuffer = view.device?.makeCommandQueue()?.makeCommandBuffer(),
              let renderPassDescriptor = view.currentRenderPassDescriptor else {
            return
        }
        
        // Get vim buffer content
        let buffer = vimCore.getCurrentBuffer()
        let cursorPos = vimCore.getCursorPosition()
        let mode = vimCore.getCurrentMode()
        
        // Render with Metal
        let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
        
        // Use GPU to render vim text
        renderVimBuffer(encoder, buffer: buffer, cursor: cursorPos, mode: mode)
        
        // Render Claude avatar on top
        renderClaudeAvatar(encoder)
        
        encoder.endEncoding()
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
    
    private func renderVimBuffer(_ encoder: MTLRenderCommandEncoder, 
                                buffer: String, 
                                cursor: CursorPosition,
                                mode: VimMode) {
        // This is where we use Metal to render text FAST
        // Custom shaders for syntax highlighting
        
        encoder.setRenderPipelineState(textRenderPipeline)
        
        // Convert text to GPU buffer
        let textBuffer = device.makeBuffer(
            bytes: buffer.utf8CString,
            length: buffer.utf8.count,
            options: []
        )!
        
        encoder.setVertexBuffer(textBuffer, offset: 0, index: 0)
        
        // Set uniforms for cursor and highlighting
        var uniforms = VimUniforms(
            cursorX: Float(cursor.column),
            cursorY: Float(cursor.line),
            mode: mode.rawValue,
            time: Float(CACurrentMediaTime())
        )
        
        encoder.setVertexBytes(&uniforms, 
                              length: MemoryLayout<VimUniforms>.stride,
                              index: 1)
        
        // Draw
        encoder.drawPrimitives(type: .triangleStrip, 
                             vertexStart: 0,
                             vertexCount: buffer.count * 6) // 6 vertices per character
    }
}

// Metal shader for vim rendering
let vimShaderSource = """
#include <metal_stdlib>
using namespace metal;

struct VimUniforms {
    float cursorX;
    float cursorY;
    uint mode;
    float time;
};

vertex float4 vim_vertex(uint vid [[vertex_id]],
                         constant char* text [[buffer(0)]],
                         constant VimUniforms& uniforms [[buffer(1)]]) {
    // Calculate character position
    uint charIndex = vid / 6;
    uint vertexInChar = vid % 6;
    
    char c = text[charIndex];
    
    // Calculate position based on character index
    float x = float(charIndex % 80) * 8.0;  // 80 chars per line, 8 pixels wide
    float y = float(charIndex / 80) * 16.0; // 16 pixels tall
    
    // Add cursor blink
    if (charIndex == uint(uniforms.cursorY * 80 + uniforms.cursorX)) {
        float blink = sin(uniforms.time * 5.0) * 0.5 + 0.5;
        // Make cursor visible
    }
    
    // Handle vim mode colors
    float4 color;
    switch(uniforms.mode) {
        case 0: // Normal mode
            color = float4(1, 1, 1, 1);
            break;
        case 1: // Insert mode
            color = float4(0, 1, 0, 1);
            break;
        case 2: // Visual mode
            color = float4(0, 0.5, 1, 1);
            break;
    }
    
    return float4(x, y, 0, 1);
}

fragment float4 vim_fragment(float4 position [[position]],
                            float2 texCoord [[texture_coord]]) {
    // Render character with syntax highlighting
    return float4(1, 1, 1, 1);
}
"""
```

