//
//  CustomTextView.swift
//  Kyozo
//
//  Created by Loc Nguyen on 8/16/25.
//

class CustomTextView: NSTextView {
    var highlighter: GPUHighlighter?
    var crdtEngine: CRDTEngine?
    
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        // Custom keyboard shortcuts
        if event.modifierFlags.contains(.command) {
            switch event.charactersIgnoringModifiers {
            case "r":
                executeCurrentBlock()
                return true
            case "e":
                enhanceWithClaude()
                return true
            case "/":
                toggleComment()
                return true
            default:
                break
            }
        }
        
        return super.performKeyEquivalent(with: event)
    }
    
    private func executeCurrentBlock() {
        // Find code block at cursor
        let cursorLocation = selectedRange().location
        if let block = findCodeBlock(at: cursorLocation) {
            NotificationCenter.default.post(
                name: .executeCodeBlock,
                object: block
            )
        }
    }
    
    private func enhanceWithClaude() {
        let selectedText = string[selectedRange()]
        Task {
            let enhanced = await ClaudeService.enhance(selectedText)
            await MainActor.run {
                self.insertText(enhanced, replacementRange: selectedRange())
            }
        }
    }
}
