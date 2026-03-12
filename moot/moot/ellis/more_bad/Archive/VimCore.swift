//
//  VimCore.swift
//  Kyozo
//
//  Created by Loc Nguyen on 8/16/25.
//



class VimCore {
    private var vimProcess: Process!
    private var vimInput: Pipe!
    private var vimOutput: Pipe!
    private var nvimConnection: NvimConnection!
    
    func start() {
        // Launch actual neovim process
        vimProcess = Process()
        vimProcess.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/nvim")
        vimProcess.arguments = [
            "--embed",  // Embedded mode
            "--headless", // No UI
            "-u", "NONE"  // No config
        ]
        
        vimInput = Pipe()
        vimOutput = Pipe()
        
        vimProcess.standardInput = vimInput
        vimProcess.standardOutput = vimOutput
        
        try! vimProcess.run()
        
        // Connect via MessagePack RPC
        nvimConnection = NvimConnection(
            input: vimInput.fileHandleForWriting,
            output: vimOutput.fileHandleForReading
        )
    }
    
    func sendKey(_ key: String) {
        nvimConnection.sendInput(key)
    }
    
    func execute(_ command: String) {
        nvimConnection.executeCommand(command)
    }
    
    func loadBuffer(_ content: String) {
        nvimConnection.setBufferContent(content)
    }
    
    func getCurrentBuffer() -> String {
        return nvimConnection.getBufferContent()
    }
}
```

