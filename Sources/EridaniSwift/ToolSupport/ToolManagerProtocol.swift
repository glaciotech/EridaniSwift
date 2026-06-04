//
//  ToolManagerProtocol.swift
//  EridaniSwiftSDK
//
//  Created by Peter Liddle on 12/2/25.
//

import SwiftyPrompts
import MCP
import MCPHelpers

public protocol ToolManagerProtocol {
    
    associatedtype ToolResult: Codable
    
    var currentlyEnabled: Bool { get }
    var availableTools: [ToolNameComponents: MCP.Tool] { get }
    
    func handleToolCall(for toolCall: MCPToolCallRequest) async throws -> [MCP.Tool.Content]
    func load(toolConfigs: [LocalMCPServerConfig]) async throws
}


public protocol ToolRequestHandlerProtocol {
    func handleToolCall(for toolCall: MCPToolCallRequest) async throws -> [MCP.Tool.Content]
}
