//
//  ExecutionView.swift
//  Kyozo
//
//  Created by Loc Nguyen on 8/16/25.
//



## ExecutionView.swift - Code Execution with WASM
```swift
import SwiftUI
import JavaScriptCore

struct ExecutionView: View {
    @ObservedObject var document: Document
    @Binding var results: [String: ExecutionResult]
    @State private var isExecuting = false
    @State private var selectedLanguage: Language = .python
    
    var body: some View {
        VSplitView {
            // Code blocks
            List(document.codeBlocks) { block in
                CodeBlockView(
                    block: block,
                    result: results[block.id],
                    onExecute: { executeBlock(block) }
                )
            }
            
            // Execution output
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(results.values), id: \.id) { result in
                        ExecutionResultView(result: result)
                    }
                }
                .padding()
            }
            .background(Color(NSColor.controlBackgroundColor))
        }
        .toolbar {
            ToolbarItemGroup {
                Button("Execute All") {
                    executeAll()
                }
                .disabled(isExecuting)
                
                Picker("Language", selection: $selectedLanguage) {
                    ForEach(Language.allCases) { lang in
                        Text(lang.rawValue).tag(lang)
                    }
                }
            }
        }
    }
    
    private func executeBlock(_ block: CodeBlock) {
        isExecuting = true
        
        Task {
            let executor = WASMExecutor()
            
            // Compile to WASM if needed
            let wasmModule = try await executor.compile(
                code: block.code,
                language: block.language
            )
            
            // Execute in sandbox
            let result = try await executor.execute(
                module: wasmModule,
                timeout: 5000,
                memoryLimit: 10_485_760 // 10MB
            )
            
            await MainActor.run {
                results[block.id] = result
                isExecuting = false
            }
        }
    }
}

