//
//  ToolApprovalCoordinator.swift
//  EridaniSwift
//
//  Created by Peter Liddle on 5/15/26.
//

import Foundation
import MCP
import SwiftyPrompts

public enum ToolApprovalError: Error, LocalizedError {
    case denied(_ reason: String? = nil)
    
    public var errorDescription: String? {
        switch self {
        case .denied(let reason):
            return "Tool use was denied with reason: \(reason ?? "none given")"
        }
    }
}

public struct ToolApprovalRequest {
    public let id: String
    public let toolName: String
    public let toolDescription: String?
    public let serverName: String?
    public let arguments: [String: Any]?
    public let annotations: MCP.Tool.Annotations
    
    public init(from toolRequest: MCPToolCallRequest, with annotations: MCP.Tool.Annotations) {
        self.id = toolRequest.callId
        self.toolName = toolRequest.toolName
        self.toolDescription = toolRequest.description
        self.serverName = "toolRequest."
        self.arguments = toolRequest.arguments
        self.annotations = annotations
    }
}

public enum ToolApprovalDecision {
    case allow
    case deny
}

public class ToolExecutionUserApprovalCoordinator: ToolCallAuthorizer {
    
    private var continuations = [String: CheckedContinuation<ToolApprovalDecision, Never>]()
    private var toolManager: any ToolManagerProtocol
    private var approvalScreener: any RequiresApprovalScreener
    
    private var approvalRequestStream: AsyncStream<ToolApprovalRequest>?
    private var approvalRequestContinuation: AsyncStream<ToolApprovalRequest>.Continuation?
    
    public init(toolManager: any ToolManagerProtocol, approvalScreener: any RequiresApprovalScreener = ConservativeAnnotationCheckScreener()) {
        self.toolManager = toolManager
        self.approvalScreener = approvalScreener
    }
    
    public func approvalEventStream() -> AsyncStream<ToolApprovalRequest> {
        if approvalRequestStream == nil {
            self.approvalRequestStream = AsyncStream<ToolApprovalRequest> { [weak self] continuation in
                self?.approvalRequestContinuation = continuation
            }
        }
        return approvalRequestStream!
    }
    
    func requestApproval(_ request: ToolApprovalRequest) {
        approvalRequestContinuation?.yield(request)
    }

    func waitForDecision(id: String) async -> ToolApprovalDecision {
        await withCheckedContinuation { continuation in
            continuations[id] = continuation
        }
    }

    public func submitDecision(id: String, decision: ToolApprovalDecision) {
        let continuation = continuations.removeValue(forKey: id)
        continuation?.resume(returning: decision)
    }
    
    public func authorize(_ toolCall: SwiftyPrompts.MCPToolCallRequest) async throws {
        let toolName = toolCall.toolName
        
        Log.debug("Checking if \(toolName) Requires approval")
        
        // Check if tool requires approval
        guard let tool = try? self.toolManager.availableTools[.init(fullName: toolName)] else {
            return
        }
       
        if approvalScreener.requiresApproval(for: tool) {

            Log.debug("\(toolName) Does require approval")
            
            // Request approval from user
            self.requestApproval(.init(from: toolCall, with: tool.annotations))
            
            guard await self.waitForDecision(id: toolCall.callId) == .allow else {
                throw ToolApprovalError.denied("User denied tool call")
            }
        }
    }
}


