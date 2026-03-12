//
//  PhoenixLiveViewClient.swift
//  Kyozo
//
//  Phoenix LiveView Client Integration for iOS/macOS
//  Connects to Phoenix Channels and LiveView for real-time sync
//

import Foundation
import Combine
import simd
import Network
import os.log

// MARK: - Phoenix Socket Client

@MainActor
class PhoenixSocket: ObservableObject {
    private let url: URL
    private let params: [String: Any]
    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession
    private let logger = Logger(subsystem: "com.nocsi.kyozo.phoenix", category: "Socket")
    
    @Published var isConnected = false
    @Published var connectionError: Error?
    @Published var lastReconnectAttempt: Date?
    
    private var channels: [String: PhoenixChannel] = [:]
    private var messageRef = 0
    private var heartbeatTimer: Timer?
    private var reconnectTimer: Timer?
    private var pendingMessages: [PhoenixMessage] = []
    
    private let reconnectInterval: TimeInterval = 5.0
    private let heartbeatInterval: TimeInterval = 30.0
    private let maxReconnectAttempts = 10
    private var reconnectAttempts = 0
    
    init(url: URL, params: [String: Any] = [:]) {
        self.url = url
        self.params = params
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.waitsForConnectivity = true
        self.urlSession = URLSession(configuration: config)
        
        logger.info("PhoenixSocket initialized for: \(url.absoluteString)")
    }
    
    func connect() {
        guard !isConnected else { 
            logger.debug("Socket already connected")
            return 
        }
        
        logger.info("Connecting to Phoenix socket...")
        
        var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        urlComponents.scheme = urlComponents.scheme == "https" ? "wss" : "ws"
        
        // Add parameters to URL
        var queryItems = urlComponents.queryItems ?? []
        for (key, value) in params {
            queryItems.append(URLQueryItem(name: key, value: "\(value)"))
        }
        urlComponents.queryItems = queryItems
        
        let websocketURL = urlComponents.url!
        
        webSocketTask = urlSession.webSocketTask(with: websocketURL)
        webSocketTask?.resume()
        
        startListening()
        startHeartbeat()
        
        isConnected = true
        connectionError = nil
        reconnectAttempts = 0
        
        // Send any pending messages
        flushPendingMessages()
        
        logger.info("Socket connected successfully")
    }
    
    func disconnect() {
        logger.info("Disconnecting Phoenix socket...")
        
        heartbeatTimer?.invalidate()
        reconnectTimer?.invalidate()
        
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        
        isConnected = false
        
        // Notify all channels of disconnection
        channels.values.forEach { $0.handleDisconnect() }
        
        logger.info("Socket disconnected")
    }
    
    func channel(_ topic: String, params: [String: Any] = [:]) -> PhoenixChannel {
        if let existingChannel = channels[topic] {
            logger.debug("Returning existing channel for topic: \(topic)")
            return existingChannel
        }
        
        let channel = PhoenixChannel(topic: topic, params: params, socket: self)
        channels[topic] = channel
        
        logger.debug("Created new channel for topic: \(topic)")
        return channel
    }
    
    internal func sendMessage(_ message: PhoenixMessage) {
        guard isConnected, let webSocketTask = webSocketTask else {
            logger.warning("Socket not connected, queuing message for topic: \(message.topic)")
            pendingMessages.append(message)
            return
        }
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .sortedKeys
            let data = try encoder.encode(message)
            let string = String(data: data, encoding: .utf8)!
            
            webSocketTask.send(.string(string)) { [weak self] error in
                if let error = error {
                    DispatchQueue.main.async {
                        self?.handleConnectionError(error)
                    }
                } else {
                    self?.logger.debug("Sent message for topic: \(message.topic), event: \(message.event)")
                }
            }
        } catch {
            logger.error("Failed to encode message: \(error)")
        }
    }
    
    private func startListening() {
        receiveMessage()
    }
    
    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let message):
                    self?.handleMessage(message)
                    self?.receiveMessage() // Continue listening
                    
                case .failure(let error):
                    self?.handleConnectionError(error)
                }
            }
        }
    }
    
    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .string(let string):
            guard let data = string.data(using: .utf8) else {
                logger.warning("Failed to convert message string to data")
                return
            }
            
            do {
                let decoder = JSONDecoder()
                let phoenixMessage = try decoder.decode(PhoenixMessage.self, from: data)
                
                logger.debug("Received message - topic: \(phoenixMessage.topic), event: \(phoenixMessage.event)")
                
                // Route message to appropriate channel
                if let channel = channels[phoenixMessage.topic] {
                    channel.handleMessage(phoenixMessage)
                } else {
                    logger.warning("No channel found for topic: \(phoenixMessage.topic)")
                }
            } catch {
                logger.error("Failed to decode Phoenix message: \(error)")
            }
            
        case .data(let data):
            logger.debug("Received binary data: \(data.count) bytes")
            
        @unknown default:
            logger.warning("Unknown message type received")
        }
    }
    
    private func handleConnectionError(_ error: Error) {
        logger.error("WebSocket error: \(error)")
        connectionError = error
        isConnected = false
        
        // Notify channels of disconnection
        channels.values.forEach { $0.handleDisconnect() }
        
        // Attempt reconnection if under limit
        if reconnectAttempts < maxReconnectAttempts {
            reconnectAttempts += 1
            let delay = min(reconnectInterval * Double(reconnectAttempts), 60.0) // Max 60s delay
            
            logger.info("Scheduling reconnection attempt \(self.reconnectAttempts) in \(delay)s")
            
            lastReconnectAttempt = Date()
            reconnectTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
                self?.connect()
            }
        } else {
            logger.error("Max reconnection attempts reached, giving up")
        }
    }
    
    private func startHeartbeat() {
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: heartbeatInterval, repeats: true) { [weak self] _ in
            self?.sendHeartbeat()
        }
    }
    
    private func sendHeartbeat() {
        let heartbeat = PhoenixMessage(
            topic: "phoenix",
            event: "heartbeat",
            payload: [:],
            ref: String(nextRef())
        )
        sendMessage(heartbeat)
        logger.debug("Sent heartbeat")
    }
    
    private func flushPendingMessages() {
        guard !pendingMessages.isEmpty else { return }
        
        let messages = pendingMessages
        pendingMessages.removeAll()
        
        logger.info("Flushing \(messages.count) pending messages")
        messages.forEach { sendMessage($0) }
    }
    
    internal func nextRef() -> Int {
        messageRef += 1
        return messageRef
    }
    
    // MARK: - Network Monitoring
    
    private func setupNetworkMonitoring() {
        let monitor = NWPathMonitor()
        let queue = DispatchQueue(label: "NetworkMonitor")
        
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                if path.status == .satisfied && !(self?.isConnected ?? true) {
                    self?.logger.info("Network available, attempting to reconnect")
                    self?.connect()
                }
            }
        }
        
        monitor.start(queue: queue)
    }
}

// MARK: - Phoenix Channel

@MainActor
class PhoenixChannel: ObservableObject {
    let topic: String
    let params: [String: Any]
    private weak var socket: PhoenixSocket?
    private let logger = Logger(subsystem: "com.nocsi.kyozo.phoenix", category: "Channel")
    
    @Published var isJoined = false
    @Published var joinError: Error?
    @Published var lastActivity: Date = Date()
    
    private var eventHandlers: [String: [(PhoenixMessage) -> Void]] = [:]
    private var replyHandlers: [String: (PhoenixMessage) -> Void] = [:]
    private var joinRef: String?
    
    init(topic: String, params: [String: Any], socket: PhoenixSocket) {
        self.topic = topic
        self.params = params
        self.socket = socket
        
        logger.debug("Channel created for topic: \(topic)")
    }
    
    func join() -> AnyPublisher<PhoenixMessage, Error> {
        let subject = PassthroughSubject<PhoenixMessage, Error>()
        
        guard let socket = socket else {
            subject.send(completion: .failure(PhoenixError.connectionFailed(NSError(domain: "No socket", code: 0))))
            return subject.eraseToAnyPublisher()
        }
        
        let ref = String(socket.nextRef())
        joinRef = ref
        
        let joinMessage = PhoenixMessage(
            topic: topic,
            event: "phx_join",
            payload: params,
            ref: ref
        )
        
        replyHandlers[ref] = { [weak self] message in
            if let status = message.payload["status"] as? String, status == "ok" {
                self?.isJoined = true
                self?.joinError = nil
                self?.lastActivity = Date()
                self?.logger.info("Successfully joined channel: \(self?.topic ?? "")")
                subject.send(message)
                subject.send(completion: .finished)
            } else {
                let errorResponse = message.payload["response"] as? [String: Any] ?? [:]
                let error = PhoenixError.joinFailed(errorResponse)
                self?.joinError = error
                self?.logger.error("Failed to join channel \(self?.topic ?? ""): \(error)")
                subject.send(completion: .failure(error))
            }
        }
        
        socket.sendMessage(joinMessage)
        logger.info("Attempting to join channel: \(self.topic)")
        
        return subject.eraseToAnyPublisher()
    }
    
    func leave() {
        guard let socket = socket, isJoined else {
            logger.debug("Channel not joined, cannot leave: \(self.topic)")
            return
        }
        
        let leaveMessage = PhoenixMessage(
            topic: topic,
            event: "phx_leave",
            payload: [:],
            ref: String(socket.nextRef())
        )
        
        socket.sendMessage(leaveMessage)
        isJoined = false
        joinRef = nil
        
        logger.info("Left channel: \(self.topic)")
    }
    
    func push(_ event: String, payload: [String: Any] = [:]) -> AnyPublisher<PhoenixMessage, Error> {
        let subject = PassthroughSubject<PhoenixMessage, Error>()
        
        guard let socket = socket else {
            subject.send(completion: .failure(PhoenixError.connectionFailed(NSError(domain: "No socket", code: 0))))
            return subject.eraseToAnyPublisher()
        }
        
        guard isJoined else {
            subject.send(completion: .failure(PhoenixError.pushFailed(["reason": "Channel not joined"])))
            return subject.eraseToAnyPublisher()
        }
        
        let ref = String(socket.nextRef())
        let message = PhoenixMessage(
            topic: topic,
            event: event,
            payload: payload,
            ref: ref
        )
        
        replyHandlers[ref] = { [weak self] replyMessage in
            self?.lastActivity = Date()
            
            if let status = replyMessage.payload["status"] as? String, status == "ok" {
                self?.logger.debug("Push successful - topic: \(self?.topic ?? ""), event: \(event)")
                subject.send(replyMessage)
                subject.send(completion: .finished)
            } else {
                let errorResponse = replyMessage.payload["response"] as? [String: Any] ?? [:]
                let error = PhoenixError.pushFailed(errorResponse)
                self?.logger.error("Push failed - topic: \(self?.topic ?? ""), event: \(event), error: \(error)")
                subject.send(completion: .failure(error))
            }
        }
        
        socket.sendMessage(message)
        logger.debug("Pushed event: \(event) to topic: \(self.topic)")
        
        return subject.eraseToAnyPublisher()
    }
    
    func on(_ event: String, handler: @escaping (PhoenixMessage) -> Void) {
        if eventHandlers[event] == nil {
            eventHandlers[event] = []
        }
        eventHandlers[event]?.append(handler)
        logger.debug("Added event handler for \(event) on topic: \(self.topic)")
    }
    
    func off(_ event: String) {
        eventHandlers[event] = nil
        logger.debug("Removed event handlers for \(event) on topic: \(self.topic)")
    }
    
    internal func handleMessage(_ message: PhoenixMessage) {
        lastActivity = Date()
        
        // Handle replies
        if let ref = message.ref, let handler = replyHandlers[ref] {
            handler(message)
            replyHandlers[ref] = nil
            return
        }
        
        // Handle events
        if let handlers = eventHandlers[message.event] {
            logger.debug("Handling event: \(message.event) on topic: \(self.topic)")
            handlers.forEach { $0(message) }
        }
    }
    
    internal func handleDisconnect() {
        isJoined = false
        logger.warning("Channel disconnected: \(self.topic)")
    }
}

// MARK: - Phoenix Message

struct PhoenixMessage: Codable {
    let topic: String
    let event: String
    let payload: [String: Any]
    let ref: String?
    
    enum CodingKeys: String, CodingKey {
        case topic, event, payload, ref
    }
    
    init(topic: String, event: String, payload: [String: Any], ref: String? = nil) {
        self.topic = topic
        self.event = event
        self.payload = payload
        self.ref = ref
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        topic = try container.decode(String.self, forKey: .topic)
        event = try container.decode(String.self, forKey: .event)
        ref = try container.decodeIfPresent(String.self, forKey: .ref)
        
        // Decode payload as [String: Any]
        let payloadContainer = try container.nestedContainer(keyedBy: AnyCodingKey.self, forKey: .payload)
        payload = try Self.decodeAnyDictionary(from: payloadContainer)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(topic, forKey: .topic)
        try container.encode(event, forKey: .event)
        try container.encodeIfPresent(ref, forKey: .ref)
        
        // Encode payload
        var payloadContainer = container.nestedContainer(keyedBy: AnyCodingKey.self, forKey: .payload)
        try Self.encodeAnyDictionary(payload, to: &payloadContainer)
    }
    
    private static func decodeAnyDictionary(from container: KeyedDecodingContainer<AnyCodingKey>) throws -> [String: Any] {
        var result: [String: Any] = [:]
        
        for key in container.allKeys {
            if let value = try? container.decode(String.self, forKey: key) {
                result[key.stringValue] = value
            } else if let value = try? container.decode(Int.self, forKey: key) {
                result[key.stringValue] = value
            } else if let value = try? container.decode(Double.self, forKey: key) {
                result[key.stringValue] = value
            } else if let value = try? container.decode(Bool.self, forKey: key) {
                result[key.stringValue] = value
            } else if let nestedContainer = try? container.nestedContainer(keyedBy: AnyCodingKey.self, forKey: key) {
                result[key.stringValue] = try decodeAnyDictionary(from: nestedContainer)
            } else if var nestedUnkeyedContainer = try? container.nestedUnkeyedContainer(forKey: key) {
                var array: [Any] = []
                while !nestedUnkeyedContainer.isAtEnd {
                    if let value = try? nestedUnkeyedContainer.decode(String.self) {
                        array.append(value)
                    } else if let value = try? nestedUnkeyedContainer.decode(Int.self) {
                        array.append(value)
                    } else if let value = try? nestedUnkeyedContainer.decode(Double.self) {
                        array.append(value)
                    } else if let value = try? nestedUnkeyedContainer.decode(Bool.self) {
                        array.append(value)
                    }
                }
                result[key.stringValue] = array
            }
        }
        
        return result
    }
    
    private static func encodeAnyDictionary(_ dictionary: [String: Any], to container: inout KeyedEncodingContainer<AnyCodingKey>) throws {
        for (key, value) in dictionary {
            let codingKey = AnyCodingKey(stringValue: key)!
            
            if let stringValue = value as? String {
                try container.encode(stringValue, forKey: codingKey)
            } else if let intValue = value as? Int {
                try container.encode(intValue, forKey: codingKey)
            } else if let doubleValue = value as? Double {
                try container.encode(doubleValue, forKey: codingKey)
            } else if let boolValue = value as? Bool {
                try container.encode(boolValue, forKey: codingKey)
            } else if let arrayValue = value as? [Any] {
                var nestedContainer = container.nestedUnkeyedContainer(forKey: codingKey)
                for item in arrayValue {
                    if let stringItem = item as? String {
                        try nestedContainer.encode(stringItem)
                    } else if let intItem = item as? Int {
                        try nestedContainer.encode(intItem)
                    } else if let doubleItem = item as? Double {
                        try nestedContainer.encode(doubleItem)
                    } else if let boolItem = item as? Bool {
                        try nestedContainer.encode(boolItem)
                    }
                }
            } else if let dictValue = value as? [String: Any] {
                var nestedContainer = container.nestedContainer(keyedBy: AnyCodingKey.self, forKey: codingKey)
                try encodeAnyDictionary(dictValue, to: &nestedContainer)
            }
        }
    }
}

// MARK: - Supporting Types

struct AnyCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?
    
    init?(stringValue: String) {
        self.stringValue = stringValue
    }
    
    init?(intValue: Int) {
        self.stringValue = "\(intValue)"
        self.intValue = intValue
    }
}

enum PhoenixError: Error, LocalizedError {
    case joinFailed([String: Any])
    case pushFailed([String: Any])
    case connectionFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .joinFailed(let response):
            return "Failed to join channel: \(response["reason"] ?? "Unknown error")"
        case .pushFailed(let response):
            return "Failed to push message: \(response["reason"] ?? "Unknown error")"
        case .connectionFailed(let error):
            return "Connection failed: \(error.localizedDescription)"
        }
    }
}

// MARK: - Kyozo-specific Phoenix Integration

@MainActor
class KyozoPhoenixClient: ObservableObject {
    private let socket: PhoenixSocket
    private var syncChannel: PhoenixChannel?
    private var workspaceId: String?
    private let logger = Logger(subsystem: "com.nocis.kyozo.phoenix", category: "KyozoClient")
    
    @Published var isConnected = false
    @Published var documents: [String: DocumentState] = [:]
    @Published var collaborators: [String: Collaborator] = [:]
    @Published var services: [Service] = []
    @Published var dagExecutions: [String: DAGExecution] = [:]
    @Published var connectionStatus: ConnectionStatus = .disconnected
    
    enum ConnectionStatus {
        case disconnected, connecting, connected, error(String)
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    // Integration with existing Metal engine
    // TODO: Re-enable when KyozoMetalTextEngine is available
    // private weak var metalEngine: KyozoMetalTextEngine?
    // private weak var folderExecutor: FolderBasedExecutor?
    
    init(baseURL: URL, authToken: String) {
        let socketURL = baseURL.appendingPathComponent("socket/websocket")
        let params = [
            "token": authToken,
            "vsn": "2.0.0",
            "client_type": Self.getCurrentClientType(),
            "client_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        ]
        
        self.socket = PhoenixSocket(url: socketURL, params: params)
        
        setupSocketObservers()
        logger.info("KyozoPhoenixClient initialized with base URL: \(baseURL.absoluteString)")
    }
    
    func connect(to workspaceId: String) {
        self.workspaceId = workspaceId
        // TODO: Re-enable when engines are available
        // self.metalEngine = metalEngine
        // self.folderExecutor = folderExecutor
        
        connectionStatus = .connecting
        socket.connect()
        
        logger.info("Connecting to workspace: \(workspaceId)")
    }
    
    func disconnect() {
        syncChannel?.leave()
        socket.disconnect()
        connectionStatus = .disconnected
        
        // Clear collaborative state
        collaborators.removeAll()
        documents.removeAll()
        
        logger.info("Disconnected from Phoenix")
    }
    
    private func setupSocketObservers() {
        // Observe socket connection state
        socket.$isConnected
            .sink { [weak self] isConnected in
                self?.isConnected = isConnected
                
                if isConnected {
                    self?.connectionStatus = .connected
                    if let workspaceId = self?.workspaceId {
                        self?.joinSyncChannel(workspaceId: workspaceId)
                    }
                } else {
                    self?.connectionStatus = .disconnected
                }
            }
            .store(in: &cancellables)
        
        // Observe connection errors
        socket.$connectionError
            .compactMap { $0 }
            .sink { [weak self] error in
                self?.connectionStatus = .error(error.localizedDescription)
                self?.logger.error("Phoenix connection error: \(error)")
            }
            .store(in: &cancellables)
    }
    
    private func joinSyncChannel(workspaceId: String) {
        let params: [String: Any] = [
            "user_id": getCurrentUserId(),
            "client_type": Self.getCurrentClientType(),
            "capabilities": ["document_sync", "lsp", "ai", "real_time_collaboration", "metal_rendering"],
            "metal_engine_version": "1.0.0"
        ]
        
        syncChannel = socket.channel("sync:\(workspaceId)", params: params)
        
        syncChannel?.join()
            .sink(
                receiveCompletion: { [weak self] completion in
                    switch completion {
                    case .finished:
                        self?.logger.info("Successfully joined sync channel for workspace: \(workspaceId)")
                        self?.setupChannelEventHandlers()
                    case .failure(let error):
                        self?.logger.error("Failed to join sync channel: \(error)")
                        self?.connectionStatus = .error("Failed to join workspace")
                    }
                },
                receiveValue: { _ in }
            )
            .store(in: &cancellables)
    }
    
    private func setupChannelEventHandlers() {
        guard let channel = syncChannel else { return }
        
        // Document delta updates
        channel.on("document_delta") { [weak self] message in
            self?.handleDocumentDelta(message)
        }
        
        // Remote document updates from other nodes
        channel.on("document_remote_delta") { [weak self] message in
            self?.handleRemoteDocumentDelta(message)
        }
        
        // Presence updates
        channel.on("presence_state") { [weak self] message in
            self?.handlePresenceState(message)
        }
        
        channel.on("presence_diff") { [weak self] message in
            self?.handlePresenceDiff(message)
        }
        
        // AI responses
        channel.on("ai_completion") { [weak self] message in
            self?.handleAICompletion(message)
        }
        
        channel.on("ai_chat") { [weak self] message in
            self?.handleAIChat(message)
        }
        
        // Service status updates
        channel.on("service_status") { [weak self] message in
            self?.handleServiceStatus(message)
        }
        
        // DAG execution updates
        channel.on("dag_execution") { [weak self] message in
            self?.handleDAGExecution(message)
        }
        
        // LSP diagnostics
        channel.on("lsp_diagnostics") { [weak self] message in
            self?.handleLSPDiagnostics(message)
        }
        
        // Collaborative cursor updates
        channel.on("cursor_update") { [weak self] message in
            self?.handleCursorUpdate(message)
        }
        
        // Apple Pencil stroke sharing
        channel.on("pencil_stroke") { [weak self] message in
            self?.handlePencilStroke(message)
        }
        
        logger.info("Channel event handlers configured")
    }
    
    // MARK: - Document Operations
    
    func subscribeToDocument(_ documentId: String) -> AnyPublisher<DocumentState, Error> {
        guard let channel = syncChannel else {
            return Fail(error: PhoenixError.connectionFailed(NSError(domain: "No channel", code: 0)))
                .eraseToAnyPublisher()
        }
        
        return channel.push("document_subscribe", payload: ["document_id": documentId])
            .map { [weak self] message in
                let state = message.payload["state"] as? [String: Any] ?? [:]
                let documentState = DocumentState(from: state)
                
                // Update local state
                self?.documents[documentId] = documentState
                
                return documentState
            }
            .eraseToAnyPublisher()
    }
    
    func applyDocumentOperation(_ operation: DocumentOperation) -> AnyPublisher<DocumentDelta, Error> {
        guard let channel = syncChannel else {
            return Fail(error: PhoenixError.connectionFailed(NSError(domain: "No channel", code: 0)))
                .eraseToAnyPublisher()
        }
        
        let payload: [String: Any] = [
            "document_id": operation.documentId,
            "operation": [
                "type": operation.type.rawValue,
                "path": operation.path,
                "value": operation.value,
                "position": operation.position
            ]
        ]
        
        return channel.push("document_operation", payload: payload)
            .map { message in
                let deltaData = message.payload["delta"] as? [String: Any] ?? [:]
                return DocumentDelta(from: deltaData)
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Collaborative Features
    
    func broadcastCursorPosition(_ position: CGPoint, documentId: String) {
        guard let channel = syncChannel else { return }
        
        let payload: [String: Any] = [
            "document_id": documentId,
            "position": [
                "x": Double(position.x),
                "y": Double(position.y)
            ],
            "timestamp": Date().timeIntervalSince1970
        ]
        
        channel.push("cursor_update", payload: payload)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { _ in }
            )
            .store(in: &cancellables)
    }
    
    #if os(iOS)
    func sharePencilStroke(_ stroke: ApplePencilRenderer.PencilStroke, documentId: String) {
        guard let channel = syncChannel else { return }
        
        let strokeData: [String: Any] = [
            "document_id": documentId,
            "stroke": [
                "id": stroke.id.uuidString,
                "points": stroke.points.map { point in
                    [
                        "x": Double(point.position.x),
                        "y": Double(point.position.y),
                        "pressure": Double(point.pressure),
                        "timestamp": point.timestamp
                    ]
                },
                "color": [
                    "red": Double(stroke.color.cgColor.components?[0] ?? 0),
                    "green": Double(stroke.color.cgColor.components?[1] ?? 0),
                    "blue": Double(stroke.color.cgColor.components?[2] ?? 0),
                    "alpha": Double(stroke.color.cgColor.alpha)
                ]
            ]
        ]
        
        channel.push("pencil_stroke", payload: strokeData)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { _ in }
            )
            .store(in: &cancellables)
    }
    #endif
    
    // MARK: - AI Operations
    
    func requestAICompletion(documentId: String, context: String, position: Int) -> AnyPublisher<AICompletion, Error> {
        guard let channel = syncChannel else {
            return Fail(error: PhoenixError.connectionFailed(NSError(domain: "No channel", code: 0)))
                .eraseToAnyPublisher()
        }
        
        let payload: [String: Any] = [
            "type": "completion",
            "data": [
                "document_id": documentId,
                "context": context,
                "position": position,
                "model": "claude-4",
                "client_capabilities": [
                    "metal_rendering": true,
                    "apple_pencil": false, // metalEngine?.isPencilActive ?? false,
                    "real_time_collaboration": true
                ]
            ]
        ]
        
        return channel.push("ai_request", payload: payload)
            .map { message in
                AICompletion(from: message.payload)
            }
            .eraseToAnyPublisher()
    }
    
    func requestAIChat(message: String, conversationId: String? = nil, workspaceContext: [String: Any] = [:]) -> AnyPublisher<AIChatResponse, Error> {
        guard let channel = syncChannel else {
            return Fail(error: PhoenixError.connectionFailed(NSError(domain: "No channel", code: 0)))
                .eraseToAnyPublisher()
        }
        
        var data: [String: Any] = [
            "message": message,
            "model": "claude-4",
            "workspace_context": workspaceContext,
            "client_context": [
                "metal_engine_active": false, // metalEngine != nil,
                "current_documents": Array(documents.keys),
                "active_collaborators": collaborators.count
            ]
        ]
        
        if let conversationId = conversationId {
            data["conversation_id"] = conversationId
        }
        
        let payload: [String: Any] = [
            "type": "chat",
            "data": data
        ]
        
        return channel.push("ai_request", payload: payload)
            .map { message in
                AIChatResponse(from: message.payload)
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - LSP Operations
    
    func requestLSPCompletion(language: String, method: String, params: [String: Any]) -> AnyPublisher<LSPResponse, Error> {
        guard let channel = syncChannel else {
            return Fail(error: PhoenixError.connectionFailed(NSError(domain: "No channel", code: 0)))
                .eraseToAnyPublisher()
        }
        
        let payload: [String: Any] = [
            "method": method,
            "params": params.merging(["language": language]) { _, new in new }
        ]
        
        return channel.push("lsp_request", payload: payload)
            .map { message in
                LSPResponse(from: message.payload)
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Service Operations
    
    func performServiceAction(_ action: ServiceAction, serviceName: String) -> AnyPublisher<ServiceOperation, Error> {
        guard let channel = syncChannel else {
            return Fail(error: PhoenixError.connectionFailed(NSError(domain: "No channel", code: 0)))
                .eraseToAnyPublisher()
        }
        
        let payload: [String: Any] = [
            "service_name": serviceName,
            "action": action.rawValue
        ]
        
        return channel.push("service_action", payload: payload)
            .map { message in
                ServiceOperation(from: message.payload)
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - DAG Operations
    
    func executeDAG(_ dagId: String, parameters: [String: Any] = [:]) -> AnyPublisher<DAGExecution, Error> {
        guard let channel = syncChannel else {
            return Fail(error: PhoenixError.connectionFailed(NSError(domain: "No channel", code: 0)))
                .eraseToAnyPublisher()
        }
        
        let payload: [String: Any] = [
            "dag_id": dagId,
            "parameters": parameters
        ]
        
        return channel.push("dag_execute", payload: payload)
            .map { message in
                let execution = DAGExecution(from: message.payload)
                return execution
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Event Handlers
    
    private func handleDocumentDelta(_ message: PhoenixMessage) {
        guard let documentId = message.payload["document_id"] as? String,
              let deltaData = message.payload["delta"] as? [String: Any] else {
            logger.warning("Invalid document delta message")
            return
        }
        
        let delta = DocumentDelta(from: deltaData)
        
        // Update local document state
        if var currentState = documents[documentId] {
            currentState.applyDelta(delta)
            documents[documentId] = currentState
            
            // Notify Metal engine of document changes
            Task { @MainActor in
                // try? await metalEngine?.loadDocument(currentState.content)
            }
        }
        
        // Notify subscribers
        NotificationCenter.default.post(
            name: .documentUpdated,
            object: nil,
            userInfo: [
                "documentId": documentId,
                "delta": delta,
                "userId": message.payload["user_id"] as? String ?? ""
            ]
        )
    }
    
    private func handleRemoteDocumentDelta(_ message: PhoenixMessage) {
        guard let documentId = message.payload["document_id"] as? String,
              let deltaData = message.payload["delta"] as? [String: Any] else {
            return
        }
        
        let delta = DocumentDelta(from: deltaData)
        
        // Update local document state
        if var currentState = documents[documentId] {
            currentState.applyDelta(delta)
            documents[documentId] = currentState
            
            // Update Metal engine with remote changes
            Task { @MainActor in
                // try? await metalEngine?.loadDocument(currentState.content)
            }
        }
        
        // Notify subscribers of remote change
        NotificationCenter.default.post(
            name: .documentRemoteUpdate,
            object: nil,
            userInfo: [
                "documentId": documentId,
                "delta": delta,
                "fromNode": message.payload["from_node"] as? String ?? ""
            ]
        )
    }
    
    private func handlePresenceState(_ message: PhoenixMessage) {
        if let presenceData = message.payload as? [String: [String: Any]] {
            var newCollaborators: [String: Collaborator] = [:]
            
            for (userId, userData) in presenceData {
                if let metasArray = userData["metas"] as? [[String: Any]],
                   let firstMeta = metasArray.first {
                    let collaborator = Collaborator(from: firstMeta)
                    newCollaborators[userId] = collaborator
                    
                    // Update collaborative cursors in Metal engine
                    // if let metalEngine = metalEngine {
                    //     let userColor = collaborator.avatarColor
                    //     metalEngine.updateCollaborativeCursor(
                    //         userId: userId,
                    //         position: CGPoint(x: 100, y: 100), // Would be actual cursor position
                    //         color: userColor
                    //     )
                    // }
                }
            }
            
            self.collaborators = newCollaborators
            logger.info("Updated collaborators: \(newCollaborators.count) users online")
        }
    }
    
    private func handlePresenceDiff(_ message: PhoenixMessage) {
        // Handle joins
        if let joins = message.payload["joins"] as? [String: [String: Any]] {
            for (userId, userData) in joins {
                if let metasArray = userData["metas"] as? [[String: Any]],
                   let firstMeta = metasArray.first {
                    collaborators[userId] = Collaborator(from: firstMeta)
                    logger.info("User joined: \(userId)")
                }
            }
        }
        
        // Handle leaves
        if let leaves = message.payload["leaves"] as? [String: [String: Any]] {
            for (userId, _) in leaves {
                collaborators.removeValue(forKey: userId)
                
                // Remove collaborative cursor from Metal engine
                // This would need to be implemented in the Metal engine
                logger.info("User left: \(userId)")
            }
        }
    }
    
    private func handleCursorUpdate(_ message: PhoenixMessage) {
        guard let userId = message.payload["user_id"] as? String,
              let positionData = message.payload["position"] as? [String: Double],
              let x = positionData["x"],
              let y = positionData["y"] else {
            return
        }
        
        // Update collaborative cursor in Metal engine
        // if let metalEngine = metalEngine,
        //    let collaborator = collaborators[userId] {
        //     metalEngine.updateCollaborativeCursor(
        //         userId: userId,
        //         position: CGPoint(x: x, y: y),
        //         color: collaborator.avatarColor
        //     )
        // }
    }
    
    private func handlePencilStroke(_ message: PhoenixMessage) {
        guard let strokeData = message.payload["stroke"] as? [String: Any],
              let userId = message.payload["user_id"] as? String,
              userId != getCurrentUserId() else { // Don't echo own strokes
            return
        }
        
        
//        metalEngine.renderCollaborativeStroke(stroke)
        
        // Convert received stroke data to local representation
        // This would be integrated with the Apple Pencil renderer
        // to show collaborative drawing strokes
        
        logger.debug("Received collaborative pencil stroke from user: \(userId)")
    }
    
    private func handleAICompletion(_ message: PhoenixMessage) {
        let completion = AICompletion(from: message.payload)
        
        // Integrate with existing AI engine
        // if let metalEngine = metalEngine {
        //     Task { @MainActor in
        //         await metalEngine.aiSuggestions.append(contentsOf: completion.toAISuggestions())
        //     }
        // }
        
        NotificationCenter.default.post(
            name: .aiCompletionReceived,
            object: nil,
            userInfo: ["completion": completion]
        )
    }
    
    private func handleAIChat(_ message: PhoenixMessage) {
        let chatResponse = AIChatResponse(from: message.payload)
        
        NotificationCenter.default.post(
            name: .aiChatReceived,
            object: nil,
            userInfo: ["response": chatResponse]
        )
    }
    
    private func handleServiceStatus(_ message: PhoenixMessage) {
        guard let serviceName = message.payload["service_name"] as? String,
              let statusString = message.payload["status"] as? String,
              let status = ServiceStatus(rawValue: statusString) else {
            return
        }
        
        // Update service in local array
        if let index = services.firstIndex(where: { $0.name == serviceName }) {
            services[index].status = status
        }
        
        // Integrate with folder executor if available
        // if let folderExecutor = folderExecutor {
        //     // Update executor with service status
        //     // This would need implementation in FolderBasedExecutor
        // }
        
        NotificationCenter.default.post(
            name: .serviceStatusChanged,
            object: nil,
            userInfo: [
                "serviceName": serviceName,
                "status": status
            ]
        )
    }
    
    private func handleDAGExecution(_ message: PhoenixMessage) {
        guard let dagId = message.payload["dag_id"] as? String,
              let statusString = message.payload["status"] as? String,
              let status = DAGExecutionStatus(rawValue: statusString) else {
            return
        }
        
        let output = message.payload["output"] as? String
        
        // Update DAG execution state
        if var execution = dagExecutions[dagId] {
            execution.status = status
            if let output = output {
                execution.output.append(output)
            }
            dagExecutions[dagId] = execution
        } else {
            let newExecution = DAGExecution(from: message.payload)
            dagExecutions[dagId] = newExecution
        }
        
        // Integrate with folder executor
        // if let folderExecutor = folderExecutor {
        //     Task {
        //         // This would trigger updates in the folder executor
        //         // to reflect DAG execution status in the UI
        //     }
        // }
        
        NotificationCenter.default.post(
            name: .dagExecutionUpdated,
            object: nil,
            userInfo: [
                "dagId": dagId,
                "status": status,
                "output": output ?? ""
            ]
        )
    }
    
    private func handleLSPDiagnostics(_ message: PhoenixMessage) {
        let diagnostics = LSPDiagnostics(from: message.payload)
        
        // Integrate with AI writing engine for better suggestions
        // if let metalEngine = metalEngine {
        //     Task {
        //         // Convert LSP diagnostics to AI suggestions
        //         // This would enhance the AI writing feedback
        //     }
        // }
        
        NotificationCenter.default.post(
            name: .lspDiagnosticsReceived,
            object: nil,
            userInfo: ["diagnostics": diagnostics]
        )
    }
    
    // MARK: - Helper Methods
    
    private func getCurrentUserId() -> String {
        // Get current user ID from your auth system
        return UserDefaults.standard.string(forKey: "current_user_id") ?? "anonymous"
    }
    
    private static func getCurrentClientType() -> String {
        #if os(iOS)
        return "ios"
        #elseif os(macOS)
        return "macos"
        #else
        return "unknown"
        #endif
    }
}

// MARK: - Data Models (Updated with Kyozo integration)

struct DocumentState {
    var id: String
    var content: String
    var vectorClock: [String: Int]
    var lastModified: Date
    
    init(from data: [String: Any]) {
        self.id = data["id"] as? String ?? ""
        self.content = data["content"] as? String ?? ""
        self.vectorClock = data["vector_clock"] as? [String: Int] ?? [:]
        
        if let timestamp = data["last_modified"] as? TimeInterval {
            self.lastModified = Date(timeIntervalSince1970: timestamp)
        } else {
            self.lastModified = Date()
        }
    }
    
    mutating func applyDelta(_ delta: DocumentDelta) {
        // Apply delta to content
        switch delta.operation {
        case .insert:
            let index = content.index(content.startIndex, offsetBy: min(delta.position, content.count))
            content.insert(contentsOf: delta.content, at: index)
        case .delete:
            let startIndex = content.index(content.startIndex, offsetBy: min(delta.position, content.count))
            let endIndex = content.index(startIndex, offsetBy: min(delta.length, content.distance(from: startIndex, to: content.endIndex)))
            content.removeSubrange(startIndex..<endIndex)
        case .replace:
            let startIndex = content.index(content.startIndex, offsetBy: min(delta.position, content.count))
            let endIndex = content.index(startIndex, offsetBy: min(delta.length, content.distance(from: startIndex, to: content.endIndex)))
            content.replaceSubrange(startIndex..<endIndex, with: delta.content)
        }
        
        // Update vector clock
        for (nodeId, timestamp) in delta.vectorClock {
            vectorClock[nodeId] = max(vectorClock[nodeId] ?? 0, timestamp)
        }
        
        lastModified = Date()
    }
}

struct DocumentDelta {
    let operation: OperationType
    let position: Int
    let length: Int
    let content: String
    let vectorClock: [String: Int]
    
    enum OperationType: String {
        case insert, delete, replace
    }
    
    init(from data: [String: Any]) {
        self.operation = OperationType(rawValue: data["operation"] as? String ?? "insert") ?? .insert
        self.position = data["position"] as? Int ?? 0
        self.length = data["length"] as? Int ?? 0
        self.content = data["content"] as? String ?? ""
        self.vectorClock = data["vector_clock"] as? [String: Int] ?? [:]
    }
}

struct DocumentOperation {
    let documentId: String
    let type: OperationType
    let path: String
    let value: String
    let position: Int
    
    enum OperationType: String {
        case insert, delete, replace, format
    }
}

struct Collaborator {
    let userId: String
    let name: String
    let clientType: String
    let capabilities: [String]
    let joinedAt: Date
    let isOnline: Bool
    let avatarColor: simd_float4
    
    init(from data: [String: Any]) {
        self.userId = data["user_id"] as? String ?? ""
        self.name = data["user"] as? String ?? "Anonymous"
        self.clientType = data["client_type"] as? String ?? ""
        self.capabilities = data["capabilities"] as? [String] ?? []
        self.isOnline = true
        
        if let timestamp = data["online_at"] as? String,
           let timeInterval = TimeInterval(timestamp) {
            self.joinedAt = Date(timeIntervalSince1970: timeInterval)
        } else {
            self.joinedAt = Date()
        }
        
        // Generate consistent color for user
        let hash = userId.hashValue
        let r = Float((hash & 0xFF0000) >> 16) / 255.0
        let g = Float((hash & 0x00FF00) >> 8) / 255.0
        let b = Float(hash & 0x0000FF) / 255.0
        self.avatarColor = simd_float4(r, g, b, 1.0)
    }
}

// MARK: - Extensions for existing types

extension AICompletion {
    func toAISuggestions() -> [String] {
        return completions.map { completion in
            completion.text
        }
    }
}

// MARK: - Remaining Data Models (LSPResponse, AICompletion, etc.)

struct LSPResponse {
    let result: [String: Any]
    let error: [String: Any]?
    
    init(from data: [String: Any]) {
        self.result = data["result"] as? [String: Any] ?? [:]
        self.error = data["error"] as? [String: Any]
    }
}

struct LSPDiagnostics {
    let documentId: String
    let diagnostics: [Diagnostic]
    
    struct Diagnostic {
        let severity: Severity
        let range: Range
        let message: String
        let source: String?
        
        enum Severity: String {
            case error, warning, information, hint
        }
        
        struct Range {
            let start: Position
            let end: Position
        }
        
        struct Position {
            let line: Int
            let character: Int
        }
    }
    
    init(from data: [String: Any]) {
        self.documentId = data["document_id"] as? String ?? ""
        self.diagnostics = [] // Would parse actual diagnostic data
    }
}

struct AICompletion {
    let completions: [Completion]
    let requestId: String
    
    struct Completion {
        let text: String
        let confidence: Double
        let reasoning: String
    }
    
    init(from data: [String: Any]) {
        self.requestId = data["request_id"] as? String ?? ""
        
        if let completionsArray = data["completions"] as? [[String: Any]] {
            self.completions = completionsArray.compactMap { completionData in
                guard let text = completionData["text"] as? String else { return nil }
                return Completion(
                    text: text,
                    confidence: completionData["confidence"] as? Double ?? 0.0,
                    reasoning: completionData["reasoning"] as? String ?? ""
                )
            }
        } else {
            self.completions = []
        }
    }
}

struct AIChatResponse {
    let response: String
    let conversationId: String
    let actions: [Action]
    
    struct Action {
        let type: String
        let description: String
        let parameters: [String: Any]
    }
    
    init(from data: [String: Any]) {
        self.response = data["response"] as? String ?? ""
        self.conversationId = data["conversation_id"] as? String ?? ""
        
        if let actionsArray = data["actions"] as? [[String: Any]] {
            self.actions = actionsArray.compactMap { actionData in
                guard let type = actionData["type"] as? String,
                      let description = actionData["description"] as? String else {
                    return nil
                }
                
                return Action(
                    type: type,
                    description: description,
                    parameters: actionData["parameters"] as? [String: Any] ?? [:]
                )
            }
        } else {
            self.actions = []
        }
    }
}

struct Service {
    let name: String
    let image: String
    var status: ServiceStatus
    let ports: [Port]
    let environment: [String: String]
    
    struct Port {
        let host: String
        let container: String
        let networkProtocol: String
    }
}

enum ServiceStatus: String {
    case running, stopped, error, starting, stopping
}

enum ServiceAction: String {
    case start, stop, restart
}

struct ServiceOperation {
    let id: String
    let serviceName: String
    let operation: ServiceAction
    let status: OperationStatus
    let startedAt: Date
    let completedAt: Date?
    
    enum OperationStatus: String {
        case pending, inProgress = "in-progress", completed, failed
    }
    
    init(from data: [String: Any]) {
        self.id = data["id"] as? String ?? ""
        self.serviceName = data["service_name"] as? String ?? ""
        self.operation = ServiceAction(rawValue: data["operation"] as? String ?? "start") ?? .start
        self.status = OperationStatus(rawValue: data["status"] as? String ?? "pending") ?? .pending
        self.startedAt = Date()
        self.completedAt = nil
    }
}

struct DAGExecution {
    let id: String
    let dagId: String
    var status: DAGExecutionStatus
    let startedAt: Date
    var completedAt: Date?
    var output: [String]
    
    init(from data: [String: Any]) {
        self.id = data["id"] as? String ?? ""
        self.dagId = data["dag_id"] as? String ?? ""
        self.status = DAGExecutionStatus(rawValue: data["status"] as? String ?? "queued") ?? .queued
        self.startedAt = Date()
        self.completedAt = nil
        self.output = []
    }
}

enum DAGExecutionStatus: String {
    case queued, running, completed, failed, cancelled
}

// MARK: - Notification Names

extension Notification.Name {
    static let documentUpdated = Notification.Name("DocumentUpdated")
    static let documentRemoteUpdate = Notification.Name("DocumentRemoteUpdate")
    static let aiCompletionReceived = Notification.Name("AICompletionReceived")
    static let aiChatReceived = Notification.Name("AIChatReceived")
    static let serviceStatusChanged = Notification.Name("ServiceStatusChanged")
    static let dagExecutionUpdated = Notification.Name("DAGExecutionUpdated")
    static let lspDiagnosticsReceived = Notification.Name("LSPDiagnosticsReceived")
}
