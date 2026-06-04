//
//  MCPToolManager.swift
//  _EridaniSwiftSDK
//
//  Created by Peter Liddle on 11/23/25.
//

import Foundation
import MCP
import MCPHelpers
import SwiftyJsonSchema
import SwiftyPrompts

public enum UIEvents {
    case pushMCPMessage(Encodable)
    case showUIResource(Resource.Content)
}

public class MCPToolManager: ToolManagerProtocol {
    public typealias ToolResult = Tool.Content
    
    public var availableTools: [ToolNameComponents: MCPTool] = [:]
    
    private var toolClients = [ToolNameComponents: Client]()
    private var toolInfo = [ToolNameComponents: Tool]()
    
    public var toolMetaInfo = [ToolNameComponents: Tool.ToolMeta]()
    
    private var compoundToolNameToFull = [String: ToolNameComponents]() // We need this as we can't use a seperator compatible with a sendable toolname
    
    public var currentlyEnabled: Bool
    
    private var associatedUIStream: AsyncThrowingStream<Resource.Content, Error>?
    
    private var associatedUIContinuation: AsyncThrowingStream<UIEvents, Error>.Continuation?
    
    
    public init(currentlyEnabled: Bool = true) {
        self.currentlyEnabled = currentlyEnabled
    }
    
    public var uiStream: AsyncThrowingStream<UIEvents, Error> {
        let associatedUIStream = AsyncThrowingStream<UIEvents, Error>{ [weak self] continuation in
            self?.associatedUIContinuation = continuation
        }
        return associatedUIStream
    }
    
    public func resolveMetaInfo(from toolName: String) throws -> Tool.ToolMeta? {
        guard let fullName = compoundToolNameToFull[toolName], let client = toolClients[fullName] else {
            throw ToolManagerError.noMCPClientFoundForTool(toolName)
        }
        
        return toolMetaInfo[fullName]
    }

    public func readResource(for toolCall: MCPToolCallRequest, forUri uri: String) async throws -> [Resource.Content] {
        try await self.readResource(for: toolCall.toolName, forUri: uri)
    }
    
    public func readResource(for toolName: String, forUri uri: String) async throws -> [Resource.Content] {
        
        guard let fullName = compoundToolNameToFull[toolName], let client = toolClients[fullName] else {
            throw ToolManagerError.noMCPClientFoundForTool(toolName)
        }
        
        let resources = try await client.readResource(uri: uri)
        return resources
    }
    
    public func loadDirect(name: String, version: String, clientTransport: Transport) async throws {
        let client = Client(name: name, version: version)
        Task {
            let _ = try await client.connect(transport: clientTransport)
            try await handleLoadingClient(client, mcpServerName: name)
        }
    }
    
#if os(macOS)
    public func load(toolConfigs: [LocalMCPServerConfig] = []) async throws {
        
//        //// MARK: - Test MCP
//
//        // This is the path to the MCP server you wish to use, you can get the build directory from the Xcode project of the Example Server in Xcode in the Product -> Copy Build Folder Path menu item
//        // As written this loads the variable from an argument passed in at launch `-MCP_SERVER_BUILD_PATH` but you can hard code here if you prefer
//        guard let pathToMCPExampleServerBuildDirectory = UserDefaults.standard.string(forKey: "TEST_MCP_SERVER_BUILD_PATH") else {
//            fatalError("!!! YOU NEED TO DEFINE THE PATH TO YOUR MCP SERVER !!!")
//        }
//
//        // An example JSON config file for our MCP Server. Here we'll make use of the example MCP server we wrote in the article:
//        // Building a MCP Server in Swift: A Step-by-Step Guide - https://blog.glacio.tech/building-a-mcp-server-in-swift-a-step-by-step-guide
//        let jsonConfig = """
//            {
//              "name": "swift-mcp-server-example",
//                "executablePath": "\(pathToMCPExampleServerBuildDirectory)/Products/Debug/SwiftMCPServerExample",
//                "arguments": [],
//                "environment": {}
//            }
//        """
//        
//        ///Users/peterliddle/Library/Developer/Xcode/DerivedData/SwiftMCPServerExample-bsuwzxobxakbigcqrbrioirikeld/Build/Products/Debug/SwiftMCPServerExample
//        
//        
//        
//        let config = try jsonDecoder.decode(LocalMCPServerConfig.self, from: jsonConfig.data(using: .ascii)!)
        
        for config in toolConfigs {
            
            guard toolClients.keys.filter({ $0.toolName.hasPrefix(config.name) }).isEmpty else {
                continue
            }
            
            do  {
                // We need to handle loading multiple tools
                let mcp = LocalMCProcess(config: config)
                let client = try await mcp.start()
                try await handleLoadingClient(client, mcpServerName: config.name)
            }
            catch {
                Log.error("Failed to load MCP Server \(config.name) with error \(error)")
            }
        }
    }
    #else
    public func load(toolConfigs: [LocalMCPServerConfig] = []) async throws {
        fatalError("Only supported on macOS")
    }
    #endif
    
    private func handleLoadingClient(_ client: Client, mcpServerName: String) async throws {
        let toolListResponse = try await client.listTools()
        
        try toolListResponse.tools.forEach {
            
            let fullToolName = ToolNameComponents(mcpServer: mcpServerName, toolName: $0.name)
            guard availableTools[fullToolName] == nil else {
                // Already loaded
                return
            }
                    
            self.compoundToolNameToFull[fullToolName.fullName] = fullToolName
            try printToolInfo($0)
            toolClients[fullToolName] = client
            availableTools[fullToolName] = .init(name: fullToolName.fullName, description: $0.description, inputSchema: $0.inputSchema, annotations: $0.annotations)
            
            if let meta = $0.meta {
                toolMetaInfo[fullToolName] = meta
            }
        }
    }
    
    public func handleToolCall(for toolCall: MCPToolCallRequest) async throws -> [Tool.Content] {
        
        guard let fullName = compoundToolNameToFull[toolCall.toolName], let client = toolClients[fullName] else {
            throw ToolManagerError.noMCPClientFoundForTool(toolCall.toolName)
        }
        
        let result = try await client.callTool(name: fullName.toolName, arguments: toolCall.arguments.mapValues({ MCP.Value.init(from: $0) }))
        print("RESULT FROM TOOL CALL: \(result.content.first)")
        
        if let metaInfo = try self.resolveMetaInfo(from: toolCall.toolName), let uiResourceUri = metaInfo.ui?.resourceUri {
            let uiResource = try await self.readResource(for: toolCall, forUri: uiResourceUri)
            
            if let uiContent = uiResource.first {
                let data = uiContent.text   // How is this encoded?
                associatedUIContinuation?.yield(with: .success(.showUIResource(uiContent)))
            }
        }
        
        
        if let error = result.isError, error {
            // Assume error is text
            if let content = result.content.first, case let Tool.Content.text(fullContent) = content {
                
                let msg = fullContent.text
                
                // Most errors get sent back to the llm, but we try and catch errors like auth or insufficent funds.
                #warning("Add more sophisticated parsing logic to look for status codes")
                if msg.contains("Status code: 402") { // This assumes all tools return 402 for insufficent funds
                    throw ToolManagerError.unrecoverableErrorFromToolCall(fullName.fullName, msg)
                }
                else {
                    throw ToolManagerError.recoverableErrorFromToolCall(fullName.fullName, msg)
                }
            }
        }
        
        if let metaInfo = try self.resolveMetaInfo(from: toolCall.toolName), let uiResourceUri = metaInfo.ui?.resourceUri {
            associatedUIContinuation?.yield(with: .success(.pushMCPMessage(result.content)))
        }
        
        return result.content
    }
    
    // MARK: - Helpers
    let jsonEncoder = JSONEncoder()
    let jsonDecoder = JSONDecoder()
    
    func printToolInfo(_ tool: MCPTool) throws {
        print("--- TOOL INFO ---")
        print("Name: \(tool.name)")
        print("Annotations: \(tool.annotations)")
    
        do {
//            guard else {
//                print("ERROR: No input schema in Tool info")
//                return
//            }
            let rawInputSchema = tool.inputSchema
            let jsonSchema = try JSONSchema(fromMCPValue: rawInputSchema)
            print("Schema: \(jsonSchema)")
        }
        catch {
            print("!!! Problem reading schema !!!: \(error)")
        }
    
        print("------------")
    }
}
