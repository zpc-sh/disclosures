//
//  Document.swift
//  Kyozo
//
//  Minimal in-memory document model.
//

import Foundation

struct Document: Identifiable, Hashable, Codable {
    var id: UUID = UUID()
    var name: String
    var text: String
}

