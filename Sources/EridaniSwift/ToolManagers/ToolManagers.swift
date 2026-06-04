//
//  ToolManagers.swift
//  _EridaniSwiftSDK
//
//  Created by Peter Liddle on 11/23/25.
//

import Foundation
import SwiftyPrompts
import MCP
import MCPHelpers

public enum ToolManagerError: Swift.Error, LocalizedError, CustomStringConvertible {
    case errorCallingTool(String)
    case unrecoverableErrorFromToolCall(String, String)
    case recoverableErrorFromToolCall(String, String)
    case noMCPClientFoundForTool(String)
    
    public var errorDescription: String? {
        switch self {
            
        case let .errorCallingTool(msg):
            return "\(msg)"
        case let .unrecoverableErrorFromToolCall(name, msg):
            return "Tool \(name) returned error: \(msg)"
        case let .recoverableErrorFromToolCall(name, msg):
            return "Tool \(name) returned error: \(msg)"
        case let .noMCPClientFoundForTool(name):
            return "No MCP Tool was found for \(name) check it's still running"
        }
    }
    
    public var description: String {
        return errorDescription ?? "No error description"
    }
}

/// Placeholder ToolManager that does nothing, used to create ExchangeManagers where you don't need tool support
public class PassthroughToolManager: ToolManagerProtocol {

    public typealias ToolResult = String
    
    public var availableTools: [ToolNameComponents: MCP.Tool] = [:]
    public var currentlyEnabled: Bool = false
    
    public init() {}
    
    public func handleToolCall(for toolCall: SwiftyPrompts.MCPToolCallRequest) async throws -> [MCP.Tool.Content] {
        return []
    }
    
    public func load(toolConfigs: [LocalMCPServerConfig]) {
        return
    }
}

