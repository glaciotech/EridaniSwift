//
//  LocalMCProcess.swift
//  SwiftMCPClientExample
//
//  Created by Peter Liddle on 6/20/25.
//

// Only supported on macOS
#if os(macOS)

import MCP
import Foundation
import Logging
import System

extension Process {
    var terminalCommand: String {
//        return  ([self.executableURL?.path] + (self.arguments ?? [])).compactMap { $0 }.joined(separator: " ")
        
        guard let launchPath = self.executableURL?.path else {
            return "No executableURL set."
        }
        
        let argumentsString = (self.arguments ?? []).map { argument in
            // Escape each argument to handle special characters or spaces
            if argument.rangeOfCharacter(from: CharacterSet.whitespacesAndNewlines) != nil {
                return "\"\(argument)\""
            }
            return argument
        }.joined(separator: " ")
        
        return "\(launchPath) \(argumentsString)"
    }
    
    func printCommand() {
        print("Command: \(terminalCommand)")
    }
    
    // Full command as a single string, including arguments and optional current directory
    var fullCommand: String {
        var parts: [String] = []

        if let path = self.launchPath {
            parts.append(Self.escapeForShell(path))
        } else if let urlPath = self.executableURL?.path {
            parts.append(Self.escapeForShell(urlPath))
        }

        if let args = self.arguments {
            for arg in args {
                parts.append(Self.escapeForShell(arg))
            }
        }

        // If a working directory is set, include it for clarity
        let cwd = self.currentDirectoryPath
        if !cwd.isEmpty {
            return "cd \"\(cwd)\" && " + parts.joined(separator: " ")
        } else {
            return parts.joined(separator: " ")
        }
    }

    // Print the full command to stdout (useful in tests)
    func printFullCommand() {
        Swift.print(self.fullCommand)
    }

    // Helper: escape a single shell argument if it contains spaces or quotes
    private static func escapeForShell(_ s: String) -> String {
        // If the string contains whitespace or a quote, wrap in double quotes and escape inner quotes
        if s.rangeOfCharacter(from: CharacterSet.whitespacesAndNewlines) != nil || s.contains("\"") {
            let escaped = s.replacingOccurrences(of: "\"", with: "\\\"")
            return "\"\(escaped)\""
        } else {
            return s
        }
    }
}

// Get the current data in the pipe as text, useful for debugging
extension Pipe {
    var currentText: String? {
        let data = self.fileHandleForReading.availableData
        if !data.isEmpty {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }
}

public class LocalMCProcess {
    
    private let config: LocalMCPServerConfig
    private var process: Process?
    private var stdinPipe: Pipe?
    private var stdoutPipe: Pipe?
    private var stderrPipe: Pipe?
    
    var additionalPaths: [String]
    
    public init(config: LocalMCPServerConfig, additionalPaths: [String] = ["/usr/local/bin", "/usr/bin", "/bin:/usr/sbin", "/sbin"]) {
        self.config = config
        self.additionalPaths = additionalPaths
    }
    
    public func start() async throws -> Client {
        // Create pipes for stdin, stdout, and stderr
        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        
        // Create and configure the process
        let process = Process()
        process.executableURL = URL(fileURLWithPath: config.executablePath)
        process.arguments = config.arguments
        
        // Set environment variables if provided
        if !config.environment.isEmpty {
            var environment = ProcessInfo.processInfo.environment
            for (key, value) in config.environment {
                environment[key] = value
            }
            process.environment = environment
        }
        
        #warning("This should be configurable to add multiple path elements for things like node, python etc")
        if let path = process.environment?["PATH"], !self.additionalPaths.isEmpty {
            let additionalPathFragment = self.additionalPaths.joined(separator: ":")
            process.environment?["PATH"] = "\(path):\(additionalPathFragment)" // Add additional bin directores. Should be able to set this
        }
        
        // Connect pipes to the process
        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        
        // Store references to prevent deallocation
        self.process = process
        self.stdinPipe = stdinPipe
        self.stdoutPipe = stdoutPipe
        self.stderrPipe = stderrPipe
        
        self.process?.terminationHandler = { process in
            print("Process terminated \(process.terminationReason)")
        }
        
        // Launch the process
        let t = Task.detached {
            try process.run()
            try await process.waitUntilExit()
        }
        
        // Create StdioTransport
        let logger = Logger(label: "mcp.transport.process.\(config.name)")
        
        readErrorPipe(errorLogger: logger)
        
        // Convert FileHandles to FileDescriptors for StdioTransport
        let inputFD = FileDescriptor(rawValue: stdoutPipe.fileHandleForReading.fileDescriptor)
        let outputFD = FileDescriptor(rawValue: stdinPipe.fileHandleForWriting.fileDescriptor)
        
        let transport = StdioTransport(
            input: inputFD,
            output: outputFD,
            logger: logger
        )
        
        // Connect the client
        let client = Client(name: self.config.name, version: "1.0.0", configuration: .default)
        _ = try await client.connect(transport: transport)
        
        return client
    }
    
    private func readErrorPipe(errorLogger: Logger) {
        stderrPipe?.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty {
                if let errorMessage = String(data: data, encoding: .utf8) {
                    errorLogger.error("Error: \(errorMessage)")
                } else {
                    errorLogger.error("Failed to encode error message")
                }
            }
        }
    }
    
    public func stop() {
        // Terminate the process
        process?.terminate()
        
        // Close all file handles
        try? stdinPipe?.fileHandleForWriting.close()
        try? stdoutPipe?.fileHandleForReading.close()
        try? stderrPipe?.fileHandleForReading.close()
        
        // Clear references
        process = nil
        stdinPipe = nil
        stdoutPipe = nil
        stderrPipe = nil
    }
}

#endif
