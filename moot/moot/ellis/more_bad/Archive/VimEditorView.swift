//
//  VimEditorView.swift
//  Kyozo
//
//  Created by Loc Nguyen on 8/16/25.
//



## VimEditorView.swift - FULL VIM IN SWIFTUI
```swift
import SwiftUI
import Metal
import MetalPerformanceShaders

struct VimEditorView: NSViewControllerRepresentable {
    @Binding var document: Document
    @StateObject private var vimState = VimState()
    @EnvironmentObject var claudeAvatar: ClaudeAvatarEngine
    
    func makeNSViewController(context: Context) -> VimViewController {
        let vc = VimViewController()
        vc.delegate = context.coordinator
        vc.document = document
        vc.claudeAvatar = claudeAvatar
        return vc
    }
    
    func updateNSViewController(_ vc: VimViewController, context: Context) {
        vc.document = document
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: VimDelegate {
        var parent: VimEditorView
        
        init(_ parent: VimEditorView) {
            self.parent = parent
        }
    }
}

