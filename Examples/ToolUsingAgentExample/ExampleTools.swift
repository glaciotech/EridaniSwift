//
//  ExampleTools.swift
//  EridaniExampleSwiftUIChatApp
//
//  Created by Peter Liddle on 5/12/26.
//

import Foundation
import SwiftyJsonSchema
import MCPHelpers
import MCP
import Logging
#if canImport(WebKit)
import WebKit
#endif

let Log = {
    var log = Logger(label: "tech.eridani.toolexample")
    log.logLevel = .debug
    return log
}()

/// Class that allows us to start internal MCPs for Eridani
public final class EridaniToolsServer {
    
    let serverFactory: ExampleTools = ExampleTools()
    
    /// Create and start our  MCP service, we make use of a ServiceGroup to handle launching and shutting down the server
    public func start() async throws -> InMemoryTransport {
        
        Log.info("Eridani internal MCP server started")
        
        // Create the configured server with registered Tools and the MCP service
        let (clientTransport, serverTransport) = await InMemoryTransport.createConnectedPair(logger: Log)
        let server = await serverFactory.makeServer(with: Log)
        
        // Run the service group - this blocks until shutdown
        Task {
            do {
                try await server.start(transport: serverTransport)
            }
            catch {
                Log.error("Internal MCP server failed to start: \(error)")
            }
        }
        
        await Task.yield()
        
        return clientTransport
    }
}

/// MCPSeverFactory creates and configures our server with the example Tools and Prompts
class ExampleTools {
    
    static let serverDescription = """
        This MCP server provides a number of tools for use in the example research application
            - \(ExtractWebContentTool.name): A tool that allows for you to navigate to a url and extract the content
"""
    
    var llmAskCallback: ((String) -> String)?
    
    /// This creates a new instance of a configured MCP server with our Tools ready to go
    @preconcurrency func makeServer(with logger: Logger) async -> Server {
        // Create our server
        let server = Server(name: "i_EridaniExampleMCP",    //small i denotes internal
                            version: "1.0",
                            instructions: Self.serverDescription,
                            capabilities: .init(logging: Server.Capabilities.Logging(),
                                                resources: .init(subscribe: true, listChanged: true),
                                                tools: .init(listChanged: true)
                                               ))
        
        // Register the tools
        await registerTools(on: server)
        
        await server.withMethodHandler(CallTool.self, handler: handleToolCall)
        
        return server
    }
    
    func registerTools(on server: Server) async {
        
        /// Register a tool list handler
        await server.withMethodHandler(ListTools.self) { _ in
            return .init(tools: [
                    try ExtractWebContentTool.definition(),
                    try CreateFileTool.definition(),
                    try ReadFileTool.definition()
                ]
            )
        }
    }
    
    func handleToolCall(params: CallTool.Parameters) async throws -> CallTool.Result {
        
        let tool = params.name
        
        do {
            switch tool {
            case ExtractWebContentTool.name:
                return try await ExtractWebContentTool().extractHTML(with: params)
            case CreateFileTool.name:
                return try await CreateFileTool().createFile(with: params)
            case ReadFileTool.name:
                return try await ReadFileTool().readFile(with: params)
            default:
                Log.error("Unkown tool called")
                return .init(content: [.text("Call to unknown tool")], isError: true)
            }
        }
        catch let error {
            return .init(content: [.text(error.localizedDescription)], isError: true)
        }
    }
}



public struct ExtractWebContentTool: ToolDefinitonProtocol {
  
    public static var annotations = Tool.Annotations(readOnlyHint: true, destructiveHint: false, idempotentHint: false, openWorldHint: true)
   
    public static var resourceUri: String? = nil

    public struct ExtractWebContentRequest: ProducesJSONSchema, ParamInitializable {
        public static var exampleValue: ExtractWebContentTool.ExtractWebContentRequest = ExtractWebContentRequest()
        
        @JSONSchemaMetadata(description: "URL for the webpage to extract content from")
        var url: String = ""
    }
    
    public typealias Schema = ExtractWebContentRequest
    
    public static var name: String = "ExtractWebContent"
    
    public static var description: String = "Extract the contents of a webpage from the given url and return as markdown"
    
    public init() {}
    
    public func extractHTML(with params: CallTool.Parameters) async throws -> CallTool.Result {
        let request = try ExtractWebContentRequest(with: params)
        let html = try await self.extractBodyHTML(from: URL(string: request.url)!)
        return .init(content: [.text(html)])
    }
    
    public func extractBodyHTML(from url: URL, timeout: TimeInterval = 300) async throws -> String {
        
        let request = URLRequest(url: url)
        let response = try await URLSession.shared.data(for: request)
        let data = response.0
        
        guard let string = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "Something went wrong no content returned from url", code: 0)
        }
        
        return string
    }
}

protocol FileTools { }

extension FileTools {
    
    internal var fileStorageDirectory: URL {
        let fileManager = FileManager.default
        let fileStorageDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        Log.debug("File Tool storage directory: \(fileStorageDirectory.path)")
        return fileStorageDirectory
    }
}

struct CreateFileTool: ToolDefinitonProtocol, FileTools {
    
    public static var annotations = Tool.Annotations(readOnlyHint: false, destructiveHint: false, idempotentHint: true, openWorldHint: false) // Mark file interaction as false for example as sandboxed to own app directory
    
    static var resourceUri: String? = nil
    
    typealias Schema = CreateFileRequest
    
    static let name: String = "CreateFile"
    
    static let description: String = "Creates or updates a file with the filename provided in the request saving it to the apps document directory"
    
    struct CreateFileRequest: ProducesJSONSchema, ParamInitializable {
        static let exampleValue = CreateFileRequest(name: "binsr.pdf", content: "This is a quick note")
        
        @JSONSchemaMetadata(description: "The name or the file to store")
        var name: String = ""
        
        @JSONSchemaMetadata(description: "The contents of the file to create or update")
        var content: String = ""
    }
    
    func createFile(with params: CallTool.Parameters) async throws -> CallTool.Result {
        let request = try Self.CreateFileRequest(with: params)

        let fileURL = fileStorageDirectory.appendingPathComponent(request.name, isDirectory: false)
        let data = Data(request.content.utf8)
        try data.write(to: fileURL, options: [.atomic])
        
        let relativePath = fileURL.path.replacingOccurrences(of: fileStorageDirectory.path, with: "")
        return .init(content: [.text("Created file \"\(relativePath)\"")])
    }
}

    
public struct ReadFileTool: ToolDefinitonProtocol, FileTools {
    
    public static var annotations = Tool.Annotations(readOnlyHint: true, destructiveHint: false, idempotentHint: nil, openWorldHint: false) // Mark file interaction as false for example as sandboxed to own app directory
    
    public static var resourceUri: String? = nil
    
    public typealias Schema = ReadFileRequest
    
    public static var name: String = "ReadFile"
    
    public static var description: String = "Reads the contents of a file with the name given in the request from the apps document directory"
    
    public init() {}
    
    private let jsonDecoder = JSONDecoder()
    
    public struct ReadFileRequest: ProducesJSONSchema, ParamInitializable {
        public static let exampleValue = ReadFileRequest(name: "binsr.pdf")
        
        @JSONSchemaMetadata(description: "The path to the file to retrieve")
        public var filePath: String = ""
        
        public init(name: String) {
            self.filePath = name
        }
    }
    
    /// Read the file contents at the given location given by path in the request
    /// - Parameter params: Parameters that can be decoded to a ReadFileRequest object
    /// - Returns: The contents of the file
    func readFile(with params: CallTool.Parameters) async throws -> CallTool.Result {
        let request = try ReadFileRequest(with: params)
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: fileStorageDirectory, withIntermediateDirectories: true)

        let fileURL = fileStorageDirectory.appending(path: request.filePath, directoryHint: .notDirectory)
        let data = try Data(contentsOf: fileURL)

        guard let string = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "Invalid file contents found. Not text", code: 0)
        }
        
        return .init(content: [.text(string)])
    }
}
