//
//  KyozoAppState.swift
//  Kyozo
//
//  Created by Loc Nguyen on 8/16/25.
//

## AppState.swift - Global State Management
```swift
import SwiftUI
import Combine

@MainActor
class KyozoAppState: ObservableObject {
    @Published var currentUser: User = .guest
    @Published var workspaces: [Workspace] = []
    @Published var currentWorkspace: Workspace?
    @Published var isConnected = false
    
    private let client = KyozoNetworkClient()
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupBindings()
    }
    
    private func setupBindings() {
        client.$isConnected
            .receive(on: DispatchQueue.main)
            .assign(to: &$isConnected)
    }
    
    func connect() async {
        await client.connectBinary()
        
        // Start receiving updates
        Task {
            for await response in client.receiveStream() {
                handleResponse(response)
            }
        }
    }
    
    func sendBinaryUpdate(_ delta: CRDTDelta) async {
        try? await client.sendBinaryRequest(delta)
    }
    
    private func handleResponse(_ response: BinaryResponse) {
        switch response.type {
        case .documentUpdate:
            // Apply CRDT update
            if let doc = findDocument(response.documentId) {
                doc.applyCRDT(response.delta)
            }
            
        case .workspaceUpdate:
            // Update workspace
            if let workspace = workspaces.first(where: { $0.id == response.workspaceId }) {
                workspace.update(from: response)
            }
            
        case .executionResult:
            // Handle execution result
            NotificationCenter.default.post(
                name: .executionComplete,
                object: response.result
            )
            
        default:
            break
        }
    }
}
```



## Performance Optimizations
```swift
// MetalShaders.metal - GPU Shaders for parsing
#include <metal_stdlib>
using namespace metal;

kernel void parseMarkdown(
    device const char* input [[buffer(0)]],
    device ParsedNode* output [[buffer(1)]],
    uint gid [[thread_position_in_grid]]
) {
    uint pos = gid * 64;
    
    // SIMD operations on GPU
    char64 chunk = ((device char64*)input)[gid];
    
    // Check for markdown special characters
    bool64 is_hash = (chunk == '#');
    bool64 is_star = (chunk == '*');
    bool64 is_bracket = (chunk == '[');
    bool64 is_backtick = (chunk == '`');
    
    // Count special chars with popcount
    uint special_count = popcount(uint64(is_hash | is_star | is_bracket | is_backtick));
    
    if (special_count > 0) {
        output[gid].type = NODE_SPECIAL;
        output[gid].position = pos;
        output[gid].special_mask = pack_mask(is_hash, is_star, is_bracket, is_backtick);
    }
}

kernel void renderMarkdown(
    texture2d<float, access::write> output [[texture(0)]],
    device const ParsedNode* nodes [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    // GPU-accelerated text rendering
    // This is where we render markdown directly to texture
}
```

