//
//  RichTextToolbar.swift
//  Kyozo
//
//  Lightweight rich-text toolbar shown above the editor.
//

import SwiftUI

struct RichTextToolbar: View {
    var onBold: () -> Void
    var onItalic: () -> Void
    var onH1: () -> Void
    var onH2: () -> Void
    var onCode: () -> Void
    var onBulletList: () -> Void
    var onOrderedList: () -> Void
    var onQuote: () -> Void
    var onLink: () -> Void
    var onImage: () -> Void
    var onTable: () -> Void
    var onUndo: () -> Void
    var onRedo: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Group {
                Button(action: onBold) { Image(systemName: "bold") }
                Button(action: onItalic) { Image(systemName: "italic") }
                Divider().frame(height: 14)
                Button(action: onH1) { Text("H1").font(.caption).bold() }
                Button(action: onH2) { Text("H2").font(.caption).bold() }
                Divider().frame(height: 14)
                Button(action: onCode) { Image(systemName: "curlybraces") }
                Button(action: onBulletList) { Image(systemName: "list.bullet") }
                Button(action: onOrderedList) { Image(systemName: "list.number") }
                Button(action: onQuote) { Image(systemName: "text.quote") }
                Divider().frame(height: 14)
                Button(action: onLink) { Image(systemName: "link") }
                Button(action: onImage) { Image(systemName: "photo") }
                Button(action: onTable) { Image(systemName: "tablecells") }
                Divider().frame(height: 14)
                Button(action: onUndo) { Image(systemName: "arrow.uturn.backward") }
                Button(action: onRedo) { Image(systemName: "arrow.uturn.forward") }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
    }
}
