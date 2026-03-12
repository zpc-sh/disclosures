//
//  MetalTextRenderer.swift
//  Kyozo
//
//  High-performance Metal text rendering with dynamic glyph tessellation
//

import Foundation
import Metal
import MetalKit
import CoreText
import simd
import SwiftUI

// MARK: - Vertex Structures

struct TextVertex {
    var position: simd_float2
    var texCoord: simd_float2
    var color: simd_float4
    var glyphIndex: UInt32
    var animationPhase: Float
}

struct GlyphInstance {
    let transform: simd_float4x4
    let color: simd_float4
    let uvRect: simd_float4 // x, y, width, height in texture atlas
    let animationData: simd_float4 // phase, speed, type, intensity
}

struct TextRenderUniforms {
    let projectionMatrix: simd_float4x4
    let viewMatrix: simd_float4x4
    let time: Float
    let screenSize: simd_float2
    let pixelScale: Float
    let subpixelShift: simd_float3
}

// MARK: - Glyph Cache

class GlyphCache {
    private let device: MTLDevice
    private var glyphTextures: [CGGlyph: MTLTexture] = [:]
    private var glyphMetrics: [CGGlyph: GlyphMetrics] = [:]
    private let textureSize: Int = 2048
    fileprivate(set) var atlasTexture: MTLTexture?
    private var atlasAllocator: TextureAtlasAllocator
    
    struct GlyphMetrics {
        let advance: CGSize
        let boundingBox: CGRect
        let atlasRect: CGRect
        let tessellatedVertices: [TextVertex]
        let indices: [UInt16]
    }
    
    init(device: MTLDevice) {
        self.device = device
        self.atlasAllocator = TextureAtlasAllocator(size: textureSize)
        createAtlasTexture()
    }
    
    private func createAtlasTexture() {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .r8Unorm,
            width: textureSize,
            height: textureSize,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .renderTarget]
        descriptor.storageMode = .shared
        
        atlasTexture = device.makeTexture(descriptor: descriptor)
    }
    
    func getGlyph(_ glyph: CGGlyph, font: CTFont, size: CGFloat) -> GlyphMetrics? {
        if let cached = glyphMetrics[glyph] {
            return cached
        }
        
        return tessellateGlyph(glyph, font: font, size: size)
    }
    
    private func tessellateGlyph(_ glyph: CGGlyph, font: CTFont, size: CGFloat) -> GlyphMetrics? {
        // Get glyph path
        guard let path = CTFontCreatePathForGlyph(font, glyph, nil) else {
            return nil
        }
        
        // Tessellate the path into triangles
        let tessellator = PathTessellator()
        let (vertices, indices) = tessellator.tessellate(path: path, size: size)
        
        // Get glyph metrics
        var mutableGlyph = glyph
        var boundingRect = CGRect.zero
        CTFontGetBoundingRectsForGlyphs(font, .default, &mutableGlyph, &boundingRect, 1)
        
        var advance = CGSize.zero
        CTFontGetAdvancesForGlyphs(font, .default, &mutableGlyph, &advance, 1)
        
        // Allocate space in atlas
        let glyphSize = CGSize(
            width: ceil(boundingRect.width) + 4, // padding
            height: ceil(boundingRect.height) + 4
        )
        
        guard let atlasRect = atlasAllocator.allocate(size: glyphSize) else {
            // Atlas is full, need to expand or flush
            return nil
        }
        
        // Render glyph to atlas
        renderGlyphToAtlas(glyph, font: font, rect: atlasRect)
        
        let metrics = GlyphMetrics(
            advance: advance,
            boundingBox: boundingRect,
            atlasRect: atlasRect,
            tessellatedVertices: vertices,
            indices: indices
        )
        
        glyphMetrics[glyph] = metrics
        return metrics
    }
    
    private func renderGlyphToAtlas(_ glyph: CGGlyph, font: CTFont, rect: CGRect) {
        // Create render pass to draw glyph into atlas texture
        guard let atlasTexture = atlasTexture else { return }
        
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = atlasTexture
        renderPassDescriptor.colorAttachments[0].loadAction = .load
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        
        // Render the glyph using Core Graphics
        let context = CGContext(
            data: nil,
            width: Int(rect.width),
            height: Int(rect.height),
            bitsPerComponent: 8,
            bytesPerRow: Int(rect.width),
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        )
        
        let cgFont = CTFontCopyGraphicsFont(font, nil)
        context?.setFont(cgFont)
        context?.setFontSize(CTFontGetSize(font))
        context?.showGlyphs([glyph], at: [CGPoint(x: 2, y: 2)])
        
        // Upload to texture
        if let imageData = context?.data {
            atlasTexture.replace(
                region: MTLRegion(
                    origin: MTLOrigin(x: Int(rect.minX), y: Int(rect.minY), z: 0),
                    size: MTLSize(width: Int(rect.width), height: Int(rect.height), depth: 1)
                ),
                mipmapLevel: 0,
                withBytes: imageData,
                bytesPerRow: Int(rect.width)
            )
        }
    }
}

// MARK: - Path Tessellator

class PathTessellator {
    func tessellate(path: CGPath, size: CGFloat) -> ([TextVertex], [UInt16]) {
        var vertices: [TextVertex] = []
        var indices: [UInt16] = []
        var currentIndex: UInt16 = 0
        
        // Convert path to polygons and tessellate
        path.applyWithBlock { element in
            switch element.pointee.type {
            case .moveToPoint:
                // Start new contour
                break
                
            case .addLineToPoint:
                // Add line segment
                break
                
            case .addQuadCurveToPoint:
                // Tessellate quadratic curve
                let points = element.pointee.points
                tessellateQuadCurve(
                    start: vertices.last?.position ?? simd_float2(0, 0),
                    control: simd_float2(Float(points[0].x), Float(points[0].y)),
                    end: simd_float2(Float(points[1].x), Float(points[1].y)),
                    vertices: &vertices,
                    indices: &indices,
                    currentIndex: &currentIndex
                )
                
            case .addCurveToPoint:
                // Tessellate cubic curve
                let points = element.pointee.points
                tessellateCubicCurve(
                    start: vertices.last?.position ?? simd_float2(0, 0),
                    control1: simd_float2(Float(points[0].x), Float(points[0].y)),
                    control2: simd_float2(Float(points[1].x), Float(points[1].y)),
                    end: simd_float2(Float(points[2].x), Float(points[2].y)),
                    vertices: &vertices,
                    indices: &indices,
                    currentIndex: &currentIndex
                )
                
            case .closeSubpath:
                // Close current contour
                break
                
            @unknown default:
                break
            }
        }
        
        return (vertices, indices)
    }
    
    private func tessellateQuadCurve(
        start: simd_float2,
        control: simd_float2,
        end: simd_float2,
        vertices: inout [TextVertex],
        indices: inout [UInt16],
        currentIndex: inout UInt16
    ) {
        let steps = 16
        let stepSize = 1.0 / Float(steps)
        
        for i in 0...steps {
            let t = Float(i) * stepSize
            let pos = quadraticBezier(t: t, p0: start, p1: control, p2: end)
            
            vertices.append(TextVertex(
                position: pos,
                texCoord: simd_float2(0, 0), // Will be set later
                color: simd_float4(1, 1, 1, 1),
                glyphIndex: 0,
                animationPhase: 0
            ))
            
            if i > 0 {
                // Create triangle fan from center
                if i > 1 {
                    indices.append(contentsOf: [0, currentIndex - 1, currentIndex])
                }
            }
            
            currentIndex += 1
        }
    }
    
    private func tessellateCubicCurve(
        start: simd_float2,
        control1: simd_float2,
        control2: simd_float2,
        end: simd_float2,
        vertices: inout [TextVertex],
        indices: inout [UInt16],
        currentIndex: inout UInt16
    ) {
        let steps = 20
        let stepSize = 1.0 / Float(steps)
        
        for i in 0...steps {
            let t = Float(i) * stepSize
            let pos = cubicBezier(t: t, p0: start, p1: control1, p2: control2, p3: end)
            
            vertices.append(TextVertex(
                position: pos,
                texCoord: simd_float2(0, 0),
                color: simd_float4(1, 1, 1, 1),
                glyphIndex: 0,
                animationPhase: 0
            ))
            
            if i > 0 && i > 1 {
                indices.append(contentsOf: [0, currentIndex - 1, currentIndex])
            }
            
            currentIndex += 1
        }
    }
    
    private func quadraticBezier(t: Float, p0: simd_float2, p1: simd_float2, p2: simd_float2) -> simd_float2 {
        let u = 1.0 - t
        return u * u * p0 + 2.0 * u * t * p1 + t * t * p2
    }
    
    private func cubicBezier(t: Float, p0: simd_float2, p1: simd_float2, p2: simd_float2, p3: simd_float2) -> simd_float2 {
        let u = 1.0 - t
        return u * u * u * p0 + 3.0 * u * u * t * p1 + 3.0 * u * t * t * p2 + t * t * t * p3
    }
}

// MARK: - Texture Atlas Allocator

class TextureAtlasAllocator {
    private let size: Int
    private var allocatedRects: [CGRect] = []
    private var freeRects: [CGRect]
    
    init(size: Int) {
        self.size = size
        self.freeRects = [CGRect(x: 0, y: 0, width: size, height: size)]
    }
    
    func allocate(size requestedSize: CGSize) -> CGRect? {
        let width = ceil(requestedSize.width)
        let height = ceil(requestedSize.height)
        
        // Find best fit using bottom-left heuristic
        var bestRect: CGRect?
        var bestIndex = -1
        var bestShortSideFit = Int.max
        var bestLongSideFit = Int.max
        
        for (index, rect) in freeRects.enumerated() {
            if rect.width >= width && rect.height >= height {
                let leftoverHorizontal = Int(rect.width - width)
                let leftoverVertical = Int(rect.height - height)
                let shortSideFit = min(leftoverHorizontal, leftoverVertical)
                let longSideFit = max(leftoverHorizontal, leftoverVertical)
                
                if shortSideFit < bestShortSideFit || 
                   (shortSideFit == bestShortSideFit && longSideFit < bestLongSideFit) {
                    bestRect = CGRect(x: rect.minX, y: rect.minY, width: width, height: height)
                    bestShortSideFit = shortSideFit
                    bestLongSideFit = longSideFit
                    bestIndex = index
                }
            }
        }
        
        guard let allocatedRect = bestRect else {
            return nil // No space available
        }
        
        // Split the free rectangle
        let freeRect = freeRects[bestIndex]
        freeRects.remove(at: bestIndex)
        
        // Add remaining rectangles
        if freeRect.width > width {
            freeRects.append(CGRect(
                x: freeRect.minX + width,
                y: freeRect.minY,
                width: freeRect.width - width,
                height: height
            ))
        }
        
        if freeRect.height > height {
            freeRects.append(CGRect(
                x: freeRect.minX,
                y: freeRect.minY + height,
                width: freeRect.width,
                height: freeRect.height - height
            ))
        }
        
        allocatedRects.append(allocatedRect)
        return allocatedRect
    }
}

// MARK: - Metal Text Renderer

@MainActor
class MetalTextRenderer: ObservableObject {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let library: MTLLibrary
    private var renderPipelineState: MTLRenderPipelineState?
    private var depthStencilState: MTLDepthStencilState?
    private var backgroundPipelineState: MTLRenderPipelineState?
    
    private let glyphCache: GlyphCache
    private let performanceMonitor: MetalPerformanceMonitor
    
    // Buffers
    private var vertexBuffer: MTLBuffer?
    private var indexBuffer: MTLBuffer?
    private var uniformBuffer: MTLBuffer?
    private var instanceBuffer: MTLBuffer?
    
    // Animation
    @Published var animationTime: Float = 0
    private var animationTimer: Timer?
    
    // Text layout
    private var textLayout: TextLayout?
    private var needsRebuild = true
    
    init(device: MTLDevice) {
        self.device = device
        self.commandQueue = device.makeCommandQueue()!
        self.library = device.makeDefaultLibrary()!
        self.glyphCache = GlyphCache(device: device)
        self.performanceMonitor = MetalPerformanceMonitor(device: device)
        
        setupRenderPipeline()
        setupBackgroundPipeline()
        setupDepthStencil()
        startAnimation()
    }
    
    private func setupRenderPipeline() {
        guard let vertexFunction = library.makeFunction(name: "textVertexShader"),
              let fragmentFunction = library.makeFunction(name: "textFragmentShader") else {
            return
        }
        
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertexFunction
        descriptor.fragmentFunction = fragmentFunction
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        descriptor.colorAttachments[0].isBlendingEnabled = true
        descriptor.colorAttachments[0].rgbBlendOperation = .add
        descriptor.colorAttachments[0].alphaBlendOperation = .add
        descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        descriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
        descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        descriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        
        // Vertex descriptor
        let vertexDescriptor = MTLVertexDescriptor()
        
        // Position
        vertexDescriptor.attributes[0].format = .float2
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = 0
        
        // Texture coordinates
        vertexDescriptor.attributes[1].format = .float2
        vertexDescriptor.attributes[1].offset = MemoryLayout<simd_float2>.size
        vertexDescriptor.attributes[1].bufferIndex = 0
        
        // Color
        vertexDescriptor.attributes[2].format = .float4
        vertexDescriptor.attributes[2].offset = MemoryLayout<simd_float2>.size * 2
        vertexDescriptor.attributes[2].bufferIndex = 0
        
        // Glyph index
        vertexDescriptor.attributes[3].format = .uint
        vertexDescriptor.attributes[3].offset = MemoryLayout<simd_float2>.size * 2 + MemoryLayout<simd_float4>.size
        vertexDescriptor.attributes[3].bufferIndex = 0
        
        // Animation phase
        vertexDescriptor.attributes[4].format = .float
        vertexDescriptor.attributes[4].offset = MemoryLayout<simd_float2>.size * 2 + MemoryLayout<simd_float4>.size + MemoryLayout<UInt32>.size
        vertexDescriptor.attributes[4].bufferIndex = 0
        
        vertexDescriptor.layouts[0].stride = MemoryLayout<TextVertex>.size
        descriptor.vertexDescriptor = vertexDescriptor
        
        do {
            renderPipelineState = try device.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            print("Failed to create render pipeline state: \(error)")
        }
    }

    private func setupBackgroundPipeline() {
        // Use functions defined in TextShaders.metal
        guard let bgVertex = library.makeFunction(name: "background_vertex"),
              let bgFragment = library.makeFunction(name: "background_fragment") else {
            return
        }
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = bgVertex
        descriptor.fragmentFunction = bgFragment
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        do {
            backgroundPipelineState = try device.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            print("Failed to create background pipeline state: \(error)")
        }
    }
    
    private func setupDepthStencil() {
        let descriptor = MTLDepthStencilDescriptor()
        descriptor.depthCompareFunction = .lessEqual
        descriptor.isDepthWriteEnabled = true
        depthStencilState = device.makeDepthStencilState(descriptor: descriptor)
    }
    
    private func startAnimation() {
        animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0/120.0, repeats: true) { _ in
            self.animationTime += 1.0/120.0
        }
    }
    
    // MARK: - Text Rendering
    
    func renderText(
        _ text: String,
        font: CTFont,
        color: simd_float4 = simd_float4(1, 1, 1, 1),
        in renderEncoder: MTLRenderCommandEncoder,
        viewport: CGSize
    ) {
        performanceMonitor.beginFrame()
        
        guard let pipelineState = renderPipelineState else { return }
        
        // Build text layout if needed
        if needsRebuild {
            buildTextLayout(text: text, font: font, viewport: viewport)
            needsRebuild = false
        }
        
        guard let layout = textLayout,
              let vertexBuffer = vertexBuffer,
              let indexBuffer = indexBuffer,
              let uniformBuffer = uniformBuffer else {
            return
        }
        
        // Update uniforms
        updateUniforms(viewport: viewport)
        
        // Set render state
        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setDepthStencilState(depthStencilState)
        
        // Set buffers
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBuffer(uniformBuffer, offset: 0, index: 1)
        renderEncoder.setFragmentBuffer(uniformBuffer, offset: 0, index: 0)
        
        // Set textures
        if let atlasTexture = glyphCache.atlasTexture {
            renderEncoder.setFragmentTexture(atlasTexture, index: 0)
        }
        
        // Draw
        renderEncoder.drawIndexedPrimitives(
            type: .triangle,
            indexCount: layout.indexCount,
            indexType: .uint16,
            indexBuffer: indexBuffer,
            indexBufferOffset: 0
        )
        
        performanceMonitor.endFrame(
            drawCallCount: 1,
            vertexCount: layout.vertexCount,
            triangleCount: layout.indexCount / 3
        )
    }
    
    private func buildTextLayout(text: String, font: CTFont, viewport: CGSize) {
        var vertices: [TextVertex] = []
        var indices: [UInt16] = []
        var currentIndex: UInt16 = 0
        
        let attributedString = NSAttributedString(
            string: text,
            attributes: [NSAttributedString.Key.font: font]
        )
        
        let line = CTLineCreateWithAttributedString(attributedString)
        let runs = CTLineGetGlyphRuns(line) as! [CTRun]
        
        var xOffset: Float = 0
        let yOffset: Float = 0
        
        for run in runs {
            let glyphCount = CTRunGetGlyphCount(run)
            var glyphs = Array<CGGlyph>(repeating: 0, count: glyphCount)
            var positions = Array<CGPoint>(repeating: .zero, count: glyphCount)
            
            CTRunGetGlyphs(run, CFRange(location: 0, length: glyphCount), &glyphs)
            CTRunGetPositions(run, CFRange(location: 0, length: glyphCount), &positions)
            
            for i in 0..<glyphCount {
                let glyph = glyphs[i]
                let position = positions[i]
                
                if let metrics = glyphCache.getGlyph(glyph, font: font, size: CTFontGetSize(font)) {
                    // Add tessellated vertices for this glyph
                    let baseIndex = currentIndex
                    
                    for vertex in metrics.tessellatedVertices {
                        var transformedVertex = vertex
                        transformedVertex.position.x += Float(position.x) + xOffset
                        transformedVertex.position.y += Float(position.y) + yOffset
                        
                        // Set texture coordinates based on atlas rect
                        let atlasRect = metrics.atlasRect
                        transformedVertex.texCoord = simd_float2(
                            Float(atlasRect.minX / 2048.0),
                            Float(atlasRect.minY / 2048.0)
                        )
                        
                        vertices.append(transformedVertex)
                        currentIndex += 1
                    }
                    
                    // Add indices with offset
                    for index in metrics.indices {
                        indices.append(baseIndex + index)
                    }
                    
                    xOffset += Float(metrics.advance.width)
                }
            }
        }
        
        // Create buffers
        createBuffers(vertices: vertices, indices: indices)
        
        textLayout = TextLayout(
            vertexCount: vertices.count,
            indexCount: indices.count,
            bounds: CGRect(x: 0, y: 0, width: CGFloat(xOffset), height: CTFontGetSize(font))
        )
    }
    
    private func createBuffers(vertices: [TextVertex], indices: [UInt16]) {
        // Vertex buffer
        let vertexDataSize = vertices.count * MemoryLayout<TextVertex>.size
        vertexBuffer = device.makeBuffer(bytes: vertices, length: vertexDataSize, options: .storageModeShared)
        
        // Index buffer
        let indexDataSize = indices.count * MemoryLayout<UInt16>.size
        indexBuffer = device.makeBuffer(bytes: indices, length: indexDataSize, options: .storageModeShared)
        
        // Uniform buffer
        uniformBuffer = device.makeBuffer(length: MemoryLayout<TextRenderUniforms>.size, options: .storageModeShared)
        
        // Track buffers for performance monitoring
        if let vb = vertexBuffer { performanceMonitor.trackBuffer(vb) }
        if let ib = indexBuffer { performanceMonitor.trackBuffer(ib) }
        if let ub = uniformBuffer { performanceMonitor.trackBuffer(ub) }
    }
    
    private func updateUniforms(viewport: CGSize) {
        guard let uniformBuffer = uniformBuffer else { return }
        
        let projectionMatrix = orthographicProjection(
            left: 0,
            right: Float(viewport.width),
            bottom: Float(viewport.height),
            top: 0,
            near: -1,
            far: 1
        )
        
        let uniforms = TextRenderUniforms(
            projectionMatrix: projectionMatrix,
            viewMatrix: matrix_identity_float4x4,
            time: animationTime,
            screenSize: simd_float2(Float(viewport.width), Float(viewport.height)),
            pixelScale: 1.0,
            subpixelShift: simd_float3(0, 0, 0)
        )
        
        let uniformPointer = uniformBuffer.contents().bindMemory(to: TextRenderUniforms.self, capacity: 1)
        uniformPointer.pointee = uniforms
    }
    
    private func orthographicProjection(left: Float, right: Float, bottom: Float, top: Float, near: Float, far: Float) -> simd_float4x4 {
        let width = right - left
        let height = top - bottom
        let depth = far - near
        
        return simd_float4x4(
            simd_float4(2.0 / width, 0, 0, 0),
            simd_float4(0, 2.0 / height, 0, 0),
            simd_float4(0, 0, -2.0 / depth, 0),
            simd_float4(-(right + left) / width, -(top + bottom) / height, -(far + near) / depth, 1)
        )
    }
    
    func invalidateLayout() {
        needsRebuild = true
    }

    // MARK: - TipTap/Markdown Rendered Document Rendering

    struct QuadVertex {
        var position: simd_float2 // clip-space position
        var color: simd_float4
    }

    func renderDocument(_ document: RenderedDocument,
                        atlasTexture: MTLTexture,
                        in renderEncoder: MTLRenderCommandEncoder,
                        viewport: CGSize,
                        yOffset: Float = 0) {
        // Draw backgrounds first
        if let bgPSO = backgroundPipelineState {
            renderEncoder.setRenderPipelineState(bgPSO)
            var bgVertices: [QuadVertex] = []
            var bgIndices: [UInt16] = []
            var idx: UInt16 = 0
            for block in document.blocks {
                switch block.type {
                case .codeBlock:
                    let r = block.bounds
                    let tl = ndc(from: CGPoint(x: r.minX, y: r.minY - CGFloat(yOffset)), viewport: viewport)
                    let br = ndc(from: CGPoint(x: r.maxX, y: r.maxY - CGFloat(yOffset)), viewport: viewport)
                    let color = simd_float4(0.15, 0.15, 0.18, 1.0)
                    bgVertices.append(contentsOf: [
                        QuadVertex(position: simd_float2(tl.x, tl.y), color: color), // top-left
                        QuadVertex(position: simd_float2(br.x, tl.y), color: color), // top-right
                        QuadVertex(position: simd_float2(br.x, br.y), color: color), // bottom-right
                        QuadVertex(position: simd_float2(tl.x, br.y), color: color)  // bottom-left
                    ])
                    bgIndices.append(contentsOf: [idx, idx+1, idx+2, idx, idx+2, idx+3])
                    idx += 4
                case .blockquote:
                    let r = block.bounds.insetBy(dx: -6, dy: -2)
                    let tl = ndc(from: CGPoint(x: r.minX, y: r.minY - CGFloat(yOffset)), viewport: viewport)
                    let br = ndc(from: CGPoint(x: r.maxX, y: r.maxY - CGFloat(yOffset)), viewport: viewport)
                    let color = simd_float4(0.12, 0.14, 0.18, 1.0)
                    bgVertices.append(contentsOf: [
                        QuadVertex(position: simd_float2(tl.x, tl.y), color: color),
                        QuadVertex(position: simd_float2(br.x, tl.y), color: color),
                        QuadVertex(position: simd_float2(br.x, br.y), color: color),
                        QuadVertex(position: simd_float2(tl.x, br.y), color: color)
                    ])
                    bgIndices.append(contentsOf: [idx, idx+1, idx+2, idx, idx+2, idx+3])
                    idx += 4
                case .heading:
                    let r = block.bounds.insetBy(dx: -4, dy: -1)
                    let tl = ndc(from: CGPoint(x: r.minX, y: r.minY - CGFloat(yOffset)), viewport: viewport)
                    let br = ndc(from: CGPoint(x: r.maxX, y: r.maxY - CGFloat(yOffset)), viewport: viewport)
                    let color = simd_float4(0.18, 0.18, 0.22, 1.0)
                    bgVertices.append(contentsOf: [
                        QuadVertex(position: simd_float2(tl.x, tl.y), color: color),
                        QuadVertex(position: simd_float2(br.x, tl.y), color: color),
                        QuadVertex(position: simd_float2(br.x, br.y), color: color),
                        QuadVertex(position: simd_float2(tl.x, br.y), color: color)
                    ])
                    bgIndices.append(contentsOf: [idx, idx+1, idx+2, idx, idx+2, idx+3])
                    idx += 4
                default:
                    break
                }
            }
            if !bgVertices.isEmpty {
                let vb = device.makeBuffer(bytes: bgVertices, length: bgVertices.count * MemoryLayout<QuadVertex>.size, options: .storageModeShared)
                renderEncoder.setVertexBuffer(vb, offset: 0, index: 0)
                // Uniforms buffer not needed; background_vertex outputs clip-space coords directly
                let ib = device.makeBuffer(bytes: bgIndices, length: bgIndices.count * MemoryLayout<UInt16>.size, options: .storageModeShared)
                renderEncoder.drawIndexedPrimitives(type: .triangle, indexCount: bgIndices.count, indexType: .uint16, indexBuffer: ib!, indexBufferOffset: 0)
            }
        }

        // Draw glyphs with per-run color
        guard let textPSO = renderPipelineState else { return }
        renderEncoder.setRenderPipelineState(textPSO)
        renderEncoder.setFragmentTexture(atlasTexture, index: 0)

        var vertices: [TextVertex] = []
        var indices: [UInt16] = []
        var current: UInt16 = 0
        for block in document.blocks {
            for run in block.content {
                let color = run.formatting.textColor
                let rgba = simd_float4(color.x, color.y, color.z, color.w)
                for glyph in run.glyphInfo {
                    let x = glyph.position.x
                    let y = glyph.position.y
                    let w = glyph.size.x
                    let h = glyph.size.y
                    let u = glyph.uvRect.x
                    let v = glyph.uvRect.y
                    let uw = glyph.uvRect.z
                    let vh = glyph.uvRect.w
                    // Four corners in screen space (origin at top-left)
                    let p0 = simd_float2(x, y - yOffset)          // top-left
                    let p1 = simd_float2(x + w, y - yOffset)      // top-right
                    let p2 = simd_float2(x + w, y + h - yOffset)  // bottom-right
                    let p3 = simd_float2(x, y + h - yOffset)      // bottom-left
                    // UVs (already normalized)
                    let t0 = simd_float2(u, v)
                    let t1 = simd_float2(u + uw, v)
                    let t2 = simd_float2(u + uw, v + vh)
                    let t3 = simd_float2(u, v + vh)
                    // Convert to clip space via uniforms in shader, so supply screen-space positions here
                    vertices.append(TextVertex(position: p0, texCoord: t0, color: rgba, glyphIndex: 0, animationPhase: 0))
                    vertices.append(TextVertex(position: p1, texCoord: t1, color: rgba, glyphIndex: 0, animationPhase: 0))
                    vertices.append(TextVertex(position: p2, texCoord: t2, color: rgba, glyphIndex: 0, animationPhase: 0))
                    vertices.append(TextVertex(position: p3, texCoord: t3, color: rgba, glyphIndex: 0, animationPhase: 0))
                    indices.append(contentsOf: [current, current+1, current+2, current, current+2, current+3])
                    current += 4
                }
            }
        }

        // Create buffers and uniforms
        if !vertices.isEmpty {
            let vb = device.makeBuffer(bytes: vertices, length: vertices.count * MemoryLayout<TextVertex>.size, options: .storageModeShared)
            let ib = device.makeBuffer(bytes: indices, length: indices.count * MemoryLayout<UInt16>.size, options: .storageModeShared)
            self.uniformBuffer = device.makeBuffer(length: MemoryLayout<TextRenderUniforms>.size, options: .storageModeShared)
            self.vertexBuffer = vb
            self.indexBuffer = ib
            self.textLayout = TextLayout(vertexCount: vertices.count, indexCount: indices.count, bounds: .zero)
            updateUniforms(viewport: viewport)
            renderEncoder.setVertexBuffer(vb, offset: 0, index: 0)
            renderEncoder.setVertexBuffer(uniformBuffer, offset: 0, index: 1)
            renderEncoder.setFragmentBuffer(uniformBuffer, offset: 0, index: 0)
            renderEncoder.drawIndexedPrimitives(type: .triangle, indexCount: indices.count, indexType: .uint16, indexBuffer: ib!, indexBufferOffset: 0)
        }

        // Draw a simple cursor marker at the end of the last run of the first block
        if let bgPSO = backgroundPipelineState, let first = document.blocks.first, let lastRun = first.content.last {
            renderEncoder.setRenderPipelineState(bgPSO)
            let x = CGFloat(lastRun.bounds.maxX) + 2
            let y0 = CGFloat(lastRun.bounds.minY) - CGFloat(yOffset)
            let y1 = CGFloat(lastRun.bounds.maxY) - CGFloat(yOffset)
            let p0 = ndc(from: CGPoint(x: x, y: y0), viewport: viewport)
            let p1 = ndc(from: CGPoint(x: x + 1.5, y: y0), viewport: viewport)
            let p2 = ndc(from: CGPoint(x: x + 1.5, y: y1), viewport: viewport)
            let p3 = ndc(from: CGPoint(x: x, y: y1), viewport: viewport)
            let color = simd_float4(0.2, 0.8, 1.0, 1.0)
            let verts = [QuadVertex(position: p0, color: color), QuadVertex(position: p1, color: color), QuadVertex(position: p2, color: color), QuadVertex(position: p3, color: color)]
            let inds: [UInt16] = [0,1,2,0,2,3]
            let vb = device.makeBuffer(bytes: verts, length: verts.count * MemoryLayout<QuadVertex>.size, options: .storageModeShared)
            let ib = device.makeBuffer(bytes: inds, length: inds.count * MemoryLayout<UInt16>.size, options: .storageModeShared)
            renderEncoder.setVertexBuffer(vb, offset: 0, index: 0)
            renderEncoder.drawIndexedPrimitives(type: .triangle, indexCount: 6, indexType: .uint16, indexBuffer: ib!, indexBufferOffset: 0)
        }
    }

    private func ndc(from point: CGPoint, viewport: CGSize) -> simd_float2 {
        // Convert from pixel space (origin top-left) to NDC (-1..1, origin center)
        let x = Float((point.x / viewport.width) * 2.0 - 1.0)
        let y = Float(1.0 - (point.y / viewport.height) * 2.0)
        return simd_float2(x, y)
    }
}

// MARK: - Supporting Types

struct TextLayout {
    let vertexCount: Int
    let indexCount: Int
    let bounds: CGRect
}

// MARK: - Metal Shaders (as strings for reference)

let textVertexShaderSource = """
#include <metal_stdlib>
using namespace metal;

struct VertexIn {
    float2 position [[attribute(0)]];
    float2 texCoord [[attribute(1)]];
    float4 color [[attribute(2)]];
    uint glyphIndex [[attribute(3)]];
    float animationPhase [[attribute(4)]];
};

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
    float4 color;
    float animationPhase;
};

struct Uniforms {
    float4x4 projectionMatrix;
    float4x4 viewMatrix;
    float time;
    float2 screenSize;
    float pixelScale;
    float3 subpixelShift;
};

vertex VertexOut textVertexShader(
    VertexIn in [[stage_in]],
    constant Uniforms& uniforms [[buffer(1)]]
) {
    VertexOut out;
    
    float4 worldPosition = float4(in.position, 0.0, 1.0);
    
    // Apply animation
    float wave = sin(uniforms.time * 2.0 + in.animationPhase) * 0.1;
    worldPosition.y += wave;
    
    out.position = uniforms.projectionMatrix * uniforms.viewMatrix * worldPosition;
    out.texCoord = in.texCoord;
    out.color = in.color;
    out.animationPhase = in.animationPhase;
    
    return out;
}
"""

let textFragmentShaderSource = """
#include <metal_stdlib>
using namespace metal;

struct FragmentIn {
    float4 position [[position]];
    float2 texCoord;
    float4 color;
    float animationPhase;
};

struct Uniforms {
    float4x4 projectionMatrix;
    float4x4 viewMatrix;
    float time;
    float2 screenSize;
    float pixelScale;
    float3 subpixelShift;
};

fragment float4 textFragmentShader(
    FragmentIn in [[stage_in]],
    texture2d<float> glyphTexture [[texture(0)]],
    constant Uniforms& uniforms [[buffer(0)]]
) {
    constexpr sampler textureSampler(
        mag_filter::linear,
        min_filter::linear,
        address::clamp_to_edge
    );
    
    float alpha = glyphTexture.sample(textureSampler, in.texCoord).r;
    
    // Apply color animation
    float4 animatedColor = in.color;
    float colorShift = sin(uniforms.time + in.animationPhase) * 0.5 + 0.5;
    animatedColor.rgb = mix(animatedColor.rgb, float3(1.0, 0.5, 0.2), colorShift * 0.3);
    
    return float4(animatedColor.rgb, animatedColor.a * alpha);
}
"""
