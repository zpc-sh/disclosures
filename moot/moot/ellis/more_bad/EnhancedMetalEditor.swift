//
//  EnhancedMetalEditor.swift
//  Kyozo
//
//  Enhanced Metal-based editor that preserves 120fps performance while improving UI
//

import SwiftUI
import MetalKit
import simd

#if os(macOS)
import AppKit

struct EnhancedMetalEditor: NSViewRepresentable {
    @Binding var notebook: Notebook
    @Binding var selection: UUID?
    @State private var fps: Double = 120.0
    @EnvironmentObject private var settings: SettingsState
    
    init(notebook: Binding<Notebook>, selection: Binding<UUID?>) {
        self._notebook = notebook
        self._selection = selection
    }
    
    func makeNSView(context: Context) -> EnhancedMTKView {
        let mtkView = EnhancedMTKView()
        mtkView.device = MTLCreateSystemDefaultDevice()
        mtkView.delegate = context.coordinator
        mtkView.enableSetNeedsDisplay = true
        mtkView.isPaused = false
        mtkView.preferredFramesPerSecond = 120 // Preserve 120fps
        
        // Enhanced visual properties
        mtkView.layer?.cornerRadius = 8
        mtkView.layer?.borderWidth = 1
        mtkView.layer?.borderColor = NSColor.separatorColor.cgColor
        
        return mtkView
    }
    
    func updateNSView(_ mtkView: EnhancedMTKView, context: Context) {
        context.coordinator.updateNotebook(notebook)
        context.coordinator.updateSelection(selection)
        // Propagate dynamic settings to coordinator so toggles take effect immediately
        context.coordinator.updateFeatureFlags(enableMarkdown: settings.enableMarkdownMetalEditor, enablePM: settings.enableProseMirrorEditor)
        mtkView.setNeedsDisplay(mtkView.bounds)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(
            notebook: notebook,
            selection: selection,
            enableMarkdownMetalEditor: settings.enableMarkdownMetalEditor,
            enableProseMirrorEditor: settings.enableProseMirrorEditor
        )
    }
    
    class Coordinator: NSObject, MTKViewDelegate {
        private var device: MTLDevice?
        var notebook: Notebook
        var selection: UUID?
        var enableMarkdownMetalEditor: Bool
        var enableProseMirrorEditor: Bool
        // Holds the active text buffer for Metal editor integration
        let textDocument: TextDocument
        // Markdown + Metal pipeline
        private var glyphAtlas: OptimizedGlyphAtlas?
        private var tiptap: TipTapMarkdownParser?
        private var textRenderer: MetalTextRenderer?
        private var renderedDoc: RenderedDocument?
        private var lastDocHash: Int = 0
        private var pmSelFrom: Int? = nil
        private var pmSelTo: Int? = nil
        private var solidPipeline: MTLRenderPipelineState?

        private func ndc(from point: CGPoint, viewport: CGSize) -> simd_float2 {
            let x = Float((point.x / viewport.width) * 2.0 - 1.0)
            let y = Float(1.0 - (point.y / viewport.height) * 2.0)
            return simd_float2(x, y)
        }

        private func ensureSolidPipeline(_ view: MTKView) {
            if solidPipeline == nil, let lib = view.device?.makeDefaultLibrary(), let v = lib.makeFunction(name: "background_vertex"), let f = lib.makeFunction(name: "background_fragment") {
                let d = MTLRenderPipelineDescriptor(); d.vertexFunction = v; d.fragmentFunction = f; d.colorAttachments[0].pixelFormat = view.colorPixelFormat
                solidPipeline = try? view.device?.makeRenderPipelineState(descriptor: d)
            }
        }

        private func drawSolidQuad(encoder: MTLRenderCommandEncoder, viewSize: CGSize, rect: CGRect, color: SIMD4<Float>) {
            struct V { var p: simd_float2; var c: SIMD4<Float> }
            let tl = ndc(from: CGPoint(x: rect.minX, y: rect.minY), viewport: viewSize)
            let br = ndc(from: CGPoint(x: rect.maxX, y: rect.maxY), viewport: viewSize)
            let verts = [V(p: simd_float2(tl.x, tl.y), c: color), V(p: simd_float2(br.x, tl.y), c: color), V(p: simd_float2(br.x, br.y), c: color), V(p: simd_float2(tl.x, br.y), c: color)]
            let inds: [UInt16] = [0,1,2,0,2,3]
            let vb = device?.makeBuffer(bytes: verts, length: verts.count * MemoryLayout<V>.size, options: .storageModeShared)
            let ib = device?.makeBuffer(bytes: inds, length: inds.count * MemoryLayout<UInt16>.size, options: .storageModeShared)
            encoder.setVertexBuffer(vb, offset: 0, index: 0)
            encoder.drawIndexedPrimitives(type: .triangle, indexCount: 6, indexType: .uint16, indexBuffer: ib!, indexBufferOffset: 0)
        }

        private func computeSelectionRects(_ doc: RenderedDocument, from: Int, to: Int) -> [CGRect] {
            if from == to { return [] }
            var rects: [CGRect] = []
            var index = 0
            for block in doc.blocks {
                for run in block.content {
                    for g in run.glyphInfo {
                        let start = index
                        let end = index + 1
                        if end > from && start < to {
                            let r = CGRect(x: CGFloat(g.position.x), y: CGFloat(g.position.y), width: CGFloat(g.size.x), height: CGFloat(g.size.y))
                            rects.append(r)
                        }
                        index += 1
                    }
                }
            }
            // Merge rects per line band
            let grouped = Dictionary(grouping: rects, by: { Int(($0.minY/18.0).rounded()) })
            return grouped.values.map { arr in
                let minY = arr.map { $0.minY }.min() ?? 0
                let maxY = arr.map { $0.maxY }.max() ?? 0
                let minX = arr.map { $0.minX }.min() ?? 0
                let maxX = arr.map { $0.maxX }.max() ?? 0
                return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
            }.sorted { $0.minY < $1.minY }
        }

        private func computeCaretRect(_ doc: RenderedDocument, at caret: Int) -> CGRect? {
            var index = 0
            var lastGlyph: GlyphRenderInfo? = nil
            for block in doc.blocks {
                for run in block.content {
                    for g in run.glyphInfo {
                        if index == caret { // caret before g
                            let x = CGFloat(g.position.x)
                            return CGRect(x: x, y: CGFloat(g.position.y), width: 1.5, height: CGFloat(g.size.y))
                        }
                        lastGlyph = g
                        index += 1
                    }
                }
            }
            if let lg = lastGlyph { // caret after last glyph
                let x = CGFloat(lg.position.x + lg.size.x)
                return CGRect(x: x, y: CGFloat(lg.position.y), width: 1.5, height: CGFloat(lg.size.y))
            }
            return nil
        }
        // Headless ProseMirror engine and command observers
        private var pmEngine: ProseMirrorEngine?
        private var observers: [NSObjectProtocol] = []
        private var lastFrameTime: CFAbsoluteTime = 0
        private var frameCount: Int = 0
        private var fpsUpdateTime: CFAbsoluteTime = 0
        
        // Enhanced rendering properties
        private var scrollOffset: Float = 0
        private var targetScrollOffset: Float = 0
        
        struct CellLayout {
            let cellId: UUID
            let rect: CGRect
            let type: CellKind
            var isSelected: Bool
        }
        
        struct CollaboratorCursor {
            let userId: String
            let position: CGPoint
            let color: simd_float4
            let userName: String
            var blinkPhase: Float
        }
        
        init(notebook: Notebook, selection: UUID?, enableMarkdownMetalEditor: Bool, enableProseMirrorEditor: Bool) {
            self.notebook = notebook
            self.selection = selection
            self.enableMarkdownMetalEditor = enableMarkdownMetalEditor
            self.enableProseMirrorEditor = enableProseMirrorEditor
            // Initialize a simple TextDocument snapshot from the notebook
            let md = MarkdownLPParser.toMarkdown(notebook.cells)
            self.textDocument = TextDocument(text: md)
            super.init()
            setupEngine()
            updateCellLayouts()
        }
        
        func updateFeatureFlags(enableMarkdown: Bool, enablePM: Bool) {
            // If flags changed, (lazily) set up engines as needed
            if enableMarkdown && !enableMarkdownMetalEditor, let device {
                glyphAtlas = OptimizedGlyphAtlas(device: device)
                tiptap = TipTapMarkdownParser(glyphAtlas: glyphAtlas!, baseFontSize: 14, lineHeightScale: 1.3, bodyFontFamily: .system)
                textRenderer = MetalTextRenderer(device: device)
            }
            if enablePM && !enableProseMirrorEditor {
                let engine = ProseMirrorEngine()
                engine.onChange = { [weak self] md in self?.textDocument.text = md; self?.renderedDoc = nil }
                engine.onState = { [weak self] state in
                    if let json = state.json { self?.textDocument.text = json } else { self?.textDocument.text = state.markdown }
                    NotificationCenter.default.post(name: .pmStateUpdated, object: nil, userInfo: [
                        "markdown": state.markdown,
                        "selectionFrom": state.selectionFrom as Any,
                        "selectionTo": state.selectionTo as Any
                    ])
                    self?.renderedDoc = nil
                }
                engine.setMarkdown(textDocument.text)
                pmEngine = engine
            }
            enableMarkdownMetalEditor = enableMarkdown
            enableProseMirrorEditor = enablePM
        }
        
        private func setupEngine() {
            device = MTLCreateSystemDefaultDevice()
            if enableMarkdownMetalEditor, let device {
                glyphAtlas = OptimizedGlyphAtlas(device: device)
                tiptap = TipTapMarkdownParser(glyphAtlas: glyphAtlas!, baseFontSize: 14, lineHeightScale: 1.3, bodyFontFamily: .system)
                textRenderer = MetalTextRenderer(device: device)
            }
            if enableProseMirrorEditor {
                let engine = ProseMirrorEngine()
                engine.onChange = { [weak self] md in
                    self?.textDocument.text = md
                    self?.renderedDoc = nil
                }
                engine.onState = { [weak self] state in
                    if let json = state.json { self?.textDocument.text = json } else { self?.textDocument.text = state.markdown }
                    NotificationCenter.default.post(name: .pmMarkdownChanged, object: nil, userInfo: ["markdown": state.markdown])
                    self?.pmSelFrom = state.selectionFrom
                    self?.pmSelTo = state.selectionTo
                    self?.renderedDoc = nil
                }
                engine.setMarkdown(textDocument.text)
                pmEngine = engine
                let nc = NotificationCenter.default
                observers.append(nc.addObserver(forName: .pmToggleBold, object: nil, queue: .main) { [weak self] _ in self?.pmEngine?.toggleBold() })
                observers.append(nc.addObserver(forName: .pmToggleItalic, object: nil, queue: .main) { [weak self] _ in self?.pmEngine?.toggleItalic() })
                observers.append(nc.addObserver(forName: .pmToggleH1, object: nil, queue: .main) { [weak self] _ in self?.pmEngine?.toggleHeading(1) })
                observers.append(nc.addObserver(forName: .pmToggleH2, object: nil, queue: .main) { [weak self] _ in self?.pmEngine?.toggleHeading(2) })
                observers.append(nc.addObserver(forName: .pmToggleCodeBlock, object: nil, queue: .main) { [weak self] _ in self?.pmEngine?.toggleCodeBlock() })
                observers.append(nc.addObserver(forName: .pmToggleBulletList, object: nil, queue: .main) { [weak self] _ in self?.pmEngine?.toggleBulletList() })
                observers.append(nc.addObserver(forName: .pmToggleOrderedList, object: nil, queue: .main) { [weak self] _ in self?.pmEngine?.toggleOrderedList() })
                observers.append(nc.addObserver(forName: .pmToggleBlockquote, object: nil, queue: .main) { [weak self] _ in self?.pmEngine?.toggleBlockquote() })
                observers.append(nc.addObserver(forName: .pmUndo, object: nil, queue: .main) { [weak self] _ in self?.pmEngine?.undo() })
                observers.append(nc.addObserver(forName: .pmRedo, object: nil, queue: .main) { [weak self] _ in self?.pmEngine?.redo() })
                observers.append(nc.addObserver(forName: .pmInsertLink, object: nil, queue: .main) { [weak self] note in
                    let href = (note.userInfo?["href"] as? String) ?? "https://example.com"
                    let title = note.userInfo?["title"] as? String
                    self?.pmEngine?.insertLink(href: href, title: title)
                })
                observers.append(nc.addObserver(forName: .pmInsertImage, object: nil, queue: .main) { [weak self] note in
                    let src = (note.userInfo?["src"] as? String) ?? "https://picsum.photos/200"
                    let alt = note.userInfo?["alt"] as? String
                    self?.pmEngine?.insertImage(src: src, alt: alt)
                })
                observers.append(nc.addObserver(forName: .pmInsertTable, object: nil, queue: .main) { [weak self] note in
                    let rows = (note.userInfo?["rows"] as? Int) ?? 3
                    let cols = (note.userInfo?["cols"] as? Int) ?? 3
                    self?.pmEngine?.insertTable(rows: rows, cols: cols)
                })
            }
        }
        
        func updateNotebook(_ notebook: Notebook) {
            self.notebook = notebook
            // When ProseMirror is active, it is the source of truth; avoid overwriting
            if !enableProseMirrorEditor {
                textDocument.text = MarkdownLPParser.toMarkdown(notebook.cells)
            }
        }
        
        func updateSelection(_ selection: UUID?) {
            self.selection = selection
        }
        
        func insertText(_ text: String) {
            if enableProseMirrorEditor {
                pmEngine?.insertText(text)
            } else {
                // Fallback: append to first markup cell and sync
                if let idx = notebook.cells.firstIndex(where: { $0.kind == .markup }) {
                    notebook.cells[idx].value.append(contentsOf: text)
                    textDocument.text = MarkdownLPParser.toMarkdown(notebook.cells)
                }
            }
        }
        
        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            // Update viewport size
            // TODO: Implement viewport update when MetalMarkdownEngine is available
        }
        
        func draw(in view: MTKView) {
            guard let drawable = view.currentDrawable,
                  let device = device else {
                return
            }
            
            // Update FPS calculation
            updateFPS()
            
            // Smooth scrolling animation
            updateScrollAnimation()
            
            // Create basic Metal rendering
            guard let commandQueue = device.makeCommandQueue(),
                  let commandBuffer = commandQueue.makeCommandBuffer(),
                  let renderPassDescriptor = view.currentRenderPassDescriptor else {
                return
            }
            
            // If markdown+metal is enabled, slightly alter background to indicate pipeline route
            if enableMarkdownMetalEditor {
                renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.09, green: 0.12, blue: 0.14, alpha: 1.0)
            } else {
                // Default background
                renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.1, green: 0.1, blue: 0.12, alpha: 1.0)
            }
            
            guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
                return
            }
            
            if enableMarkdownMetalEditor,
               let atlas = glyphAtlas?.texture,
               let tiptap,
               let renderer = textRenderer {
                // Build or reuse rendered document
                let text = textDocument.text
                let h = text.hashValue
                if renderedDoc == nil || h != lastDocHash {
                    renderedDoc = tiptap.parseMarkdown(text)
                    lastDocHash = h
                }
                if let doc = renderedDoc {
                    renderer.renderDocument(doc, atlasTexture: atlas, in: renderEncoder, viewport: view.drawableSize)
                    if let f = pmSelFrom, let t = pmSelTo, f < t {
                        ensureSolidPipeline(view)
                        if let pso = solidPipeline {
                            renderEncoder.setRenderPipelineState(pso)
                            let rects = computeSelectionRects(doc, from: f, to: t)
                            let color = SIMD4<Float>(0.20, 0.60, 1.00, 0.22)
                            for r in rects { drawSolidQuad(encoder: renderEncoder, viewSize: view.drawableSize, rect: r, color: color) }
                            // Draw selection handles (endpoints)
                            if let first = rects.first { let h = CGRect(x: first.minX - 3, y: first.minY, width: 6, height: first.height); drawSolidQuad(encoder: renderEncoder, viewSize: view.drawableSize, rect: h, color: SIMD4<Float>(0.20,0.60,1.00,0.9)) }
                            if let last = rects.last { let h = CGRect(x: last.maxX - 3, y: last.minY, width: 6, height: last.height); drawSolidQuad(encoder: renderEncoder, viewSize: view.drawableSize, rect: h, color: SIMD4<Float>(0.20,0.60,1.00,0.9)) }
                        }
                    } else if let c = pmSelFrom, let caret = computeCaretRect(doc, at: c) {
                        // Blinking caret
                        ensureSolidPipeline(view)
                        if let pso = solidPipeline {
                            renderEncoder.setRenderPipelineState(pso)
                            let t = CFAbsoluteTimeGetCurrent()
                            let visible = fmod(t, 1.2) < 0.6
                            if visible { drawSolidQuad(encoder: renderEncoder, viewSize: view.drawableSize, rect: caret, color: SIMD4<Float>(0.85, 0.90, 1.00, 0.95)) }
                        }
                    }
                }
            }

            renderEncoder.endEncoding()
            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
        
        private func updateFPS() {
            let currentTime = CFAbsoluteTimeGetCurrent()
            frameCount += 1
            
            if currentTime - fpsUpdateTime >= 1.0 {
                // Update FPS every second
                fpsUpdateTime = currentTime
                frameCount = 0
            }
        }
        
        private func updateScrollAnimation() {
            // Smooth scrolling interpolation
            let lerpFactor: Float = 0.15
            scrollOffset = scrollOffset + (targetScrollOffset - scrollOffset) * lerpFactor
        }
        
        // Handle scroll events
        func handleScroll(deltaY: Float) {
            targetScrollOffset = max(0, scrollOffset + deltaY * 0.5)
        }
    }
}

// Custom MTKView with enhanced interaction handling
class EnhancedMTKView: MTKView {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }
    
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        // Handle cell selection and cursor placement
        let location = convert(event.locationInWindow, from: nil)
        handleMouseDown(at: location)
    }
    
    override func mouseDragged(with event: NSEvent) {
        super.mouseDragged(with: event)
        // Handle text selection
        let location = convert(event.locationInWindow, from: nil)
        handleMouseDrag(to: location)
    }
    
    override func scrollWheel(with event: NSEvent) {
        // Smooth scrolling
        if let coordinator = delegate as? EnhancedMetalEditor.Coordinator {
            coordinator.handleScroll(deltaY: Float(event.scrollingDeltaY))
        }
    }
    
    override func keyDown(with event: NSEvent) {
        // Enhanced keyboard handling
        handleKeyDown(event)
        if let chars = event.characters, let coordinator = delegate as? EnhancedMetalEditor.Coordinator {
            coordinator.insertText(chars)
        }
    }
    
    private func handleMouseDown(at location: CGPoint) {
        // Find which cell was clicked and update selection
    }
    
    private func handleMouseDrag(to location: CGPoint) {
        // Update text selection range
    }
    
    private func handleKeyDown(_ event: NSEvent) {
        // Handle text editing, navigation, etc.
    }
}

#else
// iOS Implementation
import UIKit
import CoreText
import PencilKit

struct EnhancedMetalEditor: UIViewRepresentable {
    @Binding var notebook: Notebook
    @Binding var selection: UUID?
    @EnvironmentObject private var settingsManager: SettingsManager
    @EnvironmentObject private var settings: SettingsState
    
    func makeUIView(context: Context) -> MTKView {
        let mtkView = MTKView()
        mtkView.device = MTLCreateSystemDefaultDevice()
        mtkView.delegate = context.coordinator
        mtkView.enableSetNeedsDisplay = true
        mtkView.isPaused = false
        // Apply target frame rate preference (0 => adaptive/high)
        let target = settingsManager.targetFrameRate
        mtkView.preferredFramesPerSecond = target == 0 ? 120 : target
        
        // Enhanced visual properties for iOS
        mtkView.layer.cornerRadius = 12
        mtkView.layer.borderWidth = 1
        mtkView.layer.borderColor = UIColor.separator.cgColor
        // Apple Pencil double-tap support
        let pencilInteraction = UIPencilInteraction()
        pencilInteraction.delegate = context.coordinator
        mtkView.addInteraction(pencilInteraction)
        
        // Enable typing overlay to capture input (fallback until full Metal IME)
        _ = context.coordinator.ensureTextOverlay(on: mtkView)
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        mtkView.addGestureRecognizer(tap)
        // Drag-to-scroll
        let pan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        pan.maximumNumberOfTouches = 1
        mtkView.addGestureRecognizer(pan)
        
        return mtkView
    }
    
    func updateUIView(_ mtkView: MTKView, context: Context) {
        // Update notebook content
        context.coordinator.notebook = notebook
        context.coordinator.selection = selection
        // Keep TextDocument in sync for future Markdown+Metal pipeline
        context.coordinator.textDocument.text = MarkdownLPParser.toMarkdown(notebook.cells)
        mtkView.setNeedsDisplay()
        // Disable UIKit text overlay when ProseMirror is enabled
        if !settings.enableProseMirrorEditor {
            _ = context.coordinator.ensureTextOverlay(on: mtkView)
            context.coordinator.syncOverlayTextIfNeeded(on: mtkView)
        } else {
            context.coordinator.hideTextOverlay()
        }
        // Update FPS if changed at runtime
        let target = settingsManager.targetFrameRate
        let desired = target == 0 ? 120 : target
        if mtkView.preferredFramesPerSecond != desired {
            mtkView.preferredFramesPerSecond = desired
        }
        // Propagate dynamic flags to coordinator
        context.coordinator.updateFeatureFlags(enableMarkdown: settings.enableMarkdownMetalEditor, enablePM: settings.enableProseMirrorEditor)
    }
    
    func makeCoordinator() -> Coordinator {
        let fontSize = Float(settingsManager.fontSize)
        let lineHeight = Float(settingsManager.lineHeight)
        let family: TextFormatting.FontFamily = {
            let name = settingsManager.fontFamily.lowercased()
            if name.contains("mono") { return .monospace }
            if name.contains("serif") { return .serif }
            if name == "system monospace" { return .monospace }
            return .custom(settingsManager.fontFamily)
        }()
        return Coordinator(
            notebook: notebook,
            selection: selection,
            baseFontSize: fontSize,
            lineHeightScale: lineHeight,
            bodyFontFamily: family,
            doubleTapAction: settingsManager.doubleTapAction,
            enableAdvanced: settings.enableAdvancedRenderer,
            showLineNumbers: settings.showLineNumbers,
            softWrap: settings.softWrap,
            showWhitespace: settings.showWhitespace,
            metalLineNumbers: settings.metalLineNumbers,
            metalSelectionOverlay: settings.metalSelectionOverlay,
            enableAISuggestions: settings.enableAISuggestions,
            enableGhostGlyphs: settings.enableGhostGlyphs,
            enableCursorGlow: settings.enableCursorGlow,
            enableParticles: settings.enableParticles,
            enableTokenHighlights: settings.enableTokenHighlights,
            tokenHighlightOpacity: settings.tokenHighlightOpacity,
            cursorStyle: settings.cursorStyle,
            ghostDensity: settings.ghostDensity,
            particleCount: settings.particleCount,
            aiBubblePosition: settings.aiBubblePosition,
            beautyMode: settings.beautyMode,
            backgroundGradient: settings.backgroundGradient,
            enableAIConfidence: settings.enableAIConfidence,
            aiConfidenceOpacity: settings.aiConfidenceOpacity,
            enableTypographyWaves: settings.enableTypographyWaves,
            waveStrength: settings.waveStrength,
            semanticHighlightStyle: settings.semanticHighlightStyle,
            enableGPUDebugText: settings.enableGPUDebugText,
            enableMarkdownMetalEditor: settings.enableMarkdownMetalEditor,
            enableProseMirrorEditor: settings.enableProseMirrorEditor
        )
    }
    
    // iOS uses similar coordinator as macOS but with touch handling
    class Coordinator: NSObject, MTKViewDelegate, UIPencilInteractionDelegate, UITextViewDelegate {
        var notebook: Notebook
        var selection: UUID?
        var enableMarkdownMetalEditor: Bool
        var enableProseMirrorEditor: Bool
        // Holds the active text buffer for Metal editor integration
        let textDocument: TextDocument
        private var pmEngine: ProseMirrorEngine?
        private var observers: [NSObjectProtocol] = []
        private var renderer: MetalTextRenderer?
        private var effects: EffectsEngine?
        private var collabCursors: CollabCursorEngine?
        private var ghostRenderer: RecoveredGhostGlyphRenderer?
        private var ghostPSO: MTLRenderPipelineState?
        private var advancedBridge = AdvancedEditorBridge()
        private let baseFontSize: Float
        private let lineHeightScale: Float
        private let bodyFontFamily: TextFormatting.FontFamily
        private let doubleTapAction: DoubleTapAction
        private let enableAdvanced: Bool
        private let showLineNumbers: Bool
        private let softWrap: Bool
        private let showWhitespace: Bool
        private let metalLineNumbers: Bool
        private let metalSelectionOverlay: Bool
        private var texturedPipeline: MTLRenderPipelineState?
        private var solidPipeline: MTLRenderPipelineState?
        private var aiEngine = AIWritingSuggestionsEngine()
        private var currentTool: Tool = .text
        enum Tool { case text, eraser }
        private var textOverlay: UITextView?
        private var caretLine: Int = 0
        private var caretColumn: Int = 0
        private var caretPixel: CGPoint = .zero
        private var selectionPixelRects: [CGRect] = []
        // Token highlight state
        private var tokenHighlighter: SemanticHighlighter = LSPSemanticHighlighter()
        private var tokens: [SemanticTokenRange] = []
        private var tokensFetchedHash: Int = 0
        // Snapshot of user settings relevant to rendering
        private let enableTokenHighlights: Bool
        private let tokenHighlightOpacity: Double
        private let cursorStyle: String
        private let ghostDensity: Double
        private let particleCount: Int
        private let aiBubblePosition: String
        private let beautyMode: Bool
        private let backgroundGradient: Bool
        private let enableAIConfidence: Bool
        private let aiConfidenceOpacity: Double
        private let enableTypographyWaves: Bool
        private let waveStrength: Double
        private let semanticHighlightStyle: String
        private let enableGPUDebugText: Bool
        private var recoveredCursor = RecoveredEnhancedCursorRenderer()
        private var recoveredTypography = RecoveredTypographyEffectsEngine()
        private var recoveredSemantic = RecoveredSemanticHighlightRenderer()
        private var scrollOffset: CGFloat = 0
        private var contentHeight: CGFloat = 0
        private var pmSelFrom: Int? = nil
        private var pmSelTo: Int? = nil
        
        init(notebook: Notebook, selection: UUID?, baseFontSize: Float, lineHeightScale: Float, bodyFontFamily: TextFormatting.FontFamily, doubleTapAction: DoubleTapAction, enableAdvanced: Bool, showLineNumbers: Bool, softWrap: Bool, showWhitespace: Bool, metalLineNumbers: Bool, metalSelectionOverlay: Bool, enableAISuggestions: Bool, enableGhostGlyphs: Bool, enableCursorGlow: Bool, enableParticles: Bool, enableTokenHighlights: Bool, tokenHighlightOpacity: Double, cursorStyle: String, ghostDensity: Double, particleCount: Int, aiBubblePosition: String, beautyMode: Bool, backgroundGradient: Bool, enableAIConfidence: Bool, aiConfidenceOpacity: Double, enableTypographyWaves: Bool, waveStrength: Double, semanticHighlightStyle: String, enableGPUDebugText: Bool, enableMarkdownMetalEditor: Bool, enableProseMirrorEditor: Bool) {
            self.notebook = notebook
            self.selection = selection
            self.enableMarkdownMetalEditor = enableMarkdownMetalEditor
            self.enableProseMirrorEditor = enableProseMirrorEditor
            let md = MarkdownLPParser.toMarkdown(notebook.cells)
            self.textDocument = TextDocument(text: md)
            self.baseFontSize = baseFontSize
            self.lineHeightScale = lineHeightScale
            self.bodyFontFamily = bodyFontFamily
            self.doubleTapAction = doubleTapAction
            self.enableAdvanced = enableAdvanced
            self.showLineNumbers = showLineNumbers
            self.softWrap = softWrap
            self.showWhitespace = showWhitespace
            self.metalLineNumbers = metalLineNumbers
            self.metalSelectionOverlay = metalSelectionOverlay
            self.enableAISuggestions = enableAISuggestions
            self.enableGhostGlyphs = enableGhostGlyphs
            self.enableCursorGlow = enableCursorGlow
            self.enableParticles = enableParticles
            self.enableTokenHighlights = enableTokenHighlights
            self.tokenHighlightOpacity = tokenHighlightOpacity
            self.cursorStyle = cursorStyle
            self.ghostDensity = ghostDensity
            self.particleCount = particleCount
            self.aiBubblePosition = aiBubblePosition
            self.beautyMode = beautyMode
            self.backgroundGradient = backgroundGradient
            self.enableAIConfidence = enableAIConfidence
            self.aiConfidenceOpacity = aiConfidenceOpacity
            self.enableTypographyWaves = enableTypographyWaves
            self.waveStrength = waveStrength
            self.semanticHighlightStyle = semanticHighlightStyle
            self.enableGPUDebugText = enableGPUDebugText
            super.init()
            if enableProseMirrorEditor {
                let engine = ProseMirrorEngine()
                engine.onChange = { [weak self] md in self?.textDocument.text = md }
                engine.onState = { [weak self] state in
                    if let json = state.json { self?.textDocument.text = json } else { self?.textDocument.text = state.markdown }
                    NotificationCenter.default.post(name: .pmMarkdownChanged, object: nil, userInfo: ["markdown": state.markdown])
                    NotificationCenter.default.post(name: .pmStateUpdated, object: nil, userInfo: [
                        "markdown": state.markdown,
                        "selectionFrom": state.selectionFrom as Any,
                        "selectionTo": state.selectionTo as Any
                    ])
                    self?.pmSelFrom = state.selectionFrom
                    self?.pmSelTo = state.selectionTo
                    self?.selectionPixelRects.removeAll()
                }
                engine.setMarkdown(textDocument.text)
                pmEngine = engine
                let nc = NotificationCenter.default
                observers.append(nc.addObserver(forName: .pmToggleBold, object: nil, queue: .main) { [weak self] _ in self?.pmEngine?.toggleBold() })
                observers.append(nc.addObserver(forName: .pmToggleItalic, object: nil, queue: .main) { [weak self] _ in self?.pmEngine?.toggleItalic() })
                observers.append(nc.addObserver(forName: .pmToggleH1, object: nil, queue: .main) { [weak self] _ in self?.pmEngine?.toggleHeading(1) })
                observers.append(nc.addObserver(forName: .pmToggleH2, object: nil, queue: .main) { [weak self] _ in self?.pmEngine?.toggleHeading(2) })
                observers.append(nc.addObserver(forName: .pmToggleCodeBlock, object: nil, queue: .main) { [weak self] _ in self?.pmEngine?.toggleCodeBlock() })
                observers.append(nc.addObserver(forName: .pmToggleBulletList, object: nil, queue: .main) { [weak self] _ in self?.pmEngine?.toggleBulletList() })
                observers.append(nc.addObserver(forName: .pmToggleOrderedList, object: nil, queue: .main) { [weak self] _ in self?.pmEngine?.toggleOrderedList() })
                observers.append(nc.addObserver(forName: .pmToggleBlockquote, object: nil, queue: .main) { [weak self] _ in self?.pmEngine?.toggleBlockquote() })
                observers.append(nc.addObserver(forName: .pmUndo, object: nil, queue: .main) { [weak self] _ in self?.pmEngine?.undo() })
                observers.append(nc.addObserver(forName: .pmRedo, object: nil, queue: .main) { [weak self] _ in self?.pmEngine?.redo() })
                observers.append(nc.addObserver(forName: .pmInsertLink, object: nil, queue: .main) { [weak self] note in
                    let href = (note.userInfo?["href"] as? String) ?? "https://example.com"
                    let title = note.userInfo?["title"] as? String
                    self?.pmEngine?.insertLink(href: href, title: title)
                })
                observers.append(nc.addObserver(forName: .pmInsertImage, object: nil, queue: .main) { [weak self] note in
                    let src = (note.userInfo?["src"] as? String) ?? "https://picsum.photos/200"
                    let alt = note.userInfo?["alt"] as? String
                    self?.pmEngine?.insertImage(src: src, alt: alt)
                })
                observers.append(nc.addObserver(forName: .pmInsertTable, object: nil, queue: .main) { [weak self] note in
                    let rows = (note.userInfo?["rows"] as? Int) ?? 3
                    let cols = (note.userInfo?["cols"] as? Int) ?? 3
                    self?.pmEngine?.insertTable(rows: rows, cols: cols)
                })
            }
        }

        func updateFeatureFlags(enableMarkdown: Bool, enablePM: Bool) {
            // Lazy init subsystems on enable (renderer is created in draw lazily)
            if enablePM && !enableProseMirrorEditor {
                let engine = ProseMirrorEngine()
                engine.onChange = { [weak self] md in self?.textDocument.text = md }
                engine.onState = { [weak self] state in
                    if let json = state.json { self?.textDocument.text = json } else { self?.textDocument.text = state.markdown }
                    self?.pmSelFrom = state.selectionFrom
                    self?.pmSelTo = state.selectionTo
                }
                engine.setMarkdown(textDocument.text)
                pmEngine = engine
            }
            enableMarkdownMetalEditor = enableMarkdown
            enableProseMirrorEditor = enablePM
        }
        
        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            // Handle resize
        }
        
        func draw(in view: MTKView) {
            guard let device = view.device,
                  let drawable = view.currentDrawable,
                  let renderPassDescriptor = view.currentRenderPassDescriptor else { return }

            if renderer == nil { renderer = MetalTextRenderer(device: device) }
            if effects == nil { effects = EffectsEngine(device: device) }
            if collabCursors == nil { collabCursors = CollabCursorEngine(device: device) }
            if enableAdvanced { advancedBridge.prepare(device: device) }
            if ghostRenderer == nil { ghostRenderer = RecoveredGhostGlyphRenderer() }
            if ghostPSO == nil, let lib = device.makeDefaultLibrary(), let v = lib.makeFunction(name: "ghost_glyph_vertex"), let f = lib.makeFunction(name: "ghost_glyph_fragment") {
                let d = MTLRenderPipelineDescriptor(); d.vertexFunction = v; d.fragmentFunction = f; d.colorAttachments[0].pixelFormat = view.colorPixelFormat; d.colorAttachments[0].isBlendingEnabled = true; d.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha; d.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha; d.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha; d.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha;
                ghostPSO = try? device.makeRenderPipelineState(descriptor: d)
            }

            let commandQueue = device.makeCommandQueue()
            let commandBuffer = commandQueue?.makeCommandBuffer()
            // Base clear color; beauty mode adds gradient overlay later
            renderPassDescriptor.colorAttachments[0].clearColor = beautyMode ? MTLClearColorMake(0.08, 0.09, 0.12, 1.0) : MTLClearColorMake(0.10, 0.10, 0.12, 1.0)
            guard let encoder = commandBuffer?.makeRenderCommandEncoder(descriptor: renderPassDescriptor),
                  let renderer = renderer else {
                commandBuffer?.present(drawable)
                commandBuffer?.commit()
                return
            }
            // Build markdown and TipTap/Markdown-LD rendered document for per-run colors and backgrounds
            // Ensure we have a selection to route text changes
            ensureSelection()
            // Prefer ProseMirror state (JSON or markdown) from textDocument
            let markdown = textDocument.text
            let atlas = OptimizedGlyphAtlas(device: device)
            let tiptap = TipTapMarkdownParser(
                glyphAtlas: atlas,
                baseFontSize: baseFontSize,
                lineHeightScale: lineHeightScale,
                bodyFontFamily: bodyFontFamily
            )
            let doc = tiptap.parseMarkdown(markdown)
            contentHeight = CGFloat(doc.totalHeight)
            if let atlasTexture = atlas.texture {
                // Optional background gradient for beauty mode
                if beautyMode && backgroundGradient {
                    drawGradientBackground(in: encoder, view: view)
                }
                renderer.renderDocument(doc, atlasTexture: atlasTexture, in: encoder, viewport: view.drawableSize, yOffset: Float(scrollOffset))
                // Build selection rects from ProseMirror state if available
                if let f = pmSelFrom, let t = pmSelTo, f <= t {
                    var rects: [CGRect] = []
                    var index = 0
                    for block in doc.blocks {
                        for run in block.content {
                            for g in run.glyphInfo {
                                let start = index
                                let end = index + 1
                                if end > f && start < t {
                                    rects.append(CGRect(x: CGFloat(g.position.x), y: CGFloat(g.position.y), width: CGFloat(g.size.x), height: CGFloat(g.size.y)))
                                }
                                index += 1
                            }
                        }
                    }
                    let grouped = Dictionary(grouping: rects, by: { Int(($0.minY/18.0).rounded()) })
                    selectionPixelRects = grouped.values.map { arr in
                        let minY = arr.map { $0.minY }.min() ?? 0
                        let maxY = arr.map { $0.maxY }.max() ?? 0
                        let minX = arr.map { $0.minX }.min() ?? 0
                        let maxX = arr.map { $0.maxX }.max() ?? 0
                        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
                    }.sorted { $0.minY < $1.minY }
                }
                if enableAdvanced && FeatureGate.allows(.advancedEffects) {
                    // Render advanced overlays if shader modules are ready; else our EffectsEngine ghost glyphs
                    let proj = matrix_float4x4(diagonal: simd_float4(1,1,1,1))
                    advancedBridge.renderOverlays(
                        encoder: encoder,
                        projection: proj,
                        viewportSize: view.drawableSize,
                        mouse: .zero,
                        glyphAtlas: atlasTexture
                    )
                    // Render recovered ghost renderer with shader pipeline
                    if enableGhostGlyphs, let gr = ghostRenderer, let pso = ghostPSO {
                        var uniforms = AdvancedUniformsSwift(
                            projectionMatrix: matrix_identity_float4x4,
                            viewportSize: simd_float2(Float(view.drawableSize.width), Float(view.drawableSize.height)),
                            contentScaleFactor: Float(UIScreen.main.scale),
                            time: Float(CACurrentMediaTime()),
                            mousePosition: simd_float2(0,0),
                            hoverIntensity: 1.0,
                            globalAnimationPhase: Float(fmod(CACurrentMediaTime(), .pi * 2))
                        )
                        gr.render(with: encoder, uniforms: uniforms, pipeline: pso)
                    }
                }
                // Render collab cursor only when cursor enhancements are enabled
                if enableCursorGlow {
                    collabCursors?.render(encoder: encoder, viewport: view.drawableSize, at: CGPoint(x: 52, y: 10))
                }
                if showLineNumbers && metalLineNumbers {
                    drawMetalGutter(in: encoder, view: view)
                }
                if metalSelectionOverlay {
                    drawMetalSelection(in: encoder, view: view)
                }
                if enableTokenHighlights && FeatureGate.allows(.tokenHighlights) {
                    drawTokenHighlights(in: encoder, view: view)
                }
                if enableAIConfidence && FeatureGate.allows(.aiConfidence) {
                    drawAIConfidence(in: encoder, view: view)
                }
                if enableCursorGlow && FeatureGate.allows(.advancedEffects) { drawCursorGlow(in: encoder, view: view) }
                if enableGhostGlyphs && FeatureGate.allows(.advancedEffects) { drawGhostGlyphs(in: encoder, view: view) }
                if enableParticles { drawParticles(in: encoder, view: view) }
                if enableAISuggestions && FeatureGate.allows(.aiSuggestions) { drawAISuggestionBubble(in: encoder, view: view) }
                if enableTypographyWaves && FeatureGate.allows(.typographyWaves) { drawTypographyWaves(in: encoder, view: view) }
                if enableGPUDebugText { drawGPUDebugText(in: encoder, view: view, text: "GPU DEBUG TEXT") }
            }
            encoder.endEncoding()
            commandBuffer?.present(drawable)
            commandBuffer?.commit()
        }

        private func drawGradientBackground(in encoder: MTLRenderCommandEncoder, view: MTKView) {
            if solidPipeline == nil, let lib = view.device?.makeDefaultLibrary(),
               let v = lib.makeFunction(name: "background_vertex"),
               let f = lib.makeFunction(name: "background_fragment") {
                let desc = MTLRenderPipelineDescriptor(); desc.vertexFunction = v; desc.fragmentFunction = f; desc.colorAttachments[0].pixelFormat = view.colorPixelFormat
                solidPipeline = try? view.device?.makeRenderPipelineState(descriptor: desc)
            }
            guard let pso = solidPipeline else { return }
            encoder.setRenderPipelineState(pso)
            // Create two stacked quads for a subtle vertical gradient
            let top = SIMD4<Float>(0.10, 0.12, 0.18, 0.8)
            let bottom = SIMD4<Float>(0.07, 0.08, 0.12, 0.8)
            let midY = view.drawableSize.height * 0.45
            drawSolidQuad(encoder: encoder, viewSize: view.drawableSize, rect: CGRect(x: 0, y: 0, width: view.drawableSize.width, height: midY), color: top)
            drawSolidQuad(encoder: encoder, viewSize: view.drawableSize, rect: CGRect(x: 0, y: midY, width: view.drawableSize.width, height: view.drawableSize.height - midY), color: bottom)
        }

        private func drawMetalGutter(in encoder: MTLRenderCommandEncoder, view: MTKView) {
            let gutterWidth: CGFloat = 36
            if texturedPipeline == nil, let lib = view.device?.makeDefaultLibrary(),
               let v = lib.makeFunction(name: "simple_tex_vertex"),
               let f = lib.makeFunction(name: "simple_tex_fragment") {
                let desc = MTLRenderPipelineDescriptor()
                desc.vertexFunction = v
                desc.fragmentFunction = f
                desc.colorAttachments[0].pixelFormat = view.colorPixelFormat
                texturedPipeline = try? view.device?.makeRenderPipelineState(descriptor: desc)
            }
            guard let pso = texturedPipeline else { return }
            let height = Int(max(1, view.drawableSize.height))
            let width = Int(gutterWidth)
            let bytesPerPixel = 4
            let rowBytes = width * bytesPerPixel
            guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else { return }
            guard let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: rowBytes, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
            ctx.setFillColor(UIColor(white: 0.0, alpha: 0.06).cgColor)
            ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
            let paragraph = NSMutableParagraphStyle(); paragraph.alignment = .right
            let font = UIFont.monospacedSystemFont(ofSize: 10, weight: .regular)
            let attrs: [NSAttributedString.Key: Any] = [ .font: font, .foregroundColor: UIColor(white: 0.6, alpha: 1.0), .paragraphStyle: paragraph ]
            let lines = max(1, notebook.cells.map { $0.value.components(separatedBy: .newlines).count }.reduce(0, +))
            let lineHeight: CGFloat = 18
            ctx.saveGState(); ctx.translateBy(x: 0, y: CGFloat(height)); ctx.scaleBy(x: 1, y: -1)
            for i in 0..<lines {
                let y = CGFloat(i) * lineHeight + 12
                ("\(i+1)" as NSString).draw(in: CGRect(x: 0, y: y, width: CGFloat(width) - 4, height: lineHeight), withAttributes: attrs)
            }
            ctx.restoreGState()
            guard let data = ctx.data else { return }
            let texDesc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: width, height: height, mipmapped: false)
            texDesc.usage = [.shaderRead]
            texDesc.storageMode = .shared
            guard let tex = view.device?.makeTexture(descriptor: texDesc) else { return }
            tex.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0, withBytes: data, bytesPerRow: rowBytes)
            encoder.setRenderPipelineState(pso)
            // Scroll the gutter by translating its quad by -scrollOffset
            drawTexturedQuad(encoder: encoder, viewSize: view.drawableSize, rect: CGRect(x: 0, y: -scrollOffset, width: gutterWidth, height: CGFloat(height)), texture: tex)
        }

        private func drawMetalSelection(in encoder: MTLRenderCommandEncoder, view: MTKView) {
            if solidPipeline == nil, let lib = view.device?.makeDefaultLibrary(),
               let v = lib.makeFunction(name: "background_vertex"),
               let f = lib.makeFunction(name: "background_fragment") {
                let desc = MTLRenderPipelineDescriptor()
                desc.vertexFunction = v
                desc.fragmentFunction = f
                desc.colorAttachments[0].pixelFormat = view.colorPixelFormat
                solidPipeline = try? view.device?.makeRenderPipelineState(descriptor: desc)
            }
            guard let pso = solidPipeline else { return }
            encoder.setRenderPipelineState(pso)
            if !selectionPixelRects.isEmpty {
                let color = SIMD4<Float>(0.20, 0.60, 1.00, 0.22)
                for var r in selectionPixelRects {
                    r.origin.y -= scrollOffset
                    drawSolidQuad(encoder: encoder, viewSize: view.drawableSize, rect: r, color: color)
                }
            } else {
                let bar = CGRect(x: 40, y: 12 - scrollOffset, width: 140, height: 18)
                drawSolidQuad(encoder: encoder, viewSize: view.drawableSize, rect: bar, color: SIMD4<Float>(0.2, 0.6, 1.0, 0.18))
            }
        }

        private func drawTokenHighlights(in encoder: MTLRenderCommandEncoder, view: MTKView) {
            let combined = notebook.cells.map { $0.value }.joined(separator: "\n")
            let textHash = combined.hashValue
            if tokensFetchedHash != textHash {
                tokensFetchedHash = textHash
                let lang = notebook.cells.last(where: { $0.kind == .code })?.languageId ?? "plaintext"
                Task { [weak self] in
                    guard let self else { return }
                    let uri = "inmemory://editor"
                    let toks = await self.tokenHighlighter.tokens(for: combined, languageId: lang, uri: uri)
                    self.tokens = toks
                }
            }
            guard !tokens.isEmpty else { return }
            if solidPipeline == nil, let lib = view.device?.makeDefaultLibrary(), let v = lib.makeFunction(name: "background_vertex"), let f = lib.makeFunction(name: "background_fragment") {
                let d = MTLRenderPipelineDescriptor(); d.vertexFunction = v; d.fragmentFunction = f; d.colorAttachments[0].pixelFormat = view.colorPixelFormat
                solidPipeline = try? view.device?.makeRenderPipelineState(descriptor: d)
            }
            guard let pso = solidPipeline else { return }
            encoder.setRenderPipelineState(pso)
            let gutterWidth: CGFloat = 36
            let charWidth = CGFloat(baseFontSize) * 0.6
            let lineHeight: CGFloat = CGFloat(lineHeightScale * baseFontSize)
            let style: RecoveredSemanticHighlightRenderer.Style = (semanticHighlightStyle == "underline" ? .underline : (semanticHighlightStyle == "glow" ? .glow : .background))
            for t in tokens.prefix(2000) {
                var rects = recoveredSemantic.rects(for: t, charWidth: charWidth, lineHeight: lineHeight, gutterWidth: gutterWidth, style: style)
                let color = tokenColor(typeIndex: t.tokenType, opacity: Float(tokenHighlightOpacity))
                for i in 0..<rects.count { rects[i].origin.y -= scrollOffset }
                for r in rects { drawSolidQuad(encoder: encoder, viewSize: view.drawableSize, rect: r, color: color) }
            }
        }

        private func tokenColor(typeIndex: Int, opacity: Float) -> SIMD4<Float> {
            let legend = LSPSemanticHighlighter.defaultLegend
            if typeIndex >= 0 && typeIndex < legend.count {
                switch legend[typeIndex] {
                case "keyword": return SIMD4<Float>(0.80, 0.55, 1.00, opacity)
                case "string": return SIMD4<Float>(0.55, 0.90, 0.60, opacity)
                case "comment": return SIMD4<Float>(0.55, 0.55, 0.55, opacity)
                case "number", "enumMember": return SIMD4<Float>(0.95, 0.75, 0.45, opacity)
                case "function", "method": return SIMD4<Float>(0.50, 0.75, 1.00, opacity)
                case "variable", "parameter", "property": return SIMD4<Float>(0.60, 0.85, 1.00, opacity)
                case "type", "class", "interface", "enum", "struct", "namespace": return SIMD4<Float>(0.55, 0.85, 0.90, opacity)
                case "operator": return SIMD4<Float>(1.00, 0.60, 0.85, opacity)
                default: break
                }
            }
            return SIMD4<Float>(0.9, 0.9, 0.9, opacity)
        }

        private func drawAIConfidence(in encoder: MTLRenderCommandEncoder, view: MTKView) {
            // Heuristic confidence: if AI suggested something, mark last code line high; functions medium; others low
            if solidPipeline == nil, let lib = view.device?.makeDefaultLibrary(), let v = lib.makeFunction(name: "background_vertex"), let f = lib.makeFunction(name: "background_fragment") {
                let d = MTLRenderPipelineDescriptor(); d.vertexFunction = v; d.fragmentFunction = f; d.colorAttachments[0].pixelFormat = view.colorPixelFormat
                solidPipeline = try? view.device?.makeRenderPipelineState(descriptor: d)
            }
            guard let pso = solidPipeline else { return }
            encoder.setRenderPipelineState(pso)
            let gutterWidth: CGFloat = 36
            let charWidth = CGFloat(baseFontSize) * 0.6
            let lineHeight: CGFloat = CGFloat(lineHeightScale * baseFontSize)
            var highLine: Int? = nil
            if let last = notebook.cells.last(where: { $0.kind == .code }) {
                let lines = last.value.components(separatedBy: .newlines).count
                highLine = max(0, lines - 1)
            }
            // Build a simple confidence per line (0..1)
            let maxLine = max(tokens.map { $0.startLine }.max() ?? 0, highLine ?? 0)
            var confidence = Array(repeating: 0.1, count: maxLine + 1)
            for t in tokens {
                let legend = LSPSemanticHighlighter.defaultLegend
                if t.startLine < confidence.count, t.tokenType < legend.count {
                    let name = legend[t.tokenType]
                    if ["function","method"].contains(name) { confidence[t.startLine] = max(confidence[t.startLine], 0.6) }
                    if name == "keyword" { confidence[t.startLine] = max(confidence[t.startLine], 0.4) }
                }
            }
            if let hl = highLine, hl < confidence.count { confidence[hl] = max(confidence[hl], 0.9) }
            // Draw a thin bar on the right indicating confidence per line
            let barWidth: CGFloat = 6
            let x = view.drawableSize.width - barWidth - 8
            for (line, c) in confidence.enumerated() {
                let y = CGFloat(line) * lineHeight + 8 - scrollOffset
                let h = lineHeight * 0.9
                let col = confidenceColor(c, alpha: Float(aiConfidenceOpacity))
                drawSolidQuad(encoder: encoder, viewSize: view.drawableSize, rect: CGRect(x: x, y: y, width: barWidth, height: h), color: col)
                // Also draw a faint underline under highly confident lines
                if c > 0.8 {
                    drawSolidQuad(encoder: encoder, viewSize: view.drawableSize, rect: CGRect(x: gutterWidth, y: y + h + 1, width: view.drawableSize.width - gutterWidth - barWidth - 12, height: 1), color: col)
                }
            }
        }

        private func confidenceColor(_ c: Double, alpha: Float) -> SIMD4<Float> {
            if c > 0.8 { return SIMD4<Float>(0.10, 0.85, 0.30, alpha) }   // green high
            if c > 0.5 { return SIMD4<Float>(0.95, 0.85, 0.20, alpha) }   // yellow mid
            return SIMD4<Float>(0.80, 0.35, 0.25, alpha)                   // orange low
        }

        private func drawTexturedQuad(encoder: MTLRenderCommandEncoder, viewSize: CGSize, rect: CGRect, texture: MTLTexture) {
            func ndc(_ pt: CGPoint) -> SIMD2<Float> {
                let x = Float((pt.x / viewSize.width) * 2.0 - 1.0)
                let y = Float(1.0 - (pt.y / viewSize.height) * 2.0)
                return SIMD2<Float>(x, y)
            }
            struct V { var position: SIMD2<Float>; var uv: SIMD2<Float> }
            let tl = ndc(CGPoint(x: rect.minX, y: rect.minY))
            let tr = ndc(CGPoint(x: rect.maxX, y: rect.minY))
            let bl = ndc(CGPoint(x: rect.minX, y: rect.maxY))
            let br = ndc(CGPoint(x: rect.maxX, y: rect.maxY))
            let verts = [ V(position: tl, uv: SIMD2<Float>(0,0)), V(position: tr, uv: SIMD2<Float>(1,0)), V(position: bl, uv: SIMD2<Float>(0,1)), V(position: tr, uv: SIMD2<Float>(1,0)), V(position: br, uv: SIMD2<Float>(1,1)), V(position: bl, uv: SIMD2<Float>(0,1)) ]
            if let vb = encoder.device.makeBuffer(bytes: verts, length: MemoryLayout<V>.stride * verts.count, options: .storageModeShared) {
                encoder.setVertexBuffer(vb, offset: 0, index: 0)
                encoder.setFragmentTexture(texture, index: 0)
                encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: verts.count)
            }
        }

        private func drawSolidQuad(encoder: MTLRenderCommandEncoder, viewSize: CGSize, rect: CGRect, color: SIMD4<Float>) {
            func ndc(_ pt: CGPoint) -> SIMD2<Float> {
                let x = Float((pt.x / viewSize.width) * 2.0 - 1.0)
                let y = Float(1.0 - (pt.y / viewSize.height) * 2.0)
                return SIMD2<Float>(x, y)
            }
            struct V { var position: SIMD2<Float>; var color: SIMD4<Float> }
            let tl = ndc(CGPoint(x: rect.minX, y: rect.minY))
            let tr = ndc(CGPoint(x: rect.maxX, y: rect.minY))
            let bl = ndc(CGPoint(x: rect.minX, y: rect.maxY))
            let br = ndc(CGPoint(x: rect.maxX, y: rect.maxY))
            let verts = [ V(position: tl, color: color), V(position: tr, color: color), V(position: bl, color: color), V(position: tr, color: color), V(position: br, color: color), V(position: bl, color: color) ]
            if let vb = encoder.device.makeBuffer(bytes: verts, length: MemoryLayout<V>.stride * verts.count, options: .storageModeShared) {
                encoder.setVertexBuffer(vb, offset: 0, index: 0)
                encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: verts.count)
            }
        }

        // MARK: - Effects (lightweight placeholders)
        private let enableAISuggestions: Bool
        private let enableGhostGlyphs: Bool
        private let enableCursorGlow: Bool
        private let enableParticles: Bool

        private func drawCursorGlow(in encoder: MTLRenderCommandEncoder, view: MTKView) {
            if solidPipeline == nil, let lib = view.device?.makeDefaultLibrary(),
               let v = lib.makeFunction(name: "background_vertex"),
               let f = lib.makeFunction(name: "background_fragment") {
                let desc = MTLRenderPipelineDescriptor()
                desc.vertexFunction = v
                desc.fragmentFunction = f
                desc.colorAttachments[0].pixelFormat = view.colorPixelFormat
                solidPipeline = try? view.device?.makeRenderPipelineState(descriptor: desc)
            }
            guard let pso = solidPipeline else { return }
            encoder.setRenderPipelineState(pso)
            // Draw cursor based on style using recovered cursor renderer
            let base = CGPoint(x: 48, y: 18)
            let style: RecoveredEnhancedCursorRenderer.Style = (cursorStyle == "block" ? .block : (cursorStyle == "underline" ? .underline : .line))
            let rects = recoveredCursor.quads(for: style, at: base)
            for r in rects {
                drawSolidQuad(encoder: encoder, viewSize: view.drawableSize, rect: r, color: SIMD4<Float>(0.25, 0.55, 1.0, 0.35))
            }
        }

        private func drawTypographyWaves(in encoder: MTLRenderCommandEncoder, view: MTKView) {
            if solidPipeline == nil, let lib = view.device?.makeDefaultLibrary(), let v = lib.makeFunction(name: "background_vertex"), let f = lib.makeFunction(name: "background_fragment") {
                let d = MTLRenderPipelineDescriptor(); d.vertexFunction = v; d.fragmentFunction = f; d.colorAttachments[0].pixelFormat = view.colorPixelFormat
                solidPipeline = try? view.device?.makeRenderPipelineState(descriptor: d)
            }
            guard let pso = solidPipeline else { return }
            encoder.setRenderPipelineState(pso)
            let lineHeight: CGFloat = CGFloat(lineHeightScale * baseFontSize)
            let lines = max(1, notebook.cells.map { $0.value.components(separatedBy: .newlines).count }.reduce(0, +))
            var rects = recoveredTypography.underlineWaves(lineCount: lines, lineHeight: lineHeight, strength: waveStrength, width: view.drawableSize.width)
            for i in 0..<rects.count { rects[i].origin.y -= scrollOffset }
            let color = SIMD4<Float>(0.25, 0.55, 1.0, 0.10)
            for r in rects { drawSolidQuad(encoder: encoder, viewSize: view.drawableSize, rect: r, color: color) }
        }

        private func drawGhostGlyphs(in encoder: MTLRenderCommandEncoder, view: MTKView) {
            if solidPipeline == nil, let lib = view.device?.makeDefaultLibrary(),
               let v = lib.makeFunction(name: "background_vertex"),
               let f = lib.makeFunction(name: "background_fragment") {
                let desc = MTLRenderPipelineDescriptor()
                desc.vertexFunction = v
                desc.fragmentFunction = f
                desc.colorAttachments[0].pixelFormat = view.colorPixelFormat
                solidPipeline = try? view.device?.makeRenderPipelineState(descriptor: desc)
            }
            guard let pso = solidPipeline else { return }
            encoder.setRenderPipelineState(pso)
            let t = CACurrentMediaTime()
            for i in 0..<6 {
                let x = 60 + CGFloat(i * 14)
                let y = 40 + CGFloat(sin(t * 1.5 + Double(i)) * 6)
                let rect = CGRect(x: x, y: y, width: 8, height: 12)
                let alpha = 0.06 + 0.04 * Float((i % 3) + 1)
                drawSolidQuad(encoder: encoder, viewSize: view.drawableSize, rect: rect, color: SIMD4<Float>(1.0, 1.0, 1.0, alpha))
            }
        }

        private func drawParticles(in encoder: MTLRenderCommandEncoder, view: MTKView) {
            if solidPipeline == nil, let lib = view.device?.makeDefaultLibrary(),
               let v = lib.makeFunction(name: "background_vertex"),
               let f = lib.makeFunction(name: "background_fragment") {
                let desc = MTLRenderPipelineDescriptor()
                desc.vertexFunction = v
                desc.fragmentFunction = f
                desc.colorAttachments[0].pixelFormat = view.colorPixelFormat
                solidPipeline = try? view.device?.makeRenderPipelineState(descriptor: desc)
            }
            guard let pso = solidPipeline else { return }
            encoder.setRenderPipelineState(pso)
            let t = CACurrentMediaTime()
            let count = max(0, particleCount)
            for i in 0..<count {
                let x = 200 + CGFloat(cos(t * 0.8 + Double(i)) * 24)
                let y = 60 + CGFloat(sin(t * 0.9 + Double(i)) * 18)
                let rect = CGRect(x: x, y: y, width: 2, height: 2)
                drawSolidQuad(encoder: encoder, viewSize: view.drawableSize, rect: rect, color: SIMD4<Float>(1.0, 1.0, 1.0, 0.25))
            }
        }

        private func drawAISuggestionBubble(in encoder: MTLRenderCommandEncoder, view: MTKView) {
            // Render simple rounded bubble as texture + hint text from last code cell
            if texturedPipeline == nil, let lib = view.device?.makeDefaultLibrary(),
               let v = lib.makeFunction(name: "simple_tex_vertex"),
               let f = lib.makeFunction(name: "simple_tex_fragment") {
                let desc = MTLRenderPipelineDescriptor()
                desc.vertexFunction = v
                desc.fragmentFunction = f
                desc.colorAttachments[0].pixelFormat = view.colorPixelFormat
                texturedPipeline = try? view.device?.makeRenderPipelineState(descriptor: desc)
            }
            guard let pso = texturedPipeline else { return }
            let bubble = buildSuggestionTexture(view: view)
            guard let tex = bubble.texture else { return }
            encoder.setRenderPipelineState(pso)
            var rect = bubble.rect
            rect.origin.y -= scrollOffset
            drawTexturedQuad(encoder: encoder, viewSize: view.drawableSize, rect: rect, texture: tex)
        }

        // MARK: - GPU Debug Text (dev-only)
        private func drawGPUDebugText(in encoder: MTLRenderCommandEncoder, view: MTKView, text: String) {
            if texturedPipeline == nil, let lib = view.device?.makeDefaultLibrary(),
               let v = lib.makeFunction(name: "simple_tex_vertex"),
               let f = lib.makeFunction(name: "simple_tex_fragment") {
                let desc = MTLRenderPipelineDescriptor()
                desc.vertexFunction = v
                desc.fragmentFunction = f
                desc.colorAttachments[0].pixelFormat = view.colorPixelFormat
                texturedPipeline = try? view.device?.makeRenderPipelineState(descriptor: desc)
            }
            guard let pso = texturedPipeline else { return }
            let (tex, rect) = buildTextTexture(view: view, text: text)
            guard let t = tex else { return }
            encoder.setRenderPipelineState(pso)
            let y: CGFloat = 8 - scrollOffset
            drawTexturedQuad(encoder: encoder, viewSize: view.drawableSize, rect: CGRect(x: 8, y: y, width: rect.width, height: rect.height), texture: t)
        }

        private func buildTextTexture(view: MTKView, text: String) -> (MTLTexture?, CGSize) {
            let padding: CGFloat = 6
            let font = UIFont.boldSystemFont(ofSize: 12)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: UIColor.white
            ]
            let size = (text as NSString).size(withAttributes: attrs)
            let width = max(1, Int(ceil(size.width + padding * 2)))
            let height = max(1, Int(ceil(size.height + padding * 2)))
            let bytesPerPixel = 4
            let rowBytes = max(width * bytesPerPixel, 4)
            guard let cs = CGColorSpace(name: CGColorSpace.sRGB) else { return (nil, .zero) }
            guard let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: rowBytes, space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return (nil, .zero) }
            ctx.setFillColor(UIColor(white: 0, alpha: 0.6).cgColor)
            ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
            ctx.saveGState(); ctx.translateBy(x: 0, y: CGFloat(height)); ctx.scaleBy(x: 1, y: -1)
            (text as NSString).draw(at: CGPoint(x: padding, y: padding), withAttributes: attrs)
            ctx.restoreGState()
            guard let data = ctx.data else { return (nil, .zero) }
            let desc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: width, height: height, mipmapped: false)
            desc.usage = [.shaderRead]
            desc.storageMode = .shared
            let tex = view.device?.makeTexture(descriptor: desc)
            tex?.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0, withBytes: data, bytesPerRow: rowBytes)
            return (tex, CGSize(width: width, height: height))
        }

        private func buildSuggestionTexture(view: MTKView) -> (texture: MTLTexture?, rect: CGRect) {
            let text = suggestionText()
            let padding: CGFloat = 8
            let font = UIFont.systemFont(ofSize: 11)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: UIColor(white: 0.95, alpha: 1.0)
            ]
            let size = (text as NSString).size(withAttributes: attributes)
            let width = Int(ceil(size.width + padding * 2))
            let height = Int(ceil(size.height + padding * 2))
            let bytesPerPixel = 4
            let rowBytes = width * bytesPerPixel
            guard let cs = CGColorSpace(name: CGColorSpace.sRGB) else { return (nil, .zero) }
            guard let ctx = CGContext(data: nil, width: max(width, 1), height: max(height, 1), bitsPerComponent: 8, bytesPerRow: max(rowBytes, 4), space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return (nil, .zero) }
            // Bubble background
            ctx.setFillColor(UIColor(white: 0.15, alpha: 0.9).cgColor)
            let bubbleRect = CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height))
            let path = UIBezierPath(roundedRect: bubbleRect, cornerRadius: 8).cgPath
            ctx.addPath(path)
            ctx.fillPath()
            // Draw text
            ctx.saveGState(); ctx.translateBy(x: 0, y: CGFloat(height)); ctx.scaleBy(x: 1, y: -1)
            (text as NSString).draw(at: CGPoint(x: padding, y: padding), withAttributes: attributes)
            ctx.restoreGState()
            guard let data = ctx.data else { return (nil, .zero) }
            let desc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: max(width, 1), height: max(height, 1), mipmapped: false)
            desc.usage = [.shaderRead]
            desc.storageMode = .shared
            let tex = view.device?.makeTexture(descriptor: desc)
            tex?.replace(region: MTLRegionMake2D(0, 0, max(width, 1), max(height, 1)), mipmapLevel: 0, withBytes: data, bytesPerRow: max(rowBytes, 4))
            let x: CGFloat = aiBubblePosition == "top-right" ? (view.drawableSize.width - CGFloat(width) - 16) : 40
            let rect = CGRect(x: x, y: 36, width: CGFloat(width), height: CGFloat(height))
            return (tex, rect)
        }

        private func suggestionText() -> String {
            let lang = notebook.cells.last(where: { $0.kind == .code })?.languageId
            let combined = notebook.cells.map { $0.value }.joined(separator: "\n")
            if let s = aiEngine.suggest(forNotebookText: combined, languageHint: lang) {
                return s.text
            }
            return "// Suggest: add a comment or print()"
        }

        

        // MARK: - Input overlay
        func ensureTextOverlay(on view: MTKView) -> UITextView {
            if let tv = textOverlay { return tv }
            let tv = UITextView(frame: view.bounds)
            tv.backgroundColor = .clear
            // Fallback text: show overlay text if enabled in settings
            let showFallback = SettingsState().showOverlayTextFallback
            tv.textColor = showFallback ? .label : .clear
            tv.tintColor = UIColor.systemBlue.withAlphaComponent(0.8) // visible caret
            tv.autocorrectionType = .no
            tv.autocapitalizationType = .none
            tv.spellCheckingType = .no
            tv.isScrollEnabled = false
            tv.delegate = self
            tv.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            view.addSubview(tv)
            textOverlay = tv
            // Seed with current selection if present
            if let sel = selection, let idx = notebook.cells.firstIndex(where: { $0.id == sel }) {
                tv.text = notebook.cells[idx].value
            } else if let first = notebook.cells.first {
                selection = first.id
                tv.text = first.value
            }
            return tv
        }

        func hideTextOverlay() {
            textOverlay?.removeFromSuperview()
            textOverlay = nil
        }

        func syncOverlayTextIfNeeded(on view: MTKView) {
            guard let tv = textOverlay else { return }
            if let sel = selection, let idx = notebook.cells.firstIndex(where: { $0.id == sel }) {
                if tv.text != notebook.cells[idx].value { tv.text = notebook.cells[idx].value }
            } else if let first = notebook.cells.first {
                selection = first.id
                tv.text = first.value
            }
        }

        @objc func handleTap(_ sender: UITapGestureRecognizer) {
            guard let view = sender.view as? MTKView else { return }
            let point = sender.location(in: view)
            let gutterWidth: CGFloat = 36
            let charWidth = CGFloat(baseFontSize) * 0.6
            let lineHeight: CGFloat = CGFloat(lineHeightScale * baseFontSize)
            caretColumn = max(0, Int((point.x - gutterWidth) / charWidth))
            caretLine = max(0, Int((point.y - 8) / lineHeight))
            let tv = ensureTextOverlay(on: view)
            syncOverlayTextIfNeeded(on: view)
            tv.becomeFirstResponder()
        }

        @objc func handlePan(_ sender: UIPanGestureRecognizer) {
            guard let v = sender.view as? MTKView else { return }
            let dy = sender.translation(in: v).y
            sender.setTranslation(.zero, in: v)
            let maxOffset = max(0, contentHeight - v.bounds.height)
            scrollOffset = min(max(scrollOffset - dy, 0), maxOffset)
        }

        func textViewDidChange(_ textView: UITextView) {
            if let sel = selection, let idx = notebook.cells.firstIndex(where: { $0.id == sel }) {
                notebook.cells[idx].value = textView.text
                if enableProseMirrorEditor { pmEngine?.setMarkdown(textView.text) }
            }
        }

        private func ensureSelection() {
            if selection == nil { selection = notebook.cells.first?.id }
        }
// MARK: - UIPencilInteractionDelegate
        func pencilInteractionDidTap(_ interaction: UIPencilInteraction) {
            switch doubleTapAction {
            case .switchTools:
                currentTool = (currentTool == .text) ? .eraser : .text
            case .colorPalette:
                NotificationCenter.default.post(name: Notification.Name("kyozo.showColorPalette"), object: nil)
            case .eraser:
                currentTool = .eraser
            case .none:
                break
            }
        }
    }
}
#endif
