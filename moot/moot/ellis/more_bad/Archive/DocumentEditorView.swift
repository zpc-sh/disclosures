//
//  DocumentEditorView.swift
//  Kyozo
//
//  Created by Loc Nguyen on 8/16/25.
//


import SwiftUI
import CodeEditor
import MarkdownUI

struct DocumentEditorView: View {
    @ObservedObject var document: Document
    @EnvironmentObject var metalEngine: MetalMarkdownEngine
    @StateObject private var editorState = EditorState()
    @State private var showPreview = true
    @State private var executionResults: [String: ExecutionResult] = [:]
    @State private var selectedTab: EditorTab = .edit
    
    enum EditorTab: String, CaseIterable {
        case edit = "Edit"
        case preview = "Preview"
        case split = "Split"
        case execute = "Execute"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            EditorToolbar(
                document: document,
                selectedTab: $selectedTab,
                onExecute: executeCurrentBlock
            )
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            Divider()
            
            // Main Editor Area
            GeometryReader { geometry in
                switch selectedTab {
                case .edit:
                    MarkdownEditorView(
                        text: $document.content,
                        language: document.language,
                        theme: editorState.theme,
                        onTextChange: handleTextChange
                    )
                    
                case .preview:
                    ScrollView {
                        MetalMarkdownView(
                            markdown: document.content,
                            engine: metalEngine
                        )
                        .padding()
                    }
                    
                case .split:
                    HSplitView {
                        MarkdownEditorView(
                            text: $document.content,
                            language: document.language,
                            theme: editorState.theme,
                            onTextChange: handleTextChange
                        )
                        
                        ScrollView {
                            MetalMarkdownView(
                                markdown: document.content,
                                engine: metalEngine
                            )
                            .padding()
                        }
                    }
                    
                case .execute:
                    ExecutionView(
                        document: document,
                        results: $executionResults
                    )
                }
            }
        }
        .navigationTitle(document.title)
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Button(action: { selectedTab = .edit }) {
                    Image(systemName: "pencil")
                }
                .keyboardShortcut("1", modifiers: .command)
                
                Button(action: { selectedTab = .preview }) {
                    Image(systemName: "eye")
                }
                .keyboardShortcut("2", modifiers: .command)
                
                Button(action: { selectedTab = .split }) {
                    Image(systemName: "rectangle.split.2x1")
                }
                .keyboardShortcut("3", modifiers: .command)
            }
            
            ToolbarItemGroup(placement: .primaryAction) {
                CollaboratorAvatars(document: document)
                
                Button(action: shareDocument) {
                    Image(systemName: "square.and.arrow.up")
                }
                
                Menu {
                    Button("Execute All", action: executeAll)
                    Button("Execute Selected", action: executeSelected)
                    Divider()
                    Button("GPU Acceleration", action: toggleGPU)
                        .badge(metalEngine.isEnabled ? "ON" : "OFF")
                } label: {
                    Image(systemName: "play.circle")
                }
            }
        }
        .searchable(text: $editorState.searchText)
        .onReceive(document.$content.debounce(for: .milliseconds(500), scheduler: RunLoop.main)) { _ in
            Task {
                await document.save()
            }
        }
    }
    
    private func handleTextChange(_ text: String) {
        // Send CRDT delta over binary protocol
        Task {
            let delta = CRDTDelta(
                content: text,
                timestamp: Date(),
                authorId: appState.currentUser.id
            )
            
            await appState.sendBinaryUpdate(delta)
        }
    }
    
    private func executeCurrentBlock() {
        guard let block = document.currentCodeBlock else { return }
        
        Task {
            let result = await KyozoExecutor.execute(
                code: block.code,
                language: block.language,
                useGPU: metalEngine.isEnabled
            )
            
            await MainActor.run {
                executionResults[block.id] = result
            }
        }
    }
}

