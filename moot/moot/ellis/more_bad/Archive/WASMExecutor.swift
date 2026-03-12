//
//  WASMExecutor.swift
//  Kyozo
//
//  Created by Loc Nguyen on 8/16/25.
//



class WASMExecutor {
    private let context = JSContext()!
    
    func compile(code: String, language: Language) async throws -> Data {
        // Send to server for compilation or use local compiler
        if language == .javascript {
            // Use local QuickJS compilation
            return compileJavaScript(code)
        } else {
            // Send to server
            let response = try await KyozoAPI.compileToWASM(code: code, language: language)
            return response.wasmBytes
        }
    }
    
    func execute(module: Data, timeout: Int, memoryLimit: Int) async throws -> ExecutionResult {
        // Execute WASM in sandboxed JSContext
        context.setObject(module, forKeyedSubscript: "wasmModule" as NSString)
        
        let js = """
        (async function() {
            const module = await WebAssembly.instantiate(wasmModule);
            return module.instance.exports.main();
        })()
        """
        
        let result = context.evaluateScript(js)
        
        return ExecutionResult(
            output: result?.toString() ?? "",
            exitCode: 0,
            executionTime: 0
        )
    }
}
```

