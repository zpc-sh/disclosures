//
//  OpenAPIModels.swift
//  Kyozo
//
//  Enhanced OpenAPI models for Kyozo Store integration
//

import Foundation
import SwiftUI

// MARK: - Base Response Types

struct EmptyResponse: Codable {}

// MARK: - Workspace Models

struct WorkspaceListResponse: Codable {
    let data: [Workspace]
    let meta: PaginationMeta
    let links: PaginationLinks
}

struct WorkspaceResponse: Codable {
    let data: Workspace
}

struct Workspace: Identifiable, Codable {
    let type: String // Always "workspace"
    let id: UUID
    let attributes: WorkspaceAttributes
    let relationships: WorkspaceRelationships?
    
    // Computed properties for easier access
    var name: String { attributes.name }
    var description: String { attributes.description }
    var status: WorkspaceStatus { attributes.status }
    var createdAt: Date { attributes.createdAt }
    var updatedAt: Date { attributes.updatedAt }
    
    enum WorkspaceStatus: String, CaseIterable, Codable {
        case active, inactive, archived
    }
}

struct WorkspaceAttributes: Codable {
    let name: String
    let description: String
    let status: Workspace.WorkspaceStatus
    let composeConfig: AnyCodable?
    let settings: AnyCodable?
    let createdAt: Date
    let updatedAt: Date
    
    private enum CodingKeys: String, CodingKey {
        case name, description, status, settings
        case composeConfig = "compose_config"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct WorkspaceRelationships: Codable {
    let services: RelationshipLinks?
    let files: RelationshipLinks?
}

struct RelationshipLinks: Codable {
    let links: Links
}

struct Links: Codable {
    let related: String
}

// MARK: - Workspace Request Models

struct WorkspaceCreateRequestBody: Codable {
    let data: WorkspaceCreateRequest
}

struct WorkspaceCreateRequest: Codable {
    let type: String // "workspace"
    let attributes: WorkspaceCreateAttributes
}

struct WorkspaceCreateAttributes: Codable {
    let name: String
    let description: String
    let templateId: String?
    
    private enum CodingKeys: String, CodingKey {
        case name, description
        case templateId = "template_id"
    }
}

struct WorkspaceUpdateRequestBody: Codable {
    let data: WorkspaceUpdateRequest
}

struct WorkspaceUpdateRequest: Codable {
    let type: String // "workspace"
    let id: UUID
    let attributes: WorkspaceUpdateAttributes
}

struct WorkspaceUpdateAttributes: Codable {
    let name: String?
    let description: String?
    let status: Workspace.WorkspaceStatus?
}

// MARK: - Enhanced Notebook/DAG Models

struct NotebookDAG: Identifiable, Codable {
    let id: UUID
    let name: String
    let description: String
    let dagType: DAGType
    let status: DAGStatus
    let agents: [DAGAgent]
    let cells: [NotebookCell]
    let dependencies: DAGDependencies?
    let parameters: [String: AnyCodable]?
    let schedule: DAGSchedule?
    let cache: CacheConfiguration?
    let collaboration: CollaborationConfiguration?
    let createdAt: Date
    let updatedAt: Date
    
    enum DAGType: String, CaseIterable, Codable {
        case notebook, pipeline, serviceMesh = "service-mesh", enlightenmentProcessor = "enlightenment-processor"
        
        var systemImage: String {
            switch self {
            case .notebook: return "doc.text"
            case .pipeline: return "flowchart"
            case .serviceMesh: return "network"
            case .enlightenmentProcessor: return "brain"
            }
        }
    }
    
    enum DAGStatus: String, CaseIterable, Codable {
        case draft, running, completed, failed, paused
    }
    
    private enum CodingKeys: String, CodingKey {
        case id, name, description, status, agents, cells, dependencies, parameters, schedule, cache, collaboration
        case dagType = "dag_type"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct DAGAgent: Identifiable, Codable {
    let id: String
    let type: AgentType
    let image: String
    let command: [String]?
    let environment: [String: String]?
    let resources: AgentResources?
    let volumes: [VolumeMount]?
    let networks: [String]?
    let dependsOn: [String]?
    let retryPolicy: RetryPolicy?
    let timeout: Int?
    let enlightenmentConfig: EnlightenmentConfig?
    let status: AgentStatus?
    
    enum AgentType: String, CaseIterable, Codable {
        case jupyter, python, r, nodejs, custom, enlightenment
    }
    
    enum AgentStatus: String, CaseIterable, Codable {
        case starting, running, completed, failed, idle
    }
    
    private enum CodingKeys: String, CodingKey {
        case id, type, image, command, environment, resources, volumes, networks, timeout, status
        case dependsOn = "depends_on"
        case retryPolicy = "retry_policy"
        case enlightenmentConfig = "enlightenment_config"
    }
}

struct AgentResources: Codable {
    let cpu: String?
    let memory: String?
    let gpu: Int?
}

struct VolumeMount: Codable {
    let source: String
    let target: String
    let type: VolumeType
    
    enum VolumeType: String, Codable {
        case bind, volume, tmpfs
    }
}

struct RetryPolicy: Codable {
    let maxAttempts: Int
    let retryDelay: Int
    
    private enum CodingKeys: String, CodingKey {
        case maxAttempts = "max_attempts"
        case retryDelay = "retry_delay"
    }
}

struct EnlightenmentConfig: Codable {
    let targetFormats: [String]?
    let processingMode: ProcessingMode?
    
    enum ProcessingMode: String, Codable {
        case extract, validate, transform
    }
    
    private enum CodingKeys: String, CodingKey {
        case targetFormats = "target_formats"
        case processingMode = "processing_mode"
    }
}

struct DAGDependencies: Codable {
    let nodes: [DependencyNode]
}

struct DependencyNode: Codable {
    let id: String
    let agentId: String
    let dependsOn: [String]
    
    private enum CodingKeys: String, CodingKey {
        case id
        case agentId = "agent_id"
        case dependsOn = "depends_on"
    }
}

struct DAGSchedule: Codable {
    let type: ScheduleType
    let expression: String?
    
    enum ScheduleType: String, Codable {
        case manual, cron, eventDriven = "event-driven"
    }
}

struct CacheConfiguration: Codable {
    let cacheStrategy: String
    let s3Bucket: String
    let localCache: String
    let ttl: Int
    let prefetch: [String]?
    
    private enum CodingKeys: String, CodingKey {
        case ttl, prefetch
        case cacheStrategy = "cache_strategy"
        case s3Bucket = "s3_bucket"
        case localCache = "local_cache"
    }
}

struct CollaborationConfiguration: Codable {
    let collaborators: [CollaboratorInfo]
    let websocketUrl: String
    
    private enum CodingKeys: String, CodingKey {
        case collaborators
        case websocketUrl = "websocket_url"
    }
}

// MARK: - Enhanced NotebookCell with metadata

extension NotebookCell {
    var metadata: CellMetadata? {
        get { 
            // Return nil for now - existing cells don't have metadata
            return nil 
        }
        set { 
            // Metadata setting would require extending the existing model
        }
    }
}

struct CellMetadata: Codable {
    let tags: [String]?
    let cached: Bool?
    let s3Key: String?
    let backgroundJob: Bool?
    let estimatedRuntime: String?
    let outputCache: OutputCache?
    let collaboration: CellCollaboration?
    
    private enum CodingKeys: String, CodingKey {
        case tags, cached, backgroundJob, collaboration
        case s3Key = "s3_key"
        case estimatedRuntime = "estimated_runtime"
        case outputCache = "output_cache"
    }
}

struct OutputCache: Codable {
    let s3Key: String
    let localPath: String
    
    private enum CodingKeys: String, CodingKey {
        case s3Key = "s3_key"
        case localPath = "local_path"
    }
}

struct CellCollaboration: Codable {
    let lastEditedBy: String?
    let lastEditedAt: Date?
    let comments: [CellComment]?
    
    private enum CodingKeys: String, CodingKey {
        case comments
        case lastEditedBy = "last_edited_by"
        case lastEditedAt = "last_edited_at"
    }
}

struct CellComment: Codable {
    let author: String
    let content: String
    let timestamp: Date
}

struct CollaboratorInfo: Identifiable, Codable {
    let id: UUID
    let name: String
    let email: String
    let role: String
    let isOnline: Bool
    let avatarColorHex: String
    let permissions: [Permission]?
    
    enum Permission: String, Codable {
        case read, write, execute, comment
    }
    
    // Computed property to get SwiftUI Color
    var avatarColor: Color {
        Color(hex: avatarColorHex) ?? .blue
    }
    
    private enum CodingKeys: String, CodingKey {
        case id, name, email, role, permissions
        case isOnline = "is_online"
        case avatarColorHex = "avatar_color"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        email = try container.decode(String.self, forKey: .email)
        role = try container.decode(String.self, forKey: .role)
        isOnline = try container.decode(Bool.self, forKey: .isOnline)
        permissions = try container.decodeIfPresent([Permission].self, forKey: .permissions)
        
        // Try to decode avatar color hex, or generate one based on user ID
        if let colorHex = try? container.decode(String.self, forKey: .avatarColorHex) {
            avatarColorHex = colorHex
        } else {
            avatarColorHex = Self.generateColorHex(from: id)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(email, forKey: .email)
        try container.encode(role, forKey: .role)
        try container.encode(isOnline, forKey: .isOnline)
        try container.encode(avatarColorHex, forKey: .avatarColorHex)
        try container.encodeIfPresent(permissions, forKey: .permissions)
    }
    
    static func generateColorHex(from id: UUID) -> String {
        let hash = abs(id.hashValue)
        let r = (hash >> 16) & 0xFF
        let g = (hash >> 8) & 0xFF
        let b = hash & 0xFF
        return String(format: "%02X%02X%02X", r, g, b)
    }
}

// MARK: - Pagination Models

struct PaginationMeta: Codable {
    let total: Int
    let page: Int
    let perPage: Int
    let totalPages: Int
    
    private enum CodingKeys: String, CodingKey {
        case total, page
        case perPage = "per_page"
        case totalPages = "total_pages"
    }
}

struct PaginationLinks: Codable {
    let `self`: String
    let first: String
    let prev: String?
    let next: String?
    let last: String
}

// MARK: - Utility Types

/// A type-erased codable value container
struct AnyCodable: Codable {
    let value: Any
    
    init<T>(_ value: T?) {
        self.value = value ?? ()
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if container.decodeNil() {
            value = ()
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            value = dictionary.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "AnyCodable value cannot be decoded"
            )
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case is Void:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map(AnyCodable.init))
        case let dictionary as [String: Any]:
            try container.encode(dictionary.mapValues(AnyCodable.init))
        default:
            let context = EncodingError.Context(
                codingPath: container.codingPath,
                debugDescription: "AnyCodable value cannot be encoded"
            )
            throw EncodingError.invalidValue(value, context)
        }
    }
}

// MARK: - Extensions

extension Color {
    static func from(id: UUID) -> Color {
        // Generate consistent color from UUID
        let hash = id.hashValue
        let hue = Double(abs(hash) % 360) / 360.0
        return Color(hue: hue, saturation: 0.7, brightness: 0.8)
    }
    
    #if os(macOS)
    static func random() -> Color {
        Color(
            red: Double.random(in: 0...1),
            green: Double.random(in: 0...1),
            blue: Double.random(in: 0...1)
        )
    }
    #endif
}

// MARK: - Date Extensions

extension Date {
    static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

// MARK: - SidebarItem

enum SidebarItem: String, CaseIterable, Identifiable {
    case notebooks = "Notebooks"
    case dags = "DAG Workflows"
    case files = "Files"  
    case templates = "Templates"
    case settings = "Settings"
    
    var id: String { rawValue }
    
    var systemImage: String {
        switch self {
        case .notebooks: return "doc.text"
        case .dags: return "flowchart"
        case .files: return "folder"
        case .templates: return "doc.on.clipboard"
        case .settings: return "gear"
        }
    }
}
