//
//  KyozoNetworkClient.swift
//  Kyozo
//
//  Created by Loc Nguyen on 8/16/25.
//



## KyozoNetworking.swift - Binary Protocol Client
```swift
import Foundation
import Network
import Combine

class KyozoNetworkClient: ObservableObject {
    private var connection: NWConnection?
    private let queue = DispatchQueue(label: "kyozo.network", qos: .userInteractive)
    
    @Published var isConnected = false
    @Published var latency: TimeInterval = 0
    
    func connectBinary() async {
        // Use HTTP/3 with QUIC
        let parameters = NWParameters.quic(alpn: ["h3"])
        parameters.multipathServiceType = .interactive // Use multiple paths if available
        
        let endpoint = NWEndpoint.hostPort(
            host: "kyozo.store",
            port: 443
        )
        
        connection = NWConnection(to: endpoint, using: parameters)
        
        connection?.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                self?.isConnected = true
                self?.startLatencyMonitoring()
            case .failed(let error):
                print("Connection failed: \(error)")
            default:
                break
            }
        }
        
        connection?.start(queue: queue)
    }
    
    func sendBinaryRequest<T: Encodable>(_ request: T) async throws {
        // Pack request in binary format
        let encoder = BinaryEncoder()
        let data = try encoder.encode(request)
        
        // Add header with action ID
        var packet = Data()
        packet.append(contentsOf: [0x01]) // Version
        packet.append(contentsOf: withUnsafeBytes(of: UInt32(T.actionId)) { Data($0) })
        packet.append(contentsOf: withUnsafeBytes(of: UInt32(data.count)) { Data($0) })
        packet.append(data)
        
        // Send with zero-copy if possible
        connection?.send(content: packet, completion: .contentProcessed { error in
            if let error = error {
                print("Send error: \(error)")
            }
        })
    }
    
    func receiveStream() -> AsyncStream<BinaryResponse> {
        AsyncStream { continuation in
            connection?.receive(minimumIncompleteLength: 1,
                              maximumLength: 65536) { data, _, isComplete, error in
                if let data = data {
                    // Parse binary response
                    if let response = self.parseBinaryResponse(data) {
                        continuation.yield(response)
                    }
                }
                
                if isComplete {
                    continuation.finish()
                }
            }
        }
    }
}
```

