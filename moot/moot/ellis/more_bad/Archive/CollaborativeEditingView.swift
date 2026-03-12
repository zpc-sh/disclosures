//
//  CollaborativeEditingView.swift
//  Kyozo
//
//  Created by Loc Nguyen on 8/16/25.
//



## CollaborativeEditingView.swift - Real-time CRDT Sync
```swift
import SwiftUI
import Combine

struct CollaborativeEditingView: View {
    @ObservedObject var document: Document
    @StateObject private var crdt = CRDTManager()
    @State private var collaboratorCursors: [CollaboratorCursor] = []
    
    var body: some View {
        ZStack {
            // Main editor
            TextEditor(text: $document.content)
                .onChange(of: document.content) { newValue in
                    // Generate CRDT operations
                    let ops = crdt.generateOperations(newValue)
                    Task {
                        await sendCRDTUpdate(ops)
                    }
                }
                .overlay(
                    // Collaborator cursors
                    ForEach(collaboratorCursors) { cursor in
                        CollaboratorCursorView(cursor: cursor)
                            .position(cursor.position)
                            .animation(.spring(), value: cursor.position)
                    }
                )
        }
        .task {
            // Subscribe to CRDT updates
            for await update in crdt.updates {
                applyRemoteUpdate(update)
            }
        }
    }
    
    private func applyRemoteUpdate(_ update: CRDTUpdate) {
        // Apply without triggering onChange
        document.content = crdt.apply(update, to: document.content)
        
        // Update collaborator cursor
        if let cursor = collaboratorCursors.first(where: { $0.userId == update.authorId }) {
            cursor.position = update.cursorPosition
        } else {
            collaboratorCursors.append(
                CollaboratorCursor(
                    userId: update.authorId,
                    position: update.cursorPosition,
                    color: .random
                )
            )
        }
    }
}


struct CollaboratorCursorView: View {
    let cursor: CollaboratorCursor
    
    var body: some View {
        VStack(spacing: 0) {
            // Cursor line
            Rectangle()
                .fill(cursor.color)
                .frame(width: 2, height: 20)
            
            // User avatar
            Circle()
                .fill(cursor.color)
                .frame(width: 24, height: 24)
                .overlay(
                    Text(cursor.initials)
                        .font(.caption)
                        .foregroundColor(.white)
                )
        }
    }
}
```

