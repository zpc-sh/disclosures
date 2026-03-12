//
//  MarkdownEditorView.swift
//  Kyozo
//
//  Created by Loc Nguyen on 8/16/25.
//



## MarkdownEditorView.swift - Custom Text Editor
import SwiftUI
import Highlighter

struct MarkdownEditorView: NSViewRepresentable {
    @Binding var text: String
    let language: Language
    let theme: Theme
    let onTextChange: (String) -> Void
    
    func makeNSView(context: Context) -> CustomTextView {
        let textView = CustomTextView()
        textView.delegate = context.coordinator
        textView.string = text
        textView.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        
        // Setup syntax highlighting with GPU acceleration
        textView.highlighter = GPUHighlighter(theme: theme)
        
        // Setup CRDT for conflict-free editing
        textView.crdtEngine = CRDTEngine()
        
        return textView
    }
    
    func updateNSView(_ nsView: CustomTextView, context: Context) {
        if nsView.string != text {
            nsView.string = text
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MarkdownEditorView
        private var updateTimer: Timer?
        
        init(_ parent: MarkdownEditorView) {
            self.parent = parent
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            
            // Debounce updates
            updateTimer?.invalidate()
            updateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { _ in
                self.parent.text = textView.string
                self.parent.onTextChange(textView.string)
            }
        }
    }
}

