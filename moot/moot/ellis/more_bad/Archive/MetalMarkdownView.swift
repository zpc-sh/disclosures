//
//  MetalMarkdownView.swift
//  Kyozo
//
//  Created by Loc Nguyen on 8/16/25.
//


## MetalMarkdownView.swift - GPU-Accelerated Rendering
```swift
import SwiftUI
import MetalKit
import simd

struct MetalMarkdownView: NSViewRepresentable {
    let markdown: String
    let engine: MetalMarkdownEngine
    
    func makeNSView(context: Context) -> MTKView {
        let mtkView = MTKView()
        mtkView.device = engine.device
        mtkView.delegate = context.coordinator
        mtkView.enableSetNeedsDisplay = true
        mtkView.isPaused = false
        mtkView.preferredFramesPerSecond = 120 // ProMotion support
        
        return mtkView
    }
    
    func updateNSView(_ mtkView: MTKView, context: Context) {
        context.coordinator.markdown = markdown
        mtkView.setNeedsDisplay()
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(engine: engine, markdown: markdown)
    }
    
    class Coordinator: NSObject, MTKViewDelegate {
        let engine: MetalMarkdownEngine
        var markdown: String
        private var renderPipeline: MTLRenderPipelineState!
        private var computePipeline: MTLComputePipelineState!
        
        init(engine: MetalMarkdownEngine, markdown: String) {
            self.engine = engine
            self.markdown = markdown
            super.init()
            setupPipelines()
        }
        
        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            // Handle resize
        }
        
        func draw(in view: MTKView) {
            guard let drawable = view.currentDrawable,
                  let commandBuffer = engine.commandQueue.makeCommandBuffer() else {
                return
            }
            
            // Parse markdown with Metal compute shader
            let parseEncoder = commandBuffer.makeComputeCommandEncoder()!
            parseEncoder.setComputePipelineState(computePipeline)
            
            let markdownBuffer = engine.device.makeBuffer(
                bytes: markdown.utf8CString,
                length: markdown.utf8.count
            )!
            
            parseEncoder.setBuffer(markdownBuffer, offset: 0, index: 0)
            parseEncoder.setBuffer(engine.outputBuffer, offset: 0, index: 1)
            
            let threadgroupSize = MTLSize(width: 64, height: 1, depth: 1)
            let threadgroupCount = MTLSize(
                width: (markdown.count + 63) / 64,
                height: 1,
                depth: 1
            )
            
            parseEncoder.dispatchThreadgroups(threadgroupCount,
                                             threadsPerThreadgroup: threadgroupSize)
            parseEncoder.endEncoding()
            
            // Render parsed markdown
            let renderPass = MTLRenderPassDescriptor()
            renderPass.colorAttachments[0].texture = drawable.texture
            renderPass.colorAttachments[0].loadAction = .clear
            renderPass.colorAttachments[0].clearColor = MTLClearColor(red: 1, green: 1, blue: 1, alpha: 1)
            
            let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPass)!
            renderEncoder.setRenderPipelineState(renderPipeline)
            
            // Render markdown elements
            renderMarkdownElements(renderEncoder)
            
            renderEncoder.endEncoding()
            
            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
        
        private func renderMarkdownElements(_ encoder: MTLRenderCommandEncoder) {
            // GPU-accelerated markdown rendering
            // This is where the magic happens - rendering text with Metal!
        }
    }
}
```

